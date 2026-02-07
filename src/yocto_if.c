#include "yocto_if.h"
//#include "i2c_io.h"
#include "queue.h"
//#include "val_msg.h"
//#include "proto_wl1.h"
#include "proto_wl2.h"
#include "proto_wl3.h"
#include "proto_wl4.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/time.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <fcntl.h>
#include <termios.h>

#include <string.h>
#include "debug.h"
#include "driving_mgr.h"
#include "gps.h"

#define PKT_STX 0xFD
#define PKT_ETX 0xFE


// I2C 설정 (환경에 맞게 수정 필요)
//#define I2C_BUS_YOCTO  "/dev/i2c-1"
//#define YOCTO_ADDR      0x42
#define HOST_NOTIFY_PORT 38474  // run.sh 등 호스트 프로세스와의 소켓 IPC 포트 (trigger_send 바이너리 호환)
#define TRIGGER_BINARY_SIZE 6   /* 거리32 + 방향8 + 위험8 = 6 bytes (trigger_send.c와 동일) */
#define MY_LANE 2               // 내 차선 번호 (1→L, 2→F, 3→R 기준)       

extern queue_t q_wl_sec;     // 수신 파이프라인 시작점
extern queue_t q_yocto_pkt_tx; // 송신 파이프라인 시작점

extern driving_status_t g_driving_status;

extern queue_t q_val_pkt_tx, q_val_yocto, q_rx_sec_rx;
extern volatile bool g_keep_running;
extern uint32_t g_sender_id;
extern queue_t q_pkt_val;
extern queue_t q_val_yocto; // VAL -> Yocto (WL-2 송신: 가장 가까운 사고 정보)
extern queue_t q_yocto_to_driving;  // Yocto_IF -> Driving (WL-4 수신: 주행정보)
extern queue_t q_pkt_sec_tx;
extern queue_t q_yocto_if_to_pkt_tx; // Yocto_IF -> PKT (WL-3 수신: 내 사고 직통 큐)

// 시간 측정을 위한 유틸리티 함수
static uint64_t get_now_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;
}
/** 127.0.0.1:HOST_NOTIFY_PORT 로 바이너리 IPC 전송 (trigger_send_binary 형식: 거리32bit + 방향8bit + 위험8bit) */
static void send_binary_to_host(const void *buf, size_t len) {
    if (!buf || len == 0) return;
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) return;
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(HOST_NOTIFY_PORT);
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);
    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(s);
        return;
    }
    send(s, buf, len, 0);
    close(s);
}

// 정밀 주기 제어 함수
static void wait_next_period(struct timespec *next, long ms) {
    next->tv_nsec += ms * 1000000L;
    while (next->tv_nsec >= 1000000000L) {
        next->tv_sec++;
        next->tv_nsec -= 1000000000L;
    }
    clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, next, NULL);
}


// UART1 초기화 함수: 포트 설정(9600bps, 8N1, Raw Mode)
int UART1_init(void) {
    int fd = open(UART1_DEV, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fd < 0) return -1;

    struct termios opt;
    tcgetattr(fd, &opt);
    cfsetispeed(&opt, B9600);
    cfsetospeed(&opt, B9600);

    opt.c_cflag |= (CLOCAL | CREAD);
    opt.c_cflag &= ~PARENB;   // 패리티 없음
    opt.c_cflag &= ~CSTOPB;   // 정지 비트 1
    opt.c_cflag &= ~CSIZE;
    opt.c_cflag |= CS8;       // 데이터 8비트

    // 중요: 바이너리 패킷 보존을 위한 Raw Mode 설정
    opt.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    opt.c_iflag &= ~(IXON | IXOFF | IXANY);
    opt.c_oflag &= ~OPOST;

    tcsetattr(fd, TCSANOW, &opt);
    return fd;
}

void* thread_yocto_if(void* arg) {
    (void)arg;
    
    // 1. UART1 포트 오픈
    int uart_fd = UART1_init();
    if (uart_fd < 0) {
        DBG_ERR("[T9] UART1 (/dev/ttyAMA1) Open Failed!");
        return NULL;
    }

    // 2. 정밀 시간 설정을 위한 구조체
    struct timespec next_time;
    clock_gettime(CLOCK_MONOTONIC, &next_time);

    //uint32_t loop_cnt = 0;
    // 50ms 루프 기준으로 30초는 600번 루프 (30,000ms / 50ms = 600)
    //const uint32_t wl4_trigger = (PERIOD_WL4_S * 1000) / PERIOD_YOCTO_MS;

    DBG_INFO("Thread 9: Yocto Interface Module started (UART3 Mode).");
    DBG_INFO("[T9] UART3 모듈 시작 (WL2/3: 50ms, WL4: 30s 주기)");

    while (g_keep_running) {
        // 50ms 정밀 주기 제어 (WL-2, WL-3을 위해 빠르게 회전)
        wait_next_period(&next_time, PERIOD_YOCTO_MS);

        // --- [A] 송신: VAL에서 온 가장 가까운 사고 정보(WL-2)를 Yocto로 전송 ---
        // 10바이트 규격(16비트 거리 포함)으로 조립된 WL-2 패킷을 꺼냅니다.
        /*wl2_packet_t *wl2 = (wl2_packet_t *)Q_pop_nowait(&q_val_yocto);
        if (wl2) {
            // 정수형으로 통일된 10바이트 구조체를 UART로 송신합니다.
            int expected_len = sizeof(wl2_packet_t); // 10바이트
            int tx_res = write(uart_fd, wl2, sizeof(wl2_packet_t));
            // [수정] 0보다 큰 것뿐만 아니라, 전체 길이가 다 나갔는지 확인
            if (tx_res == expected_len) {
                // 성공: 10바이트 완벽 전송
                // DBG_INFO("[T9-TX] WL-2 Full Sent (%d bytes)", tx_res);
            } else if (tx_res > 0) {
                // 일부 전송됨 (데이터 유실 가능성)
                DBG_WARN("[T9-TX] WL-2 Partial Write: %d / %d bytes", tx_res, expected_len);
            } else {
                // 전송 실패 (포트 오류 등)
                perror("[T9-TX] UART Write Error");
            }
            free(wl2);
            wl2 = NULL;
        }*/
        //uint8_t rx_buf[256] = {0};
        //int rx_len = read(uart_fd, rx_buf, sizeof(rx_buf)); // <-- read 호출이 여기 있어야 함

        // --- [A] 송신: VAL에서 온 가장 가까운 사고 정보(WL-2) 처리 ---
        wl2_packet_t *wl2 = (wl2_packet_t *)Q_pop_nowait(&q_val_yocto);
        if (wl2) {
            // 1. UART로 Yocto에 10바이트 규격 패킷 전송
            int expected_len = sizeof(wl2_packet_t);
            int tx_res = write(uart_fd, wl2, expected_len);

            if (tx_res == expected_len) {
                // 2. [추가] 송신 성공 시, 호스트(38474 포트)로 디스플레이용 바이너리 전송
                // 주석에 있던 로직을 UART 모드에 맞춰 통합
                uint16_t dist = wl2->distance; // WL-2 구조체의 거리 정보
                uint8_t sev = wl2->severity;  // 위험도 (0: 일반, 1: 위험)
                
                // 차선(lane)에 따른 방향 설정 (1:L, 2:F, 3:R)
                uint8_t dir = (wl2->lane == 1) ? 'L' : (wl2->lane == 2) ? 'F' : (wl2->lane == 3) ? 'R' : 'F';
                // 위험도 매핑 (sev 0->1, 1->3 등 필요에 따라 조정)
                uint8_t danger = (sev == 0) ? 1 : 3; 

                uint32_t dist_be = htonl((uint32_t)dist); // 32bit Big-Endian 변환
                unsigned char bin[TRIGGER_BINARY_SIZE];
                
                memcpy(bin, &dist_be, 4);
                bin[4] = dir;
                bin[5] = danger;

                // 디스플레이 프로세스로 전송
                send_binary_to_host(bin, TRIGGER_BINARY_SIZE);
                
                DBG_INFO("[T9-TX] WL-2 Sent (UART & Host Notify) -> Dist:%dm, Dir:%c", dist, dir);
            } else {
                DBG_WARN("[T9-TX] UART Write Failed or Partial: %d/%d", tx_res, expected_len);
            }

            free(wl2);
            wl2 = NULL;
        }


        // --- [B] 수신: Yocto로부터 데이터 읽기 (WL-3, WL-4) ---
        uint8_t rx_buf[512] = {0};
        int rx_len = read(uart_fd, rx_buf, sizeof(rx_buf));

        if (rx_len > 0) {
        //uint8_t type = rx_buf[0];
        //DBG_INFO("yocto로부터 uart3으로 메세지 받음 %lX, %d, %d \r\n", rx_buf, rx_len, type);
        // [수정] 여기서 바로 type을 쓰면 에러가 납니다. (아직 선언 안 됨)
            // 대신 데이터가 들어왔다는 사실과 길이만 먼저 찍어보세요.
        DBG_INFO("[T9] UART Data Received: %d bytes", rx_len);
        
        // [검색 루프] 뭉친 데이터 속에서 PKT_STX(0xFD)를 찾음
        for (int i = 0; i < rx_len; i++) {
            // 1. 시작 신호(0xFD) 탐색
            if (rx_buf[i] == PKT_STX) {
                if (i + 1 >= rx_len) break; // 타입 확인 불가

                uint8_t type = rx_buf[i + 1];

                // --- WL-4 처리 (8바이트) ---
                // Case 1: WL-4 수신 (8바이트: STX + Type + Data(5) + ETX)
                if (type == TYPE_WL4 && (i + 7) < rx_len) {
                    if (rx_buf[i + 7] == PKT_ETX) {
                        wl4_packet_t *wl4 = malloc(sizeof(wl4_packet_t));
                       if (wl4) {
                                memcpy(wl4, &rx_buf[i], sizeof(wl4_packet_t));
                                Q_push(&q_yocto_to_driving, wl4);
                                
                                uint16_t dir = wl4_get_direction(*wl4);
                                DBG_INFO("[T9-RX] WL-4 수신: 방향(%d), 시간(%d)", dir, wl4->timestamp);
                            }
                            i += 7; // 패킷 크기만큼 건너뜀
                            continue;
                        }
                }

               // --- WL-3 처리 (26바이트로 수정) ---
                // Case 2: WL-3 수신 (26바이트: STX + Type + Pad + Time(2) + Data(20) + ETX)
                else if (type == TYPE_WL3 && (i + 25) < rx_len) {
                    if (rx_buf[i + 25] == PKT_ETX) {
                        wl3_packet_t *wl3 = malloc(sizeof(wl3_packet_t));
                       if (wl3) {
                                // 구조체 크기(26바이트)만큼 한 번에 복사
                                memcpy(wl3, &rx_buf[i], sizeof(wl3_packet_t));
                                // WL-3 특정 필드 추출 (필요 시)
                                //wl3->accident_id = *((unsigned long long*)(rx_buf + i + 16));
                                //wl3->lane = *(rx_buf + i + 5);
                                // [참고] 이제 memcpy로 모든 필드가 들어왔으므로 
                                // 아래와 같은 수동 추출은 생략하거나 구조체 멤버로 접근하면 됩니다.
                                // 예: wl3->accident_id = ... (이미 memcpy로 들어옴)

                                Q_push(&q_yocto_if_to_pkt_tx, wl3);
                                DBG_INFO("\x1b[32m[T9-RX] WL-3 수신: 내 사고 데이터 전달\x1b[0m");
                         
                            }
                        i += 25; // [수정] 패킷 크기만큼 점프
                        continue;
                    }
                }







            }
       } // for loop 끝
        } // if rx_len 끝
    } // while loop 끝

    close(uart_fd);
    return NULL;
}





        // [2] 데이터 송신 처리 (WL-2 결과 전송)
        /*wl2_packet_t *wl2 = (wl2_packet_t *)Q_pop_nowait(&q_val_yocto);
        if (wl2) {

            /*uint16_t distance = (wl2->dist_rsv >> 4); 
            */
            //printf("\x1b[35m[T9-TX-SIM] WL-2 Result -> Dist: %dm, Lane: %d\x1b[0m\n", wl2_get_distance(wl2), wl2->lane);


            // 실제 I2C 전송 (i2c_io.c의 함수 사용)
            /*int tx_res = I2C_write_data(I2C_BUS_YOCTO, YOCTO_ADDR, (uint8_t*)wl2, sizeof(wl2_packet_t));
            if (tx_res > 0) {
                printf("\x1b[35m[T9-TX-HW] WL-2 Result Sent to Yocto\x1b[0m\n");
                /* wl2 파싱 후 trigger_send_binary 호환 6바이트 전송: 거리(32bit BE) + 방향(8bit) + 위험도(8bit) */
                /*uint16_t dist = wl2_get_distance(wl2);
                uint8_t sev = wl2_get_severity(wl2);
                uint8_t dir = (wl2->lane == 1) ? 'L' : (wl2->lane == 2) ? 'F' : (wl2->lane == 3) ? 'R' : (uint8_t)'F';
                uint8_t danger = (sev == 0) ? 1 : (sev == 1) ? 2 : 3;  /* 위험도 1, 2, 3 */
                /*uint32_t dist_be = htonl((uint32_t)dist);
                unsigned char bin[TRIGGER_BINARY_SIZE];
                memcpy(bin, &dist_be, 4);
                bin[4] = dir;
                bin[5] = danger;
                send_binary_to_host(bin, TRIGGER_BINARY_SIZE);
            }
            free(wl2); // 송신 후 메모리 해제
        }
        loop_cnt++;
    }
    return NULL;
}*/
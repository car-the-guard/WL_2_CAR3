#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "proto_wl1.h"
#include "queue.h"
#include "driving_mgr.h"

extern queue_t q_rx_filter; // 필터 입구 큐
extern driving_status_t g_driving_status;
extern uint32_t g_sender_id;

// 테스트용 패킷 생성 헬퍼 함수
wl1_packet_t* create_test_packet(uint32_t s_id, double lat_offset, double lon_offset, uint8_t sev, uint8_t lane) {
    wl1_packet_t *pkt = (wl1_packet_t *)malloc(sizeof(wl1_packet_t));
    memset(pkt, 0, sizeof(wl1_packet_t));

    pkt->header.msg_type = 0x00; // 사고 메시지
    pkt->sender.sender_id = s_id;
    
    // 내 현재 위치 기준으로 상대적 좌표 설정 (uDeg 단위)
    pkt->accident.lat_uDeg = (int32_t)((g_driving_status.lat + lat_offset) * 1000000);
    pkt->accident.lon_uDeg = (int32_t)((g_driving_status.lon + lon_offset) * 1000000);
    pkt->accident.severity = sev;
    pkt->accident.lane = lane;
    pkt->accident.direction = g_driving_status.heading; // 나랑 같은 방향 사고 가정
    pkt->accident.accident_id = (uint64_t)rand();

    return pkt;
}

void run_filter_test() {
    printf("\n[TEST] V2X 필터링 및 상태관리 테스트 시작...\n");

    // 상황 1: 루프백 차단 테스트 (내 ID와 동일)
    printf("1. 내 패킷(Loopback) 차단 테스트 중...\n");
    Q_push(&q_rx_filter, create_test_packet(g_sender_id, 0.001, 0, 1, 1));
    sleep(3);
    
    // 상황 2: 후방 사고 차단 테스트 (is_forward 확인)
    printf("2. 후방 사고(내 뒤 100m) 차단 테스트 중...\n");
    // 위도가 북쪽일 때 위도를 깎으면 내 뒤쪽(남쪽)이 됨
    Q_push(&q_rx_filter, create_test_packet(0xAAAA, -0.001, 0, 1, 1));
    sleep(3);

    // 상황 3: RSU 긴급 통과 테스트 (Sender ID <= 0x0FFF)
    printf("3. RSU 패킷(긴급 큐) 통과 테스트 중...\n");
    Q_push(&q_rx_filter, create_test_packet(0x0100, 0.002, 0, 1, 1));
    sleep(3);

    // 상황 4: 200m 이내 초근접 사고 (긴급 큐)
    printf("4. 초근접 사고(50m) 긴급 통과 테스트 중...\n");
    Q_push(&q_rx_filter, create_test_packet(0xBBBB, 0.0004, 0, 1, 1));
    sleep(3);

    // 상황 5: 3차선 환경 차선 걸침 (1, 2차선 점유 0x03)
    printf("5. 다중 차선 점유(0x03) 업데이트 테스트 중...\n");
    Q_push(&q_rx_filter, create_test_packet(0xCCCC, 0.003, 0, 2, 0x03));
    sleep(3);

    // 상황 6: 자동 해제(Passing) 테스트
    printf("6. 사고 지점 통과(Passing Logic) 시뮬레이션...\n");
    wl1_packet_t *p_pass = create_test_packet(0xDDDD, 0.0001, 0, 1, 2);
    uint64_t pass_id = p_pass->accident.accident_id;
    Q_push(&q_rx_filter, p_pass);
    
    sleep(1); // VAL 리스트에 등록될 시간 확보
    printf("   -> 차량 전진 시뮬레이션 (사고 지점 뒤로 이동)...\n");
    pthread_mutex_lock(&g_driving_status.lock);
    g_driving_status.lat += 0.001; // 사고 지점을 내 뒤로 만듦
    pthread_mutex_unlock(&g_driving_status.lock);
    
    // 1초 뒤 VAL 리스트에서 0xDDDD가 사라졌는지 로그로 확인 필요
}

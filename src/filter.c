#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include "filter.h"
#include "v2x_util.h"
#include "queue.h"
#include "proto_wl1.h"
#include "driving_mgr.h"

#define RSU_ID_MAX    0x0FFF
#define MAX_RANGE     1000.0
#define HEADING_LIMIT 45
#define CRITICAL_DIST 200.0 


extern uint32_t g_sender_id;
extern driving_status_t g_driving_status;
extern queue_t q_rx_filter, q_filter_sec_rx, q_filter_sec_urgent; // thread_rx -> filter -> sec 경로용 큐
extern volatile bool g_keep_running;

void *thread_filter(void *arg) {
    printf("[FILTER] Thread Started: Physical Gateway Mode\n");

    while (g_keep_running) {
        wl1_packet_t *pkt = Q_pop(&q_rx_filter);
        if (!pkt) { usleep(1000); continue; }

        // 1. 루프백(내 패킷) 차단
        if (pkt->sender.sender_id == g_sender_id) {
            free(pkt); continue;
        }

        // 2. 내 현재 위치 및 방향 정보 스냅샷
        pthread_mutex_lock(&g_driving_status.lock);
        double my_lat = g_driving_status.lat;
        double my_lon = g_driving_status.lon;
        int my_head = g_driving_status.heading;
        pthread_mutex_unlock(&g_driving_status.lock);

        double t_lat = (double)pkt->accident.lat_uDeg / 1000000.0;
        double t_lon = (double)pkt->accident.lon_uDeg / 1000000.0;

        // 3. 거리 및 전방 유효성 필터 (물리적 입구 컷)
        double dist = calc_dist(my_lat, my_lon, t_lat, t_lon);
        bool forward = is_forward(my_lat, my_lon, my_head, t_lat, t_lon);

        if (dist > MAX_RANGE || !forward) {
            // 너무 멀거나 뒤쪽 패킷은 보안 스레드로 보내지 않음
            free(pkt); continue;
        }

        // 4. 주행 방향성 필터 (반대 차선 사고 제외)
        int h_diff = get_angle_diff(my_head, pkt->accident.direction);
        if (h_diff > HEADING_LIMIT) {
            free(pkt); continue;

        }

        // --- [L3 단계] 긴급도 분류 및 큐 삽입 (새로 추가된 로직) ---
        
        // 1. RSU 패킷 (키 접두사 기반)
        bool is_rsu = (pkt->sender.sender_id <= RSU_ID_MAX);
        // 2. 심각도가 3(최상위)인 경우
        bool is_high_severity = (pkt->accident.severity >= 3);
        // 3. 사고 지점이 200m 이내로 매우 가까운 경우
        bool is_very_close = (dist <= CRITICAL_DIST);

        if (is_rsu || is_high_severity || is_very_close) {
            // 긴급/우선순위 패킷: 우선순위 큐(q_filter_sec_urgent)로 전송
            // 만약 별도 큐가 없다면 일반 큐의 가장 앞으로 넣는(Push_Front) 등의 처리가 필요합니다.
            Q_push(&q_filter_sec_urgent, pkt); 
            printf("[FILTER-PRIORITY] Urgent Packet Sent! ID: 0x%lX, Dist: %.1fm\n", 
                    pkt->accident.accident_id, dist);
        } 
        else {
            // 일반 패킷: 일반 검증 큐로 전송
            Q_push(&q_filter_sec_rx, pkt);
        }

        // 5. 통과: 모든 유효 패킷은 보안 스레드로 전달 (동일 ID 중복 체크 없음)
        // RSU이거나 Severity가 높으면 우선순위 처리 가능 (현재는 일반 Push)
        //Q_push(&q_filter_sec_rx, pkt);
    }
    return NULL;
}

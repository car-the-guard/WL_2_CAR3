#include "gps.h"
#include "val.h"
#include "debug.h"
#include <unistd.h>
#include <math.h>
#include "driving_mgr.h"

extern volatile bool g_keep_running;
extern driving_status_t g_driving_status;

// [1] GPS 초기화 함수 구현
void GPS_init(void) {
    DBG_INFO("GPS: Mock Mode Initialized.");
}

// [2] 최신 데이터 반환 함수 구현 
gps_data_t GPS_get_latest(void) {
    gps_data_t data;
    
    // 현재 전역 상태에 업데이트된 값을 가져온다.
    pthread_mutex_lock(&g_driving_status.lock);
    data.lat = g_driving_status.lat;
    data.lon = g_driving_status.lon;
    data.alt = (double)g_driving_status.alt;
    pthread_mutex_unlock(&g_driving_status.lock);
    
    return data;
}

/**
 * GPS 정보를 수집하여 전역 차량 상태를 업데이트하는 스레드
 */
void *thread_gps(void *arg) {
    DBG_INFO("Thread 7: GPS Client Module started.");

    //// [고정값 설정] 차3 기준
    //double current_lat = 37.5618; // (사고차와 논리적 거리 약 1,000m)

    // 이동 속도 설정 (약 0.0001도 ~= 11.1m)
    // 1초에 한 번씩 약 11m씩 전진하도록 설정
    double step = 0.0001;

     // [고정값 설정] 차2 기준 => 차1로부터 사고 정보 수신하는 지 확인하기 위해서 임시로 추가함.
    double current_lat = 37.5654; // (사고차와 논리적 거리 약 400m) 
    double current_lon = 126.9780;
    double current_alt = 15.0; // 고도 기본값

    while (g_keep_running) {
       
        // --- [핵심] 위도값을 조금씩 줄여서 사고 지점으로 접근 시뮬레이션 ---
        // 사고 지점이 37.5618 근처라면, 37.5654에서 계속 줄어들어야 접근함.
        // -=였는데 거리가 멀어져서 +=로 변경
        current_lat += step;

        pthread_mutex_lock(&g_driving_status.lock);
        g_driving_status.lat = current_lat;
        g_driving_status.lon = current_lon;
        g_driving_status.alt = current_alt; 
        pthread_mutex_unlock(&g_driving_status.lock);

        // 너무 잦은 업데이트 방지 (10Hz: 100ms)
        usleep(1000000); 
       
        // 매 초마다 현재 내 위치 로그 출력
        printf("[GPS-SIM] 내 차 이동 중... Lat: %.6f, Lon: %.6f\n", current_lat, current_lon);

        // 10초마다 로그 출력
        //static int count = 0;
        //if (++count % 100 == 0) {
                    //printf("[GPS-FIXED] 차2 위치: Lat %.6f, Lon %.6f, Alt %.1f\n", 
                    //current_lat, current_lon, current_alt);
        //}
        // 만약 특정 지점까지 가면 멈추거나 리셋하는 로직 (선택사항)
        //if (current_lat < 37.5704) {
        if (current_lat > 37.5800) {
            current_lat = 37.5654; // 다시 처음 위치로 리셋 (무한 반복 테스트용)
            DBG_INFO("GPS: 위치 리셋 (시뮬레이션 반복)");
        }
    }


    DBG_INFO("Thread 7: GPS Client Module terminating.");
    return NULL;
}

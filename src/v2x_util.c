#include "v2x_util.h"
#include <math.h>
#include <stdlib.h>

bool is_forward(double my_lat, double my_lon, int my_head, double target_lat, double target_lon) {
    // 1. 위경도 차이를 미터 단위로 근사 (한국 위도 기준)
    double dx = (target_lon - my_lon) * 88804.0; 
    double dy = (target_lat - my_lat) * 111319.9;

    // 2. 내 헤딩을 수학적 라디안으로 변환 (0도 북쪽 -> 시계방향 기준)
    double rad = (90.0 - (double)my_head) * M_PI / 180.0;
    
    // 3. 내 주행 방향 단위 벡터
    double vx = cos(rad);
    double vy = sin(rad);

    // 4. 내적(Dot Product): v · d
    // 결과가 0보다 크면 전방, 0보다 작으면 후방
    return (dx * vx + dy * vy) > 0;
}

double calc_dist(double lat1, double lon1, double lat2, double lon2) {
    double dlat = (lat2 - lat1) * 111319.9;
    double dlon = (lon2 - lon1) * 88804.0;
    return sqrt(dlat * dlat + dlon * dlon);
}

int get_angle_diff(int a, int b) {
    int diff = a - b;
    if (diff < 0) diff = -diff; // 정수 절대값 처리
    
    if (diff > 180) {
        diff = 360 - diff;
    }
    return diff;
}

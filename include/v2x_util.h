#ifndef V2X_UTIL_H
#define V2X_UTIL_H

#include <stdbool.h>

/**
 * @brief 벡터 내적을 이용해 목표 지점이 전방인지 판별
 * @return true: 전방 180도 이내, false: 후방
 */
bool is_forward(double my_lat, double my_lon, int my_head, double target_lat, double target_lon);

/**
 * @brief 두 지점 간의 거리 계산 (미터 단위)
 */
double calc_dist(double lat1, double lon1, double lat2, double lon2);

/**
 * @brief 헤딩 차이 계산 (0~180도)
 */
int get_angle_diff(int a, int b);

#endif

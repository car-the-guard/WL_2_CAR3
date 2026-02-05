#ifndef PKT_H
#define PKT_H

#include "proto_wl1.h"
#include "proto_wl2.h"
#include "proto_wl3.h"

// [Thread 2] 패킷 모듈: WL-1 조립/파싱 및 WL-3 <-> WL-1 래핑
void *thread_pkt(void *arg);
// 수신 후 필터: q_rx_filter → (자기 패킷 제거) → q_rx_sec_rx
void *sub_thread_filter(void *arg);

// 헬퍼 함수: WL-3(Yocto 수신) 데이터를 WL-1(무선 송신)로 조립
void PKT_assemble_wl1(wl1_packet_t *dst, const wl3_packet_t *src);

// 헬퍼 함수: WL-1(무선 수신) 데이터를 WL-2(Yocto 송신용 요약)로 변환
void PKT_convert_wl1_to_wl2(wl2_packet_t *dst, const wl1_packet_t *src);

#endif

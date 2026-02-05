#!/bin/bash

INTERFACE="wlan0"
SSID="V2X_ADHOC"

echo "주변의 $SSID 네트워크를 스캔 중..."

# 1. 주변 스캔하여 해당 SSID의 주파수(freq) 추출
FREQ=$(sudo iw dev $INTERFACE scan | grep -B 12 "SSID: $SSID" | grep "freq:" | awk '{print $2}' | head -n 1)

if [ -z "$FREQ" ]; then
    echo "에러: $SSID 를 찾지 못했습니다. 상대방 보드가 켜져 있는지 확인하세요."
    exit 1
fi

echo "찾은 주파수: $FREQ MHz. 조인을 시작합니다."

# 2. 기존 연결 해제 및 재접속
sudo ip link set $INTERFACE down
sudo iw dev $INTERFACE set type ibss
sudo ip link set $INTERFACE up
sudo iw dev $INTERFACE ibss join $SSID $FREQ

# 3. 결과 확인
sleep 2
iw dev $INTERFACE link

#!/bin/bash
# test_spk 일괄 실행: Weston 재시작 → sound_trigger → test_spk_host (백그라운드) → key_trigger (포그라운드)

cd "$(dirname "$0")"

# echo "Weston 서버 재시작 중..."
# sudo systemctl stop weston
# sleep 2
# sudo systemctl start weston
# sleep 2


echo "기존 sound_trigger / test_spk_host 프로세스 정리..."
sudo fuser -k 38473/tcp 2>/dev/null #qml port# 38473 사고 정보를 38473으로 주입.
sudo fuser -k 38474/tcp 2>/dev/null
sleep 2

#echo "sound_trigger 시작 (백그라운드, 로그: sound.log)..."
#./sound_trigger 2>&1 | tee sound.log &
#SOUND_PID=$!
#sleep 1

echo "test_spk_host 시작 (백그라운드, 로그: host.log)..."
# Weston = topst(1000), /dev/dri 접근 = render 그룹 → topst로 실행 (sudo 없이)
./run_test_spk_host.sh 2>&1 | tee host.log &
HOST_PID=$!
sleep 1

echo "key_trigger 시작 (포그라운드)..."
./key_trigger  2>&1 | tee key.log 

# key_trigger 종료 시 나머지 정리
kill $SOUND_PID $HOST_PID 2>/dev/null

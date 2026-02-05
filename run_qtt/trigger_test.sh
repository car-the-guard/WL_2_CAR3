#!/bin/bash
# 수신 측(38473 sound_trigger, 38474 test_spk_host) 동작 확인용
# 사용법: ./trigger_test.sh [PLAY|바이너리]
#  - PLAY: echo "PLAY" 전송 (sound_trigger / 호스트가 PLAY만 받는 경우)
#  - 없으면 기본으로 PLAY 전송

cd "$(dirname "$0")"
MSG="${1:-PLAY}"

echo "=== 포트 연결 테스트 (127.0.0.1) ==="
echo "전송 메시지: $MSG"
echo ""

echo "1) 38473 (sound_trigger) 로 전송..."
if ( echo -n "$MSG"; sleep 0.3 ) | timeout 2 nc 127.0.0.1 38473 2>/dev/null; then
    echo "   -> 38473 전송 완료 (sound_trigger에서 소리 나오면 정상)"
else
    echo "   -> 38473 연결 실패 (sound_trigger 실행 중인지 확인: ./run_sound_trigger.sh 2>&1 | tee sound.log)"
fi
echo ""

echo "2) 38474 (test_spk_host) 로 전송..."
if ( echo -n "$MSG"; sleep 0.3 ) | timeout 2 nc 127.0.0.1 38474 2>/dev/null; then
    echo "   -> 38474 전송 완료 (호스트 화면에 '재생 중' 등 표시되면 정상)"
else
    echo "   -> 38474 연결 실패 (test_spk_host 실행 중인지 확인: sudo ./run_test_spk_host.sh 2>&1 | tee host.log)"
fi
echo ""
echo "끝."

#!/bin/bash
# sound_trigger 전용 실행 스크립트 (로그: sound.log 는 호출 시 tee 로 지정)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR"
exec ./sound_trigger "$@"

#!/bin/bash
# 1회 실행: sudoers 설정으로 run.sh 실행 시 비밀번호 불필요
# 사용법: sudo ./setup_sudoers.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USERNAME="$(logname 2>/dev/null || echo "$SUDO_USER" || whoami)"

if [ "$EUID" -ne 0 ]; then
    echo "sudo로 실행해주세요: sudo ./setup_sudoers.sh"
    exit 1
fi

SYSTEMCTL="$(which systemctl 2>/dev/null || echo /usr/bin/systemctl)"
SUDOERS_FILE="/etc/sudoers.d/test-spk-$USERNAME"
cat > "$SUDOERS_FILE" << EOF
# test_spk run.sh 비밀번호 없이 실행 (관리자 1회 설정)
$USERNAME ALL=(ALL) NOPASSWD: $SYSTEMCTL stop weston
$USERNAME ALL=(ALL) NOPASSWD: $SYSTEMCTL start weston
$USERNAME ALL=(ALL) NOPASSWD: $SCRIPT_DIR/run_test_spk_host.sh
EOF

chmod 440 "$SUDOERS_FILE"
echo "설정 완료: $SUDOERS_FILE"
echo "이제 ./run.sh 실행 시 비밀번호를 묻지 않습니다."

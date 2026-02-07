#!/bin/bash
# test_spk_host 전용 실행 스크립트 (sudoers NOPASSWD용)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR"
# Weston = topst → /run/user/1000 (현재 사용자로 실행 시 $(id -u)=1000)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
# UID를 1000으로 강제 지정하여 Weston 소켓 경로 고정
export XDG_RUNTIME_DIR=/run/user/1000
#export WAYLAND_DISPLAY=wayland-0

# /mnt/sdcard 경로를 읽기/쓰기(rw) 모드로 다시 마운트
sudo mount -o remount,rw /mnt/sdcard
export QT_QUICK_BACKEND=software  # Qt Quick에게 CPU 렌더링 강제
export QT_QPA_PLATFORM=wayland    # 화면 전송은 Wayland 사용

# EGL 0x3005 회피: SSH 세션에서 GPU 접근 불가 → 소프트웨어 렌더링 사용
export QT_OPENGL=software
export LIBGL_ALWAYS_SOFTWARE=1
exec env QT_QPA_FONTDIR=/usr/share/fonts/truetype QT_WAYLAND_DISABLE_WINDOWDECORATION=1 ./test_spk_host -platform wayland

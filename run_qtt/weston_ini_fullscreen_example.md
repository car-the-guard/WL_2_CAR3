# Weston 전체화면 설정 (weston.ini)

`/etc/xdg/weston/weston.ini`를 수정해서 **상단 패널(툴바)을 없애고** 전체화면처럼 쓰는 방법입니다.  
수정 시 **root 권한**이 필요합니다: `sudo nano /etc/xdg/weston/weston.ini`

---

## 1. 상단 패널만 없애기 (가장 흔한 방법)

**[shell]** 섹션에 다음 한 줄을 넣습니다.**[shell]** 섹션이 없으면 새로 만들면 됩니다.

```ini
[shell]
panel-position=none
```

- `panel-position` 값: `top`, `bottom`, `left`, `right`, **`none`**(패널 숨김)  
- 일부 Weston 버전에서는 `panel-location=""` 도 사용됩니다. `none`이 동작하지 않으면 둘 다 넣어 보세요:
  ```ini
  [shell]
  panel-position=none
  panel-location=
  ```

---

## 2. 배경을 검정으로 (선택)

앱만 보이게 하려면 배경을 검정으로 두는 것이 좋습니다.

```ini
[shell]
panel-position=none
background-color=0xff000000
```

- `0xAARRGGBB` 형식 (Alpha, Red, Green, Blue). `0xff000000` = 불투명 검정.

---

## 3. 전체 예시 (복사해서 쓰기 좋게)

아래는 **패널 제거 + 검정 배경**만 넣은 최소 예시입니다.  
기존 `weston.ini`에 **[shell]** 섹션이 있으면 그 안에 `panel-position=none` 등만 추가하고, 없으면 **[shell]** 섹션 전체를 추가하면 됩니다.

```ini
[core]
# shell은 기본값(desktop) 사용. 키오스크용이면 shell=kiosk-shell.so 로 변경 가능

[shell]
panel-position=none
background-color=0xff000000
```

---

## 4. 적용 방법

1. 수정 저장 후 Weston 재시작:
   ```bash
   sudo systemctl restart weston
   ```
2. 또는 재부팅.

---

## 5. 키오스크/단일 앱 전체화면 (선택)

모든 최상위 앱 창을 **강제로 전체화면**으로 띄우려면 **kiosk-shell**을 쓸 수 있습니다.

```ini
[core]
shell=kiosk-shell.so
```

- 이렇게 하면 desktop 대신 kiosk-shell이 로드되어, 앱 창이 전체화면으로 뜹니다.  
- 패널을 없애는 것은 위 **[shell]** 의 `panel-position=none` 으로 처리합니다 (desktop-shell 사용 시). kiosk-shell은 패널이 없을 수 있습니다.

---

## 요약

| 목적           | weston.ini 설정 |
|----------------|------------------|
| 상단 패널 제거 | `[shell]` 에 `panel-position=none` |
| 배경 검정      | `[shell]` 에 `background-color=0xff000000` |
| 적용           | `sudo systemctl restart weston` |

앱 쪽 전체화면(타이틀바 없음)은 **test_spk_host**의 main.cpp에서 `FramelessWindowHint` + `showFullScreen()` 로 처리하는 것이 맞고, weston.ini는 **Weston 자체의 패널/배경**만 제어합니다.

---

## 6. 상단바가 안 없어질 때 (체크리스트)

### ① 어떤 상단바인지 구분

- **Weston 패널**: 시계, 런처 아이콘 등이 있는 **Weston이 그리는 막대** → weston.ini로 제거.
- **앱 창 타이틀바**: **test_spk_host 창만** 상단에 제목·닫기 버튼이 있는 막대 → **앱(main.cpp) 수정 후 재빌드**해야 함.

### ② Weston 패널인데 `panel-position=none` 이 안 먹을 때

1. **적용 여부 확인**
   - 수정한 파일이 **실제로 쓰이는** weston.ini인지 확인:
     ```bash
     cat /etc/xdg/weston/weston.ini | grep -A2 '\[shell\]'
     ```
   - 수정 후 **Weston 재시작** 필수: `sudo systemctl restart weston`

2. **다른 옵션 시도** (버전마다 키 이름이 다름)
   ```ini
   [shell]
   panel-position=none
   panel-location=
   ```

3. **kiosk-shell 사용** (패널이 아예 없는 셸)
   ```ini
   [core]
   shell=kiosk-shell.so
   ```
   - 주의: kiosk-shell은 앱을 전체화면으로 띄우는 셸이라, 데스크톱/런처 동작이 달라질 수 있음.
   - 사용 후 다시 desktop 쓰려면 `shell=desktop` 으로 되돌리기.

### ③ 앱 창 타이틀바(테두리)가 보일 때

- **test_spk_host**는 **빌드할 때** main.cpp에 `FramelessWindowHint` + `showFullScreen()` 가 들어가 있어야 타이틀바가 사라짐.
- 지금 쓰는 실행 파일에 그 패치가 **안 들어가 있으면** weston.ini만으로는 타이틀바가 없어지지 않음.
- **호스트 소스**에서 `host_patch_fullscreen_nomenu.md` 대로 수정한 뒤 **다시 빌드**해서 test_spk_host를 교체해야 함.

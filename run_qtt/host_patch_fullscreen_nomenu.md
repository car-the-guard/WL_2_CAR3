# test_spk_host: 전체화면 + 상단 메뉴바 제거

호스트 소스의 **main.cpp**에서 아래처럼 수정하세요.

## 1. include 추가 (파일 상단)

```cpp
#include <QWindow>  // Qt::Window, Qt::FramelessWindowHint
```

(또는 `#include <QtCore/Qt>` 등 이미 Window 플래그를 쓰고 있다면 생략)

## 2. QQuickView 설정 부분

**setResizeMode** 다음에 다음 두 줄을 추가:

```cpp
view.setResizeMode(QQuickView::SizeViewToRootObject);

// 상단 메뉴바/타이틀바 제거 + 전체화면
view.setFlags(Qt::Window | Qt::FramelessWindowHint);
view.showFullScreen();
```

기존에 `view.show();` 만 있었다면 **삭제**하고 위의 `view.showFullScreen();` 만 사용하세요.

## 요약

| 목적           | 코드 |
|----------------|------|
| 뷰 크기에 루트 맞춤 | `view.setResizeMode(QQuickView::SizeViewToRootObject);` |
| 메뉴바/타이틀바 제거 | `view.setFlags(Qt::Window \| Qt::FramelessWindowHint);` |
| 전체화면       | `view.showFullScreen();` |

빌드 후 실행하면 창 모드·메뉴바 없이 전체화면으로 뜹니다.

---

## Wayland(Weston)에서 오른쪽 닫기 버튼이 보일 때

Wayland에서는 **컴포지터(Weston)**가 창 장식(닫기·최소화 버튼 등)을 그립니다.  
`FramelessWindowHint`만으로는 서버 측 장식이 사라지지 않을 수 있으므로, **실행 시** 다음 환경 변수를 설정하세요.

```bash
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
```

예: `run_test_spk_host.sh` 에서

```bash
exec env ... QT_WAYLAND_DISABLE_WINDOWDECORATION=1 ./test_spk_host -platform wayland
```

이렇게 하면 Weston이 그리는 닫기 버튼이 사라집니다.

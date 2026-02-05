import QtQuick 2.0
import QtQuick.Window 2.0
import QtQuick.Shapes 1.15
import QtMultimedia 5.15

// test_qt 클러스터 UI + test_spk 신호 수신 (PLAY 수신 시 "재생 중" 표시)
Item {
    id: root
    width: 800
    height: 480

    // [수정] 소프트웨어 렌더링 확인을 위해 배경을 흰색으로 고정
    //Rectangle {
        //anchors.fill: parent
        //color: "white" 
        //z: -10 // 가장 뒤에 배치
    //}

    // 전체화면은 host/main.cpp에서 view.showFullScreen()으로 처리

    // === test_spk: 신호 수신 기능 (방향, 거리, 위험등급) ===
    property bool showPlaying: false
    property string warningDirection: "F"
    property int warningDistance: 400
    property int warningDangerLevel: 1

    Connections {
        target: typeof triggerHelper !== "undefined" ? triggerHelper : null
        function onPlayAlertRequested(direction, distanceMeters, dangerLevel) {
            warningDirection = direction
            warningDistance = distanceMeters > 0 ? distanceMeters : 400
            warningDangerLevel = Math.max(1, Math.min(3, dangerLevel))
            playAlertSound()
            // N일 때는 화살표만 안 그리고, 삼각형(경고 오버레이)은 그림
            showPlaying = true
            playingTimer.start()
        }
    }

    Timer {
        id: playingTimer
        interval: 5000
        repeat: false
        onTriggered: showPlaying = false
    }

    // test_qt 속성들
    property int speed: 70
    property int rpm: 2500
    property int fuel: 75
    property int temp: 60
    property string gear: "P"
    property int odometer: 12345
    property bool isRecording: false
    property int frameCount: 0
    property string savePath: "captures/"
    property string audioTestFile: "alert.mp3"

    function captureScreen() {
        var timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        var filename = savePath + "screenshot_" + timestamp + ".png";
        clusterArea.grabToImage(function(result) {
            var success = result.saveToFile(filename);
            if (success) {
                captureNotification.text = "캡쳐 저장: " + filename;
            } else {
                captureNotification.text = "캡쳐 실패!";
            }
            captureNotification.opacity = 1;
            notificationTimer.restart();
        });
    }

    function toggleRecording() {
        if (isRecording) {
            isRecording = false;
            recordTimer.stop();
            captureNotification.text = "녹화 중지 - " + frameCount + " 프레임 저장됨";
            captureNotification.opacity = 1;
            notificationTimer.restart();
            frameCount = 0;
        } else {
            isRecording = true;
            frameCount = 0;
            captureNotification.text = "녹화 시작...";
            captureNotification.opacity = 1;
            recordTimer.start();
        }
    }

    Timer {
        id: recordTimer
        interval: 100
        repeat: true
        onTriggered: {
            var filename = savePath + "recording/frame_" + String(frameCount).padStart(5, "0") + ".png";
            clusterArea.grabToImage(function(result) {
                result.saveToFile(filename);
            });
            frameCount++;
            captureNotification.text = "녹화 중: " + frameCount + " 프레임";
        }
    }

    Timer {
        id: notificationTimer
        interval: 3000
        onTriggered: {
            if (!isRecording) {
                captureNotification.opacity = 0;
            }
        }
    }

    MediaPlayer {
        id: audioTestPlayer
        source: audioTestFile ? Qt.resolvedUrl(audioTestFile) : ""
        volume: 1.0
        onStatusChanged: {
            if (status === MediaPlayer.InvalidMedia) {
                captureNotification.text = "오디오 파일을 열 수 없습니다: " + audioTestFile;
                captureNotification.opacity = 1;
                notificationTimer.restart();
            }
        }
    }

    function playAlertSound() {
        if (!audioTestFile) return
        audioTestPlayer.stop()
        audioTestPlayer.source = Qt.resolvedUrl(audioTestFile)
        audioTestPlayer.play()
    }

    function playTestSound() {
        if (!audioTestFile) {
            captureNotification.text = "audioTestFile 경로를 설정한 뒤 테스트하세요.";
            captureNotification.opacity = 1;
            notificationTimer.restart();
            return;
        }
        audioTestPlayer.stop();
        audioTestPlayer.source = Qt.resolvedUrl(audioTestFile);
        audioTestPlayer.play();
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: {
            if (event.key === Qt.Key_S) {
                captureScreen();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                toggleRecording();
                event.accepted = true;
            } else if (event.key === Qt.Key_A) {
                playTestSound();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1a2e" }
            GradientStop { position: 0.5; color: "#16213e" }
            GradientStop { position: 1.0; color: "#0f0f1a" }
        }
    }

    Item {
        id: clusterArea
        anchors.fill: parent

        Item {
            id: rpmGauge
            width: parent.width * 0.35
            height: width
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.05
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: rpmCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    var centerX = width / 2;
                    var centerY = height / 2;
                    var radius = Math.min(width, height) / 2 - 20;

                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                    ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius - 10, Math.PI * 0.75, Math.PI * 2.25, false);
                    ctx.strokeStyle = "#333";
                    ctx.lineWidth = 15;
                    ctx.stroke();
                    var rpmAngle = Math.PI * 0.75 + (rpm / 8000) * Math.PI * 1.5;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius - 10, Math.PI * 0.75, rpmAngle, false);
                    var gradient = ctx.createLinearGradient(0, 0, width, 0);
                    gradient.addColorStop(0, "#00ff88");
                    gradient.addColorStop(0.6, "#ffff00");
                    gradient.addColorStop(1, "#ff3333");
                    ctx.strokeStyle = gradient;
                    ctx.lineWidth = 15;
                    ctx.stroke();
                    ctx.fillStyle = "#ffffff";
                    ctx.font = "bold " + (radius * 0.12) + "px sans-serif";
                    ctx.textAlign = "center";
                    for (var i = 0; i <= 8; i++) {
                        var angle = Math.PI * 0.75 + (i / 8) * Math.PI * 1.5;
                        var x = centerX + Math.cos(angle) * (radius - 35);
                        var y = centerY + Math.sin(angle) * (radius - 35);
                        ctx.fillText(i.toString(), x, y + 5);
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 20
                spacing: 5
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: rpm
                    font.pixelSize: rpmGauge.width * 0.15
                    font.bold: true
                    color: "#00ff88"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "RPM x1000"
                    font.pixelSize: rpmGauge.width * 0.06
                    color: "#888888"
                }
            }
        }

        Item {
            id: speedGauge
            width: parent.width * 0.3
            height: parent.height * 0.6
            anchors.centerIn: parent

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: speed
                    font.pixelSize: speedGauge.width * 0.5
                    font.bold: true
                    color: "#ffffff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "km/h"
                    font.pixelSize: speedGauge.width * 0.12
                    color: "#888888"
                }
            }
        }

        Item {
            id: rightGauges
            width: parent.width * 0.35
            height: width
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.05
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: fuelTempCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    var centerX = width / 2;
                    var centerY = height / 2;
                    var radius = Math.min(width, height) / 2 - 20;
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                    ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius - 10, Math.PI * 0.75, Math.PI * 1.25, false);
                    ctx.strokeStyle = "#333";
                    ctx.lineWidth = 15;
                    ctx.stroke();
                    var fuelAngle = Math.PI * 0.75 + (fuel / 100) * Math.PI * 0.5;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius - 10, Math.PI * 0.75, fuelAngle, false);
                    ctx.strokeStyle = fuel < 20 ? "#ff3333" : "#00aaff";
                    ctx.lineWidth = 15;
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius - 10, Math.PI * 1.75, Math.PI * 2.25, false);
                    ctx.strokeStyle = "#333";
                    ctx.lineWidth = 15;
                    ctx.stroke();
                    var tempAngle = Math.PI * 1.75 + (temp / 120) * Math.PI * 0.5;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius - 10, Math.PI * 1.75, tempAngle, false);
                    ctx.strokeStyle = temp > 100 ? "#ff3333" : "#ff8800";
                    ctx.lineWidth = 15;
                    ctx.stroke();
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.15
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    text: fuel + "%"
                    font.pixelSize: rightGauges.width * 0.08
                    font.bold: true
                    color: fuel < 20 ? "#ff3333" : "#00aaff"
                }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.15
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    text: temp + "°C"
                    font.pixelSize: rightGauges.width * 0.08
                    font.bold: true
                    color: temp > 100 ? "#ff3333" : "#ff8800"
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.4
            height: 50
            radius: 25
            color: Qt.rgba(0, 0, 0, 0.5)
            border.color: "#333"
            border.width: 1
            Row {
                anchors.centerIn: parent
                spacing: 10
                Text { text: "ODO"; font.pixelSize: 14; color: "#888888"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: odometer + " km"; font.pixelSize: 16; font.bold: true; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    SequentialAnimation {
        running: true
        loops: Animation.Infinite
        ParallelAnimation {
            NumberAnimation { target: root; property: "speed"; to: 70; duration: 2000; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "rpm"; to: 2500; duration: 2000 }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "speed"; to: 60; duration: 2000; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "rpm"; to: 2200; duration: 2000 }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "speed"; to: 80; duration: 2000; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "rpm"; to: 2800; duration: 2000 }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "speed"; to: 65; duration: 2000; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "rpm"; to: 2400; duration: 2000 }
        }
    }

    onRpmChanged: rpmCanvas.requestPaint()
    onFuelChanged: fuelTempCanvas.requestPaint()
    onTempChanged: fuelTempCanvas.requestPaint()

    // === test_spk: 신호 수신 시 경고 표지 (속도 숫자 위, 5초 표시) ===
    Item {
        id: warningSign
        width: 140
        height: 140
        anchors.bottom: clusterArea.speedGauge.top - 50
        //anchors.bottom: (clusterArea && clusterArea.speedGauge) ? clusterArea.speedGauge.top - 50 : parent.bottom
        anchors.bottomMargin: (clusterArea.speedGauge !== undefined && clusterArea.speedGauge !== null) ? 15 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: showPlaying ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Item {
            id: warningRoot
            width: 400
            height: 400
            scale: 0.28
            transformOrigin: Item.Center
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 28
            clip: false

            property color warningColor: root.warningDangerLevel >= 3 ? "#FF4400" : "#FFD700"
            property color iconColor: "#000000"

            // 노란 외곽 테두리 (삼각형 검은 테두리 바깥, 6px)
            Shape {
                id: yellowBorderShape
                anchors.fill: parent
                anchors.margins: -25
                smooth: true
                antialiasing: false
                z: -1

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: warningRoot.warningColor
                    strokeWidth: 6
                    joinStyle: ShapePath.RoundJoin

                    startX: 225
                    startY: 21
                    PathLine { x: 429; y: 410 }
                    PathLine { x: 21; y: 410 }
                    PathLine { x: 225; y: 21 }
                }
            }

            // 삼각형 경고판 (노란 채움 + 검은 테두리)
            Shape {
                id: triangleBackground
                anchors.fill: parent
                anchors.margins: 8
                smooth: true
                antialiasing: false

                ShapePath {
                    fillColor: warningRoot.warningColor
                    strokeColor: warningRoot.iconColor
                    strokeWidth: 18
                    joinStyle: ShapePath.RoundJoin

                    startX: triangleBackground.width / 2
                    startY: 12
                    PathLine { x: triangleBackground.width - 8; y: triangleBackground.height - 20 }
                    PathLine { x: 8; y: triangleBackground.height - 20 }
                    PathLine { x: triangleBackground.width / 2; y: 12 }
                }

                // --- 내부 사고 아이콘 (차량 실루엣 + 번개 + 400m) ---
                Item {
                    id: iconContent
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    width: 300
                    height: 180

                    // 1. 충돌 충격 아이콘 (14각형, 1.2배)
                    Shape {
                        width: 96
                        height: 96
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        antialiasing: false

                        // 외곽 테두리 (14각형, 여백 두고)
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: warningRoot.iconColor
                            strokeWidth: 3
                            joinStyle: ShapePath.RoundJoin

                            startX: 90
                            startY: 48
                            PathLine { x: 62; y: 42 }
                            PathLine { x: 74; y: 17 }
                            PathLine { x: 51; y: 33 }
                            PathLine { x: 40; y: 9 }
                            PathLine { x: 39; y: 36 }
                            PathLine { x: 13; y: 31 }
                            PathLine { x: 33; y: 48 }
                            PathLine { x: 13; y: 65 }
                            PathLine { x: 39; y: 60 }
                            PathLine { x: 56; y: 87 }
                            PathLine { x: 51; y: 63 }
                            PathLine { x: 74; y: 79 }
                            PathLine { x: 62; y: 54 }
                            PathLine { x: 90; y: 48 }
                        }

                        // 내부 채움 (14각형)
                        ShapePath {
                            fillColor: warningRoot.iconColor
                            strokeColor: "transparent"
                            strokeWidth: 0
                            startX: 86
                            startY: 48
                            PathLine { x: 62; y: 42 }
                            PathLine { x: 71; y: 20 }
                            PathLine { x: 50; y: 35 }
                            PathLine { x: 41; y: 15 }
                            PathLine { x: 40; y: 38 }
                            PathLine { x: 18; y: 34 }
                            PathLine { x: 34; y: 48 }
                            PathLine { x: 18; y: 62 }
                            PathLine { x: 40; y: 58 }
                            PathLine { x: 55; y: 81 }
                            PathLine { x: 50; y: 61 }
                            PathLine { x: 71; y: 76 }
                            PathLine { x: 62; y: 54 }
                            PathLine { x: 86; y: 48 }
                        }
                    }

                    // 2. 왼쪽 차량 (삼각형 중심 정렬)
                    Shape {
                        width: 105
                        height: 52
                        x: 45
                        y: 98
                        rotation: -12
                        antialiasing: false

                        ShapePath {
                            fillColor: warningRoot.iconColor
                            strokeColor: "transparent"
                            strokeWidth: 0
                            startX: 0
                            startY: 42
                            PathLine { x: 0; y: 26 }
                            PathQuad { x: 30; y: 21; controlX: 5; controlY: 19 }
                            PathLine { x: 47; y: 5 }
                            PathLine { x: 78; y: 5 }
                            PathLine { x: 95; y: 26 }
                            PathLine { x: 105; y: 31 }
                            PathLine { x: 105; y: 42 }
                            PathLine { x: 0; y: 42 }
                        }

                        Rectangle {
                            x: 15; y: 42; width: 16; height: 16
                            radius: 8
                            color: warningRoot.iconColor
                            border.width: 0
                        }
                        Rectangle {
                            x: 74; y: 42; width: 16; height: 16
                            radius: 8
                            color: warningRoot.iconColor
                            border.width: 0
                        }
                    }

                    // 3. 오른쪽 차량 (삼각형 중심 정렬)
                    Shape {
                        width: 105
                        height: 52
                        x: 150
                        y: 98
                        rotation: 12
                        antialiasing: false

                        ShapePath {
                            fillColor: warningRoot.iconColor
                            strokeColor: "transparent"
                            strokeWidth: 0
                            startX: 105
                            startY: 42
                            PathLine { x: 105; y: 26 }
                            PathQuad { x: 75; y: 21; controlX: 100; controlY: 19 }
                            PathLine { x: 58; y: 5 }
                            PathLine { x: 27; y: 5 }
                            PathLine { x: 10; y: 26 }
                            PathLine { x: 0; y: 31 }
                            PathLine { x: 0; y: 42 }
                            PathLine { x: 105; y: 42 }
                        }

                        Rectangle {
                            x: 15; y: 42; width: 16; height: 16
                            radius: 8
                            color: warningRoot.iconColor
                            border.width: 0
                        }
                        Rectangle {
                            x: 74; y: 42; width: 16; height: 16
                            radius: 8
                            color: warningRoot.iconColor
                            border.width: 0
                        }
                    }
                }

                // 4. 거리 텍스트 (신호에서 받은 warningDistance)
                Text {
                    text: root.warningDistance + "m"
                    font.pixelSize: 55
                    font.bold: true
                    color: warningRoot.iconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 30
                }
            }

            // 방향 꺾쇄: Path, 삼각형 바깥 (L/R 60x90, F 90x60), 크기에 맞게 Path 확장 + 0.5초 깜빡임
            Shape {
                id: leftDirShape
                width: 60
                height: 90
                x: -54
                y: 155
                visible: root.showPlaying && root.warningDirection === "L"
                smooth: true
                antialiasing: false

                SequentialAnimation {
                    running: root.showPlaying && root.warningDirection === "L"
                    loops: Animation.Infinite
                    NumberAnimation { target: leftDirShape; property: "opacity"; to: 0; duration: 250 }
                    NumberAnimation { target: leftDirShape; property: "opacity"; to: 1; duration: 250 }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: warningRoot.warningColor
                    strokeWidth: 14
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: 50
                    startY: 8
                    PathLine { x: 10; y: 45 }
                    PathLine { x: 50; y: 82 }
                }
            }
            Shape {
                id: rightDirShape
                width: 60
                height: 90
                x: 394
                y: 155
                visible: root.showPlaying && root.warningDirection === "R"
                smooth: true
                antialiasing: false

                SequentialAnimation {
                    running: root.showPlaying && root.warningDirection === "R"
                    loops: Animation.Infinite
                    NumberAnimation { target: rightDirShape; property: "opacity"; to: 0; duration: 250 }
                    NumberAnimation { target: rightDirShape; property: "opacity"; to: 1; duration: 250 }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: warningRoot.warningColor
                    strokeWidth: 14
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: 10
                    startY: 8
                    PathLine { x: 50; y: 45 }
                    PathLine { x: 10; y: 82 }
                }
            }
            Shape {
                id: frontDirShape
                width: 90
                height: 60
                x: 155
                y: -65
                visible: root.showPlaying && root.warningDirection === "F"
                smooth: true
                antialiasing: false

                SequentialAnimation {
                    running: root.showPlaying && root.warningDirection === "F"
                    loops: Animation.Infinite
                    NumberAnimation { target: frontDirShape; property: "opacity"; to: 0; duration: 250 }
                    NumberAnimation { target: frontDirShape; property: "opacity"; to: 1; duration: 250 }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: warningRoot.warningColor
                    strokeWidth: 14
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: 8
                    startY: 50
                    PathLine { x: 45; y: 10 }
                    PathLine { x: 82; y: 50 }
                }
            }
        }
    }

    Rectangle {
        id: notificationBox
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        width: captureNotification.width + 40
        height: 40
        radius: 20
        color: isRecording ? "#cc0000" : "#333333"
        opacity: captureNotification.opacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on color { ColorAnimation { duration: 300 } }

        Row {
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: "#ff0000"
                visible: isRecording
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
            Text {
                id: captureNotification
                text: ""
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
                opacity: 0
            }
        }
    }

}

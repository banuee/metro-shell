import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

// Медиа-плитка, адаптируется под размер:
// 1x1 — обложка во всю плитку + play по центру;
// 2x1 — обложка слева, текст, прогресс, play справа;
// 2x2 — обложка во всю плитку + seek-бар (drag) и транспорт.
// Клик по плитке мимо кнопок = play/pause. В idle — тихое стекло с нотой.
TileFrame {
    id: root

    readonly property bool mini: width < 120
    readonly property bool large: width >= 170 && height >= 170
    readonly property bool hasArt: Media.artUrl !== "" && artReady

    property bool artReady: false

    readonly property real frac: Media.length > 0 ? Math.min(1, Math.max(0, Media.pos / Media.length)) : 0

    width: Theme.tileW(2)
    height: Theme.tileH(1)
    color: Media.idle || !hasArt ? Theme.glass : Qt.rgba(1, 1, 1, 0.05)

    onClicked: if (!Media.idle)
        Media.act("play-pause")

    // общая маска скругления (арт — картинка, radius сама не обрежет)
    Rectangle {
        id: cornerMask

        anchors.fill: parent
        radius: Theme.radius
        visible: false
    }

    // ── 2x2: обложка во всю плитку + scrim-градиенты ──
    Item {
        id: fullArt

        anchors.fill: parent
        visible: root.large && !Media.idle
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: cornerMask
        }

        Image {
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: Media.artUrl !== "" && status === Image.Ready
            onStatusChanged: root.artReady = status === Image.Ready
            onSourceChanged: root.artReady = false
        }

        // общее затемнение + скримы для читаемости текста
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.30)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 76
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.45)
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 104
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.62)
                }
            }
        }
    }

    // фолбэк: без арта — крупная нота
    Text {
        anchors.centerIn: parent
        visible: root.large && !Media.idle && !root.hasArt
        text: "\uf001"
        font.family: Theme.iconFont
        font.pixelSize: 46
        color: Qt.rgba(1, 1, 1, 0.12)
    }

    // ── 2x2: трек / артист ──
    Column {
        visible: root.large && !Media.idle
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 13
            leftMargin: 14
            rightMargin: 14
        }
        spacing: 3

        Text {
            width: parent.width
            text: Media.title
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Media.artist !== "" ? Media.artist : " "
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.alpha(Theme.text, 0.75)
            elide: Text.ElideRight
        }
    }

    // ── 2x2: seek-бар (drag + hover-ручка) ──
    Item {
        visible: root.large && !Media.idle
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 14
            rightMargin: 14
            bottomMargin: 28
        }
        height: 18

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * (seekMa.pressed ? seekMa.dragFrac : root.frac)
            height: 4
            radius: 2
            color: Theme.accent

            Behavior on width {
                enabled: !seekMa.pressed
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.Linear
                }
            }
        }

        Rectangle {
            visible: seekMa.containsMouse || seekMa.pressed
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round((parent.width - 10) * (seekMa.pressed ? seekMa.dragFrac : root.frac))
            width: 10
            height: 10
            radius: 5
            color: Theme.text

            Behavior on x {
                enabled: !seekMa.pressed
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.Linear
                }
            }
        }

        MouseArea {
            id: seekMa

            property real dragFrac: 0

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function fracAt(x) {
                return Math.max(0, Math.min(1, x / width))
            }

            onPressed: mouse => dragFrac = fracAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    dragFrac = fracAt(mouse.x)
            }
            onReleased: if (Media.length > 0)
                Media.seek(dragFrac * Media.length)
        }
    }

    // ── 2x2: таймкоды ──
    Text {
        visible: root.large && !Media.idle
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: 14
            bottomMargin: 10
        }
        text: fmtTime(Media.pos)
        font.family: Theme.fontFamily
        font.pixelSize: 10
        color: Theme.alpha(Theme.text, 0.60)
    }

    Text {
        visible: root.large && !Media.idle
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 14
            bottomMargin: 10
        }
        text: fmtTime(Media.length)
        font.family: Theme.fontFamily
        font.pixelSize: 10
        color: Theme.alpha(Theme.text, 0.60)
    }

    // ── 2x2: транспорт ──
    Row {
        visible: root.large && !Media.idle
        spacing: 8
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 50
        }

        component SkipBtn: Item {
            id: skip

            required property string glyph
            required property string cmd

            width: 38
            height: 38

            Rectangle {
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: 14
                color: skipMa.pressed ? Qt.rgba(1, 1, 1, 0.20) : skipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: skip.glyph
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: Theme.text
            }

            MouseArea {
                id: skipMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.act(skip.cmd)
            }
        }

        SkipBtn {
            glyph: "\uf04a"
            cmd: "previous"
        }

        Item {
            width: 42
            height: 42
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 21
                color: bigPlayMa.pressed ? Theme.alpha(Theme.accent, 0.95) : bigPlayMa.containsMouse ? Theme.alpha(Theme.accent, 0.70) : Qt.rgba(1, 1, 1, 0.14)
                scale: bigPlayMa.pressed ? 0.92 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Media.playStatus === "playing" ? "\uf04c" : "\uf04b"
                font.family: Theme.iconFont
                font.pixelSize: 17
                color: Theme.text
            }

            MouseArea {
                id: bigPlayMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.act("play-pause")
            }
        }

        SkipBtn {
            glyph: "\uf04e"
            cmd: "next"
        }
    }

    // ── 2x1: компакт ──
    Item {
        anchors.fill: parent
        visible: !root.mini && !root.large && !Media.idle

        Rectangle {
            id: smallArt

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            height: 50
            radius: Theme.radiusSmall
            color: Theme.glass

            Image {
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.hasArt
                layer.enabled: visible
                layer.effect: OpacityMask {
                    maskSource: smallArt
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.hasArt
                text: "\uf001"
                font.family: Theme.iconFont
                font.pixelSize: 20
                color: Theme.textDim
            }
        }

        Column {
            anchors {
                left: smallArt.right
                right: smallPlay.left
                verticalCenter: parent.verticalCenter
                leftMargin: 10
                rightMargin: 7
            }
            spacing: 3

            Text {
                width: parent.width
                text: Media.title
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Media.artist !== "" ? Media.artist : " "
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textDim
                elide: Text.ElideRight
            }

            Item {
                width: parent.width
                height: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.15)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * root.frac
                    height: 4
                    radius: 2
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.Linear
                        }
                    }
                }
            }
        }

        Rectangle {
            id: smallPlay

            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            width: 30
            height: 30
            radius: 15
            color: smallPlayMa.pressed ? Theme.alpha(Theme.accent, 0.95) : smallPlayMa.containsMouse ? Theme.alpha(Theme.accent, 0.70) : Qt.rgba(1, 1, 1, 0.08)
            scale: smallPlayMa.pressed ? 0.92 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutQuad
                }
            }

            Text {
                anchors.centerIn: parent
                text: Media.playStatus === "playing" ? "\uf04c" : "\uf04b"
                font.family: Theme.iconFont
                font.pixelSize: 13
                color: Theme.text
            }

            MouseArea {
                id: smallPlayMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.act("play-pause")
            }
        }
    }

    // ── 1x1: обложка во всю плитку + play по центру ──
    Item {
        anchors.fill: parent
        visible: root.mini && !Media.idle
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: cornerMask
        }

        Image {
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.hasArt
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasArt
            text: "\uf001"
            font.family: Theme.iconFont
            font.pixelSize: 24
            color: Theme.textDim
        }

        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: 16
            color: miniPlayMa.containsMouse ? Theme.alpha(Theme.accent, 0.85) : Qt.rgba(0, 0, 0, 0.45)

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Text {
                anchors.centerIn: parent
                text: Media.playStatus === "playing" ? "\uf04c" : "\uf04b"
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: Theme.text
            }

            MouseArea {
                id: miniPlayMa

                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.act("play-pause")
            }
        }
    }

    // idle: тихая плитка
    Text {
        anchors.centerIn: parent
        visible: Media.idle
        text: root.mini ? "" : "\uf001"
        font.family: Theme.iconFont
        font.pixelSize: root.large ? 34 : 24
        color: Qt.rgba(1, 1, 1, 0.25)
    }

    function fmtTime(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }
}

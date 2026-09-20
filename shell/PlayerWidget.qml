import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

TileFrame {
    id: root

    readonly property bool mini: width < 120
    readonly property bool large: width >= 170 && height >= 170
    readonly property bool isWide: width > 120 && height < 120
    readonly property bool isTallOnly: height > 120 && width <= 120
    readonly property bool isXL: width >= 260 && height >= 170
    readonly property bool hasArt: Media.artUrl !== "" && artReady

    property bool artReady: false
    property real wavePhase: 0.0

    readonly property real frac: Media.length > 0 ? Math.min(1, Math.max(0, Media.pos / Media.length)) : 0

    // Размер задаёт ячейка сетки через Loader — фикс-размера нет (иначе вылезает за 1x1/1x2)
    color: Theme.isMaterial ? (Theme.surface_container) : (Media.idle || !hasArt ? Theme.glass : Qt.rgba(1, 1, 1, 0.05))

    onClicked: if (!Media.idle)
        Media.act("play-pause")

    Timer {
        interval: 50
        running: Boolean(Media && (Media.playStatus === "playing") && Theme.isMaterial)
        repeat: true
        onTriggered: {
            root.wavePhase = (root.wavePhase + 0.15) % (Math.PI * 2)
            if (waveCanvas2x2.visible) waveCanvas2x2.requestPaint()
        }
    }

    Rectangle {
        id: cornerMask
        anchors.fill: parent
        radius: Theme.radius
        visible: false
    }

    // =========================================================================
    //  МАТЕРИАЛЬНЫЙ СТИЛЬ (Theme.isMaterial == true) - Music 5 с фото 4
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: Theme.isMaterial

        // ── 1x1 Компактный вид ──
        Item {
            anchors.fill: parent
            visible: root.mini && !root.isTallOnly
            z: 1

            Rectangle {
                anchors.centerIn: parent
                width: 44
                height: 44
                radius: 22
                color: Theme.primary

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 2
                    text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.on_primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.act("play-pause")
                }
            }
        }

        // ── 1x2 Вертикаль (material) ──
        Item {
            anchors.fill: parent
            visible: root.isTallOnly
            z: 1
            anchors.margins: 8

            Column {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52
                    height: 52
                    radius: 26
                    color: Theme.secondary_container
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: root.hasArt
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.hasArt
                        text: "\uf001"
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        color: Theme.on_secondary_container
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 68
                    text: Media.idle ? I18n.t("no_media") : (Media.title || "Track")
                    font.family: "Google Sans"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.on_surface
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 2
                        text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.on_primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.act("play-pause")
                    }
                }
            }
        }

        // ── 2x1 Широкий вид ──
        Item {
            anchors.fill: parent
            visible: root.isWide
            z: 1
            anchors.margins: 10

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    width: parent.height
                    height: parent.height
                    radius: 12
                    color: Theme.secondary_container
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: root.hasArt
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.hasArt
                        text: "\uf001"
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                        color: Theme.on_secondary_container
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - parent.height - 54
                    spacing: 2

                    Text {
                        width: parent.width
                        text: Media.idle ? I18n.t("no_media") : (Media.title || "Track")
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.on_surface
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: !Media.idle && Media.artist !== ""
                        text: Media.artist
                        font.family: "Google Sans"
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 2
                        text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        color: Theme.on_primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.act("play-pause")
                    }
                }
            }
        }

        // ── 2x2 Большой вид (Music 5) ──
        Item {
            anchors.fill: parent
            visible: root.large
            z: 1
            anchors.margins: 12

            Column {
                anchors.fill: parent
                spacing: 8

                // Верхний блок: трек и артист
                Item {
                    width: parent.width
                    height: 36

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 2

                        Text {
                            width: parent.width
                            text: Media.idle ? I18n.t("no_media") : (Media.title || "Track")
                            font.family: "Google Sans"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.on_surface
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: !Media.idle && Media.artist !== ""
                            text: Media.artist
                            font.family: "Google Sans"
                            font.pixelSize: 11
                            color: Theme.on_surface_variant
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Транспортные кнопки (Prev, Scalloped Play, Next)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Theme.secondary_container
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "\uf048"
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            color: Theme.on_secondary_container
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("previous")
                        }
                    }

                    Item {
                        width: 48
                        height: 48
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            radius: 18
                            color: Theme.primary
                        }
                        Repeater {
                            model: 12
                            Rectangle {
                                readonly property real angle: index * (Math.PI * 2 / 12)
                                width: 14
                                height: 14
                                radius: 7
                                x: 24 + 16 * Math.cos(angle) - 7
                                y: 24 + 16 * Math.sin(angle) - 7
                                color: Theme.primary
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 2
                            text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: Theme.on_primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("play-pause")
                        }
                    }

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Theme.secondary_container
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "\uf051"
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            color: Theme.on_secondary_container
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("next")
                        }
                    }
                }

                // Wavy Squiggly Seekbar
                Item {
                    width: parent.width
                    height: 16

                    Canvas {
                        id: waveCanvas2x2
                        anchors.fill: parent

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.lineWidth = 3
                            ctx.lineCap = "round"

                            const midY = height / 2
                            const progressW = width * root.frac

                            if (progressW > 0) {
                                ctx.beginPath()
                                ctx.strokeStyle = Theme.primary
                                const waveAmp = (Media.playStatus === "playing") ? 2.5 : 0
                                const waveFreq = 0.25
                                ctx.moveTo(0, midY)
                                for (let x = 0; x <= progressW; x += 2) {
                                    const y = midY + Math.sin(x * waveFreq + root.wavePhase) * waveAmp
                                    ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(progressW, midY, 5, 0, Math.PI * 2)
                                ctx.fillStyle = Theme.primary
                                ctx.fill()
                            }

                            if (progressW < width) {
                                ctx.beginPath()
                                ctx.strokeStyle = Theme.surface_container_highest
                                ctx.moveTo(progressW, midY)
                                ctx.lineTo(width, midY)
                                ctx.stroke()
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (Media.length > 0) {
                                const targetSec = (mouse.x / width) * Media.length
                                Media.act("position " + targetSec.toFixed(1))
                            }
                        }
                    }
                }

                // Временные метки
                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        text: Media.posStr
                        font.family: "Google Sans"
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                    }

                    Text {
                        anchors.right: parent.right
                        text: Media.lengthStr
                        font.family: "Google Sans"
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                    }
                }
            }
        }
    }

    // =========================================================================
    //  КЛАССИЧЕСКИЙ СТИЛЬ METRO / WP (Theme.isMaterial == false)
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: !Theme.isMaterial

        // ── 1x1 Компактный вид Metro / WP ──
        Item {
            anchors.fill: parent
            visible: root.mini && !root.isTallOnly
            z: 1

            // Idle состояние (1x1)
            Item {
                anchors.fill: parent
                visible: Media.idle

                Text {
                    anchors.centerIn: parent
                    text: "\uf001"
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: Theme.textDim
                }
            }

            // Играет / на паузе (1x1)
            Item {
                anchors.fill: parent
                visible: !Media.idle

                Rectangle {
                    id: miniArtMask
                    anchors.fill: parent
                    radius: Theme.isWP ? 0 : Theme.radius
                    visible: false
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: !Theme.isWP
                    layer.effect: OpacityMask {
                        maskSource: miniArtMask
                    }

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: root.hasArt
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !root.hasArt
                        color: Theme.glass
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
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.35)
                    }
                }

                // Кнопка play/pause по центру
                Rectangle {
                    id: miniMetroPlay
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: Theme.isWP ? 0 : 18
                    color: miniMetroPlayMa.pressed ? Theme.alpha(Theme.accent, 0.95) : (miniMetroPlayMa.containsMouse ? Theme.alpha(Theme.accent, 0.80) : Qt.rgba(0, 0, 0, 0.50))
                    scale: miniMetroPlayMa.pressed ? 0.92 : (miniMetroPlayMa.containsMouse ? 1.06 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 1
                        text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: miniMetroPlayMa
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.act("play-pause")
                    }
                }
            }
        }

        // ── 1x2 Вертикаль Metro / WP ──
        Item {
            anchors.fill: parent
            visible: root.isTallOnly && !Theme.isMaterial
            z: 1
            anchors.margins: 8

            Item {
                anchors.fill: parent
                visible: Media.idle

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\uf001"
                        font.family: Theme.iconFont
                        font.pixelSize: 24
                        color: Theme.textDim
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: I18n.t("no_media")
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: !Media.idle

                Column {
                    anchors.fill: parent
                    spacing: 4

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 60
                        height: 60
                        radius: Theme.isWP ? 0 : Theme.radiusSmall
                        color: Theme.glass
                        clip: true

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
                            font.pixelSize: 22
                            color: Theme.textDim
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: Media.title || "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.text
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Media.artist !== ""
                        width: parent.width
                        text: Media.artist
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.textDim
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 34
                        height: 34
                        radius: Theme.isWP ? 0 : 17
                        color: vertPlayMa.pressed ? Theme.alpha(Theme.accent, 0.95) : (vertPlayMa.containsMouse ? Theme.alpha(Theme.accent, 0.75) : Theme.glass)

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 1
                            text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            color: Theme.text
                        }

                        MouseArea {
                            id: vertPlayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("play-pause")
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 8
                        height: 3
                        radius: Theme.isWP ? 0 : 1.5
                        color: Qt.rgba(1, 1, 1, 0.20)

                        Rectangle {
                            width: parent.width * root.frac
                            height: parent.height
                            radius: Theme.isWP ? 0 : 1.5
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        // ── 2x1 Широкий вид Metro / WP ──
        Item {
            anchors.fill: parent
            visible: root.isWide
            z: 1
            anchors.margins: 10

            // Idle состояние (2x1)
            Item {
                anchors.fill: parent
                visible: Media.idle

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: Theme.isWP ? 0 : 17
                        color: Theme.glass
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "\uf001"
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: Theme.textDim
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("no_media")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }
            }

            // Играет / на паузе (2x1)
            Item {
                anchors.fill: parent
                visible: !Media.idle

                // Обложка трека слева
                Rectangle {
                    id: wideArt
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height
                    height: parent.height
                    radius: Theme.isWP ? 0 : Theme.radiusSmall
                    color: Theme.glass
                    clip: true

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
                        font.pixelSize: 20
                        color: Theme.textDim
                    }
                }

                // Кнопка play/pause справа
                Rectangle {
                    id: widePlayBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: Theme.isWP ? 0 : 17
                    color: widePlayMa.pressed ? Theme.alpha(Theme.accent, 0.95) : (widePlayMa.containsMouse ? Theme.alpha(Theme.accent, 0.75) : Theme.glass)
                    scale: widePlayMa.pressed ? 0.92 : (widePlayMa.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 1
                        text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.text
                    }

                    MouseArea {
                        id: widePlayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.act("play-pause")
                    }
                }

                // Текст по центру + прогресс-бар
                Column {
                    anchors {
                        left: wideArt.right
                        right: widePlayBtn.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 8
                    }
                    spacing: 3

                    Text {
                        width: parent.width
                        text: Media.title || "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Media.artist || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                        elide: Text.ElideRight
                        visible: Media.artist !== ""
                    }

                    Item {
                        width: parent.width
                        height: 4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 3
                            radius: Theme.isWP ? 0 : 1.5
                            color: Qt.rgba(1, 1, 1, 0.20)
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * root.frac
                            height: 3
                            radius: Theme.isWP ? 0 : 1.5
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
            }
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
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 104
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.62) }
                }
            }
        }

        // 2x2 Контент Metro
        Item {
            anchors.fill: parent
            visible: root.large
            z: 1

            Item {
                visible: Media.idle
                anchors.fill: parent

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48
                        height: 48
                        radius: Theme.isWP ? 0 : 24
                        color: Theme.glass

                        Text {
                            anchors.centerIn: parent
                            text: "\uf001"
                            font.family: Theme.iconFont
                            font.pixelSize: 22
                            color: Theme.textDim
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("no_media")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }
            }

            Item {
                visible: !Media.idle
                anchors.fill: parent

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: Media.title || "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Media.artist || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.80)
                        elide: Text.ElideRight
                    }
                }

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 12
                    }
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors.left: parent.left
                            text: Media.posStr
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }

                        Text {
                            anchors.right: parent.right
                            text: Media.lengthStr
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }
                    }

                    Rectangle {
                        id: seekTrack
                        width: parent.width
                        height: 4
                        radius: Theme.isWP ? 0 : 2
                        color: Qt.rgba(255, 255, 255, 0.25)

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * root.frac
                            radius: Theme.isWP ? 0 : 2
                            color: Theme.accent
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.isWP ? 0 : 16
                            color: Theme.glass
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "\uf048"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.act("previous")
                            }
                        }

                        Rectangle {
                            width: 40
                            height: 40
                            radius: Theme.isWP ? 0 : 20
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 2
                                text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                                color: "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.act("play-pause")
                            }
                        }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.isWP ? 0 : 16
                            color: Theme.glass
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "\uf051"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.act("next")
                            }
                        }
                    }
                }
            }
        }
    }
}

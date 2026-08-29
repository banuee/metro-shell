import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

PanelBase {
    id: root

    slideDir: "right"
    anchors {
        top: true
        bottom: true
        right: true
    }
    implicitWidth: Theme.panelWidth + 14

    property int volume: 50
    property bool volMuted: false
    property int brightness: 50
    property bool wifiOn: true
    property string ssid: ""
    property bool btOn: false
    property bool micMuted: false
    property int battery: 0
    property bool charging: false
    property bool wifiMenuOpen: false
    property bool btMenuOpen: false
    property var notifHidden: ({})
    ListModel {
        id: notifModel
    }

    function dismissNotif(nid) {
        const h = Object.assign({}, root.notifHidden)
        h[nid] = true
        root.notifHidden = h
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === nid) {
                notifModel.remove(i)
                break
            }
        }
    }

    function clearNotifs() {
        const h = Object.assign({}, root.notifHidden)
        for (let i = 0; i < notifModel.count; i++)
            h[notifModel.get(i).nid] = true
        root.notifHidden = h
        notifModel.clear()
    }

    signal wifiSettingsRequested()
    signal btSettingsRequested()

    function toggleWifiMenu() {
        root.wifiMenuOpen = !root.wifiMenuOpen
        if (root.wifiMenuOpen)
            root.btMenuOpen = false
    }

    function toggleBtMenu() {
        root.btMenuOpen = !root.btMenuOpen
        if (root.btMenuOpen)
            root.wifiMenuOpen = false
    }

    Connections {
        target: root

        function onShownChanged() {
            if (!root.shown) {
                root.wifiMenuOpen = false
                root.btMenuOpen = false
            }
        }
    }

    readonly property bool playerVisible: !Media.idle

    function refresh() {
        pVolGet.running = true
        pBriGet.running = true
        pWifiGet.running = true
        pBtGet.running = true
        pMicGet.running = true
        pBatGet.running = true
        pNotif.running = true
    }

    function fmtTime(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    Process {
        id: pVolGet
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                const v = parseFloat(parts[1])
                if (!isNaN(v))
                    root.volume = Math.round(v * 100)
                root.volMuted = data.indexOf("MUTED") !== -1
            }
        }
    }

    Process {
        id: pBriGet
        command: ["sh", "-c", "brightnessctl -m"]
        stdout: SplitParser {
            onRead: data => {
                const p = data.split(",")
                const v = parseInt(p[3])
                if (!isNaN(v))
                    root.brightness = v
            }
        }
    }

    Process {
        id: pWifiGet
        command: ["sh", "-c", "echo w=$(LC_ALL=C nmcli radio wifi); echo s=$(LC_ALL=C nmcli -g ACTIVE,SSID dev wifi list 2>/dev/null | grep '^yes:' | head -n1 | cut -d: -f2-)"]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("w="))
                    root.wifiOn = data.substring(2).trim() === "enabled"
                else if (data.startsWith("s="))
                    root.ssid = data.substring(2).trim()
            }
        }
    }

    Process {
        id: pBtGet
        command: ["sh", "-c", "rfkill list bluetooth 2>/dev/null | grep -c 'Soft blocked: no'"]
        stdout: SplitParser {
            onRead: data => root.btOn = parseInt(data.trim()) > 0
        }
    }

    Process {
        id: pMicGet
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser {
            onRead: data => root.micMuted = data.indexOf("MUTED") !== -1
        }
    }

    Process {
        id: pBatGet
        command: ["sh", "-c", "echo c=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0); echo s=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)"]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("c="))
                    root.battery = parseInt(data.substring(2)) || 0
                else if (data.startsWith("s="))
                    root.charging = data.substring(2).indexOf("Charging") !== -1
            }
        }
    }

    // история уведомлений mako; время mako не отдаёт — запоминаем момент
    // первого появления каждого id
    Process {
        id: pNotif
        command: ["sh", "-c", "makoctl history -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let arr = []
                try {
                    arr = JSON.parse(text)
                } catch (e) {
                    return
                }
                if (!arr.length)
                    return
                const known = {}
                for (let i = 0; i < notifModel.count; i++)
                    known[notifModel.get(i).nid] = true
                // вставляем с конца через insert(0) — новейший оказывается сверху
                for (let i = arr.length - 1; i >= 0; i--) {
                    const n = arr[i]
                    if (known[n.id] || root.notifHidden[n.id])
                        continue
                    notifModel.insert(0, {
                        "nid": n.id,
                        "app": n.app_name || "",
                        "icon": n.app_icon || "",
                        "summary": n.summary || "",
                        "body": (n.body || "").replace(/\n/g, " "),
                        "urgency": n.urgency || "normal",
                        "ntime": Date.now()
                    })
                }
            }
        }
    }

    Process {
        id: pAction
        property string after: ""
        command: []
        onExited: {
            if (after === "refresh")
                root.refresh()
        }
    }

    function act(cmd, doRefresh) {
        if (pAction.running)
            pAction.running = false
        pAction.after = doRefresh === true ? "refresh" : ""
        pAction.command = ["sh", "-c", cmd]
        pAction.running = true
    }

    Timer {
        interval: 1500
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        x: 0
        width: parent.width + 18
        radius: Theme.panelRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.stroke
    }

    Flickable {
        id: ccFlick

        anchors.fill: parent
        anchors {
            leftMargin: 22
            rightMargin: 32
            topMargin: 20
            bottomMargin: 22
        }
        clip: true
        contentHeight: ccCol.height
        contentWidth: ccCol.width
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: wheel => {
                ccFlick.contentY = Math.max(0, Math.min(Math.max(0, ccFlick.contentHeight - ccFlick.height), ccFlick.contentY - wheel.angleDelta.y / 3))
            }
        }

        Column {
            id: ccCol

            width: ccFlick.width
            spacing: 14

        Item {
            width: parent.width
            height: 46

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "центр управления"
                font.family: Theme.fontFamily
                font.pixelSize: 24
                font.weight: Font.Light
                color: Theme.text
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: batRow.width + 20
                height: 30
                radius: 15
                color: root.charging ? Theme.alpha(Theme.accent, 0.22) : Theme.glass

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.charging ? "\uf0e7" : root.battery < 15 ? "\uf244" : root.battery < 40 ? "\uf243" : root.battery < 65 ? "\uf242" : root.battery < 90 ? "\uf241" : "\uf240"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: root.charging ? Theme.accent : Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.battery + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: !root.charging && root.battery < 20 ? Theme.red : Theme.text
                    }
                }
            }
        }

        Grid {
            columns: 2
            spacing: Theme.gap

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.tileH(1)
                color: root.wifiOn ? Theme.alpha(Theme.accent, Theme.tileAlpha) : Qt.rgba(1, 1, 1, 0.07)
                onClicked: root.toggleWifiMenu()

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.wifiOn ? "\uf1eb" : String.fromCodePoint(0xf092d)
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                    color: Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Wi-Fi"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.wifiOn ? (root.ssid !== "" ? root.ssid : "включён") : "выключен"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                        width: 110
                        elide: Text.ElideRight
                    }
                }

                // стрелка-подсказка: раскрытие вниз
                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf105"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Qt.rgba(1, 1, 1, 0.5)
                    rotation: root.wifiMenuOpen ? 90 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.tileH(1)
                color: root.btOn ? Theme.alpha(Theme.accent, Theme.tileAlpha) : Qt.rgba(1, 1, 1, 0.07)
                onClicked: root.toggleBtMenu()

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf294"
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                    color: Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Bluetooth"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.btOn ? "включён" : "выключен"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf105"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Qt.rgba(1, 1, 1, 0.5)
                    rotation: root.btMenuOpen ? 90 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

        }

        WifiMenu {
            shown: root.wifiMenuOpen
            wifiOn: root.wifiOn
            onSettingsRequested: root.wifiSettingsRequested()
        }

        BtMenu {
            shown: root.btMenuOpen
            powered: root.btOn
            onSettingsRequested: root.btSettingsRequested()
        }

        Grid {
            columns: 2
            spacing: Theme.gap

            component SliderTile: TileFrame {
                id: sliderTile
                property real value: 0.5
                property string icon: ""
                property string title: ""
                property color fillColor: Theme.teal
                signal changed(real v)
                signal tapped()

                width: Theme.tileW(2)
                height: Theme.tileH(1)

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: parent.width * Math.max(0.03, sliderTile.value)
                    radius: parent.radius
                    color: Theme.alpha(sliderTile.fillColor, Theme.tileAlpha)
                    Behavior on width {
                        NumberAnimation {
                            duration: 90
                        }
                    }
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: sliderTile.icon
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                    color: Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: sliderTile.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: Math.round(sliderTile.value * 100) + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }

                MouseArea {
                    id: sliderArea

                    property real downX: 0
                    property bool dragged: false

                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: mouse => {
                        downX = mouse.x
                        dragged = false
                        apply(mouse.x)
                    }
                    onPositionChanged: mouse => {
                        if (pressed) {
                            if (Math.abs(mouse.x - downX) > 5)
                                dragged = true
                            apply(mouse.x)
                        }
                    }
                    onClicked: {
                        if (!dragged)
                            sliderTile.tapped()
                    }

                    function apply(x) {
                        sliderTile.changed(Math.max(0.01, Math.min(1, x / sliderTile.width)))
                    }
                }
            }

            SliderTile {
                value: root.volume / 100
                icon: root.volMuted ? "\uf026" : "\uf028"
                title: "Звук" + (root.volMuted ? " (выкл)" : "")
                fillColor: root.volMuted ? Theme.red : Theme.accent
                onChanged: v => {
                    root.volume = Math.round(v * 100)
                    root.volMuted = false
                    root.act("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2) + " && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0")
                }
                onTapped: root.act("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", true)
            }

            SliderTile {
                value: root.brightness / 100
                icon: String.fromCodePoint(0xe30d)
                title: "Яркость"
                fillColor: Theme.accent
                onChanged: v => {
                    root.brightness = Math.round(v * 100)
                    root.act("brightnessctl -q set " + Math.round(v * 100) + "%")
                }
            }

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.tileH(1)
                color: root.micMuted ? Qt.rgba(1, 1, 1, 0.07) : Theme.alpha(Theme.accent, Theme.tileAlpha)
                onClicked: root.act("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", true)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf130"
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                    color: Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Микрофон"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.micMuted ? "выключен" : "включён"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }
            }

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.tileH(1)
                color: Theme.glass
                onClicked: root.act("grim \"$HOME/Pictures/Screenshot-$(date +%Y%m%d-%H%M%S).png\"", "")

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf030"
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                    color: Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Снимок экрана"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: "в ~/Pictures"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }
            }
        }

        TileFrame {
            width: parent.width
            height: 150
            visible: root.playerVisible
            color: Theme.glass

            Row {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    width: 84
                    height: 84
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Media.artUrl !== "" ? "transparent" : Theme.glass

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: Media.artUrl !== "" && status === Image.Ready
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Media.artUrl === ""
                        text: "\uf001"
                        font.family: Theme.iconFont
                        font.pixelSize: 34
                        color: Theme.text
                    }
                }

                Column {
                    width: parent.width - 112
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

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
                        text: Media.artist !== "" ? Media.artist : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }

                    Item {
                        id: seekBar

                        property real dragFrac: -1

                        width: parent.width
                        height: 18

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: 2.5
                            color: Qt.rgba(1, 1, 1, 0.15)
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * (seekBar.dragFrac >= 0 ? seekBar.dragFrac : (Media.length > 0 ? Math.min(1, Media.pos / Media.length) : 0))
                            height: 5
                            radius: 2.5
                            color: Theme.accent
                        }

                        // перетаскивание прогресса
                        MouseArea {
                            id: seekMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function frac(mouse) {
                                return Math.max(0, Math.min(1, mouse.x / seekBar.width))
                            }

                            onPressed: mouse => seekBar.dragFrac = frac(mouse)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    seekBar.dragFrac = frac(mouse)
                            }
                            onReleased: mouse => {
                                const f = frac(mouse)
                                if (Media.length > 0)
                                    Media.seek(f * Media.length)
                                seekBar.dragFrac = -1
                            }
                        }
                    }

                    Row {
                        spacing: 26
                        anchors.horizontalCenter: parent.horizontalCenter

                        component MediaBtn: Text {
                            id: mb

                            required property string glyph
                            required property string cmd
                            property real px: 22

                            text: mb.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: mb.px
                            color: Theme.text

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.act(mb.cmd)
                            }
                        }

                        MediaBtn {
                            glyph: "\uf04a"
                            cmd: "previous"
                        }

                        MediaBtn {
                            glyph: Media.playStatus === "playing" ? "\uf04c" : "\uf04b"
                            cmd: "play-pause"
                            px: 26
                        }

                        MediaBtn {
                            glyph: "\uf04e"
                            cmd: "next"
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.playerVisible
            text: Media.playStatus === "playing" ? fmtTime(Media.pos) + " / " + fmtTime(Media.length) : (Media.playStatus === "paused" ? "пауза" : "нет активных плееров")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }


        // ─── уведомления ───
        Item {
            id: notifHeader

            width: parent.width
            height: 26

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 2
                    verticalCenter: parent.verticalCenter
                }
                text: "уведомления"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2.5
                color: Theme.textDim
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 132
                    verticalCenter: parent.verticalCenter
                }
                text: notifModel.count > 0 ? notifModel.count : ""
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.alpha(Theme.accent, 0.9)
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                visible: notifModel.count > 0
                color: notifClearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf1f8"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: Theme.textDim
                }

                MouseArea {
                    id: notifClearMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearNotifs()
                }
            }
        }

        Text {
            width: parent.width
            height: visible ? 18 : 0
            visible: notifModel.count === 0
            text: "пусто"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textDim
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            id: notifListV

            // растянут до низа панели; при раскрытии меню Wi-Fi/BT «складывается»
            readonly property int spaceAbove: notifHeader.y + notifHeader.height + 14
            height: Math.max(108, ccFlick.height - spaceAbove - 22)

            Behavior on height {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            width: parent.width
            clip: true
            model: notifModel
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            interactive: true

            // плавный доводчик скролла
            NumberAnimation {
                id: nScrollAnim

                target: notifListV
                property: "contentY"
                duration: 200
                easing.type: Easing.OutQuad
            }

            onDragStarted: nScrollAnim.stop()
            onFlickStarted: nScrollAnim.stop()

            function smoothScroll(dy) {
                const max = Math.max(0, notifListV.contentHeight - notifListV.height)
                nScrollAnim.stop()
                nScrollAnim.to = Math.max(0, Math.min(max, notifListV.contentY - dy * 1.9))
                nScrollAnim.restart()
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: wheel => notifListV.smoothScroll(wheel.angleDelta.y)
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 220
                }

                NumberAnimation {
                    property: "scale"
                    from: 0.94
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            addDisplaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: 140
                }

                NumberAnimation {
                    property: "height"
                    to: 0
                    duration: 240
                    easing.type: Easing.InQuad
                }
            }

            removeDisplaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            delegate: Item {
                id: nrow

                width: notifListV.width
                height: 62
                transform: Translate {
                    id: rowShift

                    x: 0
                }

                readonly property bool isFileIcon: model.icon.indexOf("/") === 0
                readonly property bool hasIcon: isFileIcon || (model.icon !== "" && Quickshell.hasThemeIcon(model.icon))

                function dismissMe() {
                    root.dismissNotif(model.nid)
                }

                // карточка
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Theme.stroke
                }

                // полоска срочности слева
                Rectangle {
                    anchors {
                        left: parent.left
                        leftMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    width: 3
                    height: parent.height - 20
                    radius: 1.5
                    color: model.urgency === "critical" ? Theme.red : Theme.alpha(Theme.accent, 0.75)
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    height: 40
                    radius: Theme.radiusSmall
                    color: Theme.glass
                    clip: true

                    IconImage {
                        anchors.centerIn: parent
                        visible: nrow.hasIcon && !nrow.isFileIcon
                        implicitSize: 24
                        source: nrow.hasIcon && !nrow.isFileIcon ? Quickshell.iconPath(model.icon) : ""
                    }

                    Image {
                        anchors.fill: parent
                        visible: nrow.isFileIcon
                        source: nrow.isFileIcon ? "file://" + model.icon : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !nrow.hasIcon
                        text: "\uf0f3"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.textDim
                    }
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 68
                        right: timeText.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 3

                    Text {
                        width: parent.width
                        text: model.app !== "" ? model.app + " · " + model.summary : model.summary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: model.urgency === "critical" ? Theme.red : Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: model.body
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.StyledText
                    }
                }

                Text {
                    id: timeText

                    anchors {
                        right: parent.right
                        rightMargin: 12
                        top: parent.top
                        topMargin: 10
                    }
                    text: Qt.formatDateTime(new Date(model.ntime), "HH:mm")
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textDim
                }

                // свайп вбок чтобы убрать карточку (как на телефоне)
                MouseArea {
                    id: swipeMa

                    property point startPt: Qt.point(0, 0)
                    property bool swiping: false

                    anchors.fill: parent
                    onPressed: mouse => {
                        startPt = Qt.point(mouse.x, mouse.y)
                        swiping = false
                    }
                    onPositionChanged: mouse => {
                        const dx = mouse.x - startPt.x
                        const dy = mouse.y - startPt.y
                        if (!swiping && Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy) * 1.4) {
                            swiping = true
                            swipeMa.preventStealing = true
                            springBack.stop()
                        }
                        if (swiping)
                            rowShift.x = dx
                    }
                    onReleased: {
                        if (swiping && Math.abs(rowShift.x) > nrow.width * 0.35) {
                            flyOut.restart()
                        } else if (swiping) {
                            springBack.restart()
                        }
                        swiping = false
                    }
                    onCanceled: {
                        springBack.restart()
                        swiping = false
                    }
                }

                NumberAnimation {
                    id: springBack

                    target: rowShift
                    property: "x"
                    to: 0
                    duration: 220
                    easing.type: Easing.OutCubic
                }

                SequentialAnimation {
                    id: flyOut

                    ParallelAnimation {
                        NumberAnimation {
                            target: rowShift
                            property: "x"
                            to: rowShift.x >= 0 ? nrow.width + 40 : -(nrow.width + 40)
                            duration: 200
                            easing.type: Easing.InQuad
                        }

                        NumberAnimation {
                            target: nrow
                            property: "opacity"
                            to: 0
                            duration: 200
                        }
                    }

                    ScriptAction {
                        script: nrow.dismissMe()
                    }
                }
            }
        }
    }
    }
}

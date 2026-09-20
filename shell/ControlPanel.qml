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
    property bool dndActive: false
    property string powerProfile: "balanced"
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
        // cap: словарь только рос за сессию — режем старые ключи
        const ks = Object.keys(h)
        if (ks.length > 500)
            ks.slice(0, ks.length - 500).forEach(k => delete h[k])
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
        const ks = Object.keys(h)
        if (ks.length > 500)
            ks.slice(0, ks.length - 500).forEach(k => delete h[k])
        root.notifHidden = h
        notifModel.clear()
        root.act("makoctl dismiss -a 2>/dev/null", false)
    }

    function cyclePowerProfile() {
        let next = "balanced"
        if (root.powerProfile === "performance")
            next = "balanced"
        else if (root.powerProfile === "balanced")
            next = "power-saver"
        else
            next = "performance"
        root.act("powerprofilesctl set " + next, true)
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
        const go = p => { if (!p.running) p.running = true }
        go(pVolGet)
        go(pBriGet)
        go(pWifiGet)
        go(pBtGet)
        go(pMicGet)
        go(pDndGet)
        go(pPowerGet)
        go(pBatGet)
        go(pNotif)
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
        id: pDndGet
        command: ["sh", "-c", "makoctl mode 2>/dev/null | grep -qw dnd && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => root.dndActive = data.trim() === "1"
        }
    }

    Process {
        id: pPowerGet
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo ''"]
        stdout: SplitParser {
            onRead: data => {
                const s = data.trim()
                if (s !== "")
                    root.powerProfile = s
            }
        }
    }

    Process {
        id: pBatGet
        command: ["sh", "-c", "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); case $b in '') b=/sys/class/power_supply/BAT0;; esac; echo c=$(cat $b/capacity 2>/dev/null || echo 0); echo s=$(cat $b/status 2>/dev/null)"]
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
        radius: Theme.panelRightRadius
        color: Theme.panelRightBg
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
                text: I18n.t("control_center")
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
                radius: Theme.isWP ? 0 : 15
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
                height: Theme.isMaterial ? 56 : Theme.tileH(1)
                radius: Theme.isMaterial ? Theme.radiusPill : Theme.radius
                color: root.wifiOn ? (Theme.isMaterial ? Theme.primary : Theme.alpha(Theme.accent, Theme.tileAlpha)) : (Theme.isMaterial ? Theme.surface_container_high : Theme.glass)
                onClicked: root.toggleWifiMenu()

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 16 : 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.wifiOn ? "\uf1eb" : String.fromCodePoint(0xf092d)
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.isMaterial ? 20 : 26
                    color: Theme.isMaterial ? (root.wifiOn ? Theme.on_primary : Theme.on_surface_variant) : Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 50 : 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.isMaterial ? 1 : 2

                    Text {
                        text: "Wi-Fi"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.isMaterial ? 13 : 14
                        font.weight: Font.DemiBold
                        color: Theme.isMaterial ? (root.wifiOn ? Theme.on_primary : Theme.on_surface) : Theme.text
                    }

                    Text {
                        text: root.wifiOn ? (root.ssid !== "" ? root.ssid : I18n.t("on")) : I18n.t("off")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.isMaterial ? (root.wifiOn ? Theme.alpha(Theme.on_primary, 0.8) : Theme.on_surface_variant) : Theme.textDim
                        width: 100
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.isMaterial ? 14 : 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf105"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Theme.isMaterial ? (root.wifiOn ? Theme.alpha(Theme.on_primary, 0.7) : Theme.on_surface_variant) : Theme.textDim
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
                height: Theme.isMaterial ? 56 : Theme.tileH(1)
                radius: Theme.isMaterial ? Theme.radiusPill : Theme.radius
                color: root.btOn ? (Theme.isMaterial ? Theme.primary : Theme.alpha(Theme.accent, Theme.tileAlpha)) : (Theme.isMaterial ? Theme.surface_container_high : Theme.glass)
                onClicked: root.toggleBtMenu()

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 16 : 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf294"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.isMaterial ? 20 : 26
                    color: Theme.isMaterial ? (root.btOn ? Theme.on_primary : Theme.on_surface_variant) : Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 50 : 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.isMaterial ? 1 : 2

                    Text {
                        text: "Bluetooth"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.isMaterial ? 13 : 14
                        font.weight: Font.DemiBold
                        color: Theme.isMaterial ? (root.btOn ? Theme.on_primary : Theme.on_surface) : Theme.text
                    }

                    Text {
                        text: root.btOn ? I18n.t("on") : I18n.t("off")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.isMaterial ? (root.btOn ? Theme.alpha(Theme.on_primary, 0.8) : Theme.on_surface_variant) : Theme.textDim
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.isMaterial ? 14 : 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf105"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Theme.isMaterial ? (root.btOn ? Theme.alpha(Theme.on_primary, 0.7) : Theme.on_surface_variant) : Theme.textDim
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

            // Dual-Theme Slider (Material 3 Pill vs Metro Live 2x1 Tile)
            component SliderTile: TileFrame {
                id: sliderTile
                property real value: 0.5
                property string icon: ""
                property string title: ""
                property color fillColor: Theme.primary
                signal changed(real v)
                signal iconClicked()

                width: Theme.tileW(2)
                height: Theme.isMaterial ? 56 : Theme.tileH(1)
                radius: Theme.isMaterial ? Theme.radiusPill : Theme.radius
                color: Theme.isMaterial ? Theme.surface_container_highest : Theme.glass
                clip: true

                // ── Material You Slider (Theme.isMaterial == true) ──
                Item {
                    id: matSlider
                    anchors.fill: parent
                    visible: Theme.isMaterial

                    // Заливка: в ноль уходит полностью, без круглой заглушки
                    Rectangle {
                        id: matFill
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * sliderTile.value
                        visible: sliderTile.value > 0.005
                        radius: Theme.radiusPill
                        color: sliderTile.fillColor

                        Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                    }

                    Item {
                        id: matIconBox
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: 50
                        // БЕЗ z: иконка ниже drag-зоны sliderArea — тап по иконке
                        // проваливается в mute-toggle, а драг идёт на всю ширину

                        Text {
                            anchors.centerIn: parent
                            text: sliderTile.icon
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            // Светлая только пока заливка реально под иконкой
                            color: (matSlider.width * sliderTile.value) > 25 ? Theme.on_primary : Theme.on_surface
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sliderTile.iconClicked()
                        }
                    }

                    // Базовый текст (тёмный, на треке)
                    Row {
                        id: matTextRow
                        anchors {
                            left: matIconBox.right
                            right: parent.right
                            rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6
                        z: 1

                        Text {
                            width: parent.width - 46
                            text: sliderTile.title
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.on_surface
                            elide: Text.ElideRight
                        }

                        Text {
                            text: Math.round(sliderTile.value * 100) + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.on_surface
                        }
                    }

                    // Knockout-дубль (светлый, виден только над заливкой):
                    // попиксельный переход вместо ступенек по порогам
                    Item {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: matFill.width
                        clip: true
                        z: 2
                        visible: matFill.visible

                        Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }

                        Row {
                            x: matIconBox.width
                            width: matTextRow.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                width: matTextRow.width - 46
                                text: sliderTile.title
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Theme.on_primary
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Math.round(sliderTile.value * 100) + "%"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.on_primary
                            }
                        }
                    }
                }

                // ── Classic Metro / WP Slider (Theme.isMaterial == false) ──
                Item {
                    anchors.fill: parent
                    visible: !Theme.isMaterial

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * Math.max(0.03, sliderTile.value)
                        radius: Theme.radius
                        color: Theme.alpha(sliderTile.fillColor, Theme.tileAlpha)
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }

                    Item {
                        id: metroIconBox
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: 48
                        z: 2

                        Text {
                            anchors.centerIn: parent
                            text: sliderTile.icon
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                            color: Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sliderTile.iconClicked()
                        }
                    }

                    Column {
                        anchors {
                            left: parent.left
                            leftMargin: 56
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2
                        z: 1

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
                }

                MouseArea {
                    id: sliderArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    property real pressX: -1
                    onPressed: mouse => { pressX = mouse.x; apply(mouse.x) }
                    onPositionChanged: mouse => {
                        if (pressed) apply(mouse.x)
                    }
                    // Тап без движения: левая иконка-зона = mute-toggle.
                    // Конец драга в иконке мут не дёргает (проверяем pressX).
                    onClicked: mouse => {
                        if (mouse.x < 54 && pressX >= 0 && pressX < 54) sliderTile.iconClicked()
                    }

                    function apply(x) {
                        sliderTile.changed(Math.max(0.0, Math.min(1.0, x / sliderTile.width)))
                    }
                }
            }

            SliderTile {
                value: root.volume / 100
                icon: root.volMuted ? "\uf026" : "\uf028"
                title: I18n.t("sound") + (root.volMuted ? " (" + I18n.t("muted") + ")" : "")
                fillColor: root.volMuted ? Theme.red : Theme.accent
                onChanged: v => {
                    root.volume = Math.round(v * 100)
                    root.volMuted = false
                    root.act("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2) + " && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0")
                }
                onIconClicked: root.act("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", true)
            }

            SliderTile {
                value: root.brightness / 100
                icon: String.fromCodePoint(0xe30d)
                title: I18n.t("brightness")
                fillColor: Theme.accent
                onChanged: v => {
                    root.brightness = Math.round(v * 100)
                    root.act("brightnessctl -q set " + Math.round(v * 100) + "%")
                }
            }

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.isMaterial ? 56 : Theme.tileH(1)
                radius: Theme.isMaterial ? Theme.radiusPill : Theme.radius
                color: !root.micMuted ? (Theme.isMaterial ? Theme.primary : Theme.alpha(Theme.accent, Theme.tileAlpha)) : (Theme.isMaterial ? Theme.surface_container_high : Theme.glass)
                onClicked: root.act("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", true)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 16 : 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf130"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.isMaterial ? 20 : 26
                    color: Theme.isMaterial ? (!root.micMuted ? Theme.on_primary : Theme.on_surface_variant) : Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 50 : 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.isMaterial ? 1 : 2

                    Text {
                        text: I18n.t("microphone")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.isMaterial ? 13 : 14
                        font.weight: Font.DemiBold
                        color: Theme.isMaterial ? (!root.micMuted ? Theme.on_primary : Theme.on_surface) : Theme.text
                    }

                    Text {
                        text: root.micMuted ? I18n.t("off") : I18n.t("on")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.isMaterial ? (!root.micMuted ? Theme.alpha(Theme.on_primary, 0.8) : Theme.on_surface_variant) : Theme.textDim
                    }
                }
            }

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.isMaterial ? 56 : Theme.tileH(1)
                radius: Theme.isMaterial ? Theme.radiusPill : Theme.radius
                color: root.dndActive ? (Theme.isMaterial ? Theme.primary : Theme.alpha(Theme.accent, Theme.tileAlpha)) : (Theme.isMaterial ? Theme.surface_container_high : Theme.glass)
                onClicked: root.act("makoctl mode -t dnd 2>/dev/null", true)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 16 : 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.dndActive ? "\uf1f6" : "\uf0f3"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.isMaterial ? 20 : 24
                    color: Theme.isMaterial ? (root.dndActive ? Theme.on_primary : Theme.on_surface_variant) : Theme.text
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.isMaterial ? 50 : 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.isMaterial ? 1 : 2

                    Text {
                        text: I18n.t("dnd")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.isMaterial ? 13 : 14
                        font.weight: Font.DemiBold
                        color: Theme.isMaterial ? (root.dndActive ? Theme.on_primary : Theme.on_surface) : Theme.text
                    }

                    Text {
                        text: root.dndActive ? I18n.t("silent_mode") : I18n.t("notifications_on")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.isMaterial ? (root.dndActive ? Theme.alpha(Theme.on_primary, 0.8) : Theme.on_surface_variant) : Theme.textDim
                    }
                }
            }

            TileFrame {
                id: shotTile
                width: Theme.tileW(2)
                height: Theme.tileH(1)
                color: shotFlash.opacity > 0 ? Theme.alpha(Theme.accent, 0.35) : Theme.glass

                Item {
                    anchors.fill: parent
                    id: shotFlash
                    opacity: 0
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.accent
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                Text {
                    id: shotIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uf030"
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: Theme.text
                    Behavior on scale {
                        NumberAnimation { duration: 120 }
                    }
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: I18n.t("screenshot")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: "metro-shot"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }

                Timer {
                    id: shotFlashTimer
                    interval: 180
                    repeat: false
                    onTriggered: {
                        shotFlash.opacity = 0
                        shotIcon.scale = 1.0
                    }
                }

                onClicked: {
                    shotFlash.opacity = 0.45
                    shotIcon.scale = 1.25
                    shotFlashTimer.restart()
                    root.act("$HOME/.local/bin/metro-shot", "")
                }
            }

            TileFrame {
                width: Theme.tileW(2)
                height: Theme.tileH(1)
                color: root.powerProfile === "performance" ? Theme.alpha(Theme.orange, 0.25) : Theme.glass
                onClicked: root.cyclePowerProfile()

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.powerProfile === "performance" ? "\uf0e7" : (root.powerProfile === "power-saver" ? "\uf188" : "\uf240")
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                    color: root.powerProfile === "performance" ? Theme.orange : (root.powerProfile === "power-saver" ? Theme.lime : Theme.accent)
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: I18n.t("power_sec")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.powerProfile === "performance" ? I18n.t("performance") : (root.powerProfile === "power-saver" ? I18n.t("power_saver") : I18n.t("balanced"))
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.7)
                        width: 110
                        elide: Text.ElideRight
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
            text: Media.playStatus === "playing" ? fmtTime(Media.pos) + " / " + fmtTime(Media.length) : (Media.playStatus === "paused" ? I18n.t("paused") : I18n.t("no_players"))
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }

        // ─── Notifications ───
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
                text: I18n.t("notifications")
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
            text: I18n.t("empty")
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
                height: 66
                transform: Translate {
                    id: rowShift

                    x: 0
                }

                readonly property bool isFileIcon: model.icon.indexOf("/") === 0
                readonly property bool hasIcon: isFileIcon || (model.icon !== "" && Quickshell.hasThemeIcon(model.icon))

                function dismissMe() {
                    root.dismissNotif(model.nid)
                }

                function invokeMe() {
                    // nid приходит из mako history (внешний ввод от любого
                    // отправителя уведомлений) — только цифры, иначе отказ
                    if (!/^\d+$/.test(String(model.nid)))
                        return
                    root.act("makoctl invoke -n " + model.nid + " 2>/dev/null || makoctl restore 2>/dev/null", false)
                    nrow.dismissMe()
                }

                // карточка
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: swipeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: swipeMa.containsMouse ? Theme.alpha(Theme.accent, 0.4) : Theme.stroke

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
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
                        maximumLineCount: 2
                        textFormat: Text.StyledText
                    }
                }

                Text {
                    id: timeText

                    anchors {
                        right: parent.right
                        rightMargin: closeBtn.visible ? 30 : 12
                        top: parent.top
                        topMargin: 10
                    }
                    text: Qt.formatDateTime(new Date(model.ntime), "HH:mm")
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textDim
                }

                // Кнопка быстрого закрытия
                Rectangle {
                    id: closeBtn

                    anchors {
                        right: parent.right
                        rightMargin: 8
                        top: parent.top
                        topMargin: 8
                    }
                    width: 18
                    height: 18
                    radius: 9
                    visible: swipeMa.containsMouse || closeMa.containsMouse
                    color: closeMa.containsMouse ? Theme.alpha(Theme.red, 0.3) : Qt.rgba(1, 1, 1, 0.12)
                    z: 3

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                        color: closeMa.containsMouse ? Theme.red : Theme.textDim
                    }

                    MouseArea {
                        id: closeMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!/^\d+$/.test(String(model.nid)))
                                return
                            root.act("makoctl dismiss -n " + model.nid + " 2>/dev/null", false)
                            nrow.dismissMe()
                        }
                    }
                }

                // Клик (invoke) + свайп вбок чтобы убрать карточку
                MouseArea {
                    id: swipeMa

                    property point startPt: Qt.point(0, 0)
                    property bool swiping: false
                    property bool dragged: false

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        startPt = Qt.point(mouse.x, mouse.y)
                        swiping = false
                        dragged = false
                    }
                    onPositionChanged: mouse => {
                        const dx = mouse.x - startPt.x
                        const dy = mouse.y - startPt.y
                        if (Math.abs(dx) > 5 || Math.abs(dy) > 5)
                            dragged = true
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
                    onClicked: {
                        if (!dragged && !swiping)
                            nrow.invokeMe()
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

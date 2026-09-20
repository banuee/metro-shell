import QtQuick
import Quickshell.Io

Item {
    id: root

    // фиксированная высота раскрытия: если список сетей придёт mid-animation,
    // анимация не «перескакивает»
    readonly property real openHeight: 298

    property bool shown: false
    property bool wifiOn: true
    property string wifiDev: ""
    property string status: ""
    property string connectingSsid: ""
    property string pendingSsid: ""
    property var networks: []
    signal settingsRequested()

    function splitLine(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && line[i + 1] === "\\") {
                cur += "\\"
                i++
            } else if (line[i] === "\\" && line[i + 1] === ":") {
                cur += ":"
                i++
            } else if (line[i] === ":") {
                out.push(cur)
                cur = ""
            } else {
                cur += line[i]
            }
        }
        out.push(cur)
        return out
    }

    function refresh() {
        pList.running = true
        pDev.running = true
    }

    function connect(ssid, pass) {
        connectingSsid = ssid
        status = I18n.t("connecting_to") + " " + ssid + "..."
        // argv, без sh: SSID/пароль уходят отдельными аргументами nmcli,
        // подстановки shell невозможны даже при враждебном SSID из эфира
        let args = ["nmcli", "dev", "wifi", "connect", ssid]
        if (pass !== "")
            args.push("password", pass)
        pConnect.command = args
        pConnect.running = true
    }

    function disconnect() {
        if (wifiDev === "")
            return
        status = I18n.t("disconnecting")
        pConnect.command = ["nmcli", "dev", "disconnect", wifiDev]
        pConnect.running = true
    }

    onShownChanged: if (shown) {
        pendingSsid = ""
        refresh()
    }

    Component.onCompleted: refresh()

    width: parent ? parent.width : 0
    height: shown ? openHeight : 0
    clip: true
    visible: height > 0

    Behavior on height {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: sheet

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: root.openHeight
        opacity: root.shown ? 1 : 0
        transform: Translate {
            id: sheetShift

            y: root.shown ? 0 : -16

            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke
        }

        Column {
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 6

            Item {
                width: parent.width
                height: 30

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("networks")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: status !== ""
                    text: status
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    component CircleBtn: Rectangle {
                        id: cb

                        property string glyph: ""
                        property bool active: false
                        signal activated()

                        width: 28
                        height: 28
                        radius: 14
                        color: cb.active ? Theme.alpha(Theme.accent, 0.85) : btnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cb.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: Theme.text
                        }

                        MouseArea {
                            id: btnMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cb.activated()
                        }
                    }

                    CircleBtn {
                        glyph: "\uf013"
                        onActivated: root.settingsRequested()
                    }

                    CircleBtn {
                        id: powerBtn

                        glyph: "\uf011"
                        active: root.wifiOn
                        onActivated: {
                            pPower.command = ["sh", "-c", "nmcli radio wifi " + (root.wifiOn ? "off" : "on")]
                            pPower.running = true
                        }
                    }

                    CircleBtn {
                        glyph: "\uf021"
                        onActivated: {
                            pRescan.running = true
                            status = I18n.t("searching_networks")
                        }
                    }
                }
            }

            Flickable {
                id: netsFlick

                width: parent.width
                height: parent.height - 36
                clip: true
                contentHeight: netsCol.height
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: wheel => netsFlick.contentY = Math.max(0, Math.min(Math.max(0, netsFlick.contentHeight - netsFlick.height), netsFlick.contentY - wheel.angleDelta.y / 3))
                }

                Column {
                    id: netsCol

                    width: netsFlick.width
                    spacing: 2

                    Repeater {
                        model: root.networks

                        Item {
                            width: netsCol.width
                            height: 34

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: netMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : modelData.active ? Theme.alpha(Theme.accent, 0.18) : "transparent"
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                text: String.fromCodePoint(parseInt("f092" + Math.min(4, Math.max(1, Math.round(modelData.signal / 25))), 16))
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                color: modelData.active ? Theme.accent : Theme.text
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 40
                                    verticalCenter: parent.verticalCenter
                                }
                                width: parent.width - 110
                                text: modelData.ssid
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.connectingSsid === modelData.ssid ? "..." : modelData.secure ? "\uf023" : ""
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: Theme.textDim
                            }

                            MouseArea {
                                id: netMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.active) {
                                        root.disconnect()
                                    } else if (modelData.secure) {
                                        root.pendingSsid = modelData.ssid
                                    } else {
                                        root.connect(modelData.ssid, "")
                                    }
                                }
                            }
                        }
                    }

                    // ввод пароля
                    Item {
                        width: netsCol.width
                        height: root.pendingSsid !== "" ? 40 : 0
                        visible: height > 0
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.06)

                            TextInput {
                                id: passInput

                                anchors {
                                    left: parent.left
                                    leftMargin: 12
                                    right: btnRow.left
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.text
                                echoMode: TextInput.Password
                                clip: true

                                Text {
                                    visible: passInput.text === "" && !passInput.activeFocus
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.t("password") + " " + root.pendingSsid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textDim
                                }
                            }

                            Row {
                                id: btnRow

                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    width: 30
                                    height: 26
                                    radius: 6
                                    color: Theme.alpha(Theme.accent, 0.85)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00c"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                        color: Theme.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connect(root.pendingSsid, passInput.text)
                                    }
                                }

                                Rectangle {
                                    width: 30
                                    height: 26
                                    radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00d"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                        color: Theme.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            passInput.text = ""
                                            root.pendingSsid = ""
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        width: netsCol.width
                        visible: root.networks.length === 0
                        text: !root.wifiOn ? I18n.t("wifi_off") : I18n.t("no_networks")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    Process {
        id: pList

        command: ["sh", "-c", "LC_ALL=C nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l !== "")
                const list = []
                for (let i = 0; i < lines.length; i++) {
                    const f = root.splitLine(lines[i])
                    if (f.length < 4 || f[1] === "" || f[1] === "--")
                        continue
                    list.push({
                        "active": f[0] === "yes" || f[0] === "*",
                        "ssid": f[1],
                        "signal": parseInt(f[2]) || 0,
                        "secure": f[3] !== "" && f[3] !== "--"
                    })
                }
                root.networks = list
                if (root.status.indexOf("Search") === 0 || root.status.indexOf("Поиск") === 0 || root.status === I18n.t("searching_networks"))
                    root.status = ""
            }
        }
    }

    Process {
        id: pDev

        command: ["sh", "-c", "echo d=$(LC_ALL=C nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | cut -d: -f1); echo r=$(LC_ALL=C nmcli radio wifi 2>/dev/null)"]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("d="))
                    root.wifiDev = data.substring(2).trim()
                else if (data.startsWith("r="))
                    root.wifiOn = data.substring(2).trim() === "enabled"
            }
        }
    }

    Process {
        id: pConnect

        onExited: {
            root.connectingSsid = ""
            root.pendingSsid = ""
            root.refresh()
        }
    }

    Process {
        id: pPower

        onExited: root.refresh()
    }

    Process {
        id: pRescan

        command: ["sh", "-c", "LC_ALL=C nmcli dev wifi rescan 2>/dev/null"]
    }
}

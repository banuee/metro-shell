import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds

    property var win

    // wi-fi
    property bool wifiOn: false
    property string wifiSsid: ""
    property string wifiDev: ""
    property var networks: []
    property var knownWifi: []

    // bluetooth
    property bool btOn: false
    property var btDevices: []
    property bool scanning: false

    function esc(s) {
        return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$")
    }

    // разбор -t строки с экранированными \: внутри полей
    function splitT(l) {
        const parts = []
        let cur = "", i = 0
        while (i < l.length) {
            if (l[i] === "\\" && l[i + 1] === ":") {
                cur += ":"
                i += 2
                continue
            }
            if (l[i] === ":") {
                parts.push(cur)
                cur = ""
                i++
                continue
            }
            cur += l[i]
            i++
        }
        parts.push(cur)
        return parts
    }

    function refresh() {
        pWl.command = ["sh", "-c", "echo p=$(nmcli radio wifi 2>/dev/null); echo d=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | head -n1 | cut -d: -f1); echo n=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep ':802-11-wireless:' | head -n1 | cut -d: -f1)"]
        pWl.running = true
        pNet.command = ["sh", "-c", "LC_ALL=C nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        pNet.running = true
        pKnown.command = ["sh", "-c", "LC_ALL=C nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep 802-11-wireless"]
        pKnown.running = true
        refreshBt()
    }

    function refreshBt() {
        pBt.command = ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -i 'Powered'; echo ---; bluetoothctl devices Paired 2>/dev/null; echo ---; bluetoothctl devices Connected 2>/dev/null"]
        pBt.running = true
        pAllBt.command = ["sh", "-c", "bluetoothctl devices 2>/dev/null"]
        pAllBt.running = true
    }

    Timer {
        id: delay

        interval: 1500
        onTriggered: refresh()
    }

    Timer {
        id: scanTimer

        interval: 2000
        repeat: true
        onTriggered: {
            root.refreshBt()
            root.scanTicks--
            if (root.scanTicks <= 0) {
                stop()
                root.scanning = false
            }
        }
    }

    property int scanTicks: 0

    Process {
        id: pScan

        command: ["true"]
    }

    function startScan() {
        if (!btOn || scanning)
            return
        scanning = true
        scanTicks = 6
        pScan.command = ["timeout", "10", "bluetoothctl", "scan", "on"]
        pScan.running = true
        scanTimer.restart()
    }

    function connectWifi(ssid, pw) {
        let c = "nmcli dev wifi connect \"" + esc(ssid) + "\""
        if (pw !== null && pw !== "")
            c += " password \"" + esc(pw) + "\""
        win.run(c)
        delay.interval = 2500
        delay.restart()
    }

    Process {
        id: pWl

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const f = root.splitT(line)
                    for (const item of f) {
                        if (item.startsWith("p="))
                            root.wifiOn = item.slice(2) === "enabled"
                        else if (item.startsWith("d="))
                            root.wifiDev = item.slice(2)
                        else if (item.startsWith("n="))
                            root.wifiSsid = item.slice(2)
                    }
                }
            }
        }
    }

    Process {
        id: pNet

        stdout: StdioCollector {
            onStreamFinished: {
                const nets = []
                let actSsid = ""
                for (const line of text.split("\n")) {
                    const parts = root.splitT(line)
                    if (parts.length < 4 || parts[1] === "")
                        continue
                    if (parts[0] === "*")
                        actSsid = parts[1]
                    nets.push({
                        ssid: parts[1],
                        signal: parseInt(parts[2]) || 0,
                        sec: parts[3],
                        active: parts[0] === "*"
                    })
                }
                nets.sort((a, b) => b.signal - a.signal)
                root.networks = nets
                if (actSsid !== "")
                    root.wifiSsid = actSsid
            }
        }
    }

    Process {
        id: pKnown

        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                for (const line of text.split("\n")) {
                    const parts = root.splitT(line)
                    if (parts.length >= 2 && parts[0] !== "")
                        names.push(parts[0])
                }
                root.knownWifi = names
            }
        }
    }

    Process {
        id: pBt

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---")
                root.btOn = /powered:\s*yes/i.test(parts[0] || "")
                const pairedSet = {}
                for (const l of (parts[1] || "").split("\n")) {
                    const m = l.match(/^Device ([0-9A-Fa-f:]+)\s(.*)$/)
                    if (m)
                        pairedSet[m[1]] = m[2]
                }
                const connSet = {}
                for (const l of (parts[2] || "").split("\n")) {
                    const m = l.match(/^Device ([0-9A-Fa-f:]+)\s(.*)$/)
                    if (m)
                        connSet[m[1]] = true
                }
                root.btPaired = pairedSet
                root.btConn = connSet
            }
        }
    }

    property var btPaired: ({})
    property var btConn: ({})

    Process {
        id: pAllBt

        stdout: StdioCollector {
            onStreamFinished: {
                const devs = []
                for (const l of text.split("\n")) {
                    const m = l.match(/^Device ([0-9A-Fa-f:]+)\s(.*)$/)
                    if (!m)
                        continue
                    devs.push({
                        mac: m[1],
                        name: m[2] !== "" ? m[2] : m[1],
                        paired: root.btPaired[m[1]] !== undefined,
                        connected: root.btConn[m[1]] !== undefined
                    })
                }
                devs.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
                root.btDevices = devs
            }
        }
    }

    Column {
        id: col

        width: root.width
        spacing: 10

        // ─── wi-fi ───
        Text {
            text: "WI-FI"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Rectangle {
            width: parent.width
            height: 48
            radius: 8
            color: Theme.glass

            KitToggle {
                id: wifiT

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                checked: root.wifiOn
                onToggled: c => {
                    root.win.run("nmcli radio wifi " + (c ? "on" : "off"))
                    delay.interval = 1200
                    delay.restart()
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 70
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.wifiOn ? (root.wifiSsid === "" ? "не подключено" : root.wifiSsid) : "wi-fi выключен"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: root.wifiOn ? Theme.text : Theme.textDim
                }
                Text {
                    text: root.networks.length + " сетей найдено"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 92
                height: 30
                radius: 6
                color: rescanMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: "обновить"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.text
                }

                MouseArea {
                    id: rescanMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.win.run("nmcli dev wifi rescan")
                        delay.interval = 1800
                        delay.restart()
                    }
                }
            }
        }

        Repeater {
            model: root.wifiOn ? root.networks : []

            Rectangle {
                id: netRow

                width: parent.width
                height: 42
                radius: 8
                color: netMa.containsMouse ? Theme.glassHover : Theme.glass

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                required property var modelData

                MouseArea {
                    id: netMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const nd = netRow.modelData
                        if (nd.active) {
                            root.win.run("nmcli dev disconnect " + root.wifiDev)
                        } else if (nd.sec !== "" && root.knownWifi.indexOf(nd.ssid) < 0) {
                            root.win.askText("пароль «" + nd.ssid + "»", "пароль", pw => root.connectWifi(nd.ssid, pw))
                        } else {
                            root.connectWifi(nd.ssid, "")
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: netRow.modelData.active ? "\uf058" : (netRow.modelData.sec !== "" ? "\uf023" : "\uf09c")
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: netRow.modelData.active ? Theme.accent : Theme.textDim
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: netOps.left
                    anchors.rightMargin: 8
                    text: netRow.modelData.ssid
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    color: netRow.modelData.active ? Theme.text : Theme.textDim
                }

                Row {
                    id: netOps

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        visible: root.knownWifi.indexOf(netRow.modelData.ssid) >= 0
                        width: ftxt.width + 16
                        height: 26
                        radius: 5
                        color: forgetMa.containsMouse ? Theme.alpha(Theme.red, 0.55) : Qt.rgba(1, 1, 1, 0.06)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            id: ftxt

                            anchors.centerIn: parent
                            text: "забыть"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textDim
                        }

                        MouseArea {
                            id: forgetMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.win.run("nmcli connection delete id \"" + root.esc(netRow.modelData.ssid) + "\"")
                                delay.interval = 1200
                                delay.restart()
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: netRow.modelData.signal + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }
            }
        }

        Item {
            width: 1
            height: 8
        }

        // ─── bluetooth ───
        Text {
            text: "BLUETOOTH"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Rectangle {
            width: parent.width
            height: 48
            radius: 8
            color: Theme.glass

            KitToggle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                checked: root.btOn
                onToggled: c => {
                    root.win.run("bluetoothctl power " + (c ? "on" : "off"))
                    delay.interval = 1200
                    delay.restart()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 70
                anchors.verticalCenter: parent.verticalCenter
                text: root.btOn ? (root.scanning ? "поиск устройств…" : root.btDevices.filter(d => d.connected).length + " подключено") : "bluetooth выключен"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                color: root.btOn ? Theme.text : Theme.textDim
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 92
                height: 30
                radius: 6
                color: scanMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: root.scanning ? "ищу…" : "поиск"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.text
                }

                MouseArea {
                    id: scanMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startScan()
                }
            }
        }

        Repeater {
            model: root.btOn ? root.btDevices : []

            Rectangle {
                id: btRow

                width: parent.width
                height: 42
                radius: 8
                color: btMa.containsMouse ? Theme.glassHover : Theme.glass

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                required property var modelData

                MouseArea {
                    id: btMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: btRow.modelData.connected ? Theme.accent : (btRow.modelData.paired ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08))
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: btRow.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: btRow.modelData.connected ? Theme.text : Theme.textDim
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: bTxt.width + 18
                    height: 26
                    radius: 5
                    color: btOpMa.containsMouse ? Theme.alpha(Theme.accent, 0.5) : Qt.rgba(1, 1, 1, 0.06)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        id: bTxt

                        anchors.centerIn: parent
                        text: btRow.modelData.connected ? "отключить" : (btRow.modelData.paired ? "подключить" : "пара")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.text
                    }

                    MouseArea {
                        id: btOpMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const d = btRow.modelData
                            if (d.connected) {
                                root.win.run("bluetoothctl disconnect " + d.mac)
                            } else if (d.paired) {
                                root.win.run("bluetoothctl connect " + d.mac)
                            } else {
                                root.win.run("bluetoothctl pair " + d.mac + " && bluetoothctl trust " + d.mac + " && bluetoothctl connect " + d.mac)
                            }
                            delay.interval = 2000
                            delay.restart()
                        }
                    }
                }
            }
        }
    }
}

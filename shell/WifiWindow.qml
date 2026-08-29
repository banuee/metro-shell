import QtQuick
import Quickshell.Io

SettingsWindow {
    id: root

    title: "Wi-Fi"

    property bool wifiOn: true
    property var networks: []
    property string status: ""
    property string connectingSsid: ""
    property string pendingSsid: ""
    property string wifiDev: ""

    dialogWidth: 480

    function esc(s) {
        return s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    }

    function splitLine(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && line[i + 1] === ":") {
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
        status = "Подключение к " + ssid + "..."
        let cmd = "nmcli dev wifi connect \"" + esc(ssid) + "\""
        if (pass !== "")
            cmd += " password \"" + esc(pass) + "\""
        pConnect.command = ["sh", "-c", cmd]
        pConnect.running = true
    }

    function disconnect() {
        if (wifiDev === "")
            return
        status = "Отключение..."
        pConnect.command = ["sh", "-c", "nmcli dev disconnect " + wifiDev]
        pConnect.running = true
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
                    if (f.length < 4 || f[1] === "")
                        continue
                    list.push({
                        "active": f[0] === "yes",
                        "ssid": f[1],
                        "signal": parseInt(f[2]) || 0,
                        "secure": f[3] !== ""
                    })
                }
                root.networks = list
                if (root.status.indexOf("Поиск") === 0)
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

    Column {
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 30

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiOn ? "Доступные сети" : "Wi-Fi выключен"
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

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: root.wifiOn ? Theme.alpha(Theme.teal, 0.85) : powerMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf011"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.text
                    }

                    MouseArea {
                        id: powerMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pPower.command = ["sh", "-c", "nmcli radio wifi " + (root.wifiOn ? "off" : "on")]
                            pPower.running = true
                        }
                    }
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: rescanMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf021"
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: Theme.text
                    }

                    MouseArea {
                        id: rescanMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pRescan.running = true
                            status = "Поиск сетей..."
                        }
                    }
                }
            }
        }

        // список сетей с прокруткой
        Item {
            width: parent.width
            height: Math.min(root.networks.length, 7) * 38 + (root.pendingSsid !== "" ? 46 : 0)

            Flickable {
                anchors.fill: parent
                clip: true
                contentHeight: netsCol.height
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: wheel => flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - wheel.angleDelta.y / 3))
                }

                Column {
                    id: netsCol

                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.networks

                        Item {
                            width: netsCol.width
                            height: 36

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: netMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : modelData.active ? Qt.rgba(0, 0.67, 0.66, 0.18) : "transparent"
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
                                color: modelData.active ? Theme.teal : Theme.text
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
                        height: root.pendingSsid !== "" ? 42 : 0
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
                                    text: "пароль " + root.pendingSsid
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
                                    height: 28
                                    radius: 6
                                    color: Theme.alpha(Theme.teal, 0.85)

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
                                    height: 28
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
                }
            }
        }
    }

    onVisibleChanged: if (visible)
        refresh()

    Component.onCompleted: refresh()
}

import QtQuick
import Quickshell.Io

SettingsWindow {
    id: root

    title: "Bluetooth"

    property var devices: []
    property bool powered: false
    property bool scanning: false
    property string connectingMac: ""
    property string status: ""

    dialogWidth: 480

    function refresh() {
        pList.running = true
    }

    function connect(mac) {
        connectingMac = mac
        status = "Подключение..."
        pAction.command = ["bluetoothctl", "connect", mac]
        pAction.running = true
    }

    function disconnectDev(mac) {
        connectingMac = mac
        status = "Отключение..."
        pAction.command = ["bluetoothctl", "disconnect", mac]
        pAction.running = true
    }

    function setPower(on) {
        status = on ? "Включение..." : "Выключение..."
        pAction.command = ["bluetoothctl", "power", on ? "on" : "off"]
        pAction.running = true
    }

    function setScan(on) {
        scanning = on
        if (on) {
            status = "Поиск устройств..."
            pScan.running = true
        } else {
            pScan.running = false
            status = ""
        }
    }

    Component.onCompleted: refresh()

    onVisibleChanged: if (visible)
        refresh()

    onScanningChanged: scanPoll.running = scanning

    Process {
        id: pList

        command: ["sh", "-c", "bluetoothctl devices Paired 2>/dev/null; echo ---; bluetoothctl devices Connected 2>/dev/null; echo ---; bluetoothctl show 2>/dev/null | grep -i powered"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n")
                const paired = (parts[0] ?? "").trim()
                const connected = (parts[1] ?? "").trim()
                const poweredLine = (parts[2] ?? "").trim()
                root.powered = poweredLine.toLowerCase().indexOf("yes") !== -1
                const connMacs = {}
                paired && connected.split("\n").forEach(l => {
                    const f = l.trim().split(" ")
                    if (f.length >= 2)
                        connMacs[f[1]] = true
                })
                const list = []
                paired && paired.split("\n").forEach(l => {
                    const f = l.trim().split(" ")
                    if (f.length >= 3)
                        list.push({
                            "mac": f[1],
                            "name": f.slice(2).join(" "),
                            "connected": connMacs[f[1]] === true
                        })
                })
                root.devices = list
                if (!root.scanning)
                    root.status = ""
            }
        }
    }

    Process {
        id: pAction

        onExited: {
            root.connectingMac = ""
            root.refresh()
        }
    }

    Process {
        id: pScan

        command: ["bluetoothctl", "scan", "on"]
    }

    Timer {
        id: scanPoll

        interval: 2000
        running: false
        repeat: true
        onTriggered: root.refresh()
    }

    Column {
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 30

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Устройства"
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
                    color: scanning ? Theme.alpha(Theme.teal, 0.85) : scanMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf002"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.text
                    }

                    MouseArea {
                        id: scanMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setScan(!root.scanning)
                    }
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: powered ? Theme.alpha(Theme.teal, 0.85) : Qt.rgba(1, 1, 1, 0.07)

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
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setPower(!root.powered)
                    }
                }
            }
        }

        Text {
            visible: devices.length === 0
            text: powered ? "Нет сопряжённых устройств" : "Bluetooth выключен"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textDim
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: devices

                Item {
                    width: parent.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: devMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : modelData.connected ? Qt.rgba(0, 0.67, 0.66, 0.18) : "transparent"
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "\uf294"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: modelData.connected ? Theme.teal : Theme.text
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 40
                            right: stateLabel.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: root.connectingMac === modelData.mac ? modelData.name + "..." : modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        id: stateLabel

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.connected ? "подключено" : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }

                    MouseArea {
                        id: devMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.connectingMac === "")
                                modelData.connected ? root.disconnectDev(modelData.mac) : root.connect(modelData.mac)
                        }
                    }
                }
            }
        }
    }
}

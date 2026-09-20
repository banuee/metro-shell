import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property real openHeight: 298

    property bool shown: false
    property bool powered: false
    property bool scanning: false
    property string connectingMac: ""
    property string status: ""
    property var devices: []
    signal settingsRequested()

    function refresh() {
        pList.running = true
    }

    function connect(mac) {
        connectingMac = mac
        status = I18n.t("connecting")
        pAction.command = ["bluetoothctl", "connect", mac]
        pAction.running = true
    }

    function disconnectDev(mac) {
        connectingMac = mac
        status = I18n.t("disconnecting")
        pAction.command = ["bluetoothctl", "disconnect", mac]
        pAction.running = true
    }

    function setPower(on) {
        status = on ? I18n.t("turning_on") : I18n.t("turning_off")
        pAction.command = ["bluetoothctl", "power", on ? "on" : "off"]
        pAction.running = true
    }

    function setScan(on) {
        scanning = on
        if (on) {
            status = I18n.t("searching_devices")
            pScan.running = true
        } else {
            // убийство процесса не останавливает скан в контроллере —
            // явно шлём scan off, иначе скан висит и жрёт батарею
            pScan.running = false
            pScanOff.running = true
            status = ""
        }
    }

    onShownChanged: if (shown)
        refresh()

    onScanningChanged: scanPoll.running = scanning

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
                    text: I18n.t("devices")
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
                        glyph: "\uf011"
                        active: root.powered
                        onActivated: root.setPower(!root.powered)
                    }

                    CircleBtn {
                        glyph: "\uf002"
                        active: root.scanning
                        onActivated: root.setScan(!root.scanning)
                    }
                }
            }

            Flickable {
                id: devsFlick

                width: parent.width
                height: parent.height - 36
                clip: true
                contentHeight: devsCol.height
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: wheel => devsFlick.contentY = Math.max(0, Math.min(Math.max(0, devsFlick.contentHeight - devsFlick.height), devsFlick.contentY - wheel.angleDelta.y / 3))
                }

                Column {
                    id: devsCol

                    width: devsFlick.width
                    spacing: 2

                    Text {
                        width: devsCol.width
                        visible: root.devices.length === 0
                        text: !root.powered ? I18n.t("bt_off") : I18n.t("no_paired_devices")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Repeater {
                        model: root.devices

                        Item {
                            width: devsCol.width
                            height: 34

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: devMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : modelData.connected ? Theme.alpha(Theme.accent, 0.18) : "transparent"
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
                                color: modelData.connected ? Theme.accent : Theme.text
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
                                text: modelData.connected ? I18n.t("connected") : ""
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
    }

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

    Process {
        id: pScanOff

        command: ["bluetoothctl", "scan", "off"]
    }

    Timer {
        id: scanPoll

        interval: 2000
        running: false
        repeat: true
        onTriggered: root.refresh()
    }
}

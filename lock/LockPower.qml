import QtQuick
import Quickshell
import Quickshell.Io

// Питание на локскрине: сон / выход / перезагрузка / выключение.
// Перезагрузка и выключение — с danger-подтверждением повторным тапом.
Rectangle {
    id: root

    signal editRequested()

    radius: Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: Theme.stroke

    property int armed: -1
    Timer {
        id: disarm
        interval: 2500
        onTriggered: root.armed = -1
    }

    function run(cmd) {
        pCmd.command = ["sh", "-c", cmd]
        pCmd.running = true
    }

    Process { id: pCmd }

    readonly property bool isTall: height >= 150 && width < 150

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onPressAndHold: root.editRequested()
    }

    Grid {
        anchors.centerIn: parent
        columns: root.isTall ? 1 : 3
        rows: root.isTall ? 3 : 1
        spacing: 10

        Repeater {
            model: [
                { "glyph": "\uf186", "label": "sleep", "cmd": "systemctl suspend", "danger": false },
                { "glyph": "\uf021", "label": "restart", "cmd": "systemctl reboot", "danger": true },
                { "glyph": "\uf011", "label": "shutdown", "cmd": "systemctl poweroff", "danger": true }
            ]

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isArmed: root.armed === index
                width: root.isTall ? root.width - 24 : (root.width - 24 - 20) / 3
                height: root.isTall ? (root.height - 24 - 20) / 3 : root.height - 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: cell.isArmed ? Theme.alpha(Theme.red, 0.30)
                        : btnMa.containsMouse ? Theme.glassHover : "transparent"
                    border.width: 1
                    border.color: cell.isArmed ? Theme.red : Theme.stroke
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: root.isTall ? 17 : 20
                            color: cell.isArmed ? Theme.red
                                : cell.modelData.danger ? Theme.alpha(Theme.red, 0.85) : Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t(cell.modelData.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.letterSpacing: 0.5
                            color: Theme.textDim
                            visible: !root.isTall && cell.width > 52
                            elide: Text.ElideRight
                            width: cell.width - 6
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (cell.modelData.danger && !cell.isArmed) {
                                root.armed = cell.index
                                disarm.restart()
                            } else {
                                root.armed = -1
                                root.run(cell.modelData.cmd)
                            }
                        }
                        onPressAndHold: root.editRequested()
                    }
                }
            }
        }
    }
}

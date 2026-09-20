import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property string profile: ""
    property string batCap: ""
    property string batStatus: ""
    property string adp: ""

    function refresh() {
        pProf.command = ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        pProf.running = true
        pBat.command = ["sh", "-c", "echo cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); echo st=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); echo adp=$(cat /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1)"]
        pBat.running = true
    }

    Process {
        id: pProf
        stdout: StdioCollector {
            onStreamFinished: root.profile = text.trim()
        }
    }

    Process {
        id: pBat
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/cap=(\S*)/)
                if (m)
                    root.batCap = m[1]
                const s = text.match(/st=(\S*)/)
                if (s)
                    root.batStatus = s[1]
                const a = text.match(/adp=(\S*)/)
                if (a)
                    root.adp = a[1]
            }
        }
    }

    function batColor(cap, status) {
        if (status === "Charging")
            return Theme.accent
        if (cap < 20)
            return Theme.red
        if (cap < 40)
            return Theme.orange
        return Theme.text
    }

    Column {
        id: col
        width: root.width
        spacing: 10

        Text {
            text: I18n.t("power_profile")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Row {
            width: parent.width
            spacing: 8

            Repeater {
                model: [
                    { id: "performance", label: I18n.t("performance"), glyph: "\uf0e7" },
                    { id: "balanced", label: I18n.t("balanced"), glyph: "\uf185" },
                    { id: "power-saver", label: I18n.t("power_saver"), glyph: "\uf06c" }
                ]

                Rectangle {
                    id: profTile
                    width: (parent.width - 2 * 8) / 3
                    height: 76
                    radius: 10
                    color: root.profile === profTile.modelData.id ? Theme.alpha(Theme.accent, 0.88) : (profMa.containsMouse ? Theme.glassHover : Theme.glass)
                    border.width: 1
                    border.color: root.profile === profTile.modelData.id ? "#ffffff" : (profMa.containsMouse ? Theme.alpha(Theme.accent, 0.4) : Theme.stroke)
                    scale: profMa.pressed ? 0.93 : (profMa.containsMouse ? 1.04 : 1.0)

                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                    required property var modelData

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: profTile.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: root.profile === profTile.modelData.id ? "#ffffff" : (profMa.containsMouse ? Theme.accent : Theme.textDim)
                            scale: profMa.containsMouse ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: profTile.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: root.profile === profTile.modelData.id ? Font.DemiBold : Font.Normal
                            color: root.profile === profTile.modelData.id ? "#ffffff" : Theme.textDim
                        }
                    }

                    MouseArea {
                        id: profMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.win.run("powerprofilesctl set " + profTile.modelData.id)
                            delay.restart()
                        }
                    }
                }
            }
        }

        Timer {
            id: delay
            interval: 600
            onTriggered: refresh()
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: I18n.t("battery")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Rectangle {
            width: parent.width
            height: 64
            radius: 8
            color: Theme.glass

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.batCap === "" ? "—" : root.batCap + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 26
                font.weight: Font.Light
                color: root.batCap === "" ? Theme.textDim : root.batColor(parseInt(root.batCap), root.batStatus)
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 100
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: root.batStatus === "" ? I18n.t("not_found") : (root.adp === "1" ? I18n.t("on_ac") : "") + root.batStatus
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.text
                }
                Text {
                    text: root.adp === "1" ? I18n.t("ac_connected") : I18n.t("on_battery")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }
            }
        }
    }
}

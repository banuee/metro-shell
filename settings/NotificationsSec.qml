import QtQuick
import Quickshell
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win

    property bool dnd: false
    property int timeoutSec: 6
    property string anchorPos: "top-right"
    property int maxVisible: 3
    property string statusMsg: ""

    function refresh() {
        pGetMako.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py mako get"]
        pGetMako.running = true
    }

    function applyMako() {
        statusMsg = I18n.t("loading")
        const payload = {
            "timeout": timeoutSec * 1000,
            "anchor": anchorPos,
            "max_visible": maxVisible,
            "dnd": dnd
        }
        const jsonStr = JSON.stringify(payload).replace(/"/g, '\\"')
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py mako set \"" + jsonStr + "\"")
        statusTimer.restart()
    }

    function sendTestNotification() {
        win.run("notify-send -a 'Metro Shell' 'Metro Live Tiles' 'Тестовое уведомление успешно доставлено!' -i preferences-system")
    }

    function clearNotifications() {
        win.run("makoctl dismiss -a")
    }

    Timer { id: statusTimer; interval: 800; onTriggered: { refresh(); statusMsg = I18n.t("success") } }

    Process {
        id: pGetMako
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    root.dnd = res.dnd === true
                    root.timeoutSec = Math.round((res.timeout || 6000) / 1000)
                    root.anchorPos = res.anchor || "top-right"
                    root.maxVisible = res.max_visible || 3
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: refresh()

    Column {
        id: col
        width: root.width
        spacing: 14

        Text {
            text: I18n.t("notif_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("notif_desc")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }

        // DND Card
        Rectangle {
            width: parent.width
            height: 60
            radius: 8
            color: root.dnd ? Theme.alpha(Theme.accent, 0.25) : Theme.glass
            border.width: 1
            border.color: root.dnd ? Theme.accent : Theme.stroke

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dnd ? "\uf1f6" : "\uf0f3"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: root.dnd ? Theme.accent : Theme.textDim
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: I18n.t("dnd_title"); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: I18n.t("dnd_desc"); font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.textDim }
                }
            }

            KitToggle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: root.dnd
                onToggled: c => { root.dnd = c; root.applyMako() }
            }
        }

        // Timeout slider
        Rectangle {
            width: parent.width
            height: 52
            radius: 8
            color: Theme.glass

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("notif_timeout")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 30; height: 30; radius: 6; color: Theme.glass
                    Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.timeoutSec = Math.max(1, root.timeoutSec - 1); root.applyMako() } }
                }
                Text { text: root.timeoutSec + " с"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 44; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 30; height: 30; radius: 6; color: Theme.glass
                    Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.timeoutSec = Math.min(30, root.timeoutSec + 1); root.applyMako() } }
                }
            }
        }

        // Max visible notifications
        Rectangle {
            width: parent.width
            height: 52
            radius: 8
            color: Theme.glass

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("notif_max")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 30; height: 30; radius: 6; color: Theme.glass
                    Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.maxVisible = Math.max(1, root.maxVisible - 1); root.applyMako() } }
                }
                Text { text: String(root.maxVisible); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 40; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 30; height: 30; radius: 6; color: Theme.glass
                    Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.maxVisible = Math.min(10, root.maxVisible + 1); root.applyMako() } }
                }
            }
        }

        // Screen Position
        Text {
            text: I18n.t("notif_anchor")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Grid {
            width: parent.width
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { id: "top-left", label: "Top-Left" },
                    { id: "top-center", label: "Top-Center" },
                    { id: "top-right", label: "Top-Right" },
                    { id: "bottom-left", label: "Bottom-Left" },
                    { id: "bottom-center", label: "Bottom-Center" },
                    { id: "bottom-right", label: "Bottom-Right" }
                ]

                Rectangle {
                    id: anchorChip
                    required property var modelData
                    width: (col.width - 2 * 8) / 3
                    height: 42
                    radius: 8
                    color: root.anchorPos === anchorChip.modelData.id ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: root.anchorPos === anchorChip.modelData.id ? Theme.accent : Theme.stroke

                    Text {
                        anchors.centerIn: parent
                        text: anchorChip.modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: root.anchorPos === anchorChip.modelData.id ? Font.DemiBold : Font.Normal
                        color: root.anchorPos === anchorChip.modelData.id ? Theme.accent : Theme.text
                        elide: Text.ElideRight
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.anchorPos = anchorChip.modelData.id
                            root.applyMako()
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 4 }

        // Test notification and clear history buttons
        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: (parent.width - 10) / 2
                height: 44
                radius: 8
                color: testMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: Theme.accent

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf0f3"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accent }
                    Text { text: I18n.t("test_notif"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                }

                MouseArea {
                    id: testMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sendTestNotification()
                }
            }

            Rectangle {
                width: (parent.width - 10) / 2
                height: 44
                radius: 8
                color: clearMa.containsMouse ? Theme.alpha(Theme.red, 0.5) : Theme.glass

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf1f8"; font.family: Theme.iconFont; font.pixelSize: 13; color: clearMa.containsMouse ? "#fff" : Theme.textDim }
                    Text { text: I18n.t("clear_notif"); font.family: Theme.fontFamily; font.pixelSize: 12; color: clearMa.containsMouse ? "#fff" : Theme.text }
                }

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearNotifications()
                }
            }
        }
    }
}

import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property var monitors: []
    property var modes: ({})

    function refresh() {
        pMons.command = ["sh", "-c", "hyprctl -j monitors 2>/dev/null"]
        pMons.running = true
    }

    Timer {
        id: delay
        interval: 500
        onTriggered: refresh()
    }

    Process {
        id: pMons
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text)
                    root.monitors = list
                    for (const m of list) {
                        if (m.availableModes) {
                            const modesCopy = Object.assign({}, root.modes)
                            modesCopy[m.name] = m.availableModes
                            root.modes = modesCopy
                        }
                    }
                } catch (e) {
                    root.monitors = []
                }
            }
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 10

        Text {
            text: I18n.t("monitors")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: root.monitors

            Rectangle {
                id: monCard
                width: parent.width
                height: monCol.implicitHeight + 28
                radius: 10
                color: Theme.glass
                border.width: 1
                border.color: monCard.modelData.focused ? Theme.alpha(Theme.accent, 0.4) : Theme.stroke

                required property var modelData

                Column {
                    id: monCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 14
                    }
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 40

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: monCard.modelData.name + (monCard.modelData.focused ? "  ●" : "")
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: monCard.modelData.focused ? Theme.accent : Theme.text
                            }
                            Text {
                                text: monCard.modelData.description
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: monCard.modelData.width + "×" + monCard.modelData.height + " @ " + Math.round(monCard.modelData.refreshRate) + " Hz"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.accent
                        }
                    }

                    KitCombo {
                        id: modeCombo
                        label: I18n.t("res_rate")
                        value: monCard.modelData.width + "x" + monCard.modelData.height + "@" + monCard.modelData.refreshRate
                        options: ["preferred"].concat(root.modes[monCard.modelData.name] || [])
                        property string chosen: "current"
                        onPicked: opt => chosen = opt
                    }

                    Item {
                        width: parent.width
                        height: 34

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("scale")
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.text
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: minusMa.containsMouse ? Theme.glassHover : Theme.glass
                                scale: minusMa.pressed ? 0.88 : (minusMa.containsMouse ? 1.08 : 1.0)

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: minusMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: monCard.scaleVal = Math.max(0.5, Math.round((monCard.scaleVal - 0.25) * 100) / 100)
                                }
                            }

                            Rectangle {
                                width: 56
                                height: 32
                                radius: 8
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: monCard.scaleVal.toFixed(2) + "x"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.accent
                                }
                            }

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: plusMa.containsMouse ? Theme.glassHover : Theme.glass
                                scale: plusMa.pressed ? 0.88 : (plusMa.containsMouse ? 1.08 : 1.0)

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: plusMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: monCard.scaleVal = Math.min(3.0, Math.round((monCard.scaleVal + 0.25) * 100) / 100)
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        Rectangle {
                            width: 118
                            height: 32
                            radius: 8
                            color: vrrMa.containsMouse ? Theme.glassHover : Theme.glass
                            scale: vrrMa.pressed ? 0.94 : (vrrMa.containsMouse ? 1.03 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: "vrr " + (monCard.vrrVal ? I18n.t("on") : I18n.t("off"))
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: monCard.vrrVal ? Theme.accent : Theme.textDim
                            }

                            MouseArea {
                                id: vrrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: monCard.vrrVal = !monCard.vrrVal
                            }
                        }

                        Rectangle {
                            width: 108
                            height: 32
                            radius: 8
                            color: Theme.alpha(Theme.accent, applyMa.pressed ? 0.95 : 0.75)
                            scale: applyMa.pressed ? 0.94 : (applyMa.containsMouse ? 1.03 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("apply")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#fff"
                            }

                            MouseArea {
                                id: applyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const md = monCard.modelData
                                    let mode = md.width + "x" + md.height + "@" + md.refreshRate
                                    if (modeCombo.chosen !== "current")
                                        mode = modeCombo.chosen
                                    root.win.run("hyprctl eval 'hl.monitor({output=\"" + md.name + "\", mode=\"" + mode + "\", position=\"" + md.x + "x" + md.y + "\", scale=" + monCard.scaleVal + ", vrr=" + (monCard.vrrVal ? "true" : "false") + "})'")
                                    root.delay.restart()
                                }
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 4
                    }
                }

                property real scaleVal: modelData.scale
                property bool vrrVal: modelData.vrr
            }
        }

        Text {
            text: I18n.t("display_hint")
            width: parent.width
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }
    }
}

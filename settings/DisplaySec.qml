import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds


    property var win
    property var monitors: []
    property var modes: ({}) // name → availableModes[]

    function refresh() {
        pJson.command = ["sh", "-c", "hyprctl -j monitors"]
        pJson.running = true
        pModes.command = ["sh", "-c", "hyprctl monitors"]
        pModes.running = true
    }

    Timer {
        id: delay

        interval: 1000
        onTriggered: refresh()
    }

    Process {
        id: pJson

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text)
                } catch (e) {
                    root.monitors = []
                }
            }
        }
    }

    Process {
        id: pModes

        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                let cur = null
                for (const line of text.split("\n")) {
                    const nm = line.match(/^Monitor (\S+) \(ID \d+\):/)
                    if (nm) {
                        cur = nm[1]
                        m[cur] = []
                        continue
                    }
                    const av = line.match(/availableModes:\s*(.+)/)
                    if (av && cur) {
                        m[cur] = av[1].trim().split(/\s+/)
                    }
                }
                root.modes = m
            }
        }
    }

    Column {
        id: col

        width: root.width
        spacing: 10

        Text {
            text: "МОНИТОРЫ"
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
                                color: Theme.text
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

                        label: "разрешение и частота"
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
                            text: "масштаб"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.text
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 6
                                color: minusMa.containsMouse ? Theme.glassHover : Theme.glass

                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
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

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46
                                horizontalAlignment: Text.AlignHCenter
                                text: monCard.scaleVal.toFixed(2)
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                color: Theme.text
                            }

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 6
                                color: plusMa.containsMouse ? Theme.glassHover : Theme.glass

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: 16
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: plusMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: monCard.scaleVal = Math.min(4, Math.round((monCard.scaleVal + 0.25) * 100) / 100)
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 4
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        Rectangle {
                            width: 118
                            height: 32
                            radius: 8
                            color: Theme.glass

                            Text {
                                anchors.centerIn: parent
                                text: "vrr " + (monCard.vrrVal ? "вкл" : "выкл")
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: monCard.vrrVal ? Theme.accent : Theme.textDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: monCard.vrrVal = !monCard.vrrVal
                            }
                        }

                        Rectangle {
                            width: 108
                            height: 32
                            radius: 8
                            color: Theme.alpha(Theme.accent, applyMa.pressed ? 0.95 : 0.75)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "применить"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#fff"
                            }

                            MouseArea {
                                id: applyMa

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const md = monCard.modelData
                                    let mode = md.width + "x" + md.height + "@" + md.refreshRate
                                    if (modeCombo.chosen !== "current")
                                        mode = modeCombo.chosen
                                    // hyprctl keyword в 0.56 (Lua-парсер) не работает для мониторов — только eval
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

                // локальные состояния карточки
                property real scaleVal: modelData.scale
                property bool vrrVal: modelData.vrr
            }
        }

        Text {
            text: "изменения применяются на лету, но живут до перезагрузки — зафиксируй выбранный режим в hyprland.lua"
            width: parent.width
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }
    }
}

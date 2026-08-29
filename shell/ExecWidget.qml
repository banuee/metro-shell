import QtQuick
import Quickshell
import Quickshell.Io

TileFrame {
    id: root

    property string command: "echo 'hello'"
    property string label: ""
    property string iconGlyph: "\uf120"
    property bool inTerminal: true
    property bool panelShown: true

    readonly property string displayLabel: label !== "" ? label : (command !== "" ? command.trim().split(/\s+/)[0] : "команда")
    readonly property bool isWide: width > Theme.unit + 20
    readonly property bool isTall: height > Theme.unit + 20
    readonly property bool isRunning: pExec.running

    // Вспышка / подсветка при клике
    Rectangle {
        id: flashOverlay
        anchors.fill: parent
        radius: root.radius
        color: Theme.accent
        opacity: 0
        z: 0

        SequentialAnimation {
            id: flashAnim
            NumberAnimation {
                target: flashOverlay
                property: "opacity"
                to: 0.28
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: flashOverlay
                property: "opacity"
                to: 0
                duration: 220
                easing.type: Easing.OutQuad
            }
        }
    }

    // Индикатор фонового выполнения (пульсирующая рамка)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1.5
        border.color: Theme.accent
        visible: root.isRunning && !root.inTerminal
        opacity: 0.85
    }

    // ── 1x1 Компактный вид ──
    Item {
        anchors.fill: parent
        visible: !root.isWide && !root.isTall
        z: 1

        // Иконка режима в верхнем правом углу (терминал или молния)
        Text {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 7
                rightMargin: 8
            }
            text: root.inTerminal ? "\uf120" : "\uf0e7"
            font.family: Theme.iconFont
            font.pixelSize: 9
            color: root.inTerminal ? Theme.textDim : Theme.accent
            opacity: 0.65
        }

        // Главная иконка по центру
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -7
            }
            text: root.iconGlyph !== "" ? root.iconGlyph : "\uf120"
            font.family: Theme.iconFont
            font.pixelSize: 24
            color: Theme.accent
        }

        // Название внизу
        Text {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 8
                rightMargin: 8
                bottomMargin: 8
            }
            text: root.displayLabel
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.text
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── 2x1 Широкий вид ──
    Item {
        anchors.fill: parent
        anchors.margins: 10
        visible: root.isWide && !root.isTall
        z: 1

        Row {
            anchors.fill: parent
            spacing: 12

            // Иконка в стеклянном боксе
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: 1
                border.color: Theme.stroke

                Text {
                    anchors.centerIn: parent
                    text: root.iconGlyph !== "" ? root.iconGlyph : "\uf120"
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: Theme.accent
                }
            }

            // Текстовый блок
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 56
                spacing: 3

                // Название
                Text {
                    width: parent.width
                    text: root.displayLabel
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideRight
                }

                // Строка команды
                Text {
                    width: parent.width
                    text: "$ " + root.command
                    font.family: "monospace"
                    font.pixelSize: 10
                    color: Theme.textDim
                    elide: Text.ElideRight
                }

                // Бейдж режима выполнения
                Row {
                    spacing: 4

                    Rectangle {
                        width: modeRow.width + 10
                        height: 16
                        radius: 8
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke

                        Row {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.inTerminal ? "\uf120" : "\uf0e7"
                                font.family: Theme.iconFont
                                font.pixelSize: 8
                                color: root.inTerminal ? Theme.textDim : Theme.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.inTerminal ? "kitty" : "фон"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: Theme.textDim
                            }
                        }
                    }

                    // Статус если выполняется
                    Rectangle {
                        visible: root.isRunning
                        width: 44
                        height: 16
                        radius: 8
                        color: Theme.alpha(Theme.accent, 0.25)
                        border.width: 1
                        border.color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "пуск..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }

    // ── 2x2 Большой вид ──
    Item {
        anchors.fill: parent
        anchors.margins: 14
        visible: root.isWide && root.isTall
        z: 1

        Column {
            width: parent.width
            spacing: 8

            // Верхний ряд: Иконка + Бейдж
            Row {
                width: parent.width
                height: 48

                Rectangle {
                    width: 48
                    height: 48
                    radius: Theme.radiusSmall
                    color: Theme.glass
                    border.width: 1
                    border.color: Theme.stroke

                    Text {
                        anchors.centerIn: parent
                        text: root.iconGlyph !== "" ? root.iconGlyph : "\uf120"
                        font.family: Theme.iconFont
                        font.pixelSize: 26
                        color: Theme.accent
                    }
                }

                Item {
                    width: parent.width - 48
                    height: parent.height

                    Rectangle {
                        anchors {
                            right: parent.right
                            top: parent.top
                        }
                        width: badgeRow.width + 12
                        height: 20
                        radius: 10
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.inTerminal ? "\uf120" : "\uf0e7"
                                font.family: Theme.iconFont
                                font.pixelSize: 10
                                color: root.inTerminal ? Theme.text : Theme.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.inTerminal ? "в терминале" : "в фоне"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }
                    }
                }
            }

            // Название
            Text {
                width: parent.width
                text: root.displayLabel
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }

            // Команда в стеклянной плашке
            Rectangle {
                width: parent.width
                height: 38
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: 1
                border.color: Theme.stroke

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    text: "$ " + root.command
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }

            Item {
                width: parent.width
                height: 1
            }

            // Статус внизу
            Row {
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isRunning ? "\uf110" : "\uf04b"
                    font.family: Theme.iconFont
                    font.pixelSize: 10
                    color: root.isRunning ? Theme.accent : Theme.textDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isRunning ? "Выполняется..." : "Нажмите для запуска"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: root.isRunning ? Theme.accent : Theme.textDim
                }
            }
        }
    }

    Process {
        id: pExec
    }

    onClicked: {
        flashAnim.restart()
        if (pExec.running)
            pExec.running = false

        if (root.inTerminal) {
            pExec.command = ["kitty", "--hold", "-e", "sh", "-c", root.command]
        } else {
            pExec.command = ["sh", "-c", root.command]
        }
        pExec.running = true
    }
}

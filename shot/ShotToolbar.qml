import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property string currentMode: "area" // area | window | output
    property int delaySeconds: 0
    property bool includeCursor: false
    property bool freezeScreen: false
    property bool ocrEnabled: false
    property bool editEnabled: false
    property bool copyOnly: false

    signal captureRequested(string mode, int timer, bool cursor, bool ocr, bool edit, bool copyOnly, bool freeze)
    signal closeRequested()

    width: 672
    height: 52
    radius: 26
    color: Theme.glassDeep
    border.width: 1
    border.color: Theme.stroke

    // Тонкая акцентная полоска свечения сверху
    Rectangle {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        width: parent.width * 0.5
        height: 1
        color: Theme.accent
        opacity: 0.6
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 8

        // Режимы (Область, Окно, Экран)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            component ModeChip: Rectangle {
                id: chip
                required property string modeId
                required property string label
                required property string glyph

                readonly property bool active: root.currentMode === chip.modeId
                width: chipRow.width + 22
                height: 32
                radius: 16
                color: active ? Theme.alpha(Theme.accent, 0.85) : chipMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: active ? Theme.accent : Theme.stroke

                scale: chipMa.pressed ? 0.92 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.glyph
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: chip.active ? "#0e1720" : Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: chip.active ? Font.DemiBold : Font.Normal
                        color: chip.active ? "#0e1720" : Theme.text
                    }
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentMode = chip.modeId
                }
            }

            ModeChip {
                modeId: "area"
                label: I18n.t("area")
                glyph: "\uf125"
            }

            ModeChip {
                modeId: "window"
                label: I18n.t("window")
                glyph: "\uf2d0"
            }

            ModeChip {
                modeId: "output"
                label: I18n.t("screen")
                glyph: "\uf108"
            }
        }

        // Разделитель
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Theme.stroke
        }

        // Опции (Таймер, Курсор, OCR, Редактор)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Таймер (0с / 3с / 5с / 10с)
            Rectangle {
                width: timerRow.width + 18
                height: 32
                radius: 16
                color: root.delaySeconds > 0 ? Theme.alpha(Theme.orange, 0.25) : timerMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: root.delaySeconds > 0 ? Theme.orange : Theme.stroke
                scale: timerMa.pressed ? 0.92 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Row {
                    id: timerRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf017"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: root.delaySeconds > 0 ? Theme.orange : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.delaySeconds > 0 ? (root.delaySeconds + "с") : "0с"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: root.delaySeconds > 0 ? Theme.orange : Theme.text
                    }
                }

                MouseArea {
                    id: timerMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.delaySeconds === 0)
                            root.delaySeconds = 3
                        else if (root.delaySeconds === 3)
                            root.delaySeconds = 5
                        else if (root.delaySeconds === 5)
                            root.delaySeconds = 10
                        else
                            root.delaySeconds = 0
                    }
                }
            }

            // Включать курсор
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: root.includeCursor ? Theme.alpha(Theme.accent, 0.3) : curMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: root.includeCursor ? Theme.accent : Theme.stroke
                scale: curMa.pressed ? 0.90 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf245"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: root.includeCursor ? Theme.accent : Theme.textDim
                }

                MouseArea {
                    id: curMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.includeCursor = !root.includeCursor
                }
            }

            // Заморозка экрана (Freeze -z via hyprpicker)
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: root.freezeScreen ? Theme.alpha(Theme.accent, 0.35) : freezeMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: root.freezeScreen ? Theme.accent : Theme.stroke
                scale: freezeMa.pressed ? 0.90 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf2dc"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: root.freezeScreen ? Theme.accent : Theme.textDim
                }

                MouseArea {
                    id: freezeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.freezeScreen = !root.freezeScreen
                }
            }

            // Редактор Satty
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: root.editEnabled ? Theme.alpha(Theme.purple, 0.3) : editMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: root.editEnabled ? Theme.purple : Theme.stroke
                scale: editMa.pressed ? 0.90 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf044"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: root.editEnabled ? Theme.purple : Theme.textDim
                }

                MouseArea {
                    id: editMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editEnabled = !root.editEnabled
                }
            }

            // OCR (текст)
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: root.ocrEnabled ? Theme.alpha(Theme.green, 0.3) : ocrMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: root.ocrEnabled ? Theme.green : Theme.stroke
                scale: ocrMa.pressed ? 0.90 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf15c"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: root.ocrEnabled ? Theme.green : Theme.textDim
                }

                MouseArea {
                    id: ocrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.ocrEnabled = !root.ocrEnabled
                }
            }

            // Только в буфер (без сохранения)
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: root.copyOnly ? Theme.alpha(Theme.lime, 0.3) : copyMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: root.copyOnly ? Theme.lime : Theme.stroke
                scale: copyMa.pressed ? 0.90 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0c5"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: root.copyOnly ? Theme.lime : Theme.textDim
                }

                MouseArea {
                    id: copyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyOnly = !root.copyOnly
                }
            }
        }

        // Разделитель
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Theme.stroke
        }

        // Главная кнопка снимка
        Rectangle {
            id: triggerBtn
            width: shotRow.width + 24
            height: 34
            radius: 17
            color: triggerMa.containsMouse ? Theme.alpha(Theme.accent, 0.95) : Theme.accent
            scale: triggerMa.pressed ? 0.90 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Row {
                id: shotRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf030"
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: "#0e1720"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("take_shot")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "#0e1720"
                }
            }

            MouseArea {
                id: triggerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.captureRequested(root.currentMode, root.delaySeconds, root.includeCursor, root.ocrEnabled, root.editEnabled, root.copyOnly, root.freezeScreen)
                }
            }
        }

        // Кнопка закрытия
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: closeMa.containsMouse ? Theme.alpha(Theme.red, 0.25) : Theme.glass
            scale: closeMa.pressed ? 0.88 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf00d"
                font.family: Theme.iconFont
                font.pixelSize: 12
                color: closeMa.containsMouse ? Theme.red : Theme.textDim
            }

            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }
}

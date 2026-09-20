import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Rectangle {
    id: root

    property string imagePath: ""
    property string imageDimensions: ""
    property bool copiedFeedback: false
    property bool ocrFeedback: false

    signal actionTriggered(string action)
    signal closeRequested()

    width: 360
    height: 260
    radius: Theme.panelRadius
    color: Theme.glassDeep
    border.width: 1
    border.color: Theme.stroke

    // Автозакрытие через 8 секунд (приостанавливается при ховере)
    property int autoCloseMs: 8000
    property int elapsedMs: 0
    readonly property real timeRemainingFrac: Math.max(0, 1.0 - (elapsedMs / autoCloseMs))

    Timer {
        interval: 100
        running: !previewHoverMa.containsMouse && root.visible
        repeat: true
        onTriggered: {
            root.elapsedMs += 100
            if (root.elapsedMs >= root.autoCloseMs) {
                running = false
                root.closeRequested()
            }
        }
    }

    MouseArea {
        id: previewHoverMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Column {
        anchors {
            fill: parent
            margins: 14
        }
        spacing: 10

        // Шапка
        Item {
            width: parent.width
            height: 22

            Row {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.copiedFeedback ? "\uf00c" : "\uf030"
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: root.copiedFeedback ? Theme.lime : Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.copiedFeedback ? I18n.t("copied_to_clipboard") : root.ocrFeedback ? I18n.t("text_copied") : I18n.t("shot_saved")
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: root.copiedFeedback ? Theme.lime : Theme.textDim
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: 22
                height: 22
                radius: 11
                color: closeBtnMa.containsMouse ? Theme.alpha(Theme.red, 0.3) : Theme.glass
                scale: closeBtnMa.pressed ? 0.88 : (closeBtnMa.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
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
                    font.pixelSize: 11
                    color: closeBtnMa.containsMouse ? Theme.red : Theme.textDim
                }

                MouseArea {
                    id: closeBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Превью изображения
        Rectangle {
            width: parent.width
            height: 125
            radius: Theme.radiusSmall
            color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            border.color: Theme.stroke
            clip: true

            Image {
                id: thumb
                anchors.fill: parent
                anchors.margins: 4
                source: root.imagePath !== "" ? "file://" + root.imagePath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true

                onStatusChanged: {
                    if (status === Image.Ready && sourceSize.width > 0) {
                        root.imageDimensions = sourceSize.width + "x" + sourceSize.height
                    }
                }
            }

            // Бейдж с разрешением внизу справа
            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 6
                }
                width: dimText.width + 12
                height: 18
                radius: 9
                color: Qt.rgba(0, 0, 0, 0.65)
                visible: root.imageDimensions !== ""

                Text {
                    id: dimText
                    anchors.centerIn: parent
                    text: root.imageDimensions
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }
        }

        // Кнопки действий
        Row {
            width: parent.width
            spacing: 6

            component ActionBtn: Rectangle {
                id: actBtn
                required property string actId
                required property string label
                required property string glyph
                property color btnColor: Theme.glass

                width: (parent.width - 24) / 5
                height: 32
                radius: Theme.radiusSmall
                color: actMa.containsMouse ? Theme.glassHover : actBtn.btnColor
                border.width: 1
                border.color: Theme.stroke
                scale: actMa.pressed ? 0.90 : (actMa.containsMouse ? 1.04 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: actBtn.glyph
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: actBtn.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.text
                        visible: actBtn.width > 60
                    }
                }

                MouseArea {
                    id: actMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.actionTriggered(actBtn.actId)
                }
            }

            ActionBtn {
                actId: "copy"
                label: I18n.t("clipboard")
                glyph: "\uf0c5"
            }

            ActionBtn {
                actId: "edit"
                label: I18n.t("editor")
                glyph: "\uf044"
            }

            ActionBtn {
                actId: "ocr"
                label: "OCR"
                glyph: "\uf15c"
            }

            ActionBtn {
                actId: "folder"
                label: I18n.t("folder")
                glyph: "\uf07b"
            }

            ActionBtn {
                actId: "delete"
                label: I18n.t("delete")
                glyph: "\uf1f8"
                btnColor: Theme.alpha(Theme.red, 0.15)
            }
        }

        // Полоса таймера закрытия внизу
        Rectangle {
            width: parent.width
            height: 2
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width * root.timeRemainingFrac
                radius: 1
                color: Theme.accent
            }
        }
    }
}

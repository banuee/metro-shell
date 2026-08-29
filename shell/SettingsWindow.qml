import QtQuick
import Quickshell
import Quickshell.Wayland

// Полноэкранное прозрачное окно с центрированным диалогом в стиле Metro.
// Закрытие — только по крестику (или Esc). Клик по затемнению не закрывает.
PanelWindow {
    id: root

    property string title: ""

    function openWin() {
        visible = true
    }

    function closeWin() {
        visible = false
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: false
    exclusiveZone: -1

    WlrLayershell.namespace: "quickshell:metro-dialog"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    default property alias content: body.data
    property alias dialogWidth: dialogBox.width

    // затемнение фона
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: function (mouse) {
                mouse.accepted = true
            }
            onWheel: wheel => wheel.accepted = true
        }
    }

    // диалог по центру
    Rectangle {
        id: dialogBox

        anchors.centerIn: parent
        width: 460
        height: headerCol.height + body.height + 16
        radius: Theme.panelRadius
        color: Theme.glassDeep
        border.width: 1
        border.color: Theme.stroke

        scale: root.visible ? 1 : 0.94
        opacity: root.visible ? 1 : 0
        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        Column {
            id: headerCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            Item {
                width: parent.width
                height: 56

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    id: titleText

                    text: root.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.Light
                    color: Theme.text
                }

                // крестик
                Rectangle {
                    id: closeBtn

                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    width: 32
                    height: 32
                    radius: 16
                    color: closeMa.containsMouse || closeMa.pressed ? Theme.alpha(Theme.red, closeMa.pressed ? 0.95 : 0.75) : Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.text
                    }

                    MouseArea {
                        id: closeMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeWin()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.stroke
            }
        }

        Item {
            id: body

            anchors {
                top: headerCol.bottom
                left: parent.left
                right: parent.right
                topMargin: 8
            }
            height: childrenRect.height
            clip: true
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: root.closeWin()
    }
}

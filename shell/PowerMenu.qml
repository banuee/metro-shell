import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Power-меню: окно по центру экрана, ряд кнопок «иконка над подписью».
// Без затемнения экрана (namespace quickshell:metro → blur даёт акрилик).
// Клик мимо / Esc — закрыть; опасные пункты — подтверждение вторым кликом.
PanelWindow {
    id: root

    function open() {
        armed = -1
        visible = true
    }

    function close() {
        visible = false
        armed = -1
    }

    function runCmd(cmd) {
        if (pCmd.running)
            pCmd.running = false
        pCmd.command = ["sh", "-c", cmd]
        pCmd.running = true
    }

    property int armed: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: false
    exclusiveZone: -1

    WlrLayershell.namespace: "quickshell:metro"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // клик мимо диалога — закрыть
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: dialog

        anchors.centerIn: parent
        width: 640
        height: 156
        radius: Theme.panelRadius
        color: Theme.bg
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

        // не даём клику «мимо» пройти сквозь диалог
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Row {
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: [
                    {
                        "glyph": "\uf023",
                        "label": I18n.t("lock"),
                        "cmd": "$HOME/.local/bin/metro-lock",
                        "danger": false
                    },
                    {
                        "glyph": "\uf2d5",
                        "label": I18n.t("logout"),
                        "cmd": "hyprctl dispatch exit",
                        "danger": false
                    },
                    {
                        "glyph": "\uf186",
                        "label": I18n.t("sleep"),
                        "cmd": "systemctl suspend",
                        "danger": false
                    },
                    {
                        "glyph": "\uf021",
                        "label": I18n.t("restart"),
                        "cmd": "systemctl reboot",
                        "danger": true
                    },
                    {
                        "glyph": "\uf011",
                        "label": I18n.t("shutdown"),
                        "cmd": "systemctl poweroff",
                        "danger": true
                    }
                ]

                delegate: Rectangle {
                    id: pbtn

                    required property var modelData
                    required property int index

                    readonly property bool armedBtn: root.armed === index

                    width: 112
                    height: 116
                    radius: Theme.radius
                    color: armedBtn ? Theme.alpha(Theme.red, 0.3) : btnMa.containsMouse ? Theme.glassHover : Theme.glass

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 26
                            color: pbtn.armedBtn ? Theme.red : modelData.danger ? Theme.alpha(Theme.text, 0.85) : Theme.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pbtn.armedBtn ? I18n.t("sure") : modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: pbtn.armedBtn ? Theme.red : Theme.textDim
                        }
                    }

                    MouseArea {
                        id: btnMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.danger) {
                                if (root.armed === index) {
                                    root.runCmd(modelData.cmd)
                                    root.close()
                                } else {
                                    root.armed = index
                                    armReset.restart()
                                }
                            } else {
                                root.runCmd(modelData.cmd)
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // снятие «прицела» через 3с
    Timer {
        id: armReset

        interval: 3000
        onTriggered: root.armed = -1
    }

    Shortcut {
        sequence: "Esc"
        onActivated: root.close()
    }

    property Process pCmd: Process {
    }
}

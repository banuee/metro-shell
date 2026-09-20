import QtQuick

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds

    property var win

    // restart only metro shell
    readonly property string restartShell: 'mkdir -p "$HOME/.local/state/metro/logs"; pkill -f "quickshell -p $HOME/.config/quickshell/metro\\$"; sleep 0.4; QT_QPA_PLATFORMTHEME=gtk3 setsid quickshell -p "$HOME/.config/quickshell/metro" >"$HOME/.local/state/metro/logs/qs-metro.log" 2>&1 </dev/null &'

    Component {
        id: actRow

        Rectangle {
            id: actRowRoot

            width: parent ? parent.width : 0
            height: 56
            radius: 8
            color: actMa.containsMouse ? Theme.glassHover : Theme.glass
            border.width: 1
            border.color: actMa.containsMouse ? Theme.alpha(Theme.accent, 0.35) : Theme.stroke
            scale: actMa.pressed ? 0.98 : (actMa.containsMouse ? 1.008 : 1.0)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

            required property var modelData
            required property int index

            MouseArea {
                id: actMa
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: actRowRoot.modelData.t
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    width: actRowRoot.width - 160
                    text: actRowRoot.modelData.d
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    color: Theme.textDim
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: atxt.width + 20
                height: 30
                radius: 6
                color: root.dangerIdx === index ? Theme.alpha(Theme.red, actBtnMa.pressed ? 0.95 : 0.8) : Theme.alpha(Theme.accent, actBtnMa.pressed ? 0.95 : 0.75)
                scale: actBtnMa.pressed ? 0.92 : (actBtnMa.containsMouse ? 1.06 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Text {
                    id: atxt
                    anchors.centerIn: parent
                    text: root.dangerIdx === index ? I18n.t("sure") : actRowRoot.modelData.b
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#fff"
                }

                MouseArea {
                    id: actBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.dangerIdx === index) {
                            root.dangerIdx = -1
                            root.win.run(actRowRoot.modelData.c)
                        } else {
                            root.dangerIdx = index
                            disarm.restart()
                        }
                    }
                }
            }
        }
    }

    property int dangerIdx: -1

    Timer {
        id: disarm
        interval: 2500
        onTriggered: root.dangerIdx = -1
    }

    Column {
        id: col
        width: root.width
        spacing: 10

        Text {
            text: I18n.t("widgets_grid")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: [
                {
                    t: I18n.t("compact_title"),
                    d: I18n.t("compact_desc"),
                    b: I18n.t("compact"),
                    c: 'jq "map(del(.x, .y))" "$HOME/.config/quickshell/metro/layout.json" > "$HOME/.config/quickshell/metro/layout.json.tmp" && mv "$HOME/.config/quickshell/metro/layout.json.tmp" "$HOME/.config/quickshell/metro/layout.json"'
                },
                {
                    t: I18n.t("reset_title"),
                    d: I18n.t("reset_desc"),
                    b: I18n.t("reset"),
                    c: "rm -f \"$HOME/.config/quickshell/metro/layout.json\""
                },
                {
                    t: I18n.t("restart_shell_title"),
                    d: I18n.t("restart_shell_desc"),
                    b: I18n.t("restart"),
                    c: restartShell
                }
            ]

            delegate: actRow
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: I18n.t("lock_grid")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: [
                {
                    t: I18n.t("compact_title"),
                    d: I18n.t("lock_compact_desc"),
                    b: I18n.t("compact"),
                    c: 'jq "map(del(.x, .y))" "$HOME/.config/quickshell/metro/lock-layout.json" > "$HOME/.config/quickshell/metro/lock-layout.json.tmp" && mv "$HOME/.config/quickshell/metro/lock-layout.json.tmp" "$HOME/.config/quickshell/metro/lock-layout.json"'
                },
                {
                    t: I18n.t("reset_title"),
                    d: I18n.t("lock_reset_desc"),
                    b: I18n.t("reset"),
                    c: "rm -f \"$HOME/.config/quickshell/metro/lock-layout.json\""
                }
            ]

            delegate: actRow
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: I18n.t("theme_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: [
                {
                    t: I18n.t("save_theme_title"),
                    d: I18n.t("save_theme_desc"),
                    b: I18n.t("remember"),
                    c: "metro-colors save-defaults"
                },
                {
                    t: I18n.t("restore_theme_title"),
                    d: I18n.t("restore_theme_desc"),
                    b: I18n.t("reset"),
                    c: "metro-colors --reset"
                }
            ]

            delegate: actRow
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: I18n.t("hints_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("hints_text")
            width: parent.width
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }
    }
}

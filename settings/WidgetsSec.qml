import QtQuick

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds


    property var win

    // перезапуск только metro-шелла (не трогает этот процесс: якорь $ на конце пути)
    readonly property string restartShell: 'pkill -f "quickshell -p $HOME/.config/quickshell/metro\\$"; sleep 0.4; QT_QPA_PLATFORMTHEME=gtk3 setsid quickshell -p "$HOME/.config/quickshell/metro" >/tmp/qs-metro.log 2>&1 </dev/null &'

    Component {
        id: actRow

        Rectangle {
            id: actRowRoot

            width: parent ? parent.width : 0
            height: 56
            radius: 8
            color: actMa.containsMouse ? Theme.glassHover : Theme.glass

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            required property var modelData
            required property int index

            MouseArea {
                id: actMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
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
                color: root.dangerIdx === index ? Theme.alpha(Theme.red, actBtnMa.pressed ? 0.95 : 0.7) : Theme.alpha(Theme.accent, actBtnMa.pressed ? 0.95 : 0.6)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    id: atxt

                    anchors.centerIn: parent
                    text: root.dangerIdx === index ? "точно?" : actRowRoot.modelData.b
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
            text: "СЕТКА ВИДЖЕТОВ"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: [
            {
                t: "уплотнить виджеты",
                d: "сбросить координаты x/y у всех плиток — packGrid заполнит дыры",
                b: "уплотнить",
                c: 'jq "map(del(.x, .y))" "$HOME/.config/quickshell/metro/layout.json" > "$HOME/.config/quickshell/metro/layout.json.tmp" && mv "$HOME/.config/quickshell/metro/layout.json.tmp" "$HOME/.config/quickshell/metro/layout.json"'
            },
            {
                t: "сбросить к дефолту",
                d: "удалить layout.json — вернётся заводская сетка",
                b: "сбросить",
                c: "rm -f \"$HOME/.config/quickshell/metro/layout.json\""
            },
            {
                t: "перезапустить metro-шелл",
                d: "TopPanel/лаунчер/CC перечитают layout.json",
                b: "рестарт",
                c: restartShell
            }]

            delegate: actRow
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: "ТЕМА"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: [
            {
                t: "запомнить тему как эталон",
                d: "текущие Theme/TopPanel/hyprlock станут точкой отката",
                b: "запомнить",
                c: "metro-colors save-defaults"
            },
            {
                t: "откатить тему к эталону",
                d: "вернуть файлы темы к запомненному состоянию (не сетка!)",
                b: "откатить",
                c: "metro-colors --reset"
            }]

            delegate: actRow
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: "ПОДСКАЗКИ"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: "edit-режим сетки (перетаскивание/ресайз/удаление) включается кнопкой «изменить» на верхней панели. Смена обоев и акцента перекрашивает шелл, hyprlock и экран входа через metro-colors."
            width: parent.width
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }
    }
}

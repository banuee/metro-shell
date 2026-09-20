import QtQuick
import Quickshell
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property var categories: []
    property string activePickerCat: ""
    property string statusMsg: ""

    function refresh() {
        pGetApps.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py apps get"]
        pGetApps.running = true
    }

    function setDefault(catId, desktopId) {
        statusMsg = I18n.t("loading")
        activePickerCat = ""
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py apps set \"" + catId + "\" \"" + desktopId + "\"")
        delayTimer.restart()
    }

    Timer { id: delayTimer; interval: 800; onTriggered: { refresh(); statusMsg = I18n.t("success") } }

    Process {
        id: pGetApps
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.categories = JSON.parse(text)
                } catch (e) {
                    root.categories = []
                }
            }
        }
    }

    Component.onCompleted: refresh()

    Column {
        id: col
        width: root.width
        spacing: 14

        Text {
            text: I18n.t("default_apps_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("default_apps_desc")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }

        Text {
            visible: root.statusMsg !== ""
            text: root.statusMsg
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.lime
        }

        Repeater {
            model: root.categories

            Column {
                id: catItem
                required property var modelData
                width: col.width
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 8
                    color: headMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: root.activePickerCat === catItem.modelData.id ? Theme.accent : Theme.stroke

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: catItem.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: Theme.accent
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: catItem.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                text: catItem.modelData.default || "—"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: pickBtnTxt.width + 20
                            height: 30
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                id: pickBtnTxt
                                anchors.centerIn: parent
                                text: root.activePickerCat === catItem.modelData.id ? "\uf077" : "\uf078"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: Theme.text
                            }
                        }
                    }

                    MouseArea {
                        id: headMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activePickerCat = (root.activePickerCat === catItem.modelData.id) ? "" : catItem.modelData.id
                        }
                    }
                }

                // Candidate apps dropdown list
                Column {
                    visible: root.activePickerCat === catItem.modelData.id
                    width: parent.width
                    spacing: 4

                    Text {
                        visible: catItem.modelData.candidates.length === 0
                        text: I18n.t("no_apps_found")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }

                    Repeater {
                        model: catItem.modelData.candidates

                        Rectangle {
                            id: appRow
                            required property var modelData
                            width: catItem.width
                            height: 42
                            radius: 6
                            color: appRowMa.containsMouse ? Theme.glassHover : Qt.rgba(0, 0, 0, 0.25)
                            border.width: appRow.modelData.id === catItem.modelData.default ? 1 : 0
                            border.color: Theme.accent

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: "transparent"
                                    border.width: 2
                                    border.color: appRow.modelData.id === catItem.modelData.default ? Theme.accent : Qt.rgba(1, 1, 1, 0.3)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.accent
                                        anchors.centerIn: parent
                                        visible: appRow.modelData.id === catItem.modelData.default
                                    }
                                }

                                Text {
                                    text: appRow.modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: appRow.modelData.id === catItem.modelData.default ? Font.DemiBold : Font.Normal
                                    color: appRow.modelData.id === catItem.modelData.default ? Theme.accent : Theme.text
                                }

                                Text {
                                    text: "(" + appRow.modelData.id + ")"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: appRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setDefault(catItem.modelData.id, appRow.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

import QtQuick

Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 4

    property string label: ""
    property string value: ""
    property var options: []
    signal picked(string opt)

    property bool open: false

    // заголовок-кнопка
    Rectangle {
        width: root.width
        height: 44
        radius: 8
        color: headMa.containsMouse ? Theme.glassHover : Theme.glass

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: 14
            color: Theme.text
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.value
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.textDim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.open ? "\uf077" : "\uf078"
                font.family: Theme.iconFont
                font.pixelSize: 10
                color: Theme.textDim
            }
        }

        MouseArea {
            id: headMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // выпадающий список (аккордеон — не ловит клиппинг фликабеля)
    Column {
        visible: root.open
        width: root.width
        spacing: 2

        Repeater {
            model: root.options

            Rectangle {
                width: root.width
                height: 36
                radius: 6
                color: optMa.containsMouse ? Theme.glassHover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: modelData === root.value ? Theme.accent : Theme.text
                }

                MouseArea {
                    id: optMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.open = false
                        root.picked(modelData)
                    }
                }
            }
        }
    }
}

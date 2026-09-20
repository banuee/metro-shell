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
        border.width: 1
        border.color: root.open ? Theme.alpha(Theme.accent, 0.5) : (headMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Theme.stroke)
        scale: headMa.pressed ? 0.98 : (headMa.containsMouse ? 1.005 : 1.0)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

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
                font.weight: Font.DemiBold
                color: root.open ? Theme.accent : Theme.textDim

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf078"
                font.family: Theme.iconFont
                font.pixelSize: 11
                color: root.open ? Theme.accent : Theme.textDim
                rotation: root.open ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color { ColorAnimation { duration: 120 } }
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

    // выпадающий список (плавный аккордеон)
    Item {
        id: dropdownBox
        width: root.width
        height: root.open ? dropCol.height : 0
        opacity: root.open ? 1 : 0
        clip: true
        visible: height > 0

        Behavior on height {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }

        Column {
            id: dropCol
            width: root.width
            spacing: 2

            Repeater {
                model: root.options

                Rectangle {
                    id: optRow
                    required property var modelData
                    readonly property bool isSelected: modelData === root.value

                    width: root.width
                    height: 36
                    radius: 6
                    color: optMa.containsMouse ? Theme.glassHover : (isSelected ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                    scale: optMa.pressed ? 0.98 : 1.0

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 14
                        radius: 2
                        color: Theme.accent
                        opacity: optRow.isSelected ? 1 : 0
                        scale: optRow.isSelected ? 1.0 : 0.0

                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: optMa.containsMouse ? 30 : 26
                        anchors.verticalCenter: parent.verticalCenter
                        text: optRow.modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: optRow.isSelected ? Font.DemiBold : Font.Normal
                        color: optRow.isSelected ? Theme.accent : Theme.text

                        Behavior on anchors.leftMargin { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: optMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.open = false
                            root.picked(optRow.modelData)
                        }
                    }
                }
            }
        }
    }
}


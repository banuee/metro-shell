import QtQuick

Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    width: 52
    height: 32
    radius: 16
    color: checked ? Theme.accent : Theme.glass
    border.width: 1
    border.color: checked ? Theme.accent : (ma.containsMouse ? Theme.accent : Theme.stroke)
    scale: ma.pressed ? 0.94 : (ma.containsMouse ? 1.04 : 1.0)

    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

    Rectangle {
        x: root.checked ? (root.width - width - 4) : 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.checked ? (ma.pressed ? 28 : 24) : (ma.pressed ? 20 : 16)
        height: root.checked ? 24 : 16
        radius: height / 2
        color: root.checked ? "#ffffff" : (ma.containsMouse ? Theme.accent : Theme.textDim)

        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}

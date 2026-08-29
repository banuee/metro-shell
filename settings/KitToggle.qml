import QtQuick

Rectangle {
    id: root

    width: 46
    height: 26
    radius: 13
    color: checked ? Theme.alpha(Theme.accent, 0.92) : Qt.rgba(1, 1, 1, 0.14)

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    property bool checked: false
    signal toggled(bool checked)

    Rectangle {
        x: root.checked ? root.width - width - 4 : 4
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: "#ffffff"

        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}

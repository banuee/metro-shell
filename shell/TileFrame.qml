import QtQuick

Rectangle {
    id: root

    property bool pressed: tap.pressed
    signal clicked()

    radius: Theme.radius
    color: Theme.glass

    scale: pressed ? 0.94 : 1
    Behavior on scale {
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.glassHover
        opacity: tap.containsMouse ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 130
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.stroke
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

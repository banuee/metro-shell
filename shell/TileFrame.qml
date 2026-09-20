import QtQuick

Rectangle {
    id: root

    property bool pressed: tap.pressed
    signal clicked()
    signal editRequested()

    radius: Theme.radius
    color: tap.containsMouse ? Theme.glassHover : Theme.glass
    border.width: Theme.isWP ? 0 : 1
    border.color: tap.containsMouse ? (Theme.isMaterial ? Theme.alpha(Theme.primary, 0.45) : Theme.accent) : Theme.stroke

    scale: pressed ? 0.95 : (tap.containsMouse ? 1.015 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 130
            easing.type: Easing.OutQuad
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 140
        }
    }

    // Material 3 Ripple / Press feedback
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.alpha(Theme.primary, 0.14)
        opacity: (root.pressed && Theme.isMaterial) ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // Долгий клик по плитке = вход в режим редактирования сетки
        onPressAndHold: root.editRequested()
    }
}

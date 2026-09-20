import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property real value: 0.5
    property bool muted: false
    signal changed(real v)
    signal tapped()

    width: parent ? parent.width : 0
    height: 48
    radius: Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: root.muted ? Theme.alpha(Theme.red, 0.6) : Theme.stroke
    clip: true

    Behavior on border.color { ColorAnimation { duration: 140 } }

    function apply(x) {
        root.changed(Math.max(0.0, Math.min(1.0, x / Math.max(1, root.width))))
    }

    // Filled Track
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: Math.max(height, parent.width * root.value)
        radius: Theme.radius
        color: root.muted ? Theme.alpha(Theme.red, 0.85) : Theme.alpha(Theme.accent, 0.85)

        Behavior on width {
            NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
        }
        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    // Icon button on left
    Item {
        id: iconBox
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 44
        z: 2

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 15
            color: root.muted ? Theme.textDim : Theme.text
        }

        MouseArea {
            id: iconMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }

    // Value percentage text on right
    Text {
        anchors {
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        z: 2
        text: Math.round(root.value * 100) + "%"
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: root.muted ? Theme.textDim : Theme.text
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.apply(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) root.apply(mouse.x)
        }
    }
}

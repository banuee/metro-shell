import QtQuick

Rectangle {
    id: root

    width: parent ? parent.width : 0
    height: 44
    radius: 8
    color: Theme.glass

    property string icon: ""
    property real value: 0.5
    property bool muted: false
    signal changed(real v)
    signal tapped()

    function apply(x) {
        root.changed(Math.max(0.01, Math.min(1, x / groove.width)))
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        font.family: Theme.iconFont
        font.pixelSize: 15
        color: root.muted ? Theme.red : Theme.text
    }

    // дорожка
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 46
        anchors.right: parent.right
        anchors.rightMargin: 58
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.glassHover

        Rectangle {
            width: parent.width * root.value
            height: parent.height
            radius: 2
            color: root.muted ? Theme.red : Theme.accent
        }

        Rectangle {
            x: parent.width * root.value - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: ma.containsMouse || ma.pressed ? 14 : 0
            height: 14
            radius: 7
            color: "#ffffff"

            Behavior on width {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            id: ma

            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            property bool dragged: false

            onPressed: {
                dragged = false
                apply(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed) {
                    dragged = true
                    apply(mouse.x)
                }
            }
            onClicked: {
                if (!dragged)
                    root.tapped()
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.muted ? "выкл" : Math.round(root.value * 100) + "%"
        font.family: Theme.fontFamily
        font.pixelSize: 12
        color: root.muted ? Theme.red : Theme.textDim
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property string edge
    property var target: null

    readonly property bool isTop: edge === "top"
    readonly property bool isLeft: edge === "left"
    readonly property bool isRight: edge === "right"

    anchors {
        top: true
        left: isTop || isLeft
        right: isTop || isRight
        bottom: !isTop
    }

    implicitHeight: isTop ? 3 : 0
    implicitWidth: isTop ? 0 : 3
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.namespace: "quickshell:metro"
    WlrLayershell.layer: WlrLayer.Top

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
            if (root.target)
                root.target.edgeHover = containsMouse
            if (containsMouse)
                armTimer.restart()
            else
                armTimer.stop()
        }
    }

    Timer {
        id: armTimer
        interval: 200
        onTriggered: {
            // только открываем: повторный ховер при открытой панели
            // не должен её закрывать
            if (root.target && !root.target.open)
                root.target.toggleOpen()
        }
    }
}

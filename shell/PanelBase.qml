import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    default property alias content: contentItem.data

    property string slideDir: "top"
    property bool open: false
    property bool shown: false
    property bool edgeHover: false
    property bool everEntered: false
    property int missCount: 0
    property bool graceMode: false

    function toggleOpen() {
        open = !open
    }

    function grace() {
        graceMode = true
        graceTimer.restart()
    }

    Timer {
        id: graceTimer

        interval: 800
        onTriggered: panel.graceMode = false
    }

    readonly property real slideX: slideDir === "left" ? (open ? 0 : -(width + 40)) : slideDir === "right" ? (open ? 0 : width + 40) : 0
    readonly property real slideY: slideDir === "top" ? (open ? 0 : -(height + 40)) : 0

    visible: shown
    color: "transparent"
    exclusiveZone: -1

    WlrLayershell.namespace: "quickshell:metro"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Connections {
        target: panel

        function onOpenChanged() {
            if (panel.open) {
                panel.shown = true
                closeTimer.stop()
                panel.missCount = 0
                panel.everEntered = false
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 340
        onTriggered: panel.shown = false
    }

    Timer {
        id: watchdog
        interval: 250
        running: panel.open
        repeat: true
        onTriggered: {
            if (panel.graceMode) {
                panel.missCount = 0
                return
            }
            if (leaveArea.containsMouse || panel.edgeHover) {
                panel.everEntered = true
                panel.missCount = 0
                return
            }
            panel.missCount++
            if (panel.missCount >= (panel.everEntered ? 1 : 8))
                panel.open = false
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent

        x: panel.slideX
        y: panel.slideY

        Behavior on x {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: leaveArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 999
        onContainsMouseChanged: if (containsMouse) panel.everEntered = true
    }
}

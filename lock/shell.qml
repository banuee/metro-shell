import QtQuick
import Quickshell
import Quickshell.Wayland

// metro-lock — экран блокировки на quickshell (замена hyprlock).
// Два режима:
//   реальный — WlSessionLock (ext-session-lock-v1), сессия блокируется
//              по-настоящему;
//   debug    — METRO_LOCK_DEBUG=1: тот же LockScreen в fullscreen PanelWindow
//              без блокировки сессии (для тестов). METRO_LOCK_FAKE_OK=1
//              имитирует успешный PAM (любой ввод = разблокировка).
ShellRoot {
    id: root
    readonly property bool debugMode: Quickshell.env("METRO_LOCK_DEBUG") === "1"
    property bool unlockRequested: false

    // ── DEBUG: оверлей поверх всего, сессия не блокируется ──────────────
    PanelWindow {
        visible: root.debugMode
        exclusiveZone: -1
        color: "#0a0a10"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:metro-lock-debug"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { left: true; right: true; top: true; bottom: true }

        LockScreen {
            anchors.fill: parent
            debug: true
            onFinished: Qt.quit()
        }
    }

    // ── реальная блокировка ──────────────────────────────────────────────
    WlSessionLock {
        id: lock
        locked: !root.debugMode && !root.unlockRequested
        surface: Component {
            WlSessionLockSurface {
                color: "#0a0a10"
                LockScreen {
                    anchors.fill: parent
                    onFinished: {
                        root.unlockRequested = true
                        quitDelay.start()
                    }
                }
            }
        }
    }

    Timer {
        id: quitDelay
        interval: 250
        onTriggered: Qt.quit()
    }
}

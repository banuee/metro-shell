import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    TopPanel {
        id: topPanel
    }

    LauncherPanel {
        id: launcherPanel
    }

    ControlPanel {
        id: controlPanel
        onWifiSettingsRequested: pOpenSettings.openNetwork()
        onBtSettingsRequested: pOpenSettings.openNetwork()
    }

    Process {
        id: pOpenSettings
        command: ["sh", "-c", "METRO_SETTINGS_SECTION=1 metro-settings"]
        function openNetwork() {
            if (running) running = false
            running = true
        }
    }

    WifiWindow {
        id: wifiWindow
    }

    BtWindow {
        id: btWindow
    }

    HoverZone {
        edge: "top"
        target: topPanel
    }

    HoverZone {
        edge: "left"
        target: launcherPanel
    }

    HoverZone {
        edge: "right"
        target: controlPanel
    }
}

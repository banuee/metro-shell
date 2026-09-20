import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    property string appState: "toolbar" // "toolbar" | "countdown" | "preview"
    property string currentImagePath: ""
    property int countdownValue: 0
    property string targetMode: "area"
    property bool targetCursor: false
    property bool targetFreeze: false
    property bool targetOcr: false
    property bool targetEdit: false
    property bool targetCopyOnly: false

    property bool toolbarActive: false
    property bool previewActive: false

    Component.onCompleted: {
        const previewPath = Quickshell.env("METRO_SHOT_PREVIEW")
        const copyEnv = Quickshell.env("METRO_SHOT_COPY") === "1"
        const ocrEnv = Quickshell.env("METRO_SHOT_OCR") === "1"

        if (previewPath && previewPath !== "") {
            root.currentImagePath = previewPath
            root.targetCopyOnly = copyEnv
            root.targetOcr = ocrEnv
            root.appState = "preview"
            if (copyEnv)
                previewCard.copiedFeedback = true
            if (ocrEnv)
                previewCard.ocrFeedback = true
            previewInitTimer.restart()
        } else {
            root.appState = "toolbar"
            toolbarInitTimer.restart()
        }
    }

    Timer {
        id: toolbarInitTimer
        interval: 10
        repeat: false
        onTriggered: root.toolbarActive = true
    }

    Timer {
        id: previewInitTimer
        interval: 10
        repeat: false
        onTriggered: root.previewActive = true
    }

    function startCapture(mode, delaySec = 0, cursor = false, ocr = false, edit = false, copyOnly = false, freeze = false) {
        root.targetMode = mode
        root.targetCursor = cursor === undefined ? false : cursor
        root.targetOcr = ocr === undefined ? false : ocr
        root.targetEdit = edit === undefined ? false : edit
        root.targetCopyOnly = copyOnly === undefined ? false : copyOnly
        root.targetFreeze = freeze === undefined ? false : freeze

        root.toolbarActive = false
        if (delaySec > 0) {
            closeToolbarTimer.onDone = () => {
                root.countdownValue = delaySec
                root.appState = "countdown"
                countTimer.restart()
            }
            closeToolbarTimer.restart()
        } else {
            closeToolbarTimer.onDone = () => {
                root.executeAndQuit()
            }
            closeToolbarTimer.restart()
        }
    }

    Timer {
        id: closeToolbarTimer
        property var onDone: null
        interval: 160
        repeat: false
        onTriggered: {
            if (onDone) onDone()
        }
    }

    function closeToolbarAndQuit() {
        root.toolbarActive = false
        closeToolbarTimer.onDone = () => Qt.quit()
        closeToolbarTimer.restart()
    }

    function closePreviewAndQuit() {
        root.previewActive = false
        closePreviewTimer.restart()
    }

    Timer {
        id: closePreviewTimer
        interval: 160
        repeat: false
        onTriggered: Qt.quit()
    }

    Timer {
        id: countTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownValue--
            countItem.pulse()
            if (root.countdownValue <= 0) {
                stop()
                countItem.finishAndQuit()
            }
        }
    }

    function executeAndQuit() {
        const mode = root.targetMode
        const freeze = root.targetFreeze ? "1" : "0"
        const cursor = root.targetCursor ? "1" : "0"
        const ocr = root.targetOcr ? "1" : "0"
        const edit = root.targetEdit ? "1" : "0"
        const copy = root.targetCopyOnly ? "1" : "0"

        const cmd = "setsid $HOME/.local/bin/metro-shot --do-capture \"" + mode + "\" \"" + freeze + "\" \"" + cursor + "\" \"" + ocr + "\" \"" + edit + "\" \"" + copy + "\" 0 >/dev/null 2>&1 &"
        pSpawn.command = ["sh", "-c", cmd]
        pSpawn.running = true
        quitTimer.restart()
    }

    Process {
        id: pSpawn
        command: []
    }

    Timer {
        id: quitTimer
        interval: 50
        repeat: false
        onTriggered: Qt.quit()
    }

    Process {
        id: pAction
        command: []
    }

    function runAction(action) {
        if (!root.currentImagePath)
            return
        // Путь передаётся через $1/$2 позиционные параметры sh — никакой
        // конкатенации в командную строку, injection через имя файла невозможен
        const img = root.currentImagePath
        const dir = img.substring(0, Math.max(img.lastIndexOf("/"), 1)) || "/"

        if (action === "copy") {
            pAction.command = ["sh", "-c", "wl-copy < \"$1\"", "_", img]
            pAction.running = true
            previewCard.copiedFeedback = true
        } else if (action === "edit") {
            pAction.command = ["sh", "-c", "satty -f \"$1\" 2>/dev/null &", "_", img]
            pAction.running = true
            root.closePreviewAndQuit()
        } else if (action === "ocr") {
            pAction.command = ["sh", "-c", "tesseract \"$1\" stdout 2>/dev/null | wl-copy 2>/dev/null", "_", img]
            pAction.running = true
            previewCard.ocrFeedback = true
        } else if (action === "folder") {
            pAction.command = ["sh", "-c", "nemo --select \"$1\" 2>/dev/null || xdg-open \"$2\" 2>/dev/null &", "_", img, dir]
            pAction.running = true
        } else if (action === "delete") {
            pAction.command = ["sh", "-c", "rm -f \"$1\"", "_", img]
            pAction.running = true
            root.closePreviewAndQuit()
        }
    }

    PanelWindow {
        id: shotWin

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:metro-shot"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region {
            item: root.appState === "toolbar" ? toolbar : root.appState === "countdown" ? countItem : root.appState === "preview" ? previewCard : null
        }

        // Клавиши Esc для закрытия
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (root.appState === "toolbar") {
                    root.closeToolbarAndQuit()
                } else if (root.appState === "preview") {
                    root.closePreviewAndQuit()
                } else {
                    Qt.quit()
                }
            }
            Keys.onReturnPressed: {
                if (root.appState === "toolbar" && root.toolbarActive) {
                    root.startCapture(toolbar.currentMode, toolbar.delaySeconds, toolbar.includeCursor, toolbar.ocrEnabled, toolbar.editEnabled, toolbar.copyOnly, toolbar.freezeScreen)
                }
            }
        }

        // 1. Верхний плавающий тулбар
        ShotToolbar {
            id: toolbar
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: root.toolbarActive ? 20 : -60
            }
            visible: root.appState === "toolbar"
            opacity: root.toolbarActive ? 1 : 0

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: root.toolbarActive ? 220 : 150
                    easing.type: root.toolbarActive ? Easing.OutCubic : Easing.InQuad
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            onCaptureRequested: (mode, timer, cursor, ocr, edit, copyOnly, freeze) => {
                root.startCapture(mode, timer, cursor, ocr, edit, copyOnly, freeze)
            }
            onCloseRequested: {
                root.closeToolbarAndQuit()
            }
        }

        // 2. Оверлей обратного отсчета (Countdown)
        Item {
            id: countItem
            anchors.centerIn: parent
            width: 140
            height: 140
            visible: root.appState === "countdown"

            property real countScale: 1.0
            property real countOpacity: 1.0

            transform: Scale {
                origin.x: countItem.width / 2
                origin.y: countItem.height / 2
                xScale: countItem.countScale
                yScale: countItem.countScale
            }
            opacity: countItem.countOpacity

            Behavior on countScale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutBack
                }
            }
            Behavior on countOpacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            function pulse() {
                countItem.countScale = 1.25
                pulseResetTimer.restart()
            }

            function finishAndQuit() {
                countItem.countScale = 1.4
                countItem.countOpacity = 0
                finishTimer.restart()
            }

            Timer {
                id: pulseResetTimer
                interval: 120
                repeat: false
                onTriggered: countItem.countScale = 1.0
            }

            Timer {
                id: finishTimer
                interval: 140
                repeat: false
                onTriggered: root.executeAndQuit()
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.glassDeep
                border.width: 2
                border.color: Theme.accent

                // Фоновое акцентное кольцо пульсации
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 4
                    border.color: Theme.alpha(Theme.accent, 0.3)
                    scale: 1.08
                }

                Text {
                    anchors.centerIn: parent
                    text: root.countdownValue
                    font.family: Theme.fontFamily
                    font.pixelSize: 56
                    font.weight: Font.Light
                    color: Theme.accent
                }
            }
        }

        // 3. Карточка предпросмотра (Preview HUD) в правом нижнем углу
        ShotPreview {
            id: previewCard
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 24
                bottomMargin: root.previewActive ? 24 : -40
            }
            visible: root.appState === "preview" && root.currentImagePath !== ""
            opacity: root.previewActive ? 1 : 0

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: root.previewActive ? 220 : 150
                    easing.type: root.previewActive ? Easing.OutCubic : Easing.InQuad
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            imagePath: root.currentImagePath
            onActionTriggered: act => root.runAction(act)
            onCloseRequested: {
                root.closePreviewAndQuit()
            }
        }
    }
}

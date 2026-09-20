import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

PanelBase {
    id: root

    slideDir: "left"
    anchors {
        top: true
        bottom: true
        left: true
    }
    implicitWidth: Theme.panelWidth + 14

    property var pinnedIds: []

    onShownChanged: if (shown) {
        pPinnedRead.running = true
    }

    function isPinned(appId) {
        if (!appId)
            return false
        for (let i = 0; i < pinnedIds.length; i++) {
            const p = pinnedIds[i]
            if (p === appId || p + ".desktop" === appId || p === appId + ".desktop")
                return true
        }
        return false
    }

    function togglePin(appId) {
        if (!appId)
            return
        const cur = pinnedIds.slice()
        let foundIdx = -1
        for (let i = 0; i < cur.length; i++) {
            const p = cur[i]
            if (p === appId || p + ".desktop" === appId || p === appId + ".desktop") {
                foundIdx = i
                break
            }
        }
        if (foundIdx !== -1) {
            cur.splice(foundIdx, 1)
        } else {
            cur.push(appId)
        }
        savePinned(cur)
        pinnedIds = cur
    }

    function savePinned(arr) {
        const json = JSON.stringify(arr !== undefined ? arr : pinnedIds)
        pPinnedWrite.command = ["sh", "-c", "cat > \"$HOME/.config/quickshell/metro/pinned.json\" << 'QSEOF'\n" + json + "\nQSEOF"]
        pPinnedWrite.running = true
    }

    Process {
        id: pPinnedRead

        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/metro/pinned.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = null
                try {
                    p = JSON.parse(text)
                } catch (e) {
                    p = null
                }
                if (Array.isArray(p)) {
                    root.pinnedIds = p
                } else {
                    const defs = ["metro-settings", "nemo", "firefox", "kitty"]
                    const validDefs = []
                    for (let i = 0; i < defs.length; i++) {
                        if (root.allApps.some(a => a.id === defs[i]))
                            validDefs.push(defs[i])
                    }
                    root.pinnedIds = validDefs.length > 0 ? validDefs : (root.allApps.length > 0 ? [root.allApps[0].id] : [])
                    root.savePinned(root.pinnedIds)
                }
            }
        }
    }

    Process {
        id: pPinnedWrite
    }

    Process {
        id: pTerminalExec
    }

    Process {
        id: pClipboard
    }

    Process {
        id: pSettingsDirect
        command: ["sh", "-c", "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; metro-settings"]
    }

    Process {
        id: pAppDirect
    }

    function copyToClipboard(text) {
        pClipboard.command = ["sh", "-c", "printf '%s' " + JSON.stringify(text) + " | wl-copy 2>/dev/null || true"]
        pClipboard.running = true
    }

    function runTerminal(cmd) {
        let clean = cmd.trim()
        if (clean.startsWith(">")) clean = clean.substring(1).trim()
        if (!clean) return
        // Команда через tempfile + quoted-heredoc: кавычки и $ безопасны.
        const script = "F=$(mktemp /tmp/metro-exec.XXXXXX.sh); cat > \"$F\" <<'METRO_EXEC_EOF'\n"
            + clean + "\nMETRO_EXEC_EOF\n"
            + "export F;"
            + " if command -v kitty >/dev/null 2>&1; then kitty -e sh -c 'sh \"$F\"; echo; read -p \"exit\" _; rm -f \"$F\"';"
            + " elif command -v alacritty >/dev/null 2>&1; then alacritty -e sh -c 'sh \"$F\"; echo; read -p \"exit\" _; rm -f \"$F\"';"
            + " elif command -v foot >/dev/null 2>&1; then foot sh -c 'sh \"$F\"; echo; read -p \"exit\" _; rm -f \"$F\"';"
            + " elif command -v gnome-terminal >/dev/null 2>&1; then gnome-terminal -- sh -c 'sh \"$F\"; echo; read -p \"exit\" _; rm -f \"$F\"';"
            + " elif command -v xterm >/dev/null 2>&1; then xterm -e sh -c 'sh \"$F\"; echo; read -p \"exit\" _; rm -f \"$F\"';"
            + " else sh \"$F\"; rm -f \"$F\"; fi"
        pTerminalExec.command = ["sh", "-c", script]
        pTerminalExec.running = true
        Qt.callLater(() => root.open = false)
    }

    function evalMath(expr) {
        if (!expr) return null
        const trimmed = expr.trim()
        if (!trimmed) return null
        if (!/^[0-9+\-*/().\s^%]+$/.test(trimmed)) return null
        if (!/[0-9]/.test(trimmed)) return null
        try {
            const res = Function('"use strict";return (' + trimmed + ')')()
            if (typeof res === 'number' && !isNaN(res) && isFinite(res)) {
                return Math.round(res * 1000000) / 1000000
            }
        } catch (e) {}
        return null
    }

    Component.onCompleted: pPinnedRead.running = true

    readonly property var allApps: {
        const values = DesktopEntries.applications.values ?? []
        const list = []
        for (let i = 0; i < values.length; i++) {
            const a = values[i]
            if (!a.noDisplay && a.name && a.name.length > 0 && a.execString !== undefined && a.execString !== "" && a.id.indexOf("kcm") !== 0 && a.id.indexOf("xdg") !== 0)
                list.push(a)
        }
        list.sort((x, y) => x.name.localeCompare(y.name))
        return list
    }

    readonly property var pinnedList: {
        const list = []
        for (let i = 0; i < pinnedIds.length; i++) {
            const pid = pinnedIds[i]
            for (let j = 0; j < allApps.length; j++) {
                const a = allApps[j]
                if (a.id === pid || a.id === pid + ".desktop" || a.id + ".desktop" === pid) {
                    list.push(a)
                    break
                }
            }
        }
        return list
    }

    property string query: ""

    readonly property var filteredApps: {
        const q = query.toLowerCase()
        if (!q)
            return allApps
        return allApps.filter(a => a.name.toLowerCase().includes(q) || a.id.toLowerCase().includes(q))
    }

    readonly property var listModel: {
        const out = []
        let last = "\u0000"
        for (let i = 0; i < filteredApps.length; i++) {
            const a = filteredApps[i]
            let letter = a.name.charAt(0).toUpperCase()
            if (/[0-9]/.test(letter) || !/[A-ZА-ЯЁ]/.test(letter)) {
                letter = "#"
            }
            if (letter !== last) {
                last = letter
                out.push({
                    "kind": "header",
                    "letter": letter
                })
            }
            out.push({
                "kind": "app",
                "app": a
            })
        }
        return out
    }

    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: -18
        }
        width: parent.width + 18
        radius: Theme.panelLeftRadius
        color: Theme.panelLeftBg
        border.width: 1
        border.color: Theme.stroke
    }

    Column {
        anchors.fill: parent
        anchors {
            leftMargin: 22
            rightMargin: 26
            topMargin: 20
            bottomMargin: 22
        }
        spacing: 12

        Item {
            width: parent.width
            height: 60

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: I18n.t("apps")
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.Light
                    color: Theme.text
                }

                Text {
                    text: filteredApps.length + " " + I18n.t("installed")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }
            }
        }

        // Metro glass search (стекло + акцент при фокусе)
        Rectangle {
            width: parent.width
            height: 44
            radius: Theme.radius
            color: searchInput.activeFocus ? Theme.glassHover : Theme.glass
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.accent : Theme.stroke

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            Text {
                visible: query === ""
                anchors {
                    left: parent.left
                    leftMargin: 16
                    verticalCenter: parent.verticalCenter
                }
                text: "\uf002"
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: searchInput.activeFocus ? Theme.accent : Theme.textDim
            }

            TextInput {
                id: searchInput

                anchors {
                    left: parent.left
                    leftMargin: 34
                    right: parent.right
                    rightMargin: 12
                    top: parent.top
                    bottom: parent.bottom
                }
                verticalAlignment: TextInput.AlignVCenter
                text: root.query
                font.family: Theme.fontFamily
                font.pixelSize: 14
                color: Theme.text
                cursorVisible: activeFocus
                clip: true
                onTextChanged: root.query = text
                onAccepted: {
                    const q = root.query.trim()
                    if (!q) return
                    if (q.startsWith(">")) {
                        root.runTerminal(q.substring(1).trim())
                        return
                    }
                    const mathVal = root.evalMath(q)
                    if (mathVal !== null) {
                        root.copyToClipboard(mathVal.toString())
                        return
                    }
                    if (root.filteredApps.length > 0) {
                        root.filteredApps[0].execute()
                        Qt.callLater(() => root.open = false)
                    } else {
                        root.runTerminal(q)
                    }
                }

                Text {
                    visible: searchInput.text === "" && !searchInput.activeFocus
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("search_dots")
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.textDim
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 2
                radius: 1
                color: Theme.accent
                opacity: searchInput.activeFocus ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }

        // ── Поисковые действия (Терминал / Калькулятор) ──
        Item {
            id: searchActionsArea
            width: parent.width
            visible: root.query.trim().length > 0
            height: visible ? searchActionsCol.height : 0

            Column {
                id: searchActionsCol
                width: parent.width
                spacing: 8

                // Карточка запуска в терминале
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: Theme.radiusSmall
                    color: termCardMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: termCardMa.containsMouse ? Theme.alpha(Theme.accent, 0.6) : Theme.stroke
                    scale: termCardMa.pressed ? 0.96 : (termCardMa.containsMouse ? 1.01 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: 6
                            color: Theme.alpha(Theme.accent, 0.18)
                            scale: termCardMa.containsMouse ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf120"
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                                color: Theme.accent
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 1

                            Text {
                                width: parent.width
                                text: "> " + root.query.trim()
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "Выполнить команду в терминале (Enter)"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }
                    }

                    MouseArea {
                        id: termCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runTerminal(root.query)
                    }
                }

                // Карточка калькулятора
                Rectangle {
                    id: mathCard
                    readonly property var mathRes: root.evalMath(root.query)
                    visible: mathCard.mathRes !== null
                    width: parent.width
                    height: 44
                    radius: Theme.radiusSmall
                    color: mathCardMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: mathCardMa.containsMouse ? Theme.alpha(Theme.green, 0.6) : Theme.stroke
                    scale: mathCardMa.pressed ? 0.96 : (mathCardMa.containsMouse ? 1.01 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    property bool copiedFlash: false
                    Timer {
                        id: copiedTimer
                        interval: 1600
                        onTriggered: mathCard.copiedFlash = false
                    }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: 6
                            color: mathCard.copiedFlash ? Theme.alpha(Theme.green, 0.4) : Qt.rgba(0.2, 0.8, 0.4, 0.18)
                            scale: mathCardMa.containsMouse || mathCard.copiedFlash ? 1.08 : 1.0

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                            Text {
                                anchors.centerIn: parent
                                text: mathCard.copiedFlash ? "\uf00c" : "\uf1ec"
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                                color: Theme.green
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 1

                            Text {
                                width: parent.width
                                text: "= " + (mathCard.mathRes !== null ? mathCard.mathRes : "")
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.green
                                elide: Text.ElideRight
                            }

                            Text {
                                text: mathCard.copiedFlash ? "✓ Результат скопирован в буфер!" : "Нажмите для копирования результата в буфер"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: mathCard.copiedFlash ? Theme.green : Theme.textDim
                            }
                        }
                    }

                    MouseArea {
                        id: mathCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (mathCard.mathRes !== null) {
                                root.copyToClipboard(mathCard.mathRes.toString())
                                mathCard.copiedFlash = true
                                copiedTimer.restart()
                            }
                        }
                    }
                }
            }
        }

        // ── закрепленные приложения ──
        Item {
            id: pinnedArea

            width: parent.width
            visible: root.query === "" && root.pinnedList.length > 0
            height: visible ? pinnedCol.height : 0

            Column {
                id: pinnedCol

                width: parent.width
                spacing: 8

                // Заголовок закреплённых
                Item {
                    width: parent.width
                    height: 26

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf005"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: Theme.accent
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("pinned")
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: pinnedCountTxt.width + 12
                        height: 18
                        radius: 9
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke

                        Text {
                            id: pinnedCountTxt

                            anchors.centerIn: parent
                            text: root.pinnedList.length
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                        }
                    }
                }

                // Сетка закрепленных приложений (2 колонки)
                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 8

                    Repeater {
                        model: root.pinnedList

                        delegate: Rectangle {
                            id: pinCard

                            required property var modelData
                            readonly property var app: modelData

                            width: Math.floor((pinnedCol.width - 8) / 2)
                            height: 46
                            radius: Theme.radiusSmall
                            color: pinCardMa.containsMouse ? Theme.glassHover : Theme.glass
                            border.width: 1
                            border.color: pinCardMa.containsMouse ? Theme.alpha(Theme.accent, 0.45) : Theme.stroke
                            scale: pinCardMa.pressed ? 0.94 : (pinCardMa.containsMouse ? 1.02 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Row {
                                anchors {
                                    left: parent.left
                                    right: unpinBtn.left
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 8
                                    rightMargin: 4
                                }
                                spacing: 8

                                // Иконка
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.15)
                                    scale: pinCardMa.containsMouse ? 1.08 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: pinCard.app && pinCard.app.icon !== "" && Quickshell.hasThemeIcon(pinCard.app.icon)
                                        implicitSize: 22
                                        source: visible ? Quickshell.iconPath(pinCard.app.icon) : ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !(pinCard.app && pinCard.app.icon !== "" && Quickshell.hasThemeIcon(pinCard.app.icon))
                                        text: "\uf1b2"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: Theme.textDim
                                    }
                                }

                                // Имя
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 38
                                    text: pinCard.app ? pinCard.app.name : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }
                            }

                            // Кнопка открепления (звёздочка / крестик при ховере)
                            Rectangle {
                                id: unpinBtn

                                anchors {
                                    right: parent.right
                                    rightMargin: 4
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 22
                                height: 22
                                radius: 11
                                color: unpinMa.containsMouse ? Theme.alpha(Theme.red, 0.85) : "transparent"
                                opacity: pinCardMa.containsMouse || unpinMa.containsMouse ? 1 : 0
                                scale: unpinMa.containsMouse ? 1.15 : 1.0

                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: unpinMa.containsMouse ? "\uf00d" : "\uf005"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 10
                                    color: unpinMa.containsMouse ? "#ffffff" : Theme.accent
                                }

                                MouseArea {
                                    id: unpinMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        mouse.accepted = true
                                        root.togglePin(pinCard.app.id)
                                    }
                                }
                            }

                            MouseArea {
                                id: pinCardMa

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.togglePin(pinCard.app ? pinCard.app.id : pinCard.modelData)
                                    } else {
                                        if (pinCard.app) {
                                            pinCard.app.execute()
                                        } else if (pinCard.modelData === "metro-settings" || (pinCard.modelData && pinCard.modelData.id === "metro-settings")) {
                                            pSettingsDirect.running = true
                                        } else if (pinCard.modelData) {
                                            const execCmd = typeof pinCard.modelData === "string" ? pinCard.modelData : (pinCard.modelData.id || "")
                                            if (execCmd) {
                                                pAppDirect.command = ["sh", "-c", "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; " + execCmd]
                                                pAppDirect.running = true
                                            }
                                        }
                                        Qt.callLater(() => root.open = false)
                                    }
                                }
                            }
                        }
                    }
                }

                // Разделитель перед основным алфавитным списком
                Item {
                    width: parent.width
                    height: 10

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Theme.stroke
                    }
                }
            }
        }

        ListView {
            id: appList

            width: parent.width
            height: parent.height - 60 - 38 - (pinnedArea.visible ? pinnedArea.height + 12 : 0) - (searchActionsArea.visible ? searchActionsArea.height + 12 : 0) - 24
            clip: true
            model: root.listModel
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: false
            spacing: 0

            // плавный доводчик скролла колесом (без рывков)
            NumberAnimation {
                id: scrollAnim

                target: appList
                property: "contentY"
                duration: 200
                easing.type: Easing.OutQuad
            }

            onDragStarted: scrollAnim.stop()
            onFlickStarted: scrollAnim.stop()

            function smoothScroll(dy) {
                const max = Math.max(0, appList.contentHeight - appList.height)
                scrollAnim.stop()
                scrollAnim.to = Math.max(0, Math.min(max, appList.contentY - dy * 1.9))
                scrollAnim.restart()
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                scrollGestureEnabled: true
                onWheel: wheel => appList.smoothScroll(wheel.angleDelta.y)
            }

            delegate: Item {
                id: entry

                required property var modelData
                readonly property var app: modelData.kind === "app" ? modelData.app : null

                width: appList.width
                height: modelData.kind === "header" ? 44 : 62

                // ── Заголовок буквы (статичный разделитель, без Jump Grid) ──
                Item {
                    visible: modelData.kind === "header"
                    anchors.fill: parent

                    // Material 3 Style
                    Rectangle {
                        visible: Theme.isMaterial
                        anchors {
                            left: parent.left
                            leftMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        height: 28
                        width: letterTxt.width + 20
                        radius: Theme.radiusPill
                        color: Theme.primary_container

                        Text {
                            id: letterTxt
                            anchors.centerIn: parent
                            text: modelData.kind === "header" ? modelData.letter : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Theme.on_primary_container
                        }
                    }

                    // Metro / WP Style
                    Column {
                        visible: !Theme.isMaterial
                        anchors {
                            left: parent.left
                            leftMargin: 6
                            bottom: parent.bottom
                            bottomMargin: 4
                        }
                        spacing: 3

                        Text {
                            text: modelData.kind === "header" ? modelData.letter : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Font.Light
                            color: Theme.text
                        }

                        Rectangle {
                            width: 30
                            height: 3
                            radius: Theme.isWP ? 0 : 1.5
                            color: Theme.accent
                        }
                    }
                }

                // ── Строка приложения ──
                Item {
                    visible: modelData.kind === "app"
                    anchors.fill: parent
                    scale: rowMa.pressed ? 0.97 : 1.0

                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSmall
                        color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Rectangle {
                        id: iconBox
                        anchors {
                            left: parent.left
                            leftMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        width: 46
                        height: 46
                        radius: Theme.radiusSmall
                        visible: entry.app !== null
                        color: Theme.glass
                        border.width: 1
                        border.color: rowMa.containsMouse ? Theme.alpha(Theme.accent, 0.4) : Theme.stroke
                        scale: rowMa.pressed ? 0.92 : (rowMa.containsMouse ? 1.06 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        IconImage {
                            anchors.centerIn: parent
                            visible: entry.app && entry.app.icon !== "" && Quickshell.hasThemeIcon(entry.app.icon)
                            implicitSize: 28
                            source: entry.app && entry.app.icon !== "" && Quickshell.hasThemeIcon(entry.app.icon) ? Quickshell.iconPath(entry.app.icon) : ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !(entry.app && entry.app.icon !== "" && Quickshell.hasThemeIcon(entry.app.icon))
                            text: "\uf1b2"
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: Theme.textDim
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: rowMa.containsMouse ? 68 : 64
                            right: parent.right
                            rightMargin: 42
                            verticalCenter: parent.verticalCenter
                        }
                        text: entry.app ? entry.app.name : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: rowMa.containsMouse ? "#ffffff" : Theme.text
                        elide: Text.ElideRight

                        Behavior on anchors.leftMargin { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    // Кнопка закрепления (звёздочка)
                    Rectangle {
                        id: pinBtn

                        anchors {
                            right: parent.right
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        width: 32
                        height: 32
                        radius: 16
                        readonly property bool pinned: entry.app && root.isPinned(entry.app.id)
                        opacity: pinned ? 1 : (pinBtnMa.containsMouse ? 1 : (rowMa.containsMouse ? 0.75 : 0.2))
                        color: pinBtnMa.containsMouse ? Theme.glassHover : "transparent"
                        scale: pinBtnMa.pressed ? 0.84 : (pinBtnMa.containsMouse ? 1.18 : 1.0)

                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: pinBtn.pinned ? "\uf005" : (pinBtnMa.containsMouse ? "\uf005" : "\uf006")
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: pinBtn.pinned || pinBtnMa.containsMouse ? Theme.accent : Theme.textDim
                        }

                        MouseArea {
                            id: pinBtnMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.app) {
                                    root.togglePin(entry.app.id)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa

                        anchors {
                            left: parent.left
                            right: pinBtn.left
                            top: parent.top
                            bottom: parent.bottom
                            rightMargin: 4
                        }
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (entry.app)
                                    root.togglePin(entry.app.id)
                            } else {
                                if (entry.app) {
                                    entry.app.execute()
                                } else if (entry.modelData && (entry.modelData.id === "metro-settings" || entry.modelData.id === "metro-settings.desktop")) {
                                    pSettingsDirect.running = true
                                }
                                Qt.callLater(() => root.open = false)
                            }
                        }
                    }
                }
            }
        }
    }

}


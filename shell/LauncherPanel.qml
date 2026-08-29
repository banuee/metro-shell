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
                    const defs = ["kitty", "firefox", "org.telegram.desktop", "nemo"]
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
            const letter = a.name.charAt(0).toUpperCase()
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
        radius: Theme.panelRadius
        color: Theme.bg
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
                    text: "приложения"
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.Light
                    color: Theme.text
                }

                Text {
                    text: filteredApps.length + " установлено"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 38
            radius: Theme.radiusSmall
            color: Theme.glass

            Text {
                visible: query === ""
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: "\uf002"
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: Theme.textDim
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

                Text {
                    visible: searchInput.text === "" && !searchInput.activeFocus
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "поиск..."
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
                            text: "закреплённые"
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
                            border.color: pinCardMa.containsMouse ? Theme.alpha(Theme.accent, 0.4) : Theme.stroke

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

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

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }

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
                                        root.togglePin(pinCard.app.id)
                                    } else {
                                        if (pinCard.app) {
                                            pinCard.app.execute()
                                            Qt.callLater(() => root.open = false)
                                        }
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
            height: parent.height - 60 - 38 - (pinnedArea.visible ? pinnedArea.height + 12 : 0) - 24
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

                Column {
                    visible: modelData.kind === "header"
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
                        radius: 1.5
                        color: Theme.accent
                    }
                }

                Item {
                    visible: modelData.kind === "app"
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSmall
                        color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    }

                    Rectangle {
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
                        border.color: Theme.stroke

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
                            leftMargin: 64
                            right: parent.right
                            rightMargin: 42
                            verticalCenter: parent.verticalCenter
                        }
                        text: entry.app ? entry.app.name : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: Theme.text
                        elide: Text.ElideRight
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

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }

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
                                    Qt.callLater(() => root.open = false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

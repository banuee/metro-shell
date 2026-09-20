import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

TileFrame {
    id: root

    property var notesList: []
    property bool panelShown: true
    property bool addMode: false

    readonly property bool isWide: width > Theme.unit + 20
    readonly property bool isTall: height > Theme.unit + 20
    readonly property bool isXL: width > Theme.tileW(2) + 20

    readonly property int totalCount: notesList.length
    readonly property int doneCount: {
        let c = 0
        for (let i = 0; i < notesList.length; i++) {
            if (notesList[i].done)
                c++
        }
        return c
    }
    readonly property int pendingCount: totalCount - doneCount
    readonly property real progressFrac: totalCount > 0 ? doneCount / totalCount : 0

    onPanelShownChanged: {
        if (panelShown)
            pNotesRead.running = true
    }

    Component.onCompleted: pNotesRead.running = true

    function saveNotes(arr) {
        const json = JSON.stringify(arr !== undefined ? arr : notesList, null, 2)
        pNotesWrite.command = ["sh", "-c", "cat > \"$HOME/.config/quickshell/metro/notes.json\" << 'QSEOF'\n" + json + "\nQSEOF"]
        pNotesWrite.running = true
    }

    function toggleNote(id) {
        const cur = notesList.slice()
        for (let i = 0; i < cur.length; i++) {
            if (cur[i].id === id) {
                cur[i] = Object.assign({}, cur[i], { "done": !cur[i].done })
                break
            }
        }
        notesList = cur
        saveNotes(cur)
    }

    function addNote(text) {
        const t = text.trim()
        if (!t)
            return
        const cur = notesList.slice()
        cur.unshift({
            "id": Date.now(),
            "text": t,
            "done": false
        })
        notesList = cur
        saveNotes(cur)
        addMode = false
    }

    function deleteNote(id) {
        const cur = notesList.slice().filter(n => n.id !== id)
        notesList = cur
        saveNotes(cur)
    }

    function clearCompleted() {
        const cur = notesList.slice().filter(n => !n.done)
        notesList = cur
        saveNotes(cur)
    }

    Process {
        id: pNotesRead
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/metro/notes.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = null
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    parsed = null
                }
                if (Array.isArray(parsed)) {
                    // пустой [] = пользователь удалил все заметки, уважаем это
                    root.notesList = parsed
                } else {
                    const defaults = [
                        { "id": 1, "text": "Настроить Material You", "done": true },
                        { "id": 2, "text": "Проверить Pixel UI виджеты", "done": false },
                        { "id": 3, "text": "Оценить динамические цвета", "done": false }
                    ]
                    root.notesList = defaults
                    root.saveNotes(defaults)
                }
            }
        }
    }

    Process {
        id: pNotesWrite
    }

    // =========================================================================
    //  МАТЕРИАЛЬНЫЙ СТИЛЬ (Theme.isMaterial == true) - Pixel UI / Material You
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: Theme.isMaterial

        // ── 2x2 Большой вид (List Style с фото 3): только широкие+высокие (3x2 тянется сам) ──
        Item {
            anchors.fill: parent
            visible: root.isWide && root.isTall
            anchors.margins: 10

            // Верхняя плашка: List слева, Scalloped Pencil кнопка справа
            Item {
                id: matHeader2x2
                width: parent.width
                height: 28

                Rectangle {
                    anchors.left: parent.left
                    height: 26
                    width: matListTag.width + 16
                    radius: Theme.radiusPill
                    color: Theme.primary_container

                    Row {
                        id: matListTag
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "List"
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.on_primary_container
                        }
                        Text {
                            text: "•"
                            font.family: "Google Sans"
                            font.pixelSize: 10
                            color: Theme.alpha(Theme.on_primary_container, 0.6)
                        }
                        Text {
                            text: root.doneCount + "/" + root.totalCount
                            font.family: "Google Sans"
                            font.pixelSize: 11
                            color: Theme.on_primary_container
                        }
                    }
                }

                // 8-lobed Scalloped Pencil FAB справа
                Item {
                    id: matPencilBtn
                    anchors.right: parent.right
                    width: 28
                    height: 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 10
                        color: Theme.tertiary_container
                    }
                    Repeater {
                        model: 8
                        Rectangle {
                            readonly property real angle: index * (Math.PI * 2 / 8)
                            width: 10
                            height: 10
                            radius: 5
                            x: 14 + 9 * Math.cos(angle) - 5
                            y: 14 + 9 * Math.sin(angle) - 5
                            color: Theme.tertiary_container
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf303"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: Theme.on_tertiary_container
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addMode = !root.addMode
                    }
                }
            }

            // Поле добавления задачи
            Rectangle {
                id: matInputCard
                anchors {
                    top: matHeader2x2.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 6
                }
                height: 28
                radius: Theme.radiusPill
                color: Theme.surface_container_highest
                visible: root.addMode

                TextInput {
                    id: matNoteInput
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    color: Theme.on_surface
                    clip: true
                    onAccepted: {
                        root.addNote(text)
                        text = ""
                    }
                }
            }

            // Список задач
            ListView {
                anchors {
                    top: root.addMode ? matInputCard.bottom : matHeader2x2.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: 8
                }
                clip: true
                model: root.notesList
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds

                delegate: Row {
                    id: matTaskRow
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 0
                    spacing: 8

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 6
                        color: matTaskRow.modelData.done ? Theme.primary : "transparent"
                        border.width: 1.5
                        border.color: matTaskRow.modelData.done ? Theme.primary : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            visible: Boolean(matTaskRow.modelData.done)
                            text: "\uf00c"
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                            color: Theme.on_primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleNote(matTaskRow.modelData.id)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: matTaskRow.width - 26
                        text: matTaskRow.modelData.text
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.strikeout: Boolean(matTaskRow.modelData.done)
                        color: matTaskRow.modelData.done ? Theme.on_surface_variant : Theme.on_surface
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ── 2x1 Широкий вид ──
        Item {
            anchors.fill: parent
            visible: root.isWide && !root.isTall
            anchors.margins: 10

            Row {
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: root.notesList.slice(0, 2)
                    delegate: Row {
                        required property var modelData
                        width: (parent.width - 8) / 2
                        spacing: 6
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 5
                            color: modelData.done ? Theme.primary : "transparent"
                            border.width: 1.5
                            border.color: modelData.done ? Theme.primary : Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                visible: Boolean(modelData.done)
                                text: "\uf00c"
                                font.family: Theme.iconFont
                                font.pixelSize: 9
                                color: Theme.on_primary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleNote(modelData.id)
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 22
                            text: modelData.text
                            font.family: "Google Sans"
                            font.pixelSize: 11
                            font.strikeout: Boolean(modelData.done)
                            color: modelData.done ? Theme.on_surface_variant : Theme.on_surface
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ── 1x1 Компакт ──
        Item {
            anchors.fill: parent
            visible: !root.isWide && !root.isTall

            Column {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.primary_container

                    Text {
                        anchors.centerIn: parent
                        text: "\uf249"
                        font.family: Theme.iconFont
                        font.pixelSize: 17
                        color: Theme.on_primary_container
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.doneCount + "/" + root.totalCount
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.on_surface
                }
            }
        }

        // ── 1x2 Вертикаль ──
        Item {
            anchors.fill: parent
            visible: !root.isWide && root.isTall
            anchors.margins: 8

            Column {
                anchors.fill: parent
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 24
                    radius: Theme.radiusPill
                    color: Theme.primary_container

                    Text {
                        anchors.centerIn: parent
                        text: root.doneCount + "/" + root.totalCount
                        font.family: "Google Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.on_primary_container
                    }
                }

                Repeater {
                    model: root.notesList.slice(0, 5)

                    Row {
                        required property var modelData
                        width: parent.width
                        spacing: 6

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 5
                            color: modelData.done ? Theme.primary : "transparent"
                            border.width: 1.5
                            border.color: modelData.done ? Theme.primary : Theme.outline
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                visible: Boolean(modelData.done)
                                text: "\uf00c"
                                font.family: Theme.iconFont
                                font.pixelSize: 9
                                color: Theme.on_primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleNote(modelData.id)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 22
                            text: modelData.text
                            font.family: "Google Sans"
                            font.pixelSize: 10
                            font.strikeout: Boolean(modelData.done)
                            color: modelData.done ? Theme.on_surface_variant : Theme.on_surface
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    //  КЛАССИЧЕСКИЙ СТИЛЬ METRO / WP (Theme.isMaterial == false)
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: !Theme.isMaterial

        // ── 2x1 Широкий вид ──
        Item {
            anchors.fill: parent
            visible: root.isWide && !root.isTall
            z: 1

            Item {
                id: head2x1
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 8
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 16

                Row {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf249"
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("notes").toUpperCase()
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        color: Theme.textDim
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.doneCount + "/" + root.totalCount
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: root.pendingCount === 0 && root.totalCount > 0 ? Theme.lime : Theme.accent
                }
            }

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: head2x1.bottom
                    bottom: parent.bottom
                    topMargin: 4
                    bottomMargin: 6
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 2

                Repeater {
                    model: root.notesList.slice(0, 2)

                    Item {
                        id: row2x1
                        required property var modelData
                        required property int index

                        width: parent.width
                        height: 22

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.isWP ? 0 : 4
                            color: rMa.containsMouse ? Theme.glassHover : "transparent"
                        }

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 2
                                rightMargin: 2
                            }
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row2x1.modelData.done ? "\uf14a" : "\uf0c8"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: row2x1.modelData.done ? Theme.accent : Theme.textDim
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: row2x1.width - 24
                                text: row2x1.modelData.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.strikeout: Boolean(row2x1.modelData.done)
                                color: row2x1.modelData.done ? Theme.textDim : Theme.text
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: rMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleNote(row2x1.modelData.id)
                        }
                    }
                }
            }
        }

        // ── 1x1 Компакт ──
        Item {
            anchors.fill: parent
            visible: !root.isWide && !root.isTall
            z: 1

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 14
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf249"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.doneCount + "/" + root.totalCount
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: root.pendingCount === 0 && root.totalCount > 0 ? Theme.lime : Theme.accent
                    }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 4
                    text: root.pendingCount
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Light
                    color: Theme.text
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 3
                    radius: Theme.isWP ? 0 : 1.5
                    color: Theme.alpha(Theme.accent, 0.16)

                    Rectangle {
                        width: Math.max(3, parent.width * root.progressFrac)
                        height: parent.height
                        radius: Theme.isWP ? 0 : 1.5
                        color: Theme.accent
                    }
                }
            }
        }

        // ── 1x2 Вертикаль: счётчик + короткие строки ──
        Item {
            anchors.fill: parent
            visible: !root.isWide && root.isTall
            z: 1

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Item {
                    id: vHead
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 20

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf249"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: Theme.accent
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.doneCount + "/" + root.totalCount
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.pendingCount === 0 && root.totalCount > 0 ? Theme.lime : Theme.accent
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: Theme.isWP ? 0 : 10
                        visible: root.doneCount > 0
                        color: vClearMa.containsMouse ? Theme.alpha(Theme.red, 0.3) : Theme.glass

                        Text {
                            anchors.centerIn: parent
                            text: "\uf1f8"
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                            color: vClearMa.containsMouse ? Theme.red : Theme.textDim
                        }

                        MouseArea {
                            id: vClearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearCompleted()
                        }
                    }
                }

                Rectangle {
                    id: vBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: vHead.bottom
                    anchors.topMargin: 4
                    height: 3
                    radius: Theme.isWP ? 0 : 1.5
                    color: Theme.alpha(Theme.accent, 0.16)

                    Rectangle {
                        width: Math.max(3, parent.width * root.progressFrac)
                        height: parent.height
                        radius: Theme.isWP ? 0 : 1.5
                        color: Theme.accent
                    }
                }

                ListView {
                    id: vList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: vBar.bottom
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 6
                    clip: true
                    model: root.notesList
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: vRow
                        required property var modelData
                        width: vList.width
                        height: 24

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: vRow.modelData.done ? "\uf14a" : "\uf0c8"
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                color: vRow.modelData.done ? Theme.accent : Theme.textDim
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: vRow.width - 24
                                text: vRow.modelData.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.strikeout: Boolean(vRow.modelData.done)
                                color: vRow.modelData.done ? Theme.textDim : Theme.text
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleNote(vRow.modelData.id)
                        }
                    }
                }
            }
        }

        // ── 2x2 Большой вид (3x2 тянется сам: ListView fluid) ──
        Item {
            anchors.fill: parent
            visible: root.isWide && root.isTall
            z: 1

            Item {
                id: header2x2
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 10
                    leftMargin: 12
                    rightMargin: 12
                }
                height: 22

                Row {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf249"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("notes").toUpperCase()
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                        color: Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.doneCount + "/" + root.totalCount
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.pendingCount === 0 && root.totalCount > 0 ? Theme.lime : Theme.accent
                    }
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22
                    height: 22
                    radius: Theme.isWP ? 0 : 11
                    visible: root.doneCount > 0
                    color: clearMa.containsMouse ? Theme.alpha(Theme.red, 0.3) : Theme.glass

                    Text {
                        anchors.centerIn: parent
                        text: "\uf1f8"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: clearMa.containsMouse ? Theme.red : Theme.textDim
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearCompleted()
                    }
                }
            }

            Rectangle {
                id: inputCard
                anchors {
                    top: header2x2.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 8
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 28
                radius: Theme.isWP ? 0 : 6
                color: Theme.glass
                border.width: Theme.isWP ? 0 : 1
                border.color: noteInput.activeFocus ? Theme.accent : Theme.stroke

                TextInput {
                    id: noteInput
                    anchors {
                        left: parent.left
                        right: addBtn.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8
                        rightMargin: 4
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.text
                    clip: true
                    selectByMouse: true
                    onAccepted: {
                        if (text.trim() !== "") {
                            root.addNote(text)
                            text = ""
                        }
                    }

                    Text {
                        anchors.fill: parent
                        visible: !noteInput.text && !noteInput.activeFocus
                        text: I18n.t("new_task")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }

                Rectangle {
                    id: addBtn
                    anchors {
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        margins: 2
                    }
                    width: 24
                    radius: Theme.isWP ? 0 : 4
                    color: addMa.containsMouse ? Theme.alpha(Theme.accent, 0.4) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf067"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: noteInput.text.trim() !== "" ? Theme.accent : Theme.textDim
                    }

                    MouseArea {
                        id: addMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (noteInput.text.trim() !== "") {
                                root.addNote(noteInput.text)
                                noteInput.text = ""
                            }
                        }
                    }
                }
            }

            ListView {
                id: notesListV
                anchors {
                    top: inputCard.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: 8
                    bottomMargin: 8
                    leftMargin: 10
                    rightMargin: 10
                }
                clip: true
                model: root.notesList
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: parent
                    visible: root.notesList.length === 0
                    text: I18n.t("list_empty")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }

                delegate: Rectangle {
                    id: dItem
                    required property var modelData
                    required property int index

                    width: notesListV.width
                    height: 26
                    radius: Theme.isWP ? 0 : 4
                    color: dMa.containsMouse ? Theme.glassHover : "transparent"

                    Row {
                        anchors {
                            left: parent.left
                            right: dDeleteBtn.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 4
                            rightMargin: 4
                        }
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: dItem.modelData.done ? "\uf14a" : "\uf0c8"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: dItem.modelData.done ? Theme.accent : Theme.textDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: dItem.width - 48
                            text: dItem.modelData.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.strikeout: Boolean(dItem.modelData.done)
                            color: dItem.modelData.done ? Theme.textDim : Theme.text
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: dMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleNote(dItem.modelData.id)
                    }

                    Rectangle {
                        id: dDeleteBtn
                        anchors {
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        width: 18
                        height: 18
                        radius: Theme.isWP ? 0 : 9
                        visible: dMa.containsMouse || delMa.containsMouse
                        color: delMa.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                            color: delMa.containsMouse ? Theme.red : Theme.textDim
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteNote(dItem.modelData.id)
                        }
                    }
                }
            }
        }
    }
}

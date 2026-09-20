import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property int currentTab: 0 // 0 = local walls & accent, 1 = wallhaven

    property string currentThemeId: "nothing"
    property string currentWall: ""
    property string accentHex: ""
    property var walls: []
    property var liveWalls: []
    property var paletteCols: []
    property var iconThemes: []
    property string iconTheme: ""
    property var gtkThemes: []
    property string gtkTheme: ""
    property bool busy: false

    // Wallhaven online state
    property string whQuery: ""
    property string whSort: "toplist"
    property int whPage: 1
    property var whResults: []
    property bool whLoading: false
    property string downloadingId: ""

    // Экранирование для подстановки внутрь ДВОЙНЫХ кавычек sh.
    // НЕ использовать результат внутри '...'!
    function esc(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`")
    }

    function switchTheme(tid) {
        if (busy || currentThemeId === tid) return
        busy = true
        currentThemeId = tid
        win.run("metro-theme set '" + tid + "'")
        delayRefresh.restart()
    }

    function refresh() {
        pWalls.command = ["sh", "-c", "find $HOME/Wallpapers -maxdepth 2 -type f 2>/dev/null | grep -Ei '\\.(jpe?g|png|webp|bmp|gif)$' | sort"]
        pWalls.running = false
        pWalls.running = true

        pLiveWalls.command = ["sh", "-c", "mkdir -p $HOME/Wallpapers/live && find $HOME/Wallpapers/live $HOME/Wallpapers -maxdepth 2 -type f 2>/dev/null | grep -Ei '\\.(gif|webp|mp4|webm)$' | sort -u"]
        pLiveWalls.running = false
        pLiveWalls.running = true

        pCur.command = ["sh", "-c", "cat $HOME/.local/state/metro/wall 2>/dev/null; echo '---'; metro-colors --status-hex 2>/dev/null; echo '---'; metro-appearance icon 2>/dev/null; echo '---'; metro-theme get 2>/dev/null; echo '---'; metro-appearance gtk 2>/dev/null"]
        pCur.running = false
        pCur.running = true

        pThemes.command = ["sh", "-c", "for d in /usr/share/icons/*/ $HOME/.local/share/icons/*/ $HOME/.icons/*/; do [ -f \"$d/index.theme\" ] && basename \"$d\"; done 2>/dev/null | grep -viE '^hicolor$|^locolor$|^default$|cursor|Legacy' | sort -u"]
        pThemes.running = false
        pThemes.running = true

        pGtkThemes.command = ["sh", "-c", "for d in /usr/share/themes/*/ $HOME/.themes/*/ $HOME/.local/share/themes/*/; do [ -d \"$d/gtk-3.0\" -o -d \"$d/gtk-4.0\" ] && basename \"$d\"; done 2>/dev/null | sort -u"]
        pGtkThemes.running = false
        pGtkThemes.running = true

        pPal.command = ["sh", "-c", "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; metro-colors palette 2>/dev/null"]
        pPal.running = false
        pPal.running = true
    }

    function searchWallhaven() {
        whLoading = true
        let url = "https://wallhaven.cc/api/v1/search?categories=111&purity=100&sorting=" + whSort + "&atleast=1920x1080&page=" + whPage
        if (whQuery.trim() !== "") {
            url += "&q=" + encodeURIComponent(whQuery.trim())
        }
        pWallhaven.command = ["sh", "-c", "curl -s -m 8 \"" + url + "\""]
        pWallhaven.running = false
        pWallhaven.running = true
    }

    function downloadWallhaven(item) {
        if (busy) return
        // item.path приходит из внешнего JSON wallhaven.cc — строгий whitelist,
        // иначе произвольный URL/команда оказалась бы в shell
        if (!/^https:\/\/w\.wallhaven\.cc\/full\/[a-z0-9]+\/[a-z0-9\-]+\.(jpg|png)$/.test(item.path))
            return
        if (!/^[A-Za-z0-9_-]+$/.test(item.id))
            return
        busy = true
        downloadingId = item.id
        const targetDir = "$HOME/Wallpapers/wallhaven"
        const targetFile = targetDir + "/" + item.id + ".jpg"
        const cmd = "mkdir -p " + targetDir + " && curl -sL \"" + esc(item.path) + "\" -o \"" + esc(targetFile) + "\" && wall \"" + esc(targetFile) + "\""
        win.run(cmd)
        delayRefresh.restart()
    }

    Timer {
        id: delayRefresh
        interval: 2500
        repeat: false
        onTriggered: {
            root.busy = false
            root.downloadingId = ""
            refresh()
        }
    }

    function setWall(path) {
        if (busy) return
        busy = true
        win.run("wall \"" + esc(path) + "\"")
        currentWall = path
        delayRefresh.restart()
    }

    function pickColor(hex) {
        busy = true
        win.run("metro-colors set '" + hex + "'")
        delayRefresh.restart()
    }

    Process {
        id: pWalls
        stdout: StdioCollector {
            onStreamFinished: {
                root.walls = text.trim().split("\n").filter(l => l.trim() !== "")
            }
        }
    }

    Process {
        id: pLiveWalls
        stdout: StdioCollector {
            onStreamFinished: {
                root.liveWalls = text.trim().split("\n").filter(l => l.trim() !== "")
            }
        }
    }

    Process {
        id: pCur
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---")
                if (parts[0] !== undefined) root.currentWall = parts[0].trim()
                if (parts[1] !== undefined) root.accentHex = parts[1].trim()
                if (parts[2] !== undefined) root.iconTheme = parts[2].trim().replace(/'/g, "")
                if (parts[3] !== undefined && parts[3].trim() !== "") root.currentThemeId = parts[3].trim()
                if (parts[4] !== undefined) root.gtkTheme = parts[4].trim().replace(/'/g, "")
            }
        }
    }

    Process {
        id: pThemes
        stdout: StdioCollector {
            onStreamFinished: {
                root.iconThemes = text.trim().split("\n").filter(l => l.trim() !== "")
            }
        }
    }

    Process {
        id: pGtkThemes
        stdout: StdioCollector {
            onStreamFinished: {
                root.gtkThemes = text.trim().split("\n").filter(l => l.trim() !== "")
            }
        }
    }

    Process {
        id: pPal
        stdout: StdioCollector {
            onStreamFinished: {
                const cols = []
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/#[0-9a-fA-F]{6}/)
                    if (m && cols.indexOf(m[0]) === -1) {
                        cols.push(m[0])
                    }
                }
                root.paletteCols = cols
            }
        }
    }

    Process {
        id: pWallhaven
        stdout: StdioCollector {
            onStreamFinished: {
                root.whLoading = false
                try {
                    const parsed = JSON.parse(text)
                    if (parsed && parsed.data) {
                        const items = []
                        for (const it of parsed.data) {
                            items.push({
                                id: it.id,
                                path: it.path,
                                thumb: it.thumbs ? (it.thumbs.large || it.thumbs.small || it.thumbs.original) : it.path,
                                resolution: it.resolution || "1920x1080"
                            })
                        }
                        if (root.whPage === 1) {
                            root.whResults = items
                        } else {
                            root.whResults = root.whResults.concat(items)
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        refresh()
        searchWallhaven()
    }

    Column {
        id: col
        width: root.width
        spacing: 14

        // ─── Global Theme Switcher ───
        Column {
            width: parent.width
            spacing: 8

            Text {
                text: (I18n.lang === "ru" ? "Глобальный стиль" : "Global Theme").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Row {
                width: parent.width
                spacing: 10

                // 1. Material You Card (Pixel UI)
                Rectangle {
                    id: materialCard
                    width: Math.floor((col.width - 20) / 3)
                    height: 106
                    radius: 18
                    color: root.currentThemeId === "material" ? Qt.rgba(0.08, 0.22, 0.16, 0.9) : (materialMa.containsMouse ? Theme.surface_container_high : Theme.surface_container)
                    border.width: root.currentThemeId === "material" ? 2 : 1
                    border.color: root.currentThemeId === "material" ? Theme.primary : Theme.stroke
                    scale: materialMa.pressed ? 0.96 : (materialMa.containsMouse ? 1.015 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 22

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    scale: materialMa.containsMouse ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                }

                                Text {
                                    text: "Material You"
                                    font.family: "Google Sans"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.on_surface
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                visible: root.currentThemeId === "material"
                                width: activeMatTxt.width + 18
                                height: 18
                                radius: 9
                                color: Theme.primary
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: activeMatTxt
                                    anchors.centerIn: parent
                                    text: I18n.lang === "ru" ? "Активна" : "Active"
                                    font.family: "Google Sans"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: Theme.on_primary
                                }
                            }
                        }

                        Text {
                            text: I18n.lang === "ru" ? "Pixel UI · Google Sans · Скругления 24px · Динамические цвета M3" : "Pixel UI · Google Sans · 24px radii · Material 3 colors"
                            font.family: "Google Sans"
                            font.pixelSize: 10
                            color: Theme.on_surface_variant
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    MouseArea {
                        id: materialMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchTheme("material")
                    }
                }

                // 2. Windows Phone Card (True Metro)
                Rectangle {
                    id: wpCard
                    width: Math.floor((col.width - 20) / 3)
                    height: 106
                    radius: 0
                    color: root.currentThemeId === "wp" ? Qt.rgba(0.08, 0.14, 0.24, 0.9) : (wpMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.width: root.currentThemeId === "wp" ? 2 : 1
                    border.color: root.currentThemeId === "wp" ? Theme.teal : Qt.rgba(1, 1, 1, 0.10)
                    scale: wpMa.pressed ? 0.96 : (wpMa.containsMouse ? 1.015 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 22

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 0
                                    color: "#0050ef"
                                    anchors.verticalCenter: parent.verticalCenter
                                    scale: wpMa.containsMouse ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                }

                                Text {
                                    text: "Windows Phone"
                                    font.family: "Segoe UI Variable Static Text"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                visible: root.currentThemeId === "wp"
                                width: activeWpTxt.width + 18
                                height: 18
                                radius: 0
                                color: Theme.teal
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: activeWpTxt
                                    anchors.centerIn: parent
                                    text: I18n.lang === "ru" ? "Активна" : "Active"
                                    font.family: "Segoe UI Variable Static Text"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                }
                            }
                        }

                        Text {
                            text: I18n.lang === "ru" ? "Острые углы 0px · Segoe UI · Настоящий Metro Live Tiles стиль" : "Sharp 0px corners · Segoe UI · Authentic Windows Phone Metro style"
                            font.family: "Segoe UI Variable Static Text"
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.60)
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    MouseArea {
                        id: wpMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchTheme("wp")
                    }
                }

                // 3. Metro Live Tiles Card
                Rectangle {
                    id: metroCard
                    width: Math.floor((col.width - 20) / 3)
                    height: 106
                    radius: 12
                    color: root.currentThemeId === "metro" ? Qt.rgba(0.15, 0.20, 0.28, 0.6) : (metroMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.width: root.currentThemeId === "metro" ? 2 : 1
                    border.color: root.currentThemeId === "metro" ? Theme.teal : Qt.rgba(1, 1, 1, 0.10)
                    scale: metroMa.pressed ? 0.96 : (metroMa.containsMouse ? 1.015 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 22

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 3
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                    scale: metroMa.containsMouse ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                }

                                Text {
                                    text: "Metro Live"
                                    font.family: "Segoe UI Variable Static Text"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                visible: root.currentThemeId === "metro"
                                width: activeMetroTxt.width + 18
                                height: 18
                                radius: 4
                                color: Theme.teal
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: activeMetroTxt
                                    anchors.centerIn: parent
                                    text: I18n.lang === "ru" ? "Активна" : "Active"
                                    font.family: "Segoe UI Variable Static Text"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                }
                            }
                        }

                        Text {
                            text: I18n.lang === "ru" ? "Акриловое стекло · Скругления 10px / 16px · Мягкий акрил" : "Acrylic glass · 10px / 16px soft radii · Frosted acrylic"
                            font.family: "Segoe UI Variable Static Text"
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.60)
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    MouseArea {
                        id: metroMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchTheme("metro")
                    }
                }
            }
        }

        // ─── Sub-Navigation Pills ───        // Tab switcher (Local & Accent / Live / Wallhaven)
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: (col.width - 16) / 3
                height: 38
                radius: 8
                color: root.currentTab === 0 ? Theme.alpha(Theme.accent, 0.9) : (localTabMa.containsMouse ? Theme.glassHover : Theme.glass)
                border.width: 1
                border.color: root.currentTab === 0 ? Theme.accent : Theme.stroke
                scale: localTabMa.pressed ? 0.95 : (localTabMa.containsMouse ? 1.015 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf03e"; font.family: Theme.iconFont; font.pixelSize: 13; color: root.currentTab === 0 ? "#fff" : Theme.accent }
                    Text { text: I18n.t("local_walls"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.currentTab === 0 ? Font.DemiBold : Font.Normal; color: root.currentTab === 0 ? "#fff" : Theme.text }
                }

                MouseArea {
                    id: localTabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = 0
                }
            }

            Rectangle {
                width: (col.width - 16) / 3
                height: 38
                radius: 8
                color: root.currentTab === 1 ? Theme.alpha(Theme.accent, 0.9) : (liveTabMa.containsMouse ? Theme.glassHover : Theme.glass)
                border.width: 1
                border.color: root.currentTab === 1 ? Theme.accent : Theme.stroke
                scale: liveTabMa.pressed ? 0.95 : (liveTabMa.containsMouse ? 1.015 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf008"; font.family: Theme.iconFont; font.pixelSize: 13; color: root.currentTab === 1 ? "#fff" : Theme.accent }
                    Text { text: I18n.t("live_walls"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.currentTab === 1 ? Font.DemiBold : Font.Normal; color: root.currentTab === 1 ? "#fff" : Theme.text }
                }

                MouseArea {
                    id: liveTabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = 1
                }
            }

            Rectangle {
                width: (col.width - 16) / 3
                height: 38
                radius: 8
                color: root.currentTab === 2 ? Theme.alpha(Theme.accent, 0.9) : (whTabMa.containsMouse ? Theme.glassHover : Theme.glass)
                border.width: 1
                border.color: root.currentTab === 2 ? Theme.accent : Theme.stroke
                scale: whTabMa.pressed ? 0.95 : (whTabMa.containsMouse ? 1.015 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf0ac"; font.family: Theme.iconFont; font.pixelSize: 13; color: root.currentTab === 2 ? "#fff" : Theme.accent }
                    Text { text: I18n.t("wallhaven_walls"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.currentTab === 2 ? Font.DemiBold : Font.Normal; color: root.currentTab === 2 ? "#fff" : Theme.text }
                }

                MouseArea {
                    id: whTabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentTab = 2
                        if (root.whResults.length === 0) root.searchWallhaven()
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 0: LOCAL WALLPAPERS & ACCENT COLOR
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 0
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("wallpapers")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            // Random wallpaper button
            Rectangle {
                width: parent.width
                height: 44
                radius: 8
                color: randMa.containsMouse ? Theme.glassHover : Theme.glass
                scale: randMa.pressed ? 0.97 : (randMa.containsMouse ? 1.01 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text { text: "\uf074"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.accent }
                    Text { text: I18n.t("random_wall"); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.busy ? I18n.t("changing") : root.currentWall.split("/").pop()
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }

                MouseArea {
                    id: randMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.busy = true
                        root.win.run("wall random")
                        root.delayRefresh.restart()
                    }
                }
            }

            // Grid of local wallpapers
            Grid {
                width: parent.width
                columns: 5
                spacing: 8

                Repeater {
                    model: root.walls

                    Rectangle {
                        id: localWallCard
                        required property var modelData
                        width: (col.width - 4 * 8) / 5
                        height: width * 0.56
                        radius: Theme.isWP ? 0 : 8
                        color: Theme.glass
                        border.width: localWallCard.modelData === root.currentWall ? 2 : 1
                        border.color: localWallCard.modelData === root.currentWall ? Theme.accent : (wallMa.containsMouse ? Theme.alpha(Theme.accent, 0.5) : Theme.stroke)
                        scale: wallMa.pressed ? 0.93 : (wallMa.containsMouse ? 1.06 : 1.0)
                        z: wallMa.containsMouse ? 10 : 1

                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            id: localWallMask
                            anchors.fill: parent
                            anchors.margins: localWallCard.border.width
                            radius: Math.max(0, localWallCard.radius - 1)
                            visible: false
                        }

                        Image {
                            id: localWallImg
                            anchors.fill: parent
                            anchors.margins: localWallCard.border.width
                            source: "file://" + localWallCard.modelData
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 400
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: localWallMask
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: localWallCard.radius
                            color: wallMa.containsMouse ? Qt.rgba(0, 0, 0, 0.25) : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                id: wallMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setWall(localWallCard.modelData)
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            // Accent Color Section
            Text {
                text: I18n.t("accent")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: Theme.radiusSmall
                color: Theme.glass

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: Theme.isWP ? 0 : 13
                    color: root.accentHex === "" ? Theme.accent : root.accentHex
                    border.width: 1
                    border.color: Theme.stroke
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 50
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text { text: I18n.t("accent_from_wall"); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: root.accentHex === "" ? "—" : root.accentHex; font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.textDim }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: [
                            { t: I18n.t("from_wall"), c: "metro-colors \"$w\"" },
                            { t: "vivid", c: "metro-colors --vivid \"$w\"" },
                            { t: I18n.t("reset_theme"), c: "metro-colors --reset" }
                        ]

                        Rectangle {
                            id: accBtn
                            required property var modelData
                            width: txt.width + 20
                            height: 30
                            radius: Theme.isWP ? 0 : 6
                            color: bMa.containsMouse ? Theme.alpha(Theme.accent, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: bMa.pressed ? 0.92 : (bMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Text {
                                id: txt
                                anchors.centerIn: parent
                                text: accBtn.modelData.t
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.text
                            }

                            MouseArea {
                                id: bMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.busy = true
                                    root.win.run("w=$(cat $HOME/.local/state/metro/wall 2>/dev/null); " + accBtn.modelData.c)
                                    root.delayRefresh.restart()
                                }
                            }
                        }
                    }
                }
            }

            // ─── Custom Accent Color (HEX) ───
            Text {
                text: (I18n.lang === "ru" ? "Свой цвет акцента (HEX)" : "Custom Accent Color (HEX)").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Rectangle {
                width: parent.width
                height: 48
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: 1
                border.color: hexInput.activeFocus ? Theme.accent : Theme.stroke

                Behavior on border.color { ColorAnimation { duration: 120 } }

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 10
                    }
                    spacing: 10

                    Rectangle {
                        width: 24
                        height: 24
                        radius: Theme.isWP ? 0 : 12
                        color: /^#[0-9a-fA-F]{6}$/.test(hexInput.text.trim()) ? hexInput.text.trim() : Theme.accent
                        border.width: 1
                        border.color: Theme.stroke
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: hexInput
                        width: parent.width - 24 - 90 - 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.accentHex !== "" ? root.accentHex : "#3a73ab"
                        font.family: "monospace"
                        font.pixelSize: 13
                        color: Theme.text
                        clip: true
                        cursorVisible: activeFocus
                    }

                    Rectangle {
                        id: applyHexBtn
                        width: 80
                        height: 30
                        radius: Theme.isWP ? 0 : 6
                        color: applyHexMa.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                        scale: applyHexMa.pressed ? 0.92 : (applyHexMa.containsMouse ? 1.05 : 1.0)
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: I18n.lang === "ru" ? "Применить" : "Apply"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: applyHexMa.containsMouse ? "#0e1720" : Theme.text
                        }

                        MouseArea {
                            id: applyHexMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const hex = hexInput.text.trim()
                                if (/^#[0-9a-fA-F]{6}$/i.test(hex)) {
                                    root.pickColor(hex)
                                }
                            }
                        }
                    }
                }
            }

            // ─── Windows Phone Palette Swatches ───
            Text {
                text: (I18n.lang === "ru" ? "Палитра Windows Phone" : "Windows Phone Palette").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Row {
                spacing: 8

                Repeater {
                    model: [
                        { name: "Cobalt", hex: "#0050ef" },
                        { name: "Cyan", hex: "#1ba1e2" },
                        { name: "Emerald", hex: "#008a00" },
                        { name: "Lime", hex: "#a4c400" },
                        { name: "Orange", hex: "#fa6800" },
                        { name: "Mango", hex: "#f09609" },
                        { name: "Red", hex: "#e51400" },
                        { name: "Crimson", hex: "#a20025" },
                        { name: "Magenta", hex: "#d80073" },
                        { name: "Violet", hex: "#aa00ff" }
                    ]

                    Rectangle {
                        id: wpSwatch
                        required property var modelData
                        width: 34
                        height: 34
                        radius: Theme.isWP ? 0 : 17
                        color: wpSwatch.modelData.hex
                        border.width: wpSwatch.modelData.hex.toLowerCase() === root.accentHex.toLowerCase() ? 2 : 1
                        border.color: wpSwatch.modelData.hex.toLowerCase() === root.accentHex.toLowerCase() ? Theme.text : Theme.stroke
                        scale: wpSwatchMa.pressed ? 0.88 : (wpSwatchMa.containsMouse ? 1.15 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        MouseArea {
                            id: wpSwatchMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hexInput.text = wpSwatch.modelData.hex
                                root.pickColor(wpSwatch.modelData.hex)
                            }
                        }
                    }
                }
            }

            // Accent shades candidate swatches
            Text {
                text: I18n.t("accent_shades")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Row {
                spacing: 10

                Repeater {
                    model: root.paletteCols

                    Rectangle {
                        id: swatch
                        required property string modelData
                        required property int index
                        width: 36
                        height: 36
                        radius: Theme.isWP ? 0 : 18
                        color: swatch.modelData
                        border.width: swatch.modelData === root.accentHex ? 2 : 1
                        border.color: swatch.modelData === root.accentHex ? Theme.text : Theme.stroke
                        scale: swatchMa.pressed ? 0.88 : (swatchMa.containsMouse ? 1.15 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        MouseArea {
                            id: swatchMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hexInput.text = swatch.modelData
                                root.pickColor(swatch.modelData)
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            // Icon Theme
            Text {
                text: I18n.t("icon_theme")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            KitCombo {
                label: I18n.t("icon_sub")
                value: root.iconTheme === "" ? "—" : root.iconTheme
                options: root.iconThemes
                onPicked: opt => {
                    root.iconTheme = opt
                    root.win.run("metro-appearance icon '" + opt + "'")
                    root.delayRefresh.restart()
                }
            }

            Item { width: 1; height: 4 }

            // GTK Theme
            Text {
                text: (I18n.lang === "ru" ? "Тема оформления GTK" : "GTK Theme").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            KitCombo {
                label: I18n.lang === "ru" ? "Стиль окон и виджетов GTK" : "GTK application and widget style"
                value: root.gtkTheme === "" ? "—" : root.gtkTheme
                options: root.gtkThemes
                onPicked: opt => {
                    root.gtkTheme = opt
                    root.win.run("metro-appearance gtk '" + opt + "'")
                    root.delayRefresh.restart()
                }
            }

            Text {
                text: I18n.t("icon_hint")
                width: parent.width
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textDim
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 1: LIVE WALLPAPERS (ЖИВЫЕ ОБОИ)
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 1
            width: parent.width
            spacing: 12

            Row {
                width: parent.width
                Item {
                    width: parent.width - openLiveBtn.width - 10
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("live_walls")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        color: Theme.textDim
                    }
                }

                Rectangle {
                    id: openLiveBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: openLiveTxt.width + 20
                    height: 30
                    radius: 6
                    color: openLiveMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: Theme.stroke
                    scale: openLiveMa.pressed ? 0.94 : (openLiveMa.containsMouse ? 1.03 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "\uf07b"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accent }
                        Text { id: openLiveTxt; text: I18n.t("open_live_folder"); font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.text }
                    }

                    MouseArea {
                        id: openLiveMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.win.run("xdg-open $HOME/Wallpapers/live &")
                    }
                }
            }

            Text {
                text: I18n.t("live_walls_desc")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textDim
            }

            // Empty state if no live wallpapers
            Rectangle {
                visible: root.liveWalls.length === 0
                width: parent.width
                height: 90
                radius: Theme.panelRadius
                color: Theme.glass

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf008"; font.family: Theme.iconFont; font.pixelSize: 22; color: Theme.textDim; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: I18n.t("no_live_walls"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textDim; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            // Grid of live wallpapers
            Grid {
                visible: root.liveWalls.length > 0
                width: parent.width
                columns: 4
                spacing: 8

                Repeater {
                    model: root.liveWalls

                    Rectangle {
                        id: liveWallCard
                        required property var modelData
                        width: (col.width - 3 * 8) / 4
                        height: width * 0.58
                        radius: Theme.isWP ? 0 : 8
                        color: Theme.glass
                        border.width: liveWallCard.modelData === root.currentWall ? 2 : 1
                        border.color: liveWallCard.modelData === root.currentWall ? Theme.accent : (liveWallMa.containsMouse ? Theme.alpha(Theme.accent, 0.5) : Theme.stroke)
                        scale: liveWallMa.pressed ? 0.93 : (liveWallMa.containsMouse ? 1.06 : 1.0)
                        z: liveWallMa.containsMouse ? 10 : 1

                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            id: liveWallMask
                            anchors.fill: parent
                            anchors.margins: liveWallCard.border.width
                            radius: Math.max(0, liveWallCard.radius - 1)
                            visible: false
                        }

                        Image {
                            id: liveWallImg
                            anchors.fill: parent
                            anchors.margins: liveWallCard.border.width
                            source: "file://" + liveWallCard.modelData
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 400
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: liveWallMask
                            }
                        }

                        // Animated badge indicator
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                margins: 6
                            }
                            width: liveBadgeTxt.width + 18
                            height: 18
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.6)
                            border.width: 1
                            border.color: Theme.accent

                            Text {
                                id: liveBadgeTxt
                                anchors.centerIn: parent
                                text: "LIVE"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: liveWallCard.radius
                            color: liveWallMa.containsMouse ? Qt.rgba(0, 0, 0, 0.25) : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                id: liveWallMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setWall(liveWallCard.modelData)
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 2: WALLHAVEN ONLINE WALLPAPERS
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 2
            width: parent.width
            spacing: 12

            Text {
                text: "WALLHAVEN.CC (ONLINE)"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            // Search bar & Sorting chips
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width - 240
                    height: 42
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: whSearchIn.activeFocus ? Theme.accent : Theme.stroke

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Text { text: "\uf002"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                        TextInput {
                            id: whSearchIn
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.text
                            text: root.whQuery
                            onAccepted: {
                                root.whQuery = text
                                root.whPage = 1
                                root.searchWallhaven()
                            }
                        }
                    }
                    Text { visible: whSearchIn.text === ""; anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: "Поиск обоев (аниме, природа, cyber, dark...)..."; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                }

                Repeater {
                    model: [
                        { id: "toplist", label: "Top" },
                        { id: "newest", label: "New" },
                        { id: "random", label: "Rand" }
                    ]

                    Rectangle {
                        id: sortPill
                        required property var modelData
                        width: 72
                        height: 42
                        radius: 8
                        color: root.whSort === sortPill.modelData.id ? Theme.alpha(Theme.accent, 0.85) : (sortMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08))
                        scale: sortMa.pressed ? 0.94 : (sortMa.containsMouse ? 1.02 : 1.0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: sortPill.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: root.whSort === sortPill.modelData.id ? Font.DemiBold : Font.Normal
                            color: root.whSort === sortPill.modelData.id ? "#fff" : Theme.text
                        }

                        MouseArea {
                            id: sortMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.whSort = sortPill.modelData.id
                                root.whPage = 1
                                root.searchWallhaven()
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.whLoading
                text: "Загрузка обоев с Wallhaven..."
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.accent
            }

            // Wallhaven grid
            Grid {
                width: parent.width
                columns: 4
                spacing: 8

                Repeater {
                    model: root.whResults

                    Rectangle {
                        id: whCard
                        required property var modelData
                        width: (col.width - 3 * 8) / 4
                        height: width * 0.58
                        radius: Theme.isWP ? 0 : 8
                        color: Theme.glass
                        border.width: root.downloadingId === whCard.modelData.id ? 2 : 1
                        border.color: root.downloadingId === whCard.modelData.id ? Theme.accent : (whCardMa.containsMouse ? Theme.alpha(Theme.accent, 0.5) : Theme.stroke)
                        scale: whCardMa.pressed ? 0.93 : (whCardMa.containsMouse ? 1.06 : 1.0)
                        z: whCardMa.containsMouse ? 10 : 1

                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            id: whMask
                            anchors.fill: parent
                            anchors.margins: whCard.border.width
                            radius: Math.max(0, whCard.radius - 1)
                            visible: false
                        }

                        Image {
                            id: whImg
                            anchors.fill: parent
                            anchors.margins: whCard.border.width
                            source: whCard.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: whMask
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: whCard.radius
                            color: whCardMa.containsMouse ? Qt.rgba(0, 0, 0, 0.35) : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Column {
                                anchors.centerIn: parent
                                visible: root.downloadingId === whCard.modelData.id
                                spacing: 4
                                Text { text: "\uf019"; font.family: Theme.iconFont; font.pixelSize: 18; color: Theme.accent; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: "Загрузка…"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter }
                            }

                            MouseArea {
                                id: whCardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.downloadWallhaven(whCard.modelData)
                            }
                        }
                    }
                }
            }

            // Load more button
            Rectangle {
                visible: root.whResults.length > 0
                width: parent.width
                height: 40
                radius: 8
                color: moreMa.containsMouse ? Theme.glassHover : Theme.glass
                scale: moreMa.pressed ? 0.96 : (moreMa.containsMouse ? 1.01 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    text: root.whLoading ? "Загрузка…" : "Загрузить ещё обои"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }

                MouseArea {
                    id: moreMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.whPage++
                        root.searchWallhaven()
                    }
                }
            }
        }
    }
}

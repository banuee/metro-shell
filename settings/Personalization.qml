import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property string currentWall: ""
    property string accentHex: ""
    property var walls: []
    property var paletteCols: []
    property var iconThemes: []
    property string iconTheme: ""
    property bool busy: false

    function esc(s) {
        return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    }

    function refresh() {
        pWalls.command = ["sh", "-c", "find $HOME/Wallpapers -maxdepth 2 -type f 2>/dev/null | grep -Ei '\\.(jpe?g|png|webp|bmp|gif)$' | sort"]
        pWalls.running = true
        pCur.command = ["sh", "-c", "cat $HOME/.local/state/metro/wall 2>/dev/null; echo ---; metro-colors --status-hex 2>/dev/null; echo ---; gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null"]
        pCur.running = true
        pThemes.command = ["sh", "-c", "for d in /usr/share/icons/*/; do [ -f \"$d/index.theme\" ] && basename \"$d\"; done 2>/dev/null | grep -viE '^hicolor$|^locolor$|^default$|cursor|Legacy' | sort"]
        pThemes.running = true
        pPal.command = ["sh", "-c", "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; metro-colors palette 2>/dev/null | grep -E '^#[0-9a-fA-F]{6}$'"]
        pPal.running = true
    }

    Timer {
        id: delayRefresh

        interval: 2500
        repeat: false
        onTriggered: refresh()
    }

    function setWall(path) {
        if (busy)
            return
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

        stdout: SplitParser {
            onRead: data => root.walls = root.walls.concat([data])
        }
        onRunningChanged: if (running)
            root.walls = []
    }

    Process {
        id: pCur

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---")
                if (parts[0] !== undefined)
                    root.currentWall = parts[0].trim()
                if (parts[1] !== undefined)
                    root.accentHex = parts[1].trim()
                if (parts[2] !== undefined)
                    root.iconTheme = parts[2].trim().replace(/'/g, "")
            }
        }
    }

    Process {
        id: pThemes

        stdout: SplitParser {
            onRead: data => root.iconThemes = root.iconThemes.concat([data])
        }
        onRunningChanged: if (running)
            root.iconThemes = []
    }

    Process {
        id: pPal

        stdout: SplitParser {
            onRead: data => root.paletteCols = root.paletteCols.concat([data])
        }
        onRunningChanged: if (running)
            root.paletteCols = []
    }

    Column {
        id: col

        width: root.width
        spacing: 10

        // ─── обои ───
        Text {
            text: "ОБОИ"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Rectangle {
            width: parent.width
            height: 44
            radius: 8
            color: randMa.containsMouse ? Theme.glassHover : Theme.glass

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf074"
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: Theme.accent
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.verticalCenter: parent.verticalCenter
                text: "случайные обои"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                color: Theme.text
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.busy ? "меняю…" : root.currentWall.split("/").pop()
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

        Grid {
            width: parent.width
            columns: 5
            spacing: 8

            Repeater {
                model: root.walls

                Rectangle {
                    width: (parent.width - 4 * 8) / 5
                    height: width * 0.56
                    radius: 8
                    clip: true
                    color: Theme.glass
                    border.width: modelData === root.currentWall ? 2 : 1
                    border.color: modelData === root.currentWall ? Theme.accent : Theme.stroke

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 400
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: wallMa.containsMouse ? Qt.rgba(0, 0, 0, 0.18) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        MouseArea {
                            id: wallMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setWall(modelData)
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: 8
        }

        // ─── акцент ───
        Text {
            text: "АКЦЕНТ"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Rectangle {
            width: parent.width
            height: 52
            radius: 8
            color: Theme.glass

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                color: root.accentHex === "" ? Theme.accent : root.accentHex
                border.width: 1
                border.color: Theme.stroke
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "цвет акцента (из обоев)"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.text
                }
                Text {
                    text: root.accentHex === "" ? "—" : root.accentHex
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [
                    {
                        t: "из обоев",
                        c: "metro-colors \"$w\""
                    },
                    {
                        t: "vivid",
                        c: "metro-colors --vivid \"$w\""
                    },
                    {
                        t: "сброс темы",
                        c: "metro-colors --reset"
                    }]

                Rectangle {
                    id: accBtn

                    width: txt.width + 20
                    height: 30
                    radius: 6
                    color: bMa.containsMouse || bMa.pressed ? Theme.alpha(Theme.accent, bMa.pressed ? 0.9 : 0.6) : Theme.glass

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    required property var modelData

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

        Item {
            width: 1
            height: 8
        }

        // ─── оттенки из обоев ───
        Text {
            text: "ОТТЕНОК АКЦЕНТА"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            visible: root.paletteCols.length === 0
            text: root.busy ? "читаю обои…" : "нет кандидатов — смена обоев обновит"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textDim
        }

        Row {
            visible: root.paletteCols.length > 0
            spacing: 10

            Repeater {
                model: root.paletteCols

                Rectangle {
                    id: swatch

                    required property string modelData
                    required property int index

                    width: 36
                    height: 36
                    radius: 18
                    color: swatch.modelData
                    border.width: swatch.modelData === root.accentHex ? 2 : 1
                    border.color: swatch.modelData === root.accentHex ? Theme.text : Theme.stroke

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -16
                        text: String(swatch.index + 1)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }

                    MouseArea {
                        id: swMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickColor(swatch.modelData)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: Theme.text
                        opacity: swMa.containsMouse ? 0.18 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: 8
        }

        // ─── иконки ───
        Text {
            text: "ТЕМА ИКОНОК"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        KitCombo {
            label: "папки приложений и шелла"
            value: root.iconTheme === "" ? "—" : root.iconTheme
            options: root.iconThemes
            onPicked: opt => {
                root.iconTheme = opt
                root.win.run("gsettings set org.gnome.desktop.interface icon-theme '" + opt + "'")
            }
        }

        Text {
            text: "иконки следуют GTK-теме (QT_QPA_PLATFORMTHEME=gtk3) — применяются на лету, перезапуск шелла не нужен"
            width: parent.width
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }
    }
}

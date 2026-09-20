import QtQuick
import Quickshell
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win

    property var sysList: [
        { k: I18n.t("os"), val: "…", glyph: "\uf303" },
        { k: I18n.t("kernel"), val: "…", glyph: "\uf17c" },
        { k: I18n.t("environment"), val: "…", glyph: "\uf2d0" },
        { k: I18n.t("device"), val: "…", glyph: "\uf108" },
        { k: I18n.t("processor"), val: "…", glyph: "\uf2db" },
        { k: I18n.t("graphics"), val: "…", glyph: "\uf108" },
        { k: I18n.t("memory"), val: "…", glyph: "\ue266" },
        { k: I18n.t("disk"), val: "…", glyph: "\uf0c7" },
        { k: I18n.t("uptime"), val: "…", glyph: "\uf017" },
        { k: I18n.t("host"), val: "…", glyph: "\uf233" }
    ]
    property string updateCount: "0"
    property bool checkingUpdates: false

    // Цвета логотипа Live Quad — 4 цвета палитры matugen из palette.json
    // (пишет metro-colors при каждой смене обоев/акцента).
    property var logoColors: ["#00aba9", "#0050ef", "#a200ff", "#10893e"]
    readonly property color logoC0: logoColors[0]
    readonly property color logoC1: logoColors[1]
    readonly property color logoC2: logoColors[2]
    readonly property color logoC3: logoColors[3]

    function refresh() {
        pAbout.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py sys"]
        pAbout.running = false
        pAbout.running = true
        pPalette.command = ["sh", "-c", "cat $HOME/.local/state/metro/palette.json 2>/dev/null || echo '[\"#00aba9\",\"#0050ef\",\"#a200ff\",\"#10893e\"]'"]
        pPalette.running = false
        pPalette.running = true
        checkUpdates()
    }

    function checkUpdates() {
        checkingUpdates = true
        pUpdates.command = ["sh", "-c", "if command -v checkupdates >/dev/null 2>&1; then checkupdates 2>/dev/null | wc -l; elif command -v apt-get >/dev/null 2>&1; then apt list --upgradable 2>/dev/null | grep -c upgradable; elif command -v dnf >/dev/null 2>&1; then dnf check-update -q 2>/dev/null | grep -Ec '^[a-zA-Z0-9]'; elif command -v zypper >/dev/null 2>&1; then zypper list-updates 2>/dev/null | tail -n +5 | grep -c .; elif command -v sven-update >/dev/null 2>&1; then echo ?; else echo 0; fi"]
        pUpdates.running = false
        pUpdates.running = true
    }

    function launchUpdater() {
        win.run("metro-update &")
    }

    Process {
        id: pAbout
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(text)
                    root.sysList = [
                        { k: I18n.t("os"), val: m.os || "—", glyph: "\uf303" },
                        { k: I18n.t("kernel"), val: m.kernel || "—", glyph: "\uf17c" },
                        { k: I18n.t("environment"), val: m.wm || "—", glyph: "\uf2d0" },
                        { k: I18n.t("device"), val: m.term || "PC", glyph: "\uf108" },
                        { k: I18n.t("processor"), val: m.cpu || "—", glyph: "\uf2db" },
                        { k: I18n.t("graphics"), val: m.gpu || "—", glyph: "\uf108" },
                        { k: I18n.t("memory"), val: m.ram || "—", glyph: "\ue266" },
                        { k: I18n.t("disk"), val: m.disk || "—", glyph: "\uf0c7" },
                        { k: I18n.t("uptime"), val: m.up || "—", glyph: "\uf017" },
                        { k: I18n.t("host"), val: m.host || "—", glyph: "\uf233" }
                    ]
                } catch (e) {}
            }
        }
    }

    Process {
        id: pPalette
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text)
                    if (Array.isArray(arr) && arr.length >= 4)
                        root.logoColors = arr.slice(0, 4)
                } catch (e) {}
            }
        }
    }

    Process {
        id: pUpdates
        stdout: StdioCollector {
            onStreamFinished: {
                root.checkingUpdates = false
                const t = text.trim()
                root.updateCount = t || "0"
            }
        }
    }

    Component.onCompleted: refresh()

    Column {
        id: col
        width: root.width
        spacing: 14

        // ═════════════════════════════════════════════════════════════
        // METRO SHELL HERO BRANDING BANNER & ANIMATED LIVE QUAD LOGO
        // ═════════════════════════════════════════════════════════════
        Rectangle {
            id: heroCard
            width: col.width
            height: 112
            radius: Theme.panelRadius
            color: heroMa.containsMouse ? Theme.glassHover : Theme.glass
            border.width: 1
            border.color: heroMa.containsMouse ? Theme.alpha(Theme.accent, 0.6) : Theme.stroke

            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 20
                    rightMargin: 20
                }
                spacing: 20

                // ── Animated Live Quad Logo (Concept 1) ──
                Item {
                    id: logoBox
                    width: 72
                    height: 72
                    anchors.verticalCenter: parent.verticalCenter

                    scale: heroMa.containsMouse ? 1.06 : 1.0
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: 6

                        // Tile 1: Top-Left (палитра matugen №4)
                        Rectangle {
                            width: 31
                            height: 31
                            radius: Theme.isWP ? 0 : 7
                            color: Theme.alpha(root.logoC3, heroMa.containsMouse ? 0.85 : 0.6)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)

                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // Tile 2: Top-Right (палитра matugen №2)
                        Rectangle {
                            width: 31
                            height: 31
                            radius: Theme.isWP ? 0 : 7
                            color: Theme.alpha(root.logoC1, heroMa.containsMouse ? 0.95 : 0.75)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)

                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // Tile 3: Bottom-Left (hero — палитра matugen №1 = акцент)
                        Rectangle {
                            id: heroLiveTile
                            width: 31
                            height: 31
                            radius: Theme.isWP ? 0 : 7
                            color: Theme.alpha(root.logoC0, heroMa.containsMouse ? 0.95 : 0.85)
                            border.width: 1
                            border.color: "#ffffff"

                            // Gentle pulsing breath animation
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.78; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf009"
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                color: "#ffffff"
                            }
                        }

                        // Tile 4: Bottom-Right (палитра matugen №3)
                        Rectangle {
                            width: 31
                            height: 31
                            radius: Theme.isWP ? 0 : 7
                            color: Theme.alpha(root.logoC2, heroMa.containsMouse ? 0.9 : 0.65)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)

                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                // ── Brand Details & Badges ──
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - logoBox.width - 20
                    spacing: 4

                    Row {
                        spacing: 10
                        Text {
                            text: "METRO SHELL"
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.5
                            color: Theme.text
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: verTxt.width + 18
                            height: 20
                            radius: 10
                            color: Theme.alpha(Theme.accent, 0.22)
                            border.width: 1
                            border.color: Theme.accent

                            Text {
                                id: verTxt
                                anchors.centerIn: parent
                                text: "v0.32"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.accent
                            }
                        }
                    }

                    Text {
                        text: "Живые плитки и акриловое стекло для Hyprland"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }

                    Row {
                        spacing: 6
                        Item { width: 1; height: 2 }

                        Rectangle {
                            width: qsBadgeTxt.width + 18
                            height: 18
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Theme.stroke

                            Text {
                                id: qsBadgeTxt
                                anchors.centerIn: parent
                                text: "Quickshell 0.3.1"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }

                        Rectangle {
                            width: hlBadgeTxt.width + 18
                            height: 18
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Theme.stroke

                            Text {
                                id: hlBadgeTxt
                                anchors.centerIn: parent
                                text: "Hyprland 0.56.2"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }

                        Rectangle {
                            width: sessionBadgeTxt.width + 18
                            height: 18
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Theme.stroke

                            Text {
                                id: sessionBadgeTxt
                                anchors.centerIn: parent
                                text: "Session 32"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: heroMa
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        Text {
            text: I18n.t("system")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: root.sysList

            Rectangle {
                id: infoRowRoot
                required property var modelData
                width: col.width
                height: 44
                radius: 8
                color: rowMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: rowMa.containsMouse ? Theme.alpha(Theme.accent, 0.35) : Theme.stroke
                scale: rowMa.pressed ? 0.98 : (rowMa.containsMouse ? 1.008 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: infoRowRoot.modelData.glyph
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.accent
                        scale: rowMa.containsMouse ? 1.15 : 1.0
                        width: 18

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: infoRowRoot.modelData.k
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.textDim
                        width: 160
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 210
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: infoRowRoot.modelData.val
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    color: Theme.text
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }

        Item { width: 1; height: 4 }

        // System updates card
        Text {
            text: I18n.t("updates_check")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Rectangle {
            width: parent.width
            height: 56
            radius: 8
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: root.checkingUpdates ? "\uf021" : "\uf019"
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: Theme.accent

                    NumberAnimation on rotation {
                        running: root.checkingUpdates
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }

                Text { text: I18n.t("updates_count"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textDim }
                Text {
                    text: root.checkingUpdates ? I18n.t("loading") : root.updateCount
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: (root.updateCount !== "0" && root.updateCount !== "—") ? Theme.lime : Theme.text
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: checkBtnTxt.width + 18
                    height: 32
                    radius: 6
                    color: checkMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08)
                    scale: checkMa.pressed ? 0.94 : (checkMa.containsMouse ? 1.03 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text {
                        id: checkBtnTxt
                        anchors.centerIn: parent
                        text: I18n.t("check_updates")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.text
                    }

                    MouseArea {
                        id: checkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.checkUpdates()
                    }
                }

                Rectangle {
                    visible: root.updateCount !== "0" && root.updateCount !== "—"
                    width: upBtnTxt.width + 18
                    height: 32
                    radius: 6
                    color: Theme.alpha(Theme.accent, upMa.pressed ? 0.95 : 0.8)
                    scale: upMa.pressed ? 0.94 : (upMa.containsMouse ? 1.03 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text {
                        id: upBtnTxt
                        anchors.centerIn: parent
                        text: I18n.t("install_updates")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#fff"
                    }

                    MouseArea {
                        id: upMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchUpdater()
                    }
                }
            }
        }

        Item { width: 1; height: 4 }

        Text {
            text: "SHELL"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("about_footer")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textDim
        }
    }
}

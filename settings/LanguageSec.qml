import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property string currentSysLocale: "ru_RU.UTF-8"
    property var availableLocales: ["en_US.UTF-8", "ru_RU.UTF-8"]
    property string selectedLocale: "en_US.UTF-8"
    property string statusMsg: ""

    function refresh() {
        pLocales.command = ["sh", "-c", "locale -a 2>/dev/null | grep -iE 'utf-?8' | sort -u"]
        pLocales.running = true
        pCurLocale.command = ["sh", "-c", "grep -E '^LANG=' ~/.config/locale.conf 2>/dev/null | cut -d= -f2 || echo \"$LANG\""]
        pCurLocale.running = true
    }

    Component.onCompleted: refresh()

    Process {
        id: pLocales
        stdout: SplitParser {
            onRead: data => {
                const item = data.trim()
                if (item && root.availableLocales.indexOf(item) === -1) {
                    const norm = item.replace(/utf8/i, "UTF-8")
                    if (root.availableLocales.indexOf(norm) === -1)
                        root.availableLocales = root.availableLocales.concat([norm])
                }
            }
        }
        onRunningChanged: if (running) root.availableLocales = ["en_US.UTF-8", "ru_RU.UTF-8"]
    }

    Process {
        id: pCurLocale
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t) {
                    root.currentSysLocale = t
                    root.selectedLocale = t
                }
            }
        }
    }

    function applySystemLocale(loc) {
        root.selectedLocale = loc
        const cmd = "mkdir -p $HOME/.config $HOME/.config/environment.d; " +
            "printf 'LANG=" + loc + "\\n' > $HOME/.config/locale.conf; " +
            "printf 'LANG=" + loc + "\\n' > $HOME/.config/environment.d/10-locale.conf; " +
            "systemctl --user import-environment LANG LC_ALL 2>/dev/null || true; " +
            "localectl set-locale LANG=" + loc + " 2>/dev/null || true"
        root.win.run(cmd)
        root.currentSysLocale = loc
        root.statusMsg = I18n.t("system_lang_applied")
        statusTimer.restart()
    }

    Timer {
        id: statusTimer
        interval: 4000
        onTriggered: root.statusMsg = ""
    }

    Column {
        id: col
        width: root.width
        spacing: 12

        // ─── Язык шелла ───
        Text {
            text: I18n.t("shell_lang_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("shell_lang_sub")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }

        Row {
            spacing: 10

            Rectangle {
                width: 140
                height: 48
                radius: 8
                color: I18n.lang === "en" ? Theme.alpha(Theme.accent, 0.9) : (enMa.containsMouse ? Theme.glassHover : Theme.glass)
                border.width: 1
                border.color: I18n.lang === "en" ? Theme.accent : Theme.stroke

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.lang === "en" ? "\uf00c" : "\uf0ac"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: I18n.lang === "en" ? "#fff" : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("lang_en")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: I18n.lang === "en" ? Font.DemiBold : Font.Normal
                        color: I18n.lang === "en" ? "#fff" : Theme.text
                    }
                }

                MouseArea {
                    id: enMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: I18n.setLanguage("en")
                }
            }

            Rectangle {
                width: 140
                height: 48
                radius: 8
                color: I18n.lang === "ru" ? Theme.alpha(Theme.accent, 0.9) : (ruMa.containsMouse ? Theme.glassHover : Theme.glass)
                border.width: 1
                border.color: I18n.lang === "ru" ? Theme.accent : Theme.stroke

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.lang === "ru" ? "\uf00c" : "\uf0ac"
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: I18n.lang === "ru" ? "#fff" : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("lang_ru")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: I18n.lang === "ru" ? Font.DemiBold : Font.Normal
                        color: I18n.lang === "ru" ? "#fff" : Theme.text
                    }
                }

                MouseArea {
                    id: ruMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: I18n.setLanguage("ru")
                }
            }
        }

        Item {
            width: 1
            height: 14
        }

        // ─── Системный язык ───
        Text {
            text: I18n.t("system_lang_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("system_lang_sub")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }

        Rectangle {
            width: parent.width
            height: 54
            radius: 8
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf108"
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: Theme.accent
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: I18n.t("current_locale")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                    Text {
                        text: root.currentSysLocale
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }
            }
        }

        KitCombo {
            label: I18n.t("system_lang_title")
            value: root.selectedLocale
            options: root.availableLocales
            onPicked: opt => {
                root.applySystemLocale(opt)
            }
        }

        Text {
            visible: root.statusMsg !== ""
            text: root.statusMsg
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.lime
        }

        Text {
            text: I18n.t("system_lang_hint")
            width: parent.width
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: win

    title: "настройки"
    color: "transparent"
    visible: true
    implicitWidth: 1080
    implicitHeight: 700
    minimumSize: Qt.size(880, 540)

    readonly property var sections: [
        { label: "персонализация", glyph: "\uf1fc", file: "Personalization.qml", sub: "обои, акцент, иконки" },
        { label: "сеть", glyph: "\uf1eb", file: "NetworkSec.qml", sub: "wi-fi и bluetooth" },
        { label: "звук", glyph: "\uf028", file: "SoundSec.qml", sub: "устройства и громкость" },
        { label: "дисплей", glyph: "\uf26c", file: "DisplaySec.qml", sub: "мониторы и режимы" },
        { label: "питание", glyph: "\uf240", file: "PowerSec.qml", sub: "профили и батарея" },
        { label: "виджеты", glyph: "\uf009", file: "WidgetsSec.qml", sub: "сетка metro-шелла" },
        { label: "о системе", glyph: "\uf109", file: "AboutSec.qml", sub: "железо и софт" }
    ]

    property int sectionId: Quickshell.env("METRO_SETTINGS_SECTION") ? parseInt(Quickshell.env("METRO_SETTINGS_SECTION")) : 0

    // однострочный запуск команды
    function run(cmd) {
        if (pRun.running)
            pRun.running = false
        pRun.command = ["sh", "-c", "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; " + cmd]
        pRun.running = true
    }

    Process {
        id: pRun
        command: ["true"]
    }

    // модалка ввода текста (пароль wi-fi)
    property var askCb: null
    property string askHeader: ""

    function askText(header, placeholder, cb) {
        askHeader = header
        askPlaceholder = placeholder
        askCb = cb
        input.text = ""
        modal.visible = true
        input.forceActiveFocus()
    }

    property string askPlaceholder: ""

    Rectangle {
        anchors.fill: parent
        radius: Theme.panelRadius
        color: Theme.glassDeep
        border.width: 1
        border.color: Theme.stroke
        clip: true

        Row {
            anchors.fill: parent

            // ─── рельса навигации ───
            Rectangle {
                width: 264
                height: parent.height
                color: "transparent"

                Column {
                    anchors.fill: parent
                    anchors.margins: 18

                    Item {
                        width: parent.width
                        height: 64

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: "настройки"
                                font.family: Theme.fontFamily
                                font.pixelSize: 24
                                font.weight: Font.Light
                                color: Theme.text
                            }
                            Rectangle {
                                width: 30
                                height: 3
                                radius: 2
                                color: Theme.accent
                            }
                        }

                        // крестик — закрыть приложение
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: 15
                            color: closeMa.containsMouse || closeMa.pressed ? Theme.alpha(Theme.red, closeMa.pressed ? 0.95 : 0.75) : Qt.rgba(1, 1, 1, 0.08)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                color: Theme.text
                            }

                            MouseArea {
                                id: closeMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 14
                    }

                    Repeater {
                        model: win.sections

                        Rectangle {
                            width: navList.width
                            height: 44
                            radius: 8
                            color: win.sectionId === index ? Theme.glassHover : (navMa.containsMouse ? Theme.glass : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            // акцентная полоска активного пункта
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 22
                                radius: 2
                                color: Theme.accent
                                opacity: win.sectionId === index ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 140
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.glyph
                                    font.family: Theme.iconFont
                                    font.pixelSize: 15
                                    color: win.sectionId === index ? Theme.accent : Theme.textDim
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: win.sectionId === index ? Font.DemiBold : Font.Normal
                                    color: win.sectionId === index ? Theme.text : Theme.textDim
                                }
                            }

                            MouseArea {
                                id: navMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.sectionId = index
                            }
                        }
                    }

                    Item {
                        id: navList

                        width: parent.width
                        height: 0
                    }

                    Item {
                        width: parent.width
                        height: parent.height
                    }

                    Text {
                        text: "metro · quickshell"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        color: Theme.textDim
                    }
                }
            }

            // разделитель
            Rectangle {
                width: 1
                height: parent.height
                color: Theme.stroke
            }

            // ─── контент ───
            Item {
                width: parent.width - 265
                height: parent.height

                Column {
                    id: headCol

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 24
                    }

                    Text {
                        text: win.sections[win.sectionId].label
                        font.family: Theme.fontFamily
                        font.pixelSize: 26
                        font.weight: Font.Light
                        color: Theme.text
                    }
                    Text {
                        text: win.sections[win.sectionId].sub
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                    Item {
                        width: 1
                        height: 8
                    }
                }

                Loader {
                    id: content

                    anchors {
                        top: headCol.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 24
                        rightMargin: 24
                        bottomMargin: 20
                    }
                    source: win.sections[win.sectionId].file
                    onLoaded: {
                        item.win = win
                        if (item.refresh !== undefined)
                            item.refresh()
                    }
                }
            }
        }

        // клик по разделу → перезагрузка секции
        Connections {
            target: win
            function onSectionIdChanged() {
                content.source = ""
                content.source = win.sections[win.sectionId].file
            }
        }
    }

    // ─── модалка ввода ───
    Rectangle {
        id: modal

        anchors.fill: parent
        radius: Theme.panelRadius
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: false

        Rectangle {
            width: 380
            height: headModal.height + bodyModal.height + 20
            radius: Theme.panelRadius
            color: Theme.glassDeep
            border.width: 1
            border.color: Theme.stroke
            anchors.centerIn: parent

            Column {
                id: headModal

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 18
                }
                spacing: 4

                Text {
                    text: win.askHeader
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    text: "введи значение и нажми «ок»"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }
            }

            Column {
                id: bodyModal

                anchors {
                    top: headModal.bottom
                    left: parent.left
                    right: parent.right
                    margins: 18
                }
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: input.activeFocus ? Theme.accent : Theme.stroke

                    TextInput {
                        id: input

                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.text
                        echoMode: win.askPlaceholder === "пароль" ? TextInput.Password : TextInput.Normal
                        clip: true
                        onAccepted: okBtn.clicked()
                    }

                    Text {
                        visible: input.text === ""
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: win.askPlaceholder
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.alpha(Theme.text, 0.35)
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    Rectangle {
                        width: 92
                        height: 34
                        radius: 8
                        color: Theme.glass

                        Text {
                            anchors.centerIn: parent
                            text: "отмена"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.askCb = null
                                modal.visible = false
                            }
                        }
                    }

                    Rectangle {
                        id: okBtn

                        width: 110
                        height: 34
                        radius: 8
                        color: Theme.alpha(Theme.accent, 0.92)

                        Text {
                            anchors.centerIn: parent
                            text: "подключить"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: "#fff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modal.visible = false
                                if (win.askCb)
                                    win.askCb(input.text)
                                win.askCb = null
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (modal.visible) {
                win.askCb = null
                modal.visible = false
            } else {
                Qt.quit()
            }
        }
    }
}

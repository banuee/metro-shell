import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: win

    title: I18n.t("settings")
    color: "transparent"
    visible: true
    implicitWidth: 1120
    implicitHeight: 740
    minimumSize: Qt.size(920, 580)

    readonly property var sections: [
        { label: I18n.t("personalization"), glyph: "\uf1fc", file: "Personalization.qml", sub: I18n.t("personalization_sub") },
        { label: I18n.t("network"), glyph: "\uf1eb", file: "NetworkSec.qml", sub: I18n.t("network_sub") },
        { label: I18n.t("keyboard_input"), glyph: "\uf11c", file: "KeyboardSec.qml", sub: I18n.t("keyboard_sub") },
        { label: I18n.t("sound_sec"), glyph: "\uf028", file: "SoundSec.qml", sub: I18n.t("sound_sub") },
        { label: I18n.t("display"), glyph: "\uf26c", file: "DisplaySec.qml", sub: I18n.t("display_sub") },
        { label: I18n.t("window_manager"), glyph: "\uf2d0", file: "WindowManagerSec.qml", sub: I18n.t("window_manager_sub") },
        { label: I18n.t("default_apps"), glyph: "\uf085", file: "DefaultAppsSec.qml", sub: I18n.t("default_apps_sub") },
        { label: I18n.t("notifications_sec"), glyph: "\uf0f3", file: "NotificationsSec.qml", sub: I18n.t("notifications_sub") },
        { label: I18n.t("power_sec"), glyph: "\uf240", file: "PowerSec.qml", sub: I18n.t("power_sub") },
        { label: I18n.t("widgets"), glyph: "\uf009", file: "WidgetsSec.qml", sub: I18n.t("widgets_sub") },
        { label: I18n.t("language"), glyph: "\uf1ab", file: "LanguageSec.qml", sub: I18n.t("language_sub") },
        { label: I18n.t("about"), glyph: "\uf109", file: "AboutSec.qml", sub: I18n.t("about_sub") }
    ]

    property int sectionId: Quickshell.env("METRO_SETTINGS_SECTION") ? parseInt(Quickshell.env("METRO_SETTINGS_SECTION")) : 0

    // Run command in shell
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

    // Modal text input
    property var askCb: null
    property string askHeader: ""
    property string askPlaceholder: ""
    property bool modalOpen: false

    function askText(header, placeholder, cb) {
        askHeader = header
        askPlaceholder = placeholder
        askCb = cb
        input.text = ""
        modalOpen = true
        input.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.panelRadius
        color: Theme.glassDeep
        border.width: 1
        border.color: Theme.stroke
        clip: true

        Row {
            anchors.fill: parent

            // ─── Navigation rail ───
            Rectangle {
                width: 270
                height: parent.height
                color: "transparent"

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    // Top Header
                    Item {
                        width: parent.width
                        height: 52

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: I18n.t("settings")
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.Light
                                color: Theme.text
                            }
                            Rectangle {
                                width: 28
                                height: 3
                                radius: 2
                                color: Theme.accent
                            }
                        }

                        // Close button
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: closeMa.containsMouse || closeMa.pressed ? Theme.alpha(Theme.red, closeMa.pressed ? 0.95 : 0.75) : Qt.rgba(1, 1, 1, 0.08)
                            scale: closeMa.pressed ? 0.88 : (closeMa.containsMouse ? 1.08 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
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

                    // Scrollable navigation list
                    Flickable {
                        id: navFlick
                        width: parent.width
                        height: parent.height - 52 - 30
                        contentHeight: navCol.height + 8
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Item {
                            id: navCol
                            width: navFlick.width
                            height: win.sections.length * 44

                            // Плавный скользящий индикатор активного раздела
                            Rectangle {
                                id: activeNavPill
                                width: navCol.width
                                height: 40
                                radius: 8
                                color: Theme.glassHover
                                border.width: 1
                                border.color: Theme.alpha(Theme.accent, 0.45)
                                y: win.sectionId * 44
                                z: 0

                                Behavior on y {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                // Акцентная полоска
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 20
                                    radius: 2
                                    color: Theme.accent
                                }
                            }

                            Repeater {
                                model: win.sections

                                Rectangle {
                                    id: navItemRoot
                                    required property var modelData
                                    required property int index

                                    width: navCol.width
                                    height: 40
                                    y: navItemRoot.index * 44
                                    radius: 8
                                    color: (win.sectionId === navItemRoot.index) ? "transparent" : (navMa.containsMouse ? Theme.glass : "transparent")
                                    scale: navMa.pressed ? 0.96 : (navMa.containsMouse ? 1.01 : 1.0)
                                    z: 1

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        spacing: 10

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: navItemRoot.modelData.glyph
                                            font.family: Theme.iconFont
                                            font.pixelSize: 14
                                            color: win.sectionId === navItemRoot.index ? Theme.accent : Theme.textDim
                                            scale: win.sectionId === navItemRoot.index ? 1.15 : (navMa.containsMouse ? 1.08 : 1.0)
                                            width: 18

                                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: navItemRoot.modelData.label
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: win.sectionId === navItemRoot.index ? Font.DemiBold : Font.Normal
                                            color: win.sectionId === navItemRoot.index ? Theme.text : Theme.textDim
                                            elide: Text.ElideRight
                                            width: navItemRoot.width - 48

                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }

                                    MouseArea {
                                        id: navMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.sectionId = navItemRoot.index
                                    }
                                }
                            }
                        }
                    }

                    // Footer
                    Text {
                        text: "metro · quickshell"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: Theme.textDim
                    }
                }
            }

            // Divider
            Rectangle {
                width: 1
                height: parent.height
                color: Theme.stroke
            }

            // ─── Content ───
            Item {
                width: parent.width - 271
                height: parent.height

                Column {
                    id: headCol
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 22
                    }
                    spacing: 2
                    transform: Translate {
                        id: headSlide
                        x: 0
                    }

                    Text {
                        text: win.sections[win.sectionId].label
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
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
                        height: 6
                    }
                }

                Loader {
                    id: content
                    anchors {
                        top: headCol.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 22
                        rightMargin: 22
                        bottomMargin: 16
                    }
                    source: win.sections[win.sectionId].file
                    transform: Translate {
                        id: pageSlide
                        x: 0
                    }
                    onLoaded: {
                        item.win = win
                        if (item.refresh !== undefined)
                            item.refresh()
                    }
                }

                // Плавная анимация смены раздела (Turnstile Slide & Fade)
                ParallelAnimation {
                    id: pageInAnim

                    NumberAnimation {
                        target: content
                        property: "opacity"
                        from: 0.2
                        to: 1.0
                        duration: 220
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        target: pageSlide
                        property: "x"
                        from: 24
                        to: 0
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: headSlide
                        property: "x"
                        from: 14
                        to: 0
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Connections {
            target: win
            function onSectionIdChanged() {
                content.source = ""
                content.source = win.sections[win.sectionId].file
                pageInAnim.restart()
            }
        }
    }

    // ─── Modal Input ───
    Rectangle {
        id: modal
        anchors.fill: parent
        radius: Theme.panelRadius
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: opacity > 0.01
        opacity: win.modalOpen ? 1.0 : 0.0
        z: 999

        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            id: modalDialog
            width: 400
            height: headModal.height + bodyModal.height + 24
            radius: Theme.panelRadius
            color: Theme.glassDeep
            border.width: 1
            border.color: Theme.stroke
            anchors.centerIn: parent
            scale: win.modalOpen ? 1.0 : 0.90

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

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
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    text: I18n.t("enter_value")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
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
                spacing: 14

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: input.activeFocus ? Theme.accent : Theme.stroke

                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.text
                        echoMode: (win.askPlaceholder === "пароль" || win.askPlaceholder === "password") ? TextInput.Password : TextInput.Normal
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
                        color: cancelMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: cancelMa.pressed ? 0.94 : (cancelMa.containsMouse ? 1.02 : 1.0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: I18n.t("cancel")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDim
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.askCb = null
                                win.modalOpen = false
                            }
                        }
                    }

                    Rectangle {
                        id: okBtn
                        width: 110
                        height: 34
                        radius: 8
                        color: Theme.alpha(Theme.accent, okMa.pressed ? 0.98 : 0.90)
                        scale: okMa.pressed ? 0.94 : (okMa.containsMouse ? 1.02 : 1.0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: I18n.t("apply")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: "#fff"
                        }

                        MouseArea {
                            id: okMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.modalOpen = false
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
            if (win.modalOpen) {
                win.askCb = null
                win.modalOpen = false
            } else {
                Qt.quit()
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win

    // Sub-tab selection: 0=layouts, 1=hotkeys, 2=mouse_touchpad
    property int currentTab: 0

    // Input state
    property var inputData: ({
        "kb_layout": "us,ru",
        "kb_options": "grp:alt_shift_toggle",
        "numlock_by_default": false,
        "repeat_rate": 25,
        "repeat_delay": 600,
        "follow_mouse": 1,
        "sensitivity": 0.0,
        "accel_profile": "flat",
        "natural_scroll": false,
        "left_handed": false,
        "touchpad": {
            "disable_while_typing": true,
            "tap_to_click": true,
            "tap_and_drag": true,
            "drag_lock": true,
            "natural_scroll": false,
            "middle_button_emulation": false
        }
    })

    property var layoutList: ["us", "ru"]
    property string currentSwitchOpt: "grp:alt_shift_toggle"
    property int repeatRate: 25
    property int repeatDelay: 600
    property bool numlock: false

    // Keybindings state
    property var allBinds: []
    property string searchFilter: ""
    property string selectedCategory: "all"
    property bool addBindOpen: false
    property string newBindMod: "SUPER"
    property string newBindKey: ""
    property string newBindCmd: ""

    // Touchpad & Mouse live properties
    property real mouseSensitivity: 0.0
    property string mouseAccel: "flat"
    property bool mouseNatScroll: false
    property bool mouseLeftHand: false
    property bool padTapClick: true
    property bool padNatScroll: false
    property bool padTypingDisable: true
    property bool padTapDrag: true
    property bool padDragLock: true
    property bool padMiddleEmul: false

    property string statusMsg: ""

    // Экранирование для подстановки внутрь ДВОЙНЫХ кавычек sh.
    // НЕ использовать результат внутри '...'!
    function esc(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`")
    }

    function refresh() {
        pGetInput.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py input get"]
        pGetInput.running = true

        pGetBinds.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py binds get"]
        pGetBinds.running = true
    }

    function applyInput() {
        statusMsg = I18n.t("loading")
        const payload = {
            "kb_layout": layoutList.join(","),
            "kb_options": currentSwitchOpt,
            "numlock_by_default": numlock,
            "repeat_rate": repeatRate,
            "repeat_delay": repeatDelay,
            "sensitivity": mouseSensitivity,
            "accel_profile": mouseAccel,
            "natural_scroll": mouseNatScroll,
            "left_handed": mouseLeftHand,
            "touchpad": {
                "tap_to_click": padTapClick,
                "natural_scroll": padNatScroll,
                "disable_while_typing": padTypingDisable,
                "tap_and_drag": padTapDrag,
                "drag_lock": padDragLock,
                "middle_button_emulation": padMiddleEmul
            }
        }
        const jsonStr = JSON.stringify(payload).replace(/"/g, '\\"')
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py input set \"" + jsonStr + "\"")
        statusTimer.restart()
    }

    function addLayout(code) {
        if (layoutList.indexOf(code) < 0) {
            layoutList = layoutList.concat([code])
        }
    }

    function removeLayout(code) {
        if (layoutList.length > 1) {
            layoutList = layoutList.filter(c => c !== code)
        }
    }

    function createNewBind() {
        if (!newBindKey.trim() || !newBindCmd.trim()) return
        const fullKey = (newBindMod.trim() ? newBindMod.trim() + " + " : "") + newBindKey.trim()
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py binds add \"" + esc(fullKey) + "\" \"" + esc(newBindCmd.trim()) + "\"")
        addBindOpen = false
        newBindKey = ""
        newBindCmd = ""
        statusTimer.restart()
    }

    function removeBind(lineStr) {
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py binds del \"" + esc(lineStr) + "\"")
        statusTimer.restart()
    }

    Timer { id: statusTimer; interval: 600; onTriggered: { refresh(); statusMsg = I18n.t("success") } }

    Process {
        id: pGetInput
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    root.inputData = res
                    if (res.kb_layout) root.layoutList = res.kb_layout.split(",")
                    if (res.kb_options) root.currentSwitchOpt = res.kb_options
                    root.repeatRate = res.repeat_rate !== undefined ? res.repeat_rate : 25
                    root.repeatDelay = res.repeat_delay !== undefined ? res.repeat_delay : 600
                    root.numlock = !!res.numlock_by_default
                    root.mouseSensitivity = res.sensitivity !== undefined ? res.sensitivity : 0.0
                    root.mouseAccel = res.accel_profile || "flat"
                    root.mouseNatScroll = !!res.natural_scroll
                    root.mouseLeftHand = !!res.left_handed
                    if (res.touchpad) {
                        root.padTapClick = res.touchpad.tap_to_click !== false
                        root.padNatScroll = !!res.touchpad.natural_scroll
                        root.padTypingDisable = res.touchpad.disable_while_typing !== false
                        root.padTapDrag = res.touchpad.tap_and_drag !== false
                        root.padDragLock = res.touchpad.drag_lock !== false
                        root.padMiddleEmul = !!res.touchpad.middle_button_emulation
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pGetBinds
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allBinds = JSON.parse(text)
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: refresh()

    Column {
        id: col
        width: root.width
        spacing: 14

        // Section Title & Description
        Text {
            text: I18n.t("keyboard_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("keyboard_desc")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }

        // Sub-tabs navigation bar
        Row {
            spacing: 8

            Rectangle {
                width: tab0Txt.width + 24
                height: 32
                radius: 6
                color: root.currentTab === 0 ? Theme.alpha(Theme.accent, 0.85) : Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf11c"; font.family: Theme.iconFont; font.pixelSize: 13; color: "#fff" }
                    Text { id: tab0Txt; text: I18n.t("layouts_tab"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.currentTab === 0 ? Font.DemiBold : Font.Normal; color: "#fff" }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = 0
                }
            }

            Rectangle {
                width: tab1Txt.width + 24
                height: 32
                radius: 6
                color: root.currentTab === 1 ? Theme.alpha(Theme.accent, 0.85) : Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf085"; font.family: Theme.iconFont; font.pixelSize: 13; color: "#fff" }
                    Text { id: tab1Txt; text: I18n.t("hotkeys_tab"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.currentTab === 1 ? Font.DemiBold : Font.Normal; color: "#fff" }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = 1
                }
            }

            Rectangle {
                width: tab2Txt.width + 24
                height: 32
                radius: 6
                color: root.currentTab === 2 ? Theme.alpha(Theme.accent, 0.85) : Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "\uf245"; font.family: Theme.iconFont; font.pixelSize: 13; color: "#fff" }
                    Text { id: tab2Txt; text: I18n.t("touchpad_tab"); font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.currentTab === 2 ? Font.DemiBold : Font.Normal; color: "#fff" }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = 2
                }
            }
        }

        Item { width: 1; height: 4 }

        // ═════════════════════════════════════════════════════════════
        // TAB 0: LAYOUTS & REPEAT SETTINGS
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 0
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("layout_manage")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Text {
                text: I18n.t("layout_manage_desc")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.text
            }

            // Current active layouts chips
            Row {
                spacing: 8

                Repeater {
                    model: root.layoutList

                    Rectangle {
                        id: lChip
                        required property string modelData
                        required property int index
                        width: lChipRow.width + 20
                        height: 34
                        radius: 6
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.accent

                        Row {
                            id: lChipRow
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 4
                                color: Theme.alpha(Theme.accent, 0.3)
                                anchors.verticalCenter: parent.verticalCenter
                                Text { anchors.centerIn: parent; text: String(lChip.index + 1); font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.accent }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: lChip.modelData.toUpperCase()
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                visible: root.layoutList.length > 1
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf00d"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: delLMa.containsMouse ? Theme.red : Theme.textDim
                            }
                        }

                        MouseArea {
                            id: delLMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.layoutList.length > 1) {
                                    root.removeLayout(lChip.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Quick add layout chips
            Row {
                spacing: 6
                Text { text: I18n.t("add_layout") + ":"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }

                Repeater {
                    model: ["us", "ru", "de", "fr", "es", "uk", "kz", "pl", "it", "tr", "pt"]

                    Rectangle {
                        required property string modelData
                        visible: root.layoutList.indexOf(modelData) < 0
                        width: addLText.width + 16
                        height: 28
                        radius: 6
                        color: addLMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.06)

                        Text {
                            id: addLText
                            anchors.centerIn: parent
                            text: "+" + modelData.toUpperCase()
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.text
                        }

                        MouseArea {
                            id: addLMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addLayout(modelData)
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            // Switch shortcut combo
            Text {
                text: I18n.t("switch_shortcut")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                Repeater {
                    model: [
                        { id: "grp:alt_shift_toggle", label: "Alt + Shift" },
                        { id: "grp:ctrl_shift_toggle", label: "Ctrl + Shift" },
                        { id: "grp:win_space_toggle", label: "Win (Super) + Space" },
                        { id: "grp:caps_toggle", label: "Caps Lock" },
                        { id: "grp:ctrl_alt_toggle", label: "Ctrl + Alt" },
                        { id: "grp:shift_caps_toggle", label: "Shift + Caps Lock" }
                    ]

                    Rectangle {
                        id: swChip
                        required property var modelData
                        width: (col.width - 10) / 2
                        height: 44
                        radius: 8
                        color: root.currentSwitchOpt === swChip.modelData.id ? Theme.glassHover : Theme.glass
                        border.width: 1
                        border.color: root.currentSwitchOpt === swChip.modelData.id ? Theme.accent : Theme.stroke

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: "transparent"
                                border.width: 2
                                border.color: root.currentSwitchOpt === swChip.modelData.id ? Theme.accent : Qt.rgba(1, 1, 1, 0.3)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.accent
                                    anchors.centerIn: parent
                                    visible: root.currentSwitchOpt === swChip.modelData.id
                                }
                            }

                            Text {
                                text: swChip.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: root.currentSwitchOpt === swChip.modelData.id ? Font.DemiBold : Font.Normal
                                color: Theme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentSwitchOpt = swChip.modelData.id
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            // Repeat settings & Numlock
            Text {
                text: I18n.t("repeat_settings")
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

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("repeat_rate")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: Theme.glass
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.repeatRate = Math.max(10, root.repeatRate - 5) }
                    }
                    Text { text: String(root.repeatRate); font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.accent; width: 36; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: Theme.glass
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.repeatRate = Math.min(80, root.repeatRate + 5) }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("repeat_delay")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: Theme.glass
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.repeatDelay = Math.max(150, root.repeatDelay - 50) }
                    }
                    Text { text: root.repeatDelay + " ms"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 64; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: Theme.glass
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.repeatDelay = Math.min(1000, root.repeatDelay + 50) }
                    }
                }
            }

            // Numlock toggle
            Rectangle {
                width: parent.width
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("numlock_title")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                KitToggle {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.numlock
                    onToggled: c => root.numlock = c
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.statusMsg !== ""
                    text: root.statusMsg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.lime
                }

                Rectangle {
                    width: applyKbTxt.width + 24
                    height: 36
                    radius: 8
                    color: Theme.alpha(Theme.accent, applyKbMa.pressed ? 0.95 : 0.8)

                    Text {
                        id: applyKbTxt
                        anchors.centerIn: parent
                        text: I18n.t("apply_keyboard")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#fff"
                    }

                    MouseArea {
                        id: applyKbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyInput()
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 1: HOTKEYS CATALOG & ADD/DELETE
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 1
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("hotkeys_catalog")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Text {
                text: I18n.t("hotkeys_catalog_desc")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.text
            }

            // Search & Add Hotkey Bar
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: parent.width - addBtnBox.width - 10
                    height: 36
                    radius: 8
                    color: Theme.glass
                    border.width: 1
                    border.color: bindSearchIn.activeFocus ? Theme.accent : Theme.stroke

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: "\uf002"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: Theme.textDim
                        }

                        TextInput {
                            id: bindSearchIn
                            width: 320
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.text
                            clip: true
                            onTextChanged: root.searchFilter = text.toLowerCase()

                            Text {
                                text: I18n.t("search_hotkeys")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textDim
                                visible: !bindSearchIn.text && !bindSearchIn.activeFocus
                            }
                        }
                    }
                }

                Rectangle {
                    id: addBtnBox
                    width: addBtnTxt.width + 24
                    height: 36
                    radius: 8
                    color: root.addBindOpen ? Theme.glassHover : Theme.alpha(Theme.accent, 0.85)

                    Text {
                        id: addBtnTxt
                        anchors.centerIn: parent
                        text: root.addBindOpen ? I18n.t("cancel") : I18n.t("add_bind")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#fff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addBindOpen = !root.addBindOpen
                    }
                }
            }

            // Add Bind Pop-down Box
            Rectangle {
                visible: root.addBindOpen
                width: parent.width
                height: addFormCol.height + 28
                radius: 8
                color: Qt.rgba(0.08, 0.08, 0.12, 0.95)
                border.width: 1
                border.color: Theme.accent

                Column {
                    id: addFormCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: I18n.t("add_bind_title")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        // Modifier selector
                        Rectangle {
                            width: 140
                            height: 34
                            radius: 6
                            color: Theme.glass
                            border.width: 1
                            border.color: Theme.stroke

                            TextInput {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                text: root.newBindMod
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                                onTextChanged: root.newBindMod = text
                            }
                        }

                        Text { text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }

                        // Key input
                        Rectangle {
                            width: 140
                            height: 34
                            radius: 6
                            color: Theme.glass
                            border.width: 1
                            border.color: keyIn.activeFocus ? Theme.accent : Theme.stroke

                            TextInput {
                                id: keyIn
                                anchors.centerIn: parent
                                width: parent.width - 16
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.text
                                onTextChanged: root.newBindKey = text
                                Text {
                                    text: I18n.t("key_placeholder")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textDim
                                    visible: !keyIn.text && !keyIn.activeFocus
                                }
                            }
                        }
                    }

                    // Command input
                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 6
                        color: Theme.glass
                        border.width: 1
                        border.color: cmdIn.activeFocus ? Theme.accent : Theme.stroke

                        TextInput {
                            id: cmdIn
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: Theme.text
                            onTextChanged: root.newBindCmd = text
                            Text {
                                text: I18n.t("cmd_placeholder")
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textDim
                                visible: !cmdIn.text && !cmdIn.activeFocus
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        width: saveBindTxt.width + 24
                        height: 32
                        radius: 6
                        color: Theme.alpha(Theme.accent, 0.9)

                        Text {
                            id: saveBindTxt
                            anchors.centerIn: parent
                            text: I18n.t("save_bind")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: "#fff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.createNewBind()
                        }
                    }
                }
            }

            // Category Filter Pills
            Row {
                spacing: 6

                Repeater {
                    model: [
                        { id: "all", label: I18n.t("cat_all") },
                        { id: "apps", label: I18n.t("cat_apps") },
                        { id: "window", label: I18n.t("cat_window") },
                        { id: "media", label: I18n.t("cat_media") },
                        { id: "tools", label: I18n.t("cat_tools") },
                        { id: "workspace", label: I18n.t("cat_workspace") },
                        { id: "system", label: I18n.t("cat_system") }
                    ]

                    Rectangle {
                        id: catPill
                        required property var modelData
                        width: catPillTxt.width + 16
                        height: 26
                        radius: 4
                        color: root.selectedCategory === catPill.modelData.id ? Theme.alpha(Theme.accent, 0.85) : Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            id: catPillTxt
                            anchors.centerIn: parent
                            text: catPill.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: root.selectedCategory === catPill.modelData.id ? Font.DemiBold : Font.Normal
                            color: "#fff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedCategory = catPill.modelData.id
                        }
                    }
                }
            }

            // Binds list
            Repeater {
                model: {
                    return root.allBinds.filter(b => {
                        if (root.selectedCategory !== "all" && b.category !== root.selectedCategory) return false
                        if (root.searchFilter) {
                            const q = root.searchFilter
                            const matchCombo = b.combo && b.combo.toLowerCase().indexOf(q) >= 0
                            const matchDesc = b.label && b.label.toLowerCase().indexOf(q) >= 0
                            const matchCmd = b.command && b.command.toLowerCase().indexOf(q) >= 0
                            return matchCombo || matchDesc || matchCmd
                        }
                        return true
                    })
                }

                Rectangle {
                    id: bindCard
                    required property var modelData
                    width: col.width
                    height: 52
                    radius: 8
                    color: Theme.glass

                    // Left: Key combo badge
                    Rectangle {
                        id: comboBadge
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: comboTxt.width + 16
                        height: 28
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.15)

                        Text {
                            id: comboTxt
                            anchors.centerIn: parent
                            text: bindCard.modelData.combo
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.accent
                        }
                    }

                    // Middle: Description and command
                    Column {
                        anchors.left: comboBadge.right
                        anchors.leftMargin: 14
                        anchors.right: delBrdBtn.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: bindCard.modelData.label || bindCard.modelData.command
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: bindCard.modelData.command
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Theme.textDim
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Delete Bind Button
                    Rectangle {
                        id: delBrdBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 6
                        color: delBrdMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\uf2ed"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: delBrdMa.containsMouse ? Theme.red : Theme.textDim
                        }

                        MouseArea {
                            id: delBrdMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeBind(bindCard.modelData.line)
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 2: TOUCHPAD & MOUSE
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 2
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("touchpad_title")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                // Tap to click
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("tap_to_click"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.padTapClick; onToggled: c => root.padTapClick = c }
                }

                // Natural scrolling touchpad
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("natural_scroll_touchpad"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.padNatScroll; onToggled: c => root.padNatScroll = c }
                }

                // Disable while typing
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("disable_while_typing"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.padTypingDisable; onToggled: c => root.padTypingDisable = c }
                }

                // Tap and drag
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("tap_and_drag"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.padTapDrag; onToggled: c => root.padTapDrag = c }
                }

                // Drag lock
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("drag_lock"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.padDragLock; onToggled: c => root.padDragLock = c }
                }

                // Middle button emulation
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("middle_click_emulation"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.padMiddleEmul; onToggled: c => root.padMiddleEmul = c }
                }
            }

            Item { width: 1; height: 4 }

            Text {
                text: I18n.t("mouse_title")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            // Sensitivity slider
            Rectangle {
                width: parent.width
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("sensitivity")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: Theme.glass
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mouseSensitivity = Math.max(-1.0, Math.round((root.mouseSensitivity - 0.1) * 10) / 10) }
                    }
                    Text { text: root.mouseSensitivity.toFixed(1); font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.accent; width: 42; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: Theme.glass
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mouseSensitivity = Math.min(1.0, Math.round((root.mouseSensitivity + 0.1) * 10) / 10) }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                // Natural scroll mouse
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("natural_scroll_mouse"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.mouseNatScroll; onToggled: c => root.mouseNatScroll = c }
                }

                // Left handed
                Rectangle {
                    width: (col.width - 10) / 2; height: 48; radius: 8; color: Theme.glass
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("left_handed"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                    KitToggle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: root.mouseLeftHand; onToggled: c => root.mouseLeftHand = c }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.statusMsg !== ""
                    text: root.statusMsg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.lime
                }

                Rectangle {
                    width: applyPadTxt.width + 24
                    height: 36
                    radius: 8
                    color: Theme.alpha(Theme.accent, applyPadMa.pressed ? 0.95 : 0.8)

                    Text {
                        id: applyPadTxt
                        anchors.centerIn: parent
                        text: I18n.t("apply_keyboard")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#fff"
                    }

                    MouseArea {
                        id: applyPadMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyInput()
                    }
                }
            }
        }
    }
}

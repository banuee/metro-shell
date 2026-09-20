import QtQuick
import Quickshell
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win

    property int gapsIn: 10
    property int gapsOut: 10
    property int rounding: 20
    property int borderSize: 0
    property string layoutMode: "dwindle"
    property bool blurEnabled: true
    property int blurSize: 3
    property int blurPasses: 3
    property bool animEnabled: true
    property real animSpeed: 3.5

    property string statusMsg: ""

    function refresh() {
        pGetWm.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py wm get"]
        pGetWm.running = true
    }

    function applyWm() {
        statusMsg = I18n.t("loading")
        const payload = {
            "gaps_in": gapsIn,
            "gaps_out": gapsOut,
            "rounding": rounding,
            "border_size": borderSize,
            "layout": layoutMode,
            "blur_enabled": blurEnabled,
            "blur_size": blurSize,
            "blur_passes": blurPasses,
            "animations_enabled": animEnabled,
            "animation_speed": animSpeed
        }
        const jsonStr = JSON.stringify(payload).replace(/"/g, '\\"')
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py wm set \"" + jsonStr + "\"")
        statusTimer.restart()
    }

    Timer { id: statusTimer; interval: 800; onTriggered: { refresh(); statusMsg = I18n.t("success") } }

    Process {
        id: pGetWm
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    root.gapsIn = res.gaps_in !== undefined ? res.gaps_in : 10
                    root.gapsOut = res.gaps_out !== undefined ? res.gaps_out : 10
                    root.rounding = res.rounding !== undefined ? res.rounding : 20
                    root.borderSize = res.border_size !== undefined ? res.border_size : 0
                    root.layoutMode = res.layout || "dwindle"
                    root.blurEnabled = res.blur_enabled !== false
                    root.blurSize = res.blur_size !== undefined ? res.blur_size : 3
                    root.blurPasses = res.blur_passes !== undefined ? res.blur_passes : 3
                    root.animEnabled = res.animations_enabled !== false
                    root.animSpeed = res.animation_speed !== undefined ? res.animation_speed : 3.5
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: refresh()

    Column {
        id: col
        width: root.width
        spacing: 14

        Text {
            text: I18n.t("wm_title")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: I18n.t("wm_desc")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }

        // Layout mode (Dwindle / Master)
        Rectangle {
            width: parent.width
            height: 52
            radius: 8
            color: Theme.glass

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("layout_mode")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 84
                    height: 30
                    radius: 6
                    color: root.layoutMode === "dwindle" ? Theme.alpha(Theme.accent, 0.85) : (dwindleMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08))
                    scale: dwindleMa.pressed ? 0.94 : (dwindleMa.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text { anchors.centerIn: parent; text: "Dwindle"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.layoutMode === "dwindle" ? Font.DemiBold : Font.Normal; color: "#fff" }
                    MouseArea { id: dwindleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.layoutMode = "dwindle" }
                }

                Rectangle {
                    width: 84
                    height: 30
                    radius: 6
                    color: root.layoutMode === "master" ? Theme.alpha(Theme.accent, 0.85) : (masterMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08))
                    scale: masterMa.pressed ? 0.94 : (masterMa.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text { anchors.centerIn: parent; text: "Master"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: root.layoutMode === "master" ? Font.DemiBold : Font.Normal; color: "#fff" }
                    MouseArea { id: masterMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.layoutMode = "master" }
                }
            }
        }

        // Gaps section
        Text {
            text: I18n.t("gaps_title")
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

            // Inner Gaps
            Rectangle {
                width: (col.width - 10) / 2
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("gaps_in")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: gInMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: gInMinusMa.pressed ? 0.88 : (gInMinusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: gInMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gapsIn = Math.max(0, root.gapsIn - 2) }
                    }
                    Text { text: root.gapsIn + " px"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 50; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: gInPlusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: gInPlusMa.pressed ? 0.88 : (gInPlusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: gInPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gapsIn = Math.min(40, root.gapsIn + 2) }
                    }
                }
            }

            // Outer Gaps
            Rectangle {
                width: (col.width - 10) / 2
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("gaps_out")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: gOutMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: gOutMinusMa.pressed ? 0.88 : (gOutMinusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: gOutMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gapsOut = Math.max(0, root.gapsOut - 2) }
                    }
                    Text { text: root.gapsOut + " px"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 50; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: gOutPlusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: gOutPlusMa.pressed ? 0.88 : (gOutPlusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: gOutPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gapsOut = Math.min(60, root.gapsOut + 2) }
                    }
                }
            }
        }

        // Rounding & Borders
        Text {
            text: I18n.t("rounding_title")
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

            // Rounding
            Rectangle {
                width: (col.width - 10) / 2
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("rounding")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: roundMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: roundMinusMa.pressed ? 0.88 : (roundMinusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: roundMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.rounding = Math.max(0, root.rounding - 2) }
                    }
                    Text { text: root.rounding + " px"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 50; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: roundPlusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: roundPlusMa.pressed ? 0.88 : (roundPlusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: roundPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.rounding = Math.min(32, root.rounding + 2) }
                    }
                }
            }

            // Border size
            Rectangle {
                width: (col.width - 10) / 2
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("border_size")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: bdrMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: bdrMinusMa.pressed ? 0.88 : (bdrMinusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: bdrMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.borderSize = Math.max(0, root.borderSize - 1) }
                    }
                    Text { text: root.borderSize + " px"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 50; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: bdrPlusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: bdrPlusMa.pressed ? 0.88 : (bdrPlusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: bdrPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.borderSize = Math.min(8, root.borderSize + 1) }
                    }
                }
            }
        }

        // Blur Effects
        Text {
            text: I18n.t("blur_title")
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
                text: I18n.t("blur_enabled")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
            }

            KitToggle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: root.blurEnabled
                onToggled: c => root.blurEnabled = c
            }
        }

        Grid {
            visible: root.blurEnabled
            width: parent.width
            columns: 2
            columnSpacing: 10
            rowSpacing: 8

            // Blur Size
            Rectangle {
                width: (col.width - 10) / 2
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("blur_size")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: bSizeMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: bSizeMinusMa.pressed ? 0.88 : (bSizeMinusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: bSizeMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.blurSize = Math.max(1, root.blurSize - 1) }
                    }
                    Text { text: String(root.blurSize); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 40; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: bSizePlusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: bSizePlusMa.pressed ? 0.88 : (bSizePlusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: bSizePlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.blurSize = Math.min(10, root.blurSize + 1) }
                    }
                }
            }

            // Blur Passes
            Rectangle {
                width: (col.width - 10) / 2
                height: 52
                radius: 8
                color: Theme.glass

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("blur_passes")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 6; color: bPassMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: bPassMinusMa.pressed ? 0.88 : (bPassMinusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: bPassMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.blurPasses = Math.max(1, root.blurPasses - 1) }
                    }
                    Text { text: String(root.blurPasses); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 40; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 30; height: 30; radius: 6; color: bPassPlusMa.containsMouse ? Theme.glassHover : Theme.glass
                        scale: bPassPlusMa.pressed ? 0.88 : (bPassPlusMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                        MouseArea { id: bPassPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.blurPasses = Math.min(5, root.blurPasses + 1) }
                    }
                }
            }
        }

        // Animations
        Text {
            text: I18n.t("animations_title")
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
                text: I18n.t("animations_enabled")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
            }

            KitToggle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: root.animEnabled
                onToggled: c => root.animEnabled = c
            }
        }

        Rectangle {
            visible: root.animEnabled
            width: parent.width
            height: 52
            radius: 8
            color: Theme.glass

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("animation_speed")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 30; height: 30; radius: 6; color: spdMinusMa.containsMouse ? Theme.glassHover : Theme.glass
                    scale: spdMinusMa.pressed ? 0.88 : (spdMinusMa.containsMouse ? 1.08 : 1.0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                    Text { anchors.centerIn: parent; text: "−"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                    MouseArea { id: spdMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.animSpeed = Math.max(1.0, Math.round((root.animSpeed - 0.5) * 10) / 10) }
                }
                Text { text: root.animSpeed.toFixed(1); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accent; width: 40; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 30; height: 30; radius: 6; color: spdPlusMa.containsMouse ? Theme.glassHover : Theme.glass
                    scale: spdPlusMa.pressed ? 0.88 : (spdPlusMa.containsMouse ? 1.08 : 1.0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                    Text { anchors.centerIn: parent; text: "+"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.text }
                    MouseArea { id: spdPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.animSpeed = Math.min(6.0, Math.round((root.animSpeed + 0.5) * 10) / 10) }
                }
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
                width: applyWmTxt.width + 24
                height: 36
                radius: 8
                color: Theme.alpha(Theme.accent, applyWmMa.pressed ? 0.95 : 0.8)
                scale: applyWmMa.pressed ? 0.94 : (applyWmMa.containsMouse ? 1.03 : 1.0)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Text {
                    id: applyWmTxt
                    anchors.centerIn: parent
                    text: I18n.t("apply_wm")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: "#fff"
                }

                MouseArea {
                    id: applyWmMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyWm()
                }
            }
        }
    }
}

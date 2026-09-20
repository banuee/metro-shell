import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win
    property var sinks: []
    property var sources: []
    property real outVol: 0.5
    property bool outMuted: false
    property real inVol: 0.5
    property bool inMuted: false
    property bool playingTest: false

    function refresh() {
        pStatus.command = ["sh", "-c", "wpctl status"]
        pStatus.running = true
        pVol.command = ["sh", "-c", "echo o=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); echo i=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)"]
        pVol.running = true
    }

    function playTestSound() {
        playingTest = true
        win.run("pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || (speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1 &)")
        testTimer.restart()
    }

    Timer { id: delay; interval: 400; onTriggered: refresh() }
    Timer { id: testTimer; interval: 1500; onTriggered: playingTest = false }

    function parseStatus(t) {
        const sinks = [], sources = []
        let top = "", sub = ""
        for (const line of t.split("\n")) {
            if (/^[A-Za-z]/.test(line)) {
                top = line.trim()
                sub = ""
                continue
            }
            if (line.indexOf("─ ") >= 0) {
                sub = line.indexOf("Sinks:") >= 0 ? "sink" : (line.indexOf("Sources:") >= 0 ? "source" : "")
                continue
            }
            const m = line.match(/^\s*[│|]?\s*(\*)?\s*(\d+)\.\s(.*?)\s\[vol:\s*([\d.]+)\]/)
            if (m && top === "Audio") {
                const item = {
                    id: m[2],
                    name: m[3].trim(),
                    def: !!m[1],
                    muted: line.indexOf("[MUTED]") >= 0
                }
                if (sub === "sink")
                    sinks.push(item)
                else if (sub === "source")
                    sources.push(item)
            }
        }
        return {
            sinks: sinks,
            sources: sources
        }
    }

    Process {
        id: pStatus
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.parseStatus(text)
                root.sinks = r.sinks
                root.sources = r.sources
            }
        }
    }

    Process {
        id: pVol
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/o=Volume: ([\d.]+)( MUTED)?/)
                if (m) {
                    root.outVol = parseFloat(m[1])
                    root.outMuted = m[2] !== undefined
                }
                const n = text.match(/i=Volume: ([\d.]+)( MUTED)?/)
                if (n) {
                    root.inVol = parseFloat(n[1])
                    root.inMuted = n[2] !== undefined
                }
            }
        }
    }

    Component {
        id: devRow

        Rectangle {
            id: devRowRoot
            width: parent ? parent.width : 0
            height: 44
            radius: 8
            color: devMa.containsMouse ? Theme.glassHover : Theme.glass
            border.width: 1
            border.color: devRowRoot.modelData.def ? Theme.alpha(Theme.accent, 0.6) : (devMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Theme.stroke)
            scale: devMa.pressed ? 0.97 : (devMa.containsMouse ? 1.01 : 1.0)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

            required property var modelData

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: devRowRoot.modelData.def ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)
                scale: devRowRoot.modelData.def ? 1.3 : 1.0

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: devMa.containsMouse ? 38 : 34
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                text: devRowRoot.modelData.name
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: devRowRoot.modelData.def ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                color: devRowRoot.modelData.def ? Theme.text : Theme.textDim

                Behavior on anchors.leftMargin { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: devMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.win.run("wpctl set-default " + devRowRoot.modelData.id)
                    root.delay.restart()
                }
            }
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 12

        // Output Sound
        Text {
            text: I18n.t("output")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        KitSlider {
            icon: "\uf028"
            value: root.outVol
            muted: root.outMuted
            onChanged: v => {
                root.outVol = v
                root.outMuted = false
                root.win.run("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + v.toFixed(2) + " && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0")
            }
            onTapped: {
                root.win.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                root.delay.restart()
            }
        }

        Repeater {
            model: root.sinks
            delegate: devRow
        }

        // Test Sound Button
        Rectangle {
            width: parent.width
            height: 42
            radius: 8
            color: testSoundMa.containsMouse ? Theme.glassHover : Theme.glass
            border.width: 1
            border.color: root.playingTest ? Theme.accent : (testSoundMa.containsMouse ? Theme.alpha(Theme.accent, 0.6) : Theme.stroke)
            scale: testSoundMa.pressed ? 0.96 : (testSoundMa.containsMouse ? 1.01 : 1.0)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

            SequentialAnimation on color {
                running: root.playingTest
                loops: Animation.Infinite
                ColorAnimation { to: Theme.alpha(Theme.accent, 0.3); duration: 300 }
                ColorAnimation { to: Theme.glass; duration: 300 }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "\uf025"
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: Theme.accent
                    scale: root.playingTest ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                }

                Text {
                    text: root.playingTest ? I18n.t("playing_test") : I18n.t("test_sound")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: root.playingTest ? Theme.accent : Theme.text
                }
            }

            MouseArea {
                id: testSoundMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playTestSound()
            }
        }

        Item { width: 1; height: 6 }

        // Input Sound (Microphone)
        Text {
            text: I18n.t("input")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        KitSlider {
            icon: "\uf130"
            value: root.inVol
            muted: root.inMuted
            onChanged: v => {
                root.inVol = v
                root.inMuted = false
                root.win.run("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ " + v.toFixed(2) + " && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0")
            }
            onTapped: {
                root.win.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
                root.delay.restart()
            }
        }

        Repeater {
            model: root.sources
            delegate: devRow
        }
    }
}

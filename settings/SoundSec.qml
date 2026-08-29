import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds


    property var win
    property var sinks: []
    property var sources: []
    property real outVol: 0.5
    property bool outMuted: false
    property real inVol: 0.5
    property bool inMuted: false

    function refresh() {
        pStatus.command = ["sh", "-c", "wpctl status"]
        pStatus.running = true
        pVol.command = ["sh", "-c", "echo o=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); echo i=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)"]
        pVol.running = true
    }

    Timer {
        id: delay

        interval: 400
        onTriggered: refresh()
    }

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

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            required property var modelData
            property bool isSource: false

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: devRowRoot.modelData.def ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                text: devRowRoot.modelData.name
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                color: devRowRoot.modelData.def ? Theme.text : Theme.textDim
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
        spacing: 10

        Text {
            text: "ВЫВОД"
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

        Item {
            width: 1
            height: 8
        }

        Text {
            text: "ВХОД"
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

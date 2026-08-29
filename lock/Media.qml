pragma Singleton
import QtQuick
import Quickshell.Io

// Единый источник медиа-состояния (MPRIS через playerctl --follow),
// процесс фолловера один на шелл.
QtObject {
    property string playStatus: "stopped"
    property string title: "Ничего не играет"
    property string artist: ""
    property string artUrl: ""      // полный url (file://...), готов для Image.source
    property real length: 0
    property real pos: 0

    readonly property bool idle: playStatus !== "playing" && playStatus !== "paused" && title === "Ничего не играет"

    function act(cmd) {
        pAction.command = ["playerctl", cmd]
        pAction.running = true
    }

    function seek(sec) {
        Media.pos = Math.max(0, sec)
        pSeek.command = ["sh", "-c", "playerctl position " + Math.round(sec)]
        pSeek.running = true
    }

    property Process follow: Process {
        command: ["sh", "-c", "playerctl --follow metadata --format '{{status}}\u001f{{title}}\u001f{{artist}}\u001f{{mpris:artUrl}}\u001f{{mpris:length}}' 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const p = data.split("\u001f")
                if (p.length < 5)
                    return
                Media.playStatus = p[0].toLowerCase()
                if (p[1])
                    Media.title = p[1]
                Media.artist = p[2]
                Media.artUrl = p[3]
                const len = parseFloat(p[4])
                Media.length = isNaN(len) ? 0 : len / 1000000
            }
        }
    }

    property Process pPos: Process {
        command: ["sh", "-c", "playerctl position 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const v = parseFloat(data)
                if (!isNaN(v))
                    Media.pos = v
            }
        }
    }

    // позиция опрашивается только когда что-то играет
    property Timer posTimer: Timer {
        interval: 1000
        running: Media.playStatus === "playing"
        repeat: true
        triggeredOnStart: true
        onTriggered: Media.pPos.running = true
    }

    property Process pAction: Process {
    }

    property Process pSeek: Process {
    }
}

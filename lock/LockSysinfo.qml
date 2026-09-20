import QtQuick
import Quickshell
import Quickshell.Io

// Мини-fastfetch для локскрина: лого дистрибутива + строки системы.
// 2x1/3x1 — две строки, 2x2+ — полный список. Только публичные данные.
Rectangle {
    id: root

    signal editRequested()

    radius: Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: Theme.stroke

    property string osName: ""
    property string kernel: ""
    property string uptime: ""
    property string mem: ""

    property string userName: ""
    property string hostName: ""

    readonly property bool isFull: height >= 150

    Process {
        id: pUser
        command: ["sh", "-c", "whoami; hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n")
                root.userName = (p[0] || "").trim()
                root.hostName = (p[1] || "").trim()
            }
        }
        running: true
    }

    Process {
        id: pInfo
        command: ["sh", "-c", "echo os=$(grep ^PRETTY_NAME= /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"'); echo kern=$(uname -r); echo up=$(uptime -p 2>/dev/null | sed 's/^up //'); awk '$1==\"MemTotal:\"{t=$2} $1==\"MemAvailable:\"{a=$2} END{if(t>0) printf \"mem=%.0f%%\", (t-a)*100/t}' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const kv = lines[i].split("=")
                    if (kv[0] === "os")
                        root.osName = kv.slice(1).join("=").trim()
                    else if (kv[0] === "kern")
                        root.kernel = kv.slice(1).join("=").trim()
                    else if (kv[0] === "up")
                        root.uptime = kv.slice(1).join("=").trim()
                    else if (kv[0] === "mem")
                        root.mem = kv.slice(1).join("=").trim()
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pInfo.running) pInfo.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onPressAndHold: root.editRequested()
    }

    Row {
        anchors { fill: parent; margins: root.isFull ? 14 : 12 }
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf17c"
            font.family: Theme.iconFont
            font.pixelSize: root.isFull ? 44 : 34
            color: Theme.accent
        }

        Column {
            width: parent.width - (root.isFull ? 56 : 46) - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.isFull ? 3 : 2
            visible: !root.isFull

            Text {
                width: parent.width
                text: (root.userName !== "" ? root.userName + "@" : "") + root.hostName
                font.family: "NotoSans Nerd Font Mono"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.accent
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.kernel !== "" ? root.kernel + (root.uptime !== "" ? " · " + root.uptime : "") : "…"
                font.family: "NotoSans Nerd Font Mono"
                font.pixelSize: 10
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }

        Column {
            width: parent.width - 56 - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            visible: root.isFull

            Text {
                width: parent.width
                text: (root.userName !== "" ? root.userName + "@" : "") + root.hostName
                font.family: "NotoSans Nerd Font Mono"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.accent
                elide: Text.ElideRight
            }
            Repeater {
                model: [
                    { "k": "os", "v": root.osName },
                    { "k": "kernel", "v": root.kernel },
                    { "k": "uptime", "v": root.uptime },
                    { "k": "memory", "v": root.mem }
                ]
                delegate: Text {
                    required property var modelData
                    width: parent ? parent.width : 0
                    text: "~ " + modelData.k + ": " + (modelData.v !== "" ? modelData.v : "…")
                    font.family: "NotoSans Nerd Font Mono"
                    font.pixelSize: 10
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }
        }
    }
}

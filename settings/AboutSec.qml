import QtQuick
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 8
    boundsBehavior: Flickable.StopAtBounds


    property var win
    property var info: ({})

    function refresh() {
        pAbout.command = ["bash", "-c", "bash $HOME/.config/quickshell/metro-settings/about.sh"]
        pAbout.running = true
    }

    Process {
        id: pAbout

        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0)
                        m[line.slice(0, i)] = line.slice(i + 1)
                }
                root.info = m
            }
        }
    }

    readonly property var rows: [
        {
            k: "система",
            key: "os"
        },
        {
            k: "ядро",
            key: "kernel"
        },
        {
            k: "окружение",
            key: "wm"
        },
        {
            k: "устройство",
            key: "term"
        },
        {
            k: "процессор",
            key: "cpu"
        },
        {
            k: "видеокарта",
            key: "gpu"
        },
        {
            k: "память",
            key: "ram"
        },
        {
            k: "диск /",
            key: "disk"
        },
        {
            k: "аптайм",
            key: "up"
        },
        {
            k: "хост",
            key: "host"
        }
    ]

    Component {
        id: infoRow

        Rectangle {
            id: infoRowRoot

            width: parent ? parent.width : 0
            height: 44
            radius: 8
            color: Theme.glass

            required property var modelData

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: infoRowRoot.modelData.k
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.textDim
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 170
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.info[infoRowRoot.modelData.key] || "—"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                color: Theme.text
            }
        }
    }

    Column {
        id: col

        width: root.width
        spacing: 10

        Text {
            text: "СИСТЕМА"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Repeater {
            model: root.rows
            delegate: infoRow
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: "SHELL"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
        }

        Text {
            text: "metro live tiles · quickshell 0.3.1 · конфиг ~/.config/quickshell/metro"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textDim
        }
    }
}

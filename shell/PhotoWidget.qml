import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

// Плитка-фото: слайдшоу из папки с кроссфейдом, без кликов.
// Размер задаёт ячейка сетки через Loader (любой: 1x1 → 3x2).
// Скругление углов через OpacityMask — clip радиус не обрезает.
Rectangle {
    id: root

    property string folder: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property int intervalSec: 30
    property bool panelShown: false
    property url current: ""

    radius: Theme.radius
    color: Theme.glass
    clip: false

    // panelShown больше не нужен снаружи: грузим сразу при создании
    Component.onCompleted: pick()
    onPanelShownChanged: if (panelShown)
        pick()

    Timer {
        interval: root.intervalSec * 1000
        running: root.current.toString() !== ""
        repeat: true
        onTriggered: root.pick()
    }

    function pick() {
        pList.running = true
    }

    // кроссфейд: грузим новую картинку в скрытый Image, по Ready меняем фронт
    property bool frontA: true

    onCurrentChanged: {
        const img = frontA ? imgB : imgA
        img.source = current
    }

    function swapTo(img) {
        if (img === imgA)
            frontA = true
        else
            frontA = false
    }

    // маска скругления (общая для обоих Image)
    Rectangle {
        id: cornerMask

        anchors.fill: parent
        radius: root.radius
        visible: false
    }

    Image {
        id: imgA

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: opacity > 0.01
        opacity: root.frontA ? 1 : 0
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: cornerMask
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 450
            }
        }

        onStatusChanged: if (source !== "" && status === Image.Ready && opacity === 0)
            root.swapTo(imgA)
    }

    Image {
        id: imgB

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: opacity > 0.01
        opacity: root.frontA ? 0 : 1
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: cornerMask
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 450
            }
        }

        onStatusChanged: if (source !== "" && status === Image.Ready && opacity === 0)
            root.swapTo(imgB)
    }

    // рамка поверх фото
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.stroke
    }

    Text {
        anchors.centerIn: parent
        visible: root.current.toString() === ""
        text: "\uf03e"
        font.family: Theme.iconFont
        font.pixelSize: 34
        color: Theme.textDim
    }

    Process {
        id: pList

        command: ["sh", "-c", "ls -1 '" + root.folder + "' 2>/dev/null | grep -iE '\\.(jpg|jpeg|png|webp|bmp)$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l !== "")
                if (lines.length === 0) {
                    root.current = ""
                    return
                }
                const pick = lines[Math.floor(Math.random() * lines.length)]
                const path = root.folder.endsWith("/") ? root.folder + pick : root.folder + "/" + pick
                root.current = "file://" + path
            }
        }
    }
}

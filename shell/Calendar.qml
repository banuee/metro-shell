import QtQuick

Rectangle {
    id: root

    property date shown: new Date()
    readonly property date today: new Date()
    readonly property var monthNames: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]

    width: 470
    height: 400
    color: "transparent"

    function rebuild() {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1)
        const offset = (first.getDay() + 6) % 7
        const cells = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i)
            cells.push({
                "day": d.getDate(),
                "cur": d.getMonth() === shown.getMonth(),
                "today": d.toDateString() === today.toDateString()
            })
        }
        grid.model = cells
    }

    onShownChanged: rebuild()
    Component.onCompleted: rebuild()

    Item {
        id: header
        width: parent.width
        height: 44

        Text {
            anchors.centerIn: parent
            text: monthNames[shown.getMonth()] + " " + shown.getFullYear()
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.Light
            color: Theme.text
        }

        component NavBtn: TileFrame {
            id: nav

            required property int dir

            width: 36
            height: 36
            radius: Theme.radiusSmall
            onClicked: {
                shown = new Date(shown.getFullYear(), shown.getMonth() + nav.dir, 1)
            }

            Text {
                anchors.centerIn: parent
                text: nav.dir < 0 ? "\uf0d9" : "\uf0da"
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: Theme.text
            }
        }

        NavBtn {
            dir: -1
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        NavBtn {
            dir: 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        id: dayNames
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            margins: 4
        }
        Repeater {
            model: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
            Text {
                width: 66
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1.5
                color: Theme.textDim
            }
        }
    }

    Grid {
        id: grid

        property var model: []

        anchors {
            top: dayNames.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 4
        }
        columns: 7
        rows: 6

        Repeater {
            model: grid.model

            Item {
                width: 66
                height: (grid.height - 4) / 6

                Rectangle {
                    anchors.centerIn: parent
                    width: 46
                    height: 46
                    radius: 23
                    color: modelData.today ? Theme.alpha(Theme.accent, 0.95) : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: modelData.today ? Font.DemiBold : Font.Normal
                    color: modelData.today ? "#fff" : modelData.cur ? Theme.text : Qt.rgba(1, 1, 1, 0.25)
                }
            }
        }
    }
}

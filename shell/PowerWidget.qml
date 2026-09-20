import QtQuick

// Плитка питания: клик открывает центральное окно PowerMenu.
// Размер задаёт ячейка сетки через Loader (1x1 → 3x2).
TileFrame {
    id: root

    signal openRequested()

    readonly property bool isWide: width > Theme.unit + 20
    readonly property bool isTall: height > Theme.unit + 20
    readonly property bool isXL: width > Theme.tileW(2) + 20

    // ── 1x1 ──
    Item {
        anchors.fill: parent
        visible: !root.isWide && !root.isTall

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -7
            text: "\uf011"
            font.family: Theme.iconFont
            font.pixelSize: 24
            color: Theme.text
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: 10
                bottom: parent.bottom
                bottomMargin: 8
            }
            text: I18n.t("power")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }
    }

    // ── 2x1: иконка + подпись в ряд ──
    Item {
        anchors.fill: parent
        anchors.margins: 10
        visible: root.isWide && !root.isTall

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: Theme.isWP ? 0 : 1
                border.color: Theme.stroke

                Text {
                    anchors.centerIn: parent
                    text: "\uf011"
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                    color: Theme.text
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("power")
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }
    }

    // ── 1x2: иконка + подпись стопкой ──
    Item {
        anchors.fill: parent
        visible: !root.isWide && root.isTall

        Column {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 44
                height: 44
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: Theme.isWP ? 0 : 1
                border.color: Theme.stroke

                Text {
                    anchors.centerIn: parent
                    text: "\uf011"
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                    color: Theme.text
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("power")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }
    }

    // ── 2x2 / 3x2: крупная иконка + подпись ──
    Item {
        anchors.fill: parent
        visible: root.isWide && root.isTall

        Column {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.isXL ? 60 : 52
                height: root.isXL ? 60 : 52
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: Theme.isWP ? 0 : 1
                border.color: Theme.stroke

                Text {
                    anchors.centerIn: parent
                    text: "\uf011"
                    font.family: Theme.iconFont
                    font.pixelSize: root.isXL ? 26 : 24
                    color: Theme.text
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("power")
                font.family: Theme.fontFamily
                font.pixelSize: root.isXL ? 15 : 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }
    }

    onClicked: root.openRequested()
}

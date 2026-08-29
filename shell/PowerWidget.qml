import QtQuick

// Плитка питания 1x1: клик открывает центральное окно PowerMenu.
TileFrame {
    id: root

    signal openRequested()

    width: Theme.unit
    height: Theme.unit

    Text {
        anchors.centerIn: parent
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
        text: "питание"
        font.family: Theme.fontFamily
        font.pixelSize: 11
        color: Theme.textDim
    }

    onClicked: root.openRequested()
}

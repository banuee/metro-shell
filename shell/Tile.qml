import QtQuick
import Quickshell
import Quickshell.Widgets

TileFrame {
    id: root

    property int size: 1
    property int rows: 1
    property string glyph: ""
    property string imageIcon: ""
    property string label: ""
    property real iconSize: rows === 2 ? 44 : 32

    width: Theme.tileW(size)
    height: Theme.tileH(rows)

    readonly property bool useGlyph: glyph !== "" || imageIcon === "" || !Quickshell.hasThemeIcon(imageIcon)

    Text {
        visible: root.useGlyph
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.label !== "" ? -12 : 0
        text: root.glyph !== "" ? root.glyph : "\uf1b2"
        font.family: Theme.iconFont
        font.pixelSize: root.iconSize
        color: Theme.text
    }

    IconImage {
        id: appIcon

        visible: !root.useGlyph
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.label !== "" ? -12 : 0
        implicitSize: root.rows === 2 ? 56 : 40
        source: !root.useGlyph ? Quickshell.iconPath(root.imageIcon) : ""
    }

    Text {
        visible: root.label !== ""
        anchors {
            left: parent.left
            leftMargin: 10
            right: parent.right
            rightMargin: 10
            bottom: parent.bottom
            bottomMargin: 8
        }
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: 12
        color: Theme.text
        elide: Text.ElideRight
    }
}

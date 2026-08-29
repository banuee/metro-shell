pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Segoe UI Variable Static Text"
    readonly property string iconFont: "NotoSans Nerd Font"

    readonly property color bg: Qt.rgba(0.06, 0.06, 0.10, 0.3)
    readonly property color text: "#f7f7f7"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.60)

    // акцент; metro-colors перезаписывает строку teal при смене обоев.
    // НЕ переименовывать: патчится по регулярке readonly property color teal
    readonly property color teal: "#3a73ab"

    readonly property color accent: teal

    // WP-палитра функциональных цветов (CPU/RAM/GPU/BAT, ошибки и т.п.)
    readonly property color purple: "#a200ff"
    readonly property color orange: "#f09609"
    readonly property color green: "#10893e"
    readonly property color lime: "#7e9600"
    readonly property color red: "#e51400"

    readonly property color glass: Qt.rgba(1, 1, 1, 0.07)
    readonly property color glassHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassDeep: Qt.rgba(0.10, 0.10, 0.14, 0.97)
    readonly property color stroke: Qt.rgba(1, 1, 1, 0.08)

    readonly property int unit: 84
    readonly property int gap: 8
    readonly property int radius: 10
    readonly property int radiusSmall: 8
    readonly property int panelRadius: 16
    readonly property int panelWidth: 400
    readonly property real tileAlpha: 0.85

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function tileW(cols) {
        return cols * unit + (cols - 1) * gap
    }

    function tileH(rows) {
        return rows * unit + (rows - 1) * gap
    }
}

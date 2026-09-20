pragma Singleton
import QtQuick

QtObject {
    readonly property string themeName: "metro"
    readonly property bool isMaterial: themeName === "material"
    readonly property bool isWP: themeName === "wp"
    readonly property bool isMetro: themeName === "metro"
    readonly property bool isLiquidGlass: false

    readonly property string fontFamily: "Segoe UI Variable Static Text"
    readonly property string headlineFont: "Segoe UI Variable Static Display Light"
    readonly property string iconFont: "NotoSans Nerd Font"

    // Material 3 Dynamic Color Tokens (M3 / Material You)
    readonly property color primary: "#90be55"
    readonly property color on_primary: "#ffffff"
    readonly property color primary_container: "#354e15"
    readonly property color on_primary_container: "#ceeda3"

    readonly property color secondary: "#c0cbac"
    readonly property color on_secondary: "#2a331e"
    readonly property color secondary_container: "#404a33"
    readonly property color on_secondary_container: "#dce7c7"

    readonly property color tertiary: "#a0d0cb"
    readonly property color on_tertiary: "#003734"
    readonly property color tertiary_container: "#1f4e4b"
    readonly property color on_tertiary_container: "#bcece7"

    readonly property color surface: "#12140e"
    readonly property color on_surface: "#e2e3d8"
    readonly property color surface_variant: "#44483d"
    readonly property color on_surface_variant: "#c5c8ba"

    readonly property color surface_container_lowest: "#0d0f09"
    readonly property color surface_container_low: "#1a1c16"
    readonly property color surface_container: "#1e201a"
    readonly property color surface_container_high: "#282b24"
    readonly property color surface_container_highest: "#33362e"

    readonly property color outline: "#8f9285"
    readonly property color outline_variant: "#44483d"

    readonly property color error: "#ffb4ab"
    readonly property color on_error: "#690005"
    readonly property color error_container: "#93000a"
    readonly property color on_error_container: "#ffdad6"

    // Accent & Compatibility Bindings
    readonly property color teal: "#90be55"
    readonly property color accent: teal

    // WP-палитра функциональных цветов (CPU/RAM/GPU/BAT, ошибки и т.п.)
    readonly property color purple: "#a200ff"
    readonly property color orange: "#f09609"
    readonly property color green: "#10893e"
    readonly property color lime: "#7e9600"
    readonly property color red: "#e51400"

    // Background & Card surfaces
    readonly property color bg: Qt.rgba(0.10, 0.10, 0.10, 0.30)
    readonly property color bgCard: Qt.rgba(1, 1, 1, 0.07)
    readonly property color bgCardHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color text: "#f7f7f7"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.60)

    readonly property color glass: Qt.rgba(1, 1, 1, 0.07)
    readonly property color glassHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassDeep: Qt.rgba(255, 255, 255, 0.06)
    readonly property color stroke: Qt.rgba(1, 1, 1, 0.08)
    readonly property color strokeStrong: Qt.rgba(1, 1, 1, 0.15)

    // Radii & Dimensions
    readonly property int unit: 84
    readonly property int gap: 8
    readonly property int radius: 10
    readonly property int radiusSmall: 8
    readonly property int radiusLarge: 14
    readonly property int radiusPill: 999
    readonly property int panelRadius: 16
    readonly property int panelWidth: 400
    readonly property real tileAlpha: 0.85

    // Per-panel поверхности (metro-shell.conf → panel.*)
    readonly property color panelTopBg: Qt.rgba(0.10, 0.10, 0.10, 0.30)
    readonly property color panelLeftBg: Qt.rgba(0.10, 0.10, 0.10, 0.30)
    readonly property color panelRightBg: Qt.rgba(0.10, 0.10, 0.10, 0.30)
    readonly property int panelTopRadius: 16
    readonly property int panelLeftRadius: 16
    readonly property int panelRightRadius: 16

    function tileW(cols) {
        return cols * unit + (cols - 1) * gap
    }

    function tileH(rows) {
        return rows * unit + (rows - 1) * gap
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}

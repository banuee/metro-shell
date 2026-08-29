pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "WeatherCodes.js" as WC

// Лёгкая версия погоды для экрана блокировки: только текущие условия.
// Город — общий city.json из шелла.
QtObject {
    property string cityName: ""
    property bool loaded: false
    property real temp: 0
    property int code: 0

    function glyph(c) {
        return WC.glyph(c)
    }

    function text(c) {
        return WC.text(c)
    }

    function fetch() {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
            "&current=temperature_2m,weather_code&timezone=auto"
        pFetch.command = ["curl", "-s", "--max-time", "8", url]
        pFetch.running = true
    }

    function handleData(txt) {
        try {
            const j = JSON.parse(txt)
            temp = j.current.temperature_2m
            code = j.current.weather_code
            loaded = true
        } catch (e) {}
    }

    function loadCity(txt) {
        try {
            const j = JSON.parse(txt)
            cityName = j.name || ""
            lat = j.lat
            lon = j.lon
        } catch (e) {}
        if (lat !== 0 || lon !== 0)
            fetch()
    }

    property real lat: 0
    property real lon: 0

    readonly property string cityPath: Quickshell.env("HOME") + "/.config/quickshell/metro/city.json"

    property Process pFetch: Process {
        stdout: StdioCollector {
            onStreamFinished: Weather.handleData(text)
        }
    }

    property Process pInit: Process {
        command: ["sh", "-c", "cat " + Weather.cityPath + " 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: Weather.loadCity(text)
        }
        running: true
    }

    property Timer refreshTimer: Timer {
        interval: 30 * 60 * 1000
        running: false
        repeat: true
        onTriggered: Weather.fetch()
    }
}

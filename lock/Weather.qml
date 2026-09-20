pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "WeatherCodes.js" as WC

QtObject {
    id: root

    readonly property string city: cityName
    property string cityName: "Minsk"
    property real lat: 53.9
    property real lon: 27.57

    property bool loaded: false
    property real temp: 0
    property int code: 0
    property real feelsLike: 0
    property real wind: 0
    property int humidity: 0
    property int pressure: 0
    property string sunset: ""
    property var hourly: []
    property var daily: []
    property var geoResults: []
    property bool fetching: false
    property bool searching: false

    function glyph(c) {
        return WC.glyph(c)
    }

    function text(c) {
        return WC.text(c, I18n.lang)
    }

    function formatDay(d, isToday) {
        if (isToday) {
            return {
                short: I18n.t("today"),
                full: I18n.t("today")
            }
        }
        const ruDays = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
        const ruFull = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        const enDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const enFull = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        const isRu = I18n.lang === "ru"
        return {
            short: isRu ? ruDays[d.getDay()] : enDays[d.getDay()],
            full: isRu ? ruFull[d.getDay()] : enFull[d.getDay()]
        }
    }

    function setCity(name, la, lo) {
        cityName = name
        lat = la
        lon = lo
        loaded = false
        saveCity()
        fetch()
    }

    function saveCity() {
        const json = JSON.stringify({
            "name": cityName.replace(/'/g, ""),
            "lat": lat,
            "lon": lon
        })
        pSaveCity.command = ["sh", "-c", "printf '%s' '" + json + "' > '" + cityPath + "'"]
        pSaveCity.running = true
    }

    function fetch() {
        fetching = true
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
            "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,surface_pressure" +
            "&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunset" +
            "&forecast_days=7&timezone=auto"
        pFetch.command = ["curl", "-s", "--max-time", "12", url]
        pFetch.running = true
    }

    function searchCity(q) {
        if (!q || q.length < 2) {
            geoResults = []
            return
        }
        searching = true
        const lang = I18n.lang === "ru" ? "ru" : "en"
        const url = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(q) +
            "&count=6&language=" + lang + "&format=json"
        pGeo.command = ["curl", "-s", "--max-time", "10", url]
        pGeo.running = true
    }

    property string rawDataCache: ""

    function handleData(txt) {
        try {
            rawDataCache = txt
            const j = JSON.parse(txt)
            temp = j.current.temperature_2m
            code = j.current.weather_code
            feelsLike = j.current.apparent_temperature
            wind = j.current.wind_speed_10m / 3.6
            humidity = j.current.relative_humidity_2m
            pressure = Math.round(j.current.surface_pressure)
            sunset = j.daily.sunset[0].split("T")[1]

            const now = new Date()
            const h = []
            for (let i = 0; i < j.hourly.time.length && h.length < 14; i++) {
                const d = new Date(j.hourly.time[i])
                if (d.getTime() + 3600000 < now.getTime())
                    continue
                h.push({
                    "hour": Qt.formatDateTime(d, "HH"),
                    "temp": Math.round(j.hourly.temperature_2m[i]),
                    "code": j.hourly.weather_code[i]
                })
            }
            hourly = h

            const days = []
            for (let i = 0; i < j.daily.time.length; i++) {
                const d = new Date(j.daily.time[i] + "T12:00")
                const dayObj = formatDay(d, i === 0)
                days.push({
                    "day": dayObj.short,
                    "full": dayObj.full,
                    "code": j.daily.weather_code[i],
                    "max": Math.round(j.daily.temperature_2m_max[i]),
                    "min": Math.round(j.daily.temperature_2m_min[i])
                })
            }
            daily = days
            loaded = true
        } catch (e) {}
        fetching = false
    }

    // Re-parse day strings when language changes
    property Connections langConn: Connections {
        target: I18n
        function onLangChanged() {
            if (root.rawDataCache !== "") {
                root.handleData(root.rawDataCache)
            }
        }
    }

    function handleGeo(txt) {
        try {
            const j = JSON.parse(txt)
            geoResults = (j.results ?? []).map(r => ({
                "name": r.name,
                "region": [r.admin1, r.country].filter(Boolean).join(", "),
                "lat": r.latitude,
                "lon": r.longitude
            }))
        } catch (e) {
            geoResults = []
        }
        searching = false
    }

    function loadCity(txt) {
        try {
            const j = JSON.parse(txt)
            if (j.name) cityName = j.name
            if (j.lat !== undefined) lat = j.lat
            if (j.lon !== undefined) lon = j.lon
        } catch (e) {}
        fetch()
    }

    readonly property string cityPath: Quickshell.env("HOME") + "/.config/quickshell/metro/city.json"

    property Process pFetch: Process {
        stdout: StdioCollector {
            onStreamFinished: Weather.handleData(text)
        }
    }

    property Process pGeo: Process {
        stdout: StdioCollector {
            onStreamFinished: Weather.handleGeo(text)
        }
    }

    property Process pSaveCity: Process {
        command: ["true"]
    }

    property Process pInit: Process {
        command: ["sh", "-c", "cat " + Weather.cityPath + " 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: Weather.loadCity(text)
        }
        running: true
    }

    property Timer refreshTimer: Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: Weather.fetch()
    }
}

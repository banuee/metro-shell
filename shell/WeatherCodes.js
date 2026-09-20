// WMO weather interpretation codes -> [english text, russian text, nerd font glyph hex]
var map = {
    0: ["Clear", "Ясно", "f0599"],
    1: ["Mainly clear", "Преимущественно ясно", "f0595"],
    2: ["Partly cloudy", "Переменная облачность", "f0595"],
    3: ["Overcast", "Пасмурно", "f0c2"],
    45: ["Fog", "Туман", "f0591"],
    48: ["Rime fog", "Изморозь", "f0591"],
    51: ["Light drizzle", "Лёгкая морось", "f0592"],
    53: ["Drizzle", "Морось", "f0592"],
    55: ["Heavy drizzle", "Сильная морось", "f0592"],
    56: ["Freezing drizzle", "Ледяная морось", "f0592"],
    57: ["Freezing drizzle", "Ледяная морось", "f0592"],
    61: ["Slight rain", "Небольшой дождь", "f0592"],
    63: ["Rain", "Дождь", "f0596"],
    65: ["Heavy rain", "Сильный дождь", "f0596"],
    66: ["Freezing rain", "Ледяной дождь", "f0596"],
    67: ["Freezing rain", "Ледяной дождь", "f0596"],
    71: ["Slight snow", "Небольшой снег", "f2dc"],
    73: ["Snow", "Снег", "f2dc"],
    75: ["Heavy snow", "Сильный снег", "f2dc"],
    77: ["Snow grains", "Снежные зёрна", "f2dc"],
    80: ["Rain showers", "Ливень", "f0596"],
    81: ["Rain showers", "Ливень", "f0596"],
    82: ["Heavy showers", "Сильный ливень", "f0596"],
    85: ["Snow showers", "Снегопад", "f2dc"],
    86: ["Heavy snow showers", "Сильный снегопад", "f2dc"],
    95: ["Thunderstorm", "Гроза", "f0e7"],
    96: ["Thunderstorm with hail", "Гроза с градом", "f0e7"],
    99: ["Thunderstorm with hail", "Гроза с градом", "f0e7"]
}

function text(code, lang) {
    var e = map[code]
    if (!e) return "—"
    return (lang === "ru") ? e[1] : e[0]
}

function glyph(code) {
    var e = map[code]
    return String.fromCodePoint(parseInt(e ? e[2] : "f0c2", 16))
}

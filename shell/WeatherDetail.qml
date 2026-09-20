import QtQuick
import Quickshell.Io

Rectangle {
    id: root

    anchors.fill: parent
    color: "transparent"

    component CardBg: Rectangle {
        radius: Theme.radius
        color: Theme.isMaterial ? Theme.surface_container : Qt.rgba(1, 1, 1, 0.05)
        border.width: Theme.isWP ? 0 : 1
        border.color: Theme.isMaterial ? Theme.stroke : Qt.rgba(1, 1, 1, 0.06)
    }

    // ── Поисковая строка ──
    Rectangle {
        id: searchBox
        width: 380
        height: Theme.isMaterial ? 42 : 38
        radius: Theme.isMaterial ? Theme.radiusPill : Theme.radiusSmall
        color: Theme.isMaterial ? Theme.surface_container_high : Theme.glass
        border.width: Theme.isMaterial && cityInput.activeFocus ? 2 : (Theme.isWP ? 0 : 1)
        border.color: cityInput.activeFocus ? (Theme.isMaterial ? Theme.primary : Theme.accent) : Theme.stroke
        z: 30

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: cityInput.activeFocus ? (Theme.isMaterial ? Theme.primary : Theme.accent) : (Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim)
            }

            TextInput {
                id: cityInput
                width: parent.width - 32
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.isMaterial ? Theme.on_surface : Theme.text
                clip: true

                Text {
                    visible: cityInput.text === "" && !cityInput.activeFocus
                    text: I18n.t("search_city")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
                }

                onTextChanged: geoDebounce.restart()
            }
        }

        Timer {
            id: geoDebounce
            interval: 400
            onTriggered: Weather.searchCity(cityInput.text)
        }
    }

    // Выпадающий список городов
    Rectangle {
        id: geoPopup
        visible: cityInput.text.length >= 2 && Weather.geoResults.length > 0
        anchors {
            left: searchBox.left
            right: searchBox.right
            top: searchBox.bottom
            topMargin: 6
        }
        height: Math.min(Weather.geoResults.length, 6) * 38 + 8
        radius: Theme.isMaterial ? 18 : Theme.radiusSmall
        color: Theme.isMaterial ? Theme.surface_container_highest : Theme.glassDeep
        border.width: Theme.isWP ? 0 : 1
        border.color: Theme.stroke
        z: 40

        Column {
            anchors.fill: parent
            anchors.margins: 4

            Repeater {
                model: Weather.geoResults
                Item {
                    width: parent.width
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.isMaterial ? 12 : Theme.radiusSmall
                        color: geoMa.containsMouse ? (Theme.isMaterial ? Theme.alpha(Theme.primary, 0.15) : Theme.glassHover) : "transparent"
                    }

                    Column {
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.isMaterial ? Theme.on_surface : Theme.text
                        }

                        Text {
                            visible: modelData.region !== ""
                            text: modelData.region
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
                        }
                    }

                    MouseArea {
                        id: geoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Weather.setCity(modelData.name, modelData.lat, modelData.lon)
                            cityInput.text = ""
                        }
                    }
                }
            }
        }
    }

    // ── Левая карточка: Текущая погода + Параметры ──
    CardBg {
        id: leftCard
        anchors {
            left: parent.left
            top: parent.top
            topMargin: 50
            bottom: parent.bottom
        }
        width: 380

        // Верхний ряд: Иконка + Температура + Описание
        Row {
            id: currentRow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 16
            }
            spacing: 16

            // Иконка
            Item {
                width: 64
                height: 64
                anchors.verticalCenter: parent.verticalCenter

                // Scalloped / Flower badge для Material You
                Rectangle {
                    anchors.centerIn: parent
                    width: 50
                    height: 50
                    radius: 25
                    visible: Theme.isMaterial
                    color: Theme.primary_container
                }
                Repeater {
                    model: Theme.isMaterial ? 8 : 0
                    Rectangle {
                        readonly property real angle: index * (Math.PI * 2 / 8)
                        width: 20
                        height: 20
                        radius: 10
                        x: 32 + 20 * Math.cos(angle) - 10
                        y: 32 + 20 * Math.sin(angle) - 10
                        color: Theme.primary_container
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Weather.loaded ? Weather.glyph(Weather.code) : "\uf0595"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.isMaterial ? 28 : 52
                    color: Theme.isMaterial ? Theme.on_primary_container : Theme.accent
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Weather.loaded ? Math.round(Weather.temp) + "°" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: 44
                    font.weight: Theme.isMaterial ? Font.Normal : Font.Light
                    color: Theme.isMaterial ? Theme.primary : Theme.text
                }

                Text {
                    text: Weather.text(Weather.code)
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Theme.isMaterial ? Font.Medium : Font.Normal
                    color: Theme.isMaterial ? Theme.on_surface : Theme.text
                }

                Text {
                    text: Weather.city
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
                }
            }
        }

        Rectangle {
            id: divider
            anchors {
                left: parent.left
                right: parent.right
                top: currentRow.bottom
                topMargin: 12
                leftMargin: 16
                rightMargin: 16
            }
            height: 1
            color: Theme.stroke
        }

        Grid {
            anchors {
                left: parent.left
                right: parent.right
                top: divider.bottom
                topMargin: 12
                leftMargin: 16
                rightMargin: 16
            }
            columns: 2
            spacing: 8

            component DetailItem: Rectangle {
                id: det
                required property string icon
                required property string label
                required property string value

                width: (parent.width - 8) / 2
                height: 52
                radius: Theme.isMaterial ? 14 : Theme.radiusSmall
                color: Theme.isMaterial ? Theme.surface_container_high : Qt.rgba(1, 1, 1, 0.06)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        visible: Theme.isMaterial
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.primary_container
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: det.icon
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: Theme.on_primary_container
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: det.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                            color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
                        }

                        Text {
                            text: det.value
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Theme.isMaterial ? Font.DemiBold : Font.Normal
                            color: Theme.isMaterial ? Theme.on_surface : Theme.text
                        }
                    }
                }
            }

            DetailItem {
                icon: "\uf72e"
                label: I18n.t("feels_like")
                value: Weather.loaded ? Math.round(Weather.feelsLike) + "°" : "—"
            }

            DetailItem {
                icon: "\uf72e"
                label: I18n.t("wind_title")
                value: Weather.loaded ? Weather.wind.toFixed(1) + " " + I18n.t("ms") : "—"
            }

            DetailItem {
                icon: "\uf043"
                label: I18n.t("humidity_title")
                value: Weather.loaded ? Weather.humidity + "%" : "—"
            }

            DetailItem {
                icon: "\uf0e2"
                label: I18n.t("pressure_sunset")
                value: Weather.loaded ? Weather.pressure + (I18n.lang === "ru" ? " гПа" : " hPa") : "—"
            }
        }
    }

    // ── Правая верхняя карточка: Почасовой прогноз (Hourly Graph) ──
    CardBg {
        id: hourlyCard
        anchors {
            left: leftCard.right
            right: parent.right
            top: parent.top
            leftMargin: 16
        }
        height: 176

        Text {
            id: hourlyLabel
            anchors {
                left: parent.left
                top: parent.top
                margins: 14
            }
            text: I18n.t("hourly_forecast")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Theme.isMaterial ? Font.DemiBold : Font.Normal
            font.letterSpacing: 1.8
            color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
        }

        Item {
            id: hourArea
            anchors {
                left: parent.left
                right: parent.right
                top: hourlyLabel.bottom
                leftMargin: 14
                rightMargin: 14
                topMargin: 4
                bottom: parent.bottom
                bottomMargin: 10
            }

            function curveX(i) {
                return (i + 0.5) * width / Math.max(1, Weather.hourly.length)
            }

            function curveY(i) {
                const n = Weather.hourly.length
                if (n === 0 || i >= n) return 0
                let min = Infinity
                let max = -Infinity
                for (let j = 0; j < n; j++) {
                    const t = Weather.hourly[j].temp
                    if (t < min) min = t
                    if (t > max) max = t
                }
                const t = Weather.hourly[i].temp
                return 48 + (1 - (t - min) / Math.max(1, max - min)) * (height - 60)
            }

            Repeater {
                model: Math.max(0, Weather.hourly.length - 1)

                Rectangle {
                    required property int index
                    readonly property real x1: hourArea.curveX(index)
                    readonly property real y1: hourArea.curveY(index)
                    readonly property real x2: hourArea.curveX(index + 1)
                    readonly property real y2: hourArea.curveY(index + 1)

                    x: (x1 + x2) / 2 - width / 2
                    y: (y1 + y2) / 2 - height / 2
                    width: Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
                    height: 2.5
                    radius: 1.25
                    color: Theme.primary
                    rotation: Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI
                }
            }

            Repeater {
                model: Weather.hourly

                Rectangle {
                    required property int index
                    x: hourArea.curveX(index) - 3
                    y: hourArea.curveY(index) - 3
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.primary
                }
            }

            Repeater {
                model: Weather.hourly

                Item {
                    x: index * (hourArea.width / Math.max(1, Weather.hourly.length))
                    width: hourArea.width / Math.max(1, Weather.hourly.length)
                    height: hourArea.height

                    Text {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                        }
                        text: modelData.hour
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
                    }

                    Text {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: 16
                        }
                        text: Weather.glyph(modelData.code)
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                        color: Theme.isMaterial ? Theme.primary : Theme.text
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: hourArea.curveY(index) - 22
                        text: modelData.temp + "°"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.isMaterial ? Theme.on_surface : Theme.text
                    }
                }
            }
        }
    }

    // ── Правая нижняя карточка: 7-дневный прогноз ──
    CardBg {
        id: dailyCard
        anchors {
            left: leftCard.right
            right: parent.right
            top: hourlyCard.bottom
            bottom: parent.bottom
            leftMargin: 16
            topMargin: 12
        }

        Text {
            id: dailyLabel
            anchors {
                left: parent.left
                top: parent.top
                margins: 14
            }
            text: I18n.t("7_days")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Theme.isMaterial ? Font.DemiBold : Font.Normal
            font.letterSpacing: 1.8
            color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
        }

        Column {
            id: dailyCol
            anchors {
                left: parent.left
                right: parent.right
                top: dailyLabel.bottom
                bottom: parent.bottom
                leftMargin: 14
                rightMargin: 14
                topMargin: 4
                bottomMargin: 12
            }
            spacing: 2

            Repeater {
                model: Weather.daily

                Item {
                    property real weekMin: {
                        let m = 99
                        for (let i = 0; i < Weather.daily.length; i++)
                            m = Math.min(m, Weather.daily[i].min)
                        return m
                    }

                    property real weekMax: {
                        let m = -99
                        for (let i = 0; i < Weather.daily.length; i++)
                            m = Math.max(m, Weather.daily[i].max)
                        return m
                    }

                    width: dailyCol.width
                    height: (dailyCol.height - 12) / Math.max(1, Weather.daily.length)

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 12

                        Text {
                            width: 80
                            text: modelData.full
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: index === 0 ? Font.Bold : Font.Normal
                            color: index === 0 ? (Theme.isMaterial ? Theme.primary : Theme.accent) : (Theme.isMaterial ? Theme.on_surface : Theme.text)
                        }

                        Text {
                            width: 26
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.glyph(modelData.code)
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: Theme.isMaterial ? Theme.primary : Theme.text
                        }

                        Text {
                            width: 32
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.min + "°"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.isMaterial ? Theme.on_surface_variant : Theme.textDim
                        }

                        Item {
                            width: parent.width - 190
                            height: 6
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.isMaterial ? Theme.surface_container_highest : Qt.rgba(1, 1, 1, 0.10)
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * (modelData.min - weekMin) / Math.max(1, weekMax - weekMin)
                                width: Math.max(6, parent.width * (modelData.max - modelData.min) / Math.max(1, weekMax - weekMin))
                                height: 6
                                radius: 3
                                color: Theme.primary
                            }

                            Rectangle {
                                visible: index === 0 && Weather.loaded
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - 6, parent.width * (Weather.temp - weekMin) / Math.max(1, weekMax - weekMin)))
                                width: 6
                                height: 6
                                radius: 3
                                color: "#ffffff"
                                border.width: 0.5
                                border.color: "#000000"
                            }
                        }

                        Text {
                            width: 32
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.max + "°"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.isMaterial ? Theme.on_surface : Theme.text
                        }
                    }
                }
            }
        }
    }
}

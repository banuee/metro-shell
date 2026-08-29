import QtQuick
import Quickshell.Io

Rectangle {
    id: root

    anchors.fill: parent
    color: "transparent"

    component CardBg: Rectangle {
        radius: Theme.radius
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    Rectangle {
        id: searchBox

        width: 380
        height: 38
        radius: Theme.radiusSmall
        color: Theme.glass

        Text {
            visible: cityInput.text === ""
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: "\uf002"
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: Theme.textDim
        }

        TextInput {
            id: cityInput

            anchors {
                left: parent.left
                leftMargin: 34
                right: parent.right
                rightMargin: 12
                top: parent.top
                bottom: parent.bottom
            }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontFamily
            font.pixelSize: 14
            color: Theme.text
            cursorVisible: activeFocus
            clip: true

            onTextChanged: {
                geoDebounce.restart()
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 10
                rightMargin: 10
            }
            height: 2
            radius: 1
            color: Theme.accent
            opacity: cityInput.activeFocus ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        Timer {
            id: geoDebounce

            interval: 500
            onTriggered: Weather.searchCity(cityInput.text)
        }
    }

    Rectangle {
        id: geoPopup

        visible: cityInput.text.length >= 2 && Weather.geoResults.length > 0
        anchors {
            left: searchBox.left
            right: searchBox.right
            top: searchBox.bottom
            topMargin: 4
        }
        height: Math.min(Weather.geoResults.length, 6) * 36 + 8
        radius: Theme.radiusSmall
        color: Theme.glassDeep
        border.width: 1
        border.color: Theme.stroke
        z: 20

        Column {
            anchors {
                fill: parent
                margins: 4
            }

            Repeater {
                model: Weather.geoResults

                Item {
                    width: parent.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: geoMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    }

                    Column {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.text
                        }

                        Text {
                            visible: modelData.region !== ""
                            text: modelData.region
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
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

    CardBg {
        id: leftCard

        anchors {
            left: parent.left
            top: searchBox.bottom
            topMargin: 12
            bottom: parent.bottom
        }
        width: 380

        Row {
            id: currentRow

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 16
            }
            spacing: 16

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.loaded ? Weather.glyph(Weather.code) : "..."
                font.family: Theme.iconFont
                font.pixelSize: 56
                color: Theme.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Weather.loaded ? Math.round(Weather.temp) + "°" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: 46
                    font.weight: Font.Light
                    color: Theme.text
                }

                Text {
                    text: Weather.text(Weather.code)
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.text
                }

                Text {
                    text: Weather.city
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }
            }
        }

        Rectangle {
            id: divider

            anchors {
                left: parent.left
                right: parent.right
                top: currentRow.bottom
                topMargin: 14
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
                topMargin: 14
                leftMargin: 16
                rightMargin: 16
            }
            columns: 2
            spacing: 8

            component Detail: Rectangle {
                id: det

                required property string label
                required property string value

                width: (parent.width - 8) / 2
                height: 52
                radius: Theme.radiusSmall
                color: Qt.rgba(1, 1, 1, 0.06)

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: det.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        color: Theme.textDim
                    }

                    Text {
                        text: det.value
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: Theme.text
                    }
                }
            }

            Detail {
                label: "ОЩУЩАЕТСЯ"
                value: Weather.loaded ? Math.round(Weather.feelsLike) + "°" : "—"
            }

            Detail {
                label: "ВЕТЕР"
                value: Weather.loaded ? Weather.wind.toFixed(1) + " м/с" : "—"
            }

            Detail {
                label: "ВЛАЖНОСТЬ"
                value: Weather.loaded ? Weather.humidity + "%" : "—"
            }

            Detail {
                label: "ДАВЛЕНИЕ / ЗАКАТ"
                value: Weather.loaded ? Weather.pressure + " гПа / " + Weather.sunset : "—"
            }
        }
    }

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
            text: "ПОЧАСОВОЙ ПРОГНОЗ"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
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
                if (n === 0 || i >= n)
                    return 0
                let min = Infinity
                let max = -Infinity
                for (let j = 0; j < n; j++) {
                    const t = Weather.hourly[j].temp
                    if (t < min)
                        min = t
                    if (t > max)
                        max = t
                }
                const t = Weather.hourly[i].temp
                return 56 + (1 - (t - min) / Math.max(1, max - min)) * (height - 68)
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
                    height: 2
                    radius: 1
                    color: Theme.accent
                    rotation: Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI
                }
            }

            Repeater {
                model: Weather.hourly

                Rectangle {
                    required property int index

                    x: hourArea.curveX(index) - 2.5
                    y: hourArea.curveY(index) - 2.5
                    width: 5
                    height: 5
                    radius: 2.5
                    color: "#ffffff"
                }
            }

            Repeater {
                model: Weather.hourly

                Item {
                    x: index * (hourArea.width / Weather.hourly.length)
                    width: hourArea.width / Weather.hourly.length
                    height: hourArea.height

                    Text {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                        }
                        text: modelData.hour
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }

                    Text {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: 16
                        }
                        text: Weather.glyph(modelData.code)
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        color: Theme.text
                    }

                    Text {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                        }
                        y: hourArea.curveY(index) - 24
                        text: modelData.temp + "°"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.text
                    }
                }
            }
        }
    }

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
            text: "НА 7 ДНЕЙ"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.textDim
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
                    height: (dailyCol.height - 12) / 7

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 12

                        Text {
                            width: 80
                            text: modelData.full
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: index === 0 ? Theme.accent : Theme.text
                        }

                        Text {
                            width: 26
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.glyph(modelData.code)
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: Theme.text
                        }

                        Text {
                            width: 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.min + "°"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDim
                        }

                        Item {
                            width: parent.width - 200
                            height: 6
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.10)
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * (modelData.min - weekMin) / Math.max(1, weekMax - weekMin)
                                width: parent.width * (modelData.max - modelData.min) / Math.max(1, weekMax - weekMin)
                                height: 6
                                radius: 3
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: Theme.accent
                                    }

                                    GradientStop {
                                        position: 1
                                        color: Theme.orange
                                    }
                                }
                            }
                        }

                        Text {
                            width: 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.max + "°"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.text
                        }
                    }
                }
            }
        }
    }
}

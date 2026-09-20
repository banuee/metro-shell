import QtQuick

// Мини-календарь для локскрина: 1x1 — число, 2x1 — дата строкой,
// 2x2 и больше — сетка месяца (today = accent).
Rectangle {
    id: root

    signal editRequested()

    radius: Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: Theme.stroke

    property date today: new Date()

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.today = new Date()
    }

    function monthName(m) {
        if (I18n.lang === "ru")
            return ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"][m]
        return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][m]
    }

    function monthShort(m) {
        if (I18n.lang === "ru")
            return ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"][m]
        return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m]
    }

    function weekdayShort(i) {
        if (I18n.lang === "ru")
            return ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"][i]
        return ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"][i]
    }

    function fullDate(d) {
        if (I18n.lang === "ru") {
            const days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
            const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
            return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
        }
        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
    }

    readonly property bool isTiny: width < 130 && height < 130
    readonly property bool isStrip: height < 130
    readonly property int firstCol: (new Date(root.today.getFullYear(), root.today.getMonth(), 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(root.today.getFullYear(), root.today.getMonth() + 1, 0).getDate()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onPressAndHold: root.editRequested()
    }

    // 1x1: крупное число + месяц
    Column {
        visible: root.isTiny
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.today.getDate()
            font.family: Theme.fontFamily
            font.pixelSize: 34
            font.weight: Font.Light
            color: Theme.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.monthShort(root.today.getMonth())
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 2
            color: Theme.accent
        }
    }

    // 2x1 и шире-низкие: дата строкой
    Column {
        visible: root.isStrip && !root.isTiny
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 12 }
        spacing: 2
        Text {
            text: root.monthName(root.today.getMonth()) + " " + root.today.getFullYear()
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Theme.accent
        }
        Text {
            width: parent.width
            text: root.fullDate(root.today)
            font.family: Theme.fontFamily
            font.pixelSize: width > 220 ? 17 : 14
            font.weight: Font.Light
            color: Theme.text
            elide: Text.ElideRight
        }
    }

    // 2x2+: сетка месяца
    Column {
        visible: !root.isTiny && !root.isStrip
        anchors { fill: parent; margins: 12 }
        spacing: 4

        Text {
            text: root.monthName(root.today.getMonth()) + " " + root.today.getFullYear()
            font.family: Theme.fontFamily
            font.pixelSize: width > 220 ? 14 : 12
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
            color: Theme.text
        }

        Grid {
            columns: 7
            spacing: 1
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: (root.width - 24 - 6) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: root.weekdayShort(index)
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.alpha(Theme.accent, 0.8)
                }
            }
        }

        Grid {
            columns: 7
            spacing: 1
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property int day: index - root.firstCol + 1
                    readonly property bool valid: day >= 1 && day <= root.daysInMonth
                    readonly property bool isToday: valid && day === root.today.getDate()
                    width: (root.width - 24 - 6) / 7
                    height: root.width > 220 ? 20 : 17
                    visible: valid
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        radius: 9
                        color: parent.isToday ? Theme.alpha(Theme.accent, 0.95) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.day
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: parent.isToday ? "#ffffff" : Theme.textDim
                    }
                }
            }
        }
    }
}

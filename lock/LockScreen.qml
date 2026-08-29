import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as Qt5Compat

// Сцена экрана блокировки (общая для реального и debug режимов).
// Фон: стоп-кадр экрана на момент блокировки (/tmp/qs-lock-bg.png, готовит
// лаунчер metro-lock; фолбэк — обои) + MultiEffect blur.
// Центр: сетка тайлов + карточка входа.
Item {
    id: root

    property bool debug: false
    signal finished()

    // ─── состояние ───────────────────────────────────────────────────────
    property string userName: ""
    property string hostName: ""
    property int attempts: 0
    property bool busy: false              // PAM-проверка идёт
    property bool capsOn: false            // best effort: трекинг клавиши CapsLock
    property string errorMsg: ""
    property bool accountMsg: false
    readonly property bool fakeOk: Quickshell.env("METRO_LOCK_FAKE_OK") === "1"

    // ─── время ───────────────────────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function greeting() {
        const h = root.now.getHours()
        if (h >= 5 && h < 11) return "доброе утро"
        if (h >= 11 && h < 17) return "добрый день"
        if (h >= 17 && h < 23) return "добрый вечер"
        return "доброй ночи"
    }

    function ruDate(d) {
        const days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
    }

    // ─── PAM ─────────────────────────────────────────────────────────────
    function submit() {
        if (root.busy || root.out)
            return
        if (field.text === "") {
            root.showError("введите пароль")
            return
        }
        if (root.fakeOk) {                 // debug: имитация успеха
            root.busy = true
            fakeTimer.start()
            return
        }
        root.busy = true
        if (!pam.start())
            root.authFailed()
    }

    function authFailed() {
        root.busy = false
        if (root.accountMsg)
            return                      // сообщение PAM (faillock) уже показано
        root.attempts++
        root.showError("неверный пароль · попытка " + root.attempts)
    }

    function showError(msg) {
        root.errorMsg = msg
        fieldBg.border.color = Theme.red
        errorReset.restart()
    }

    function finish() {
        if (root.out) return
        root.out = true
        field.enabled = false
        outTimer.start()                   // гасим 300мс → сигнал хосту (unlock)
    }

    property bool out: false
    Timer { id: outTimer; interval: 300; onTriggered: root.finished() }
    Timer { id: errorReset; interval: 4000; onTriggered: { root.errorMsg = ""; root.accountMsg = false; fieldBg.border.color = field.activeFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.12) } }
    Timer { id: fakeTimer; interval: 450; onTriggered: root.finish() }

    PamContext {
        id: pam
        config: "hyprlock"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(field.text)
            else if (pam.messageIsError && pam.message !== "") {
                root.accountMsg = true     // напр. «аккаунт заблокирован, осталось N минут»
                root.showError(pam.message)
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success)
                root.finish()
            else
                root.authFailed()
            field.text = ""
        }
        onError: error => {
            root.busy = false
            root.showError("ошибка аутентификации")
        }
    }

    // ─── раскладка тайлов (сетка Theme, как в шелле) ─────────────────────
    readonly property var lockTiles: [
        { "type": "clock", "w": 2, "h": 2, "x": 0, "y": 0 },
        { "type": "greet", "w": 2, "h": 1, "x": 2, "y": 0 },
        { "type": "weather", "w": 1, "h": 1, "x": 4, "y": 0 },
        { "type": "media", "w": 2, "h": 1, "x": 2, "y": 1 },
        { "type": "battery", "w": 1, "h": 1, "x": 4, "y": 1 }
    ]

    // ─── фон: стоп-кадр + blur ───────────────────────────────────────────
    Image {
        id: bgImg
        anchors { fill: parent; margins: -48 }
        source: "file:///tmp/qs-lock-bg.png"
        fillMode: Image.PreserveAspectCrop
        visible: false
        opacity: root.out ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    MultiEffect {
        anchors { fill: bgImg }
        source: bgImg
        blurEnabled: true
        blur: 0.45
        blurMax: 64
        brightness: -0.15
        saturation: -0.12
        contrast: 0.08
        opacity: bgImg.opacity
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.out ? 0 : 0.35
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // ─── центральная колонна: сетка тайлов + карточка входа ──────────────
    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -26
        spacing: 26
        opacity: root.out ? 0 : 1
        scale: root.out ? 0.96 : 1
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InQuad } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.InQuad } }

        // сетка тайлов
        Item {
            width: Theme.tileW(5)
            height: Theme.tileH(2)

            Repeater {
                model: root.lockTiles

                delegate: Item {
                    id: tileWrap
                    required property var modelData
                    required property int index
                    x: modelData.x * (Theme.unit + Theme.gap)
                    y: modelData.y * (Theme.unit + Theme.gap)
                    width: Theme.tileW(modelData.w)
                    height: Theme.tileH(modelData.h)

                    // stagger-вход
                    opacity: 0
                    transform: Translate { id: entT; y: 24 }
                    SequentialAnimation {
                        running: true
                        PauseAnimation { duration: tileWrap.index * 55 }
                        ParallelAnimation {
                            NumberAnimation { target: tileWrap; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: entT; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: tileWrap.modelData.type === "clock" ? clockTile :
                                         tileWrap.modelData.type === "greet" ? greetTile :
                                         tileWrap.modelData.type === "weather" ? weatherTile :
                                         tileWrap.modelData.type === "media" ? mediaTile : batteryTile
                    }
                }
            }
        }

        // карточка входа
        Rectangle {
            id: card
            width: 450
            height: 246
            radius: Theme.panelRadius
            color: Qt.rgba(255, 255, 255, 0.06)
            border.width: 1
            border.color: Theme.stroke
            anchors.horizontalCenter: parent.horizontalCenter

            opacity: 0
            transform: [
                Translate { id: cardT; y: 36 },
                Translate { id: shakeT; x: 0 }
            ]
            SequentialAnimation {
                running: true
                PauseAnimation { duration: 180 }
                ParallelAnimation {
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { target: cardT; property: "y"; to: 0; duration: 300; easing.type: Easing.OutCubic }
                }
            }

            SequentialAnimation {
                id: shakeAnim
                property int dist: 9
                NumberAnimation { target: shakeT; property: "x"; to: shakeAnim.dist; duration: 45; easing.type: Easing.OutCubic }
                NumberAnimation { target: shakeT; property: "x"; to: -shakeAnim.dist; duration: 45; easing.type: Easing.OutCubic }
                NumberAnimation { target: shakeT; property: "x"; to: shakeAnim.dist * 0.6; duration: 45; easing.type: Easing.OutCubic }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45; easing.type: Easing.OutCubic }
            }

            // аватар (~/.config/avatar.jpeg), фолбэк — буква
            Item {
                id: avatar
                width: 84; height: 84
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20

                Rectangle {
                    anchors.fill: parent
                    radius: 42
                    color: Theme.glass
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "file://" + Quickshell.env("HOME") + "/.config/avatar.jpeg"
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                Rectangle {
                    id: avatarMask
                    anchors.fill: avatarImg
                    radius: 40
                    visible: false
                }
                Qt5Compat.OpacityMask {
                    anchors.fill: avatarImg
                    source: avatarImg
                    maskSource: avatarMask
                    visible: avatarImg.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: root.userName.charAt(0).toUpperCase() || "?"
                    font.family: Theme.fontFamily
                    font.pixelSize: 36
                    font.weight: Font.Light
                    color: Theme.text
                    visible: avatarImg.status !== Image.Ready
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 112
                text: root.userName.toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                color: Qt.rgba(1, 1, 1, 0.85)
            }

            // поле пароля
            Rectangle {
                id: fieldBg
                width: 340; height: 50
                anchors.horizontalCenter: parent.horizontalCenter
                y: 142
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: 1
                border.color: field.activeFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: field
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    clip: true
                    enabled: !root.busy
                    focus: true

                    onAccepted: root.submit()
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_CapsLock) {
                            root.capsOn = !root.capsOn
                            e.accepted = true
                        }
                    }

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    verticalAlignment: Text.AlignVCenter
                    text: root.busy ? "проверка…" : "пароль"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: root.busy ? Theme.alpha(Theme.accent, 0.7) : Qt.rgba(1, 1, 1, 0.40)
                    visible: field.text === ""
                }
            }

            Text {
                width: parent.width - 36
                anchors.horizontalCenter: parent.horizontalCenter
                y: 200
                text: root.errorMsg
                font.family: Theme.fontFamily
                font.pixelSize: root.accountMsg ? 11 : 13
                font.italic: true
                color: root.accountMsg ? Theme.orange : "#ff6b60"
                visible: root.errorMsg !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Behavior on opacity { NumberAnimation { duration: 150 } }
                opacity: root.errorMsg !== "" ? 1 : 0
            }
        }
    }

    // ─── компоненты тайлов ───────────────────────────────────────────────

    // hero-часы
    Component {
        id: clockTile

        Rectangle {
            radius: Theme.radius
            color: Theme.alpha(Theme.accent, 0.92)

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "HH:mm")
                    font.family: "Segoe UI Variable Static Display Light"
                    font.pixelSize: 60
                    color: Theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.ruDate(root.now)
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.80)
                }
            }

            // секундная полоска
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 10
                }
                height: 3
                color: Qt.rgba(1, 1, 1, 0.55)
                width: parent.width * (root.now.getSeconds() / 60)
                Behavior on width { NumberAnimation { duration: 950; easing.type: Easing.Linear } }
            }
        }
    }

    // «привет, $USER»
    Component {
        id: greetTile

        Rectangle {
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            Column {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 2

                Text {
                    text: root.greeting() + ","
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: Theme.textDim
                }

                Text {
                    text: root.userName || "user"
                    font.family: Theme.fontFamily
                    font.pixelSize: 30
                    font.weight: Font.Light
                    color: Theme.text
                }
            }
        }
    }

    // погода: текущая, без раскрытия
    Component {
        id: weatherTile

        Rectangle {
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.loaded ? Weather.glyph(Weather.code) : "\uf042"
                    font.family: Theme.iconFont
                    font.pixelSize: 28
                    color: Theme.accent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.loaded ? Math.round(Weather.temp) + "°" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.Light
                    color: Theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.cityName
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Theme.textDim
                    elide: Text.ElideRight
                    width: Theme.unit - 16
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // медиа: MPRIS, клик = play/pause
    Component {
        id: mediaTile

        Rectangle {
            id: mediaBg
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            readonly property bool hasArt: Media.artUrl !== "" && artImg.status === Image.Ready

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.act("play-pause")
            }

            // idle: приглушённая нота
            Text {
                anchors.centerIn: parent
                text: "\uf001"
                font.family: Theme.iconFont
                font.pixelSize: 26
                color: Qt.rgba(1, 1, 1, 0.22)
                visible: Media.idle
            }

            Row {
                anchors { fill: parent; margins: 12 }
                spacing: 12
                visible: !Media.idle

                Item {
                    width: 56; height: 56
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        visible: false
                    }
                    Qt5Compat.OpacityMask {
                        anchors.fill: parent
                        source: artImg
                        maskSource: artMask
                        visible: mediaBg.hasArt
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.glass
                        visible: !mediaBg.hasArt
                        Text {
                            anchors.centerIn: parent
                            text: "\uf001"
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: Theme.alpha(Theme.accent, 0.6)
                        }
                    }
                }

                Column {
                    width: parent.width - 68
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: Media.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Media.artist
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.75)
                        elide: Text.ElideRight
                    }
                }
            }

            // прогресс
            Rectangle {
                visible: !Media.idle && Media.length > 0
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 10
                }
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: parent.width * Math.min(1, Media.pos / Media.length)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                }
            }
        }
    }

    // батарея
    Component {
        id: batteryTile

        Rectangle {
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.batteryPct >= 0 ? root.batteryPct + "%" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    font.weight: Font.Light
                    color: root.batteryPct < 0 ? Theme.textDim :
                           root.batteryPct < 20 ? Theme.red :
                           root.batteryPct < 35 ? Theme.orange : Theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "батарея"
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Theme.textDim
                }
            }
        }
    }

    // ─── нижний статус-бар ──────────────────────────────────────────────
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 26 }
        height: 20
        opacity: root.out ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: root.userName && root.hostName ? root.userName + "@" + root.hostName : ""
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Light
            color: Qt.rgba(1, 1, 1, 0.50)
        }

        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.batteryPct >= 0 ? "BAT " + root.batteryPct + "%" : ""
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Light
            color: Qt.rgba(1, 1, 1, 0.50)
        }
    }

    // ─── чип CAPS LOCK ──────────────────────────────────────────────────
    Rectangle {
        visible: root.capsOn
        anchors { bottom: parent.bottom; bottomMargin: 60; horizontalCenter: parent.horizontalCenter }
        width: capsRow.implicitWidth + 28
        height: 38
        radius: Theme.radiusSmall
        color: Qt.rgba(0.04, 0.04, 0.06, 0.85)
        border.width: 1
        border.color: Theme.stroke

        Row {
            id: capsRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle { width: 8; height: 8; radius: 2; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CAPS LOCK"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }
        }
    }

    // ─── debug-бейдж + Esc = выход в debug ───────────────────────────────
    Rectangle {
        visible: root.debug
        anchors { top: parent.top; topMargin: 14; left: parent.left; leftMargin: 14 }
        width: dbgRow.implicitWidth + 20
        height: 26
        radius: 6
        color: Qt.rgba(0.04, 0.04, 0.06, 0.7)
        border.width: 1
        border.color: Theme.stroke

        Row {
            id: dbgRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle { width: 6; height: 6; radius: 3; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "DEBUG · ESC = выход"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1
                color: Theme.textDim
            }
        }
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape && root.debug) {
            root.finished()
            e.accepted = true
        } else if (e.key === Qt.Key_CapsLock) {
            root.capsOn = !root.capsOn
            e.accepted = true
        }
    }

    // ─── данные: user@host, батарея ──────────────────────────────────────
    property int batteryPct: -1

    Process {
        id: pUser
        command: ["sh", "-c", "whoami; hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n")
                root.userName = (p[0] || "").trim()
                root.hostName = (p[1] || "").trim()
            }
        }
        running: true
    }

    Process {
        id: pBat
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim())
                if (!isNaN(v))
                    root.batteryPct = v
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pBat.running = true
    }

    Component.onCompleted: focusTimer.start()
    Timer {
        id: focusTimer
        interval: 120
        onTriggered: field.forceActiveFocus()
    }
}

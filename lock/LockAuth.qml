import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects as Qt5Compat

// Блок входа на экране блокировки: аватар + имя + пилюля пароля.
// Виджет сетки (тип auth), размеры 5x3 / 4x2 / 3x2 / 2x2 / 3x1 / 2x1
// (только горизонталь и квадрат). Неудаляемый, перетаскиваемый.
Item {
    id: root

    property string userName: ""
    property bool busy: false
    property string errorMsg: ""
    property bool accountMsg: false
    property bool capsOn: false
    property bool locked: false          // edit-режим или fade-out: ввод глушим
    property string pwd: ""
    property bool showPwd: false

    signal accepted()
    signal editRequested()
    signal capsPressed()

    readonly property bool isRow: height < 130
    readonly property bool isHero: width >= 400 && height >= 200
    readonly property bool isNarrow: width < 200
    readonly property bool hasError: errorMsg !== ""
    readonly property bool fieldFocus: colField.activeFocus || rowField.activeFocus

    function focusField() {
        if (root.locked)
            return
        (isRow ? rowField : colField).forceActiveFocus()
    }

    function shake() {
        shakeAnim.start()
    }

    onPwdChanged: {
        if (colField.text !== root.pwd)
            colField.text = root.pwd
        if (rowField.text !== root.pwd)
            rowField.text = root.pwd
        typePulse.restart()   // отклик на каждое нажатие
    }

    onHasErrorChanged: {
        if (hasError)
            errPop.restart()
    }

    // пульс пилюли при печатании
    SequentialAnimation {
        id: typePulse
        NumberAnimation { target: isRow ? rowPill : colPill; property: "scale"; to: 1.018; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: isRow ? rowPill : colPill; property: "scale"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
    }

    // попин текста ошибки
    SequentialAnimation {
        id: errPop
        NumberAnimation { target: errText; property: "scale"; from: 0.9; to: 1.0; duration: 160; easing.type: Easing.OutBack }
    }

    // фон карточки
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.isHero ? Theme.panelRadius : Theme.radius
        color: Qt.rgba(255, 255, 255, 0.06)
        border.width: 1
        border.color: root.hasError ? Theme.red : Theme.stroke
        transform: Translate { id: shakeT; x: 0 }

        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // акцентное свечение при фокусе поля
    Rectangle {
        anchors.fill: bg
        anchors.margins: -1.5
        radius: bg.radius + 1.5
        color: "transparent"
        border.width: 1.5
        border.color: Theme.alpha(Theme.accent, 0.45)
        opacity: root.fieldFocus && !root.hasError ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    SequentialAnimation {
        id: shakeAnim
        property int dist: 9
        NumberAnimation { target: shakeT; property: "x"; to: shakeAnim.dist; duration: 45; easing.type: Easing.OutCubic }
        NumberAnimation { target: shakeT; property: "x"; to: -shakeAnim.dist; duration: 45; easing.type: Easing.OutCubic }
        NumberAnimation { target: shakeT; property: "x"; to: shakeAnim.dist * 0.6; duration: 45; easing.type: Easing.OutCubic }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45; easing.type: Easing.OutCubic }
    }

    // долгий клик по стеклу = edit-режим (лежит под контентом)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onPressAndHold: root.editRequested()
    }

    // ── вариант-колонка (все размеры с h >= 2) ──────────────────────
    Column {
        visible: !root.isRow
        anchors.centerIn: parent
        width: parent.width - (root.isNarrow ? 20 : root.isHero ? 56 : 32)
        spacing: root.isHero ? 10 : 6

        Item {
            id: avatar
            width: root.isHero ? 76 : root.isNarrow ? 44 : 56
            height: width
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.glass
                border.width: 2
                border.color: root.fieldFocus ? Theme.alpha(Theme.accent, 0.7) : Qt.rgba(1, 1, 1, 0.14)
                Behavior on border.color { ColorAnimation { duration: 150 } }
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
                radius: (avatar.width - 4) / 2
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
                font.pixelSize: root.isHero ? 30 : 22
                font.weight: Font.Light
                color: Theme.text
                visible: avatarImg.status !== Image.Ready
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.userName.toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: root.isNarrow ? 12 : root.isHero ? 16 : 14
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            color: Qt.rgba(1, 1, 1, 0.85)
            elide: Text.ElideRight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        // пилюля пароля (колоночная)
        Rectangle {
            id: colPill
            width: parent.width
            height: root.isHero ? 52 : 46
            radius: height / 2
            color: Theme.glass
            border.width: 1
            border.color: root.hasError ? Theme.red : root.fieldFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors { fill: parent; leftMargin: root.isNarrow ? 10 : 16; rightMargin: 8 }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf023"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: root.hasError ? Theme.red : root.fieldFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.35)
                    visible: !root.isNarrow
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextInput {
                    id: colField
                    width: parent.width - (root.isNarrow ? 76 : 96)
                    anchors.verticalCenter: parent.verticalCenter
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.showPwd ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    // сам текст скрыт — точки рисует оверлей dotsRow с попином
                    color: root.showPwd ? Theme.text : "transparent"
                    cursorDelegate: Rectangle {
                        width: 2
                        height: 19
                        color: Theme.accent
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    clip: true
                    enabled: !root.busy && !root.locked
                    text: root.pwd

                    onTextChanged: if (activeFocus) root.pwd = text
                    onAccepted: root.accepted()
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_CapsLock) {
                            root.capsPressed()
                            e.accepted = true
                        }
                    }

                    // анимированные точки: каждая новая попинится
                    Item {
                        anchors.fill: parent
                        clip: true
                        visible: !root.showPwd && root.pwd.length > 0
                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            spacing: 0
                            Repeater {
                                model: root.pwd.length
                                delegate: Text {
                                    text: "●"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    color: Theme.text
                                    NumberAnimation on scale {
                                        from: 0.3
                                        to: 1.0
                                        duration: 150
                                        easing.type: Easing.OutBack
                                        running: true
                                    }
                                    NumberAnimation on opacity {
                                        from: 0.2
                                        to: 1.0
                                        duration: 110
                                        running: true
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf071"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: Theme.orange
                    visible: root.capsOn && !root.busy
                }

                // глаз
                Item {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: root.showPwd ? "\uf070" : "\uf06e"
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: eyeMa.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.40)
                    }
                    MouseArea {
                        id: eyeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPwd = !root.showPwd
                    }
                }

                // стрелка входа / спиннер
                Rectangle {
                    width: 30; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 15
                    color: goMa.containsMouse || goMa.pressed ? Theme.alpha(Theme.accent, 1.0) : Theme.alpha(Theme.accent, 0.85)
                    scale: goMa.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                    Text {
                        id: goGlyph
                        anchors.centerIn: parent
                        text: root.busy ? "\uf110" : "\uf061"
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: "#ffffff"
                    }
                    RotationAnimation on rotation {
                        target: goGlyph
                        running: root.busy
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }
                    MouseArea {
                        id: goMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.accepted()
                    }
                }
            }

            Text {
                anchors { fill: parent; leftMargin: root.isNarrow ? 10 : 42; rightMargin: 70 }
                verticalAlignment: Text.AlignVCenter
                text: root.busy ? I18n.t("checking") : I18n.t("password")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.letterSpacing: 1
                color: root.busy ? Theme.alpha(Theme.accent, 0.8) : Qt.rgba(1, 1, 1, 0.40)
                opacity: root.pwd === "" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        Text {
            id: errText
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.errorMsg
            font.family: Theme.fontFamily
            font.pixelSize: root.accountMsg ? 11 : 12
            font.italic: true
            color: root.accountMsg ? Theme.orange : "#ff6b60"
            visible: root.errorMsg !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // ── вариант-строка (2x1 / 3x1) ─────────────────────────────────
    Row {
        visible: root.isRow
        anchors { fill: parent; margins: 10 }
        spacing: 10

        Item {
            width: 40; height: 40
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Theme.glass
                border.width: 2
                border.color: root.fieldFocus ? Theme.alpha(Theme.accent, 0.7) : Qt.rgba(1, 1, 1, 0.14)
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            Image {
                id: avatarImgRow
                anchors.fill: parent
                anchors.margins: 2
                source: "file://" + Quickshell.env("HOME") + "/.config/avatar.jpeg"
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            Rectangle {
                id: avatarMaskRow
                anchors.fill: avatarImgRow
                radius: 18
                visible: false
            }
            Qt5Compat.OpacityMask {
                anchors.fill: avatarImgRow
                source: avatarImgRow
                maskSource: avatarMaskRow
                visible: avatarImgRow.status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: root.userName.charAt(0).toUpperCase() || "?"
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.Light
                color: Theme.text
                visible: avatarImgRow.status !== Image.Ready
            }
        }

        Column {
            width: parent.width - 50
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.userName.toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
                color: Qt.rgba(1, 1, 1, 0.55)
                elide: Text.ElideRight
                width: parent.width
            }

            Rectangle {
                id: rowPill
                width: parent.width
                height: 38
                radius: 19
                color: Theme.glass
                border.width: 1
                border.color: root.hasError ? Theme.red : root.fieldFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                    spacing: 6

                    TextInput {
                        id: rowField
                        width: parent.width - (root.capsOn && !root.busy ? 100 : 76)
                        anchors.verticalCenter: parent.verticalCenter
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.showPwd ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        color: root.showPwd ? Theme.text : "transparent"
                        cursorDelegate: Rectangle {
                            width: 2
                            height: 17
                            color: Theme.accent
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        clip: true
                        enabled: !root.busy && !root.locked
                        text: root.pwd

                        onTextChanged: if (activeFocus) root.pwd = text
                        onAccepted: root.accepted()
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_CapsLock) {
                                root.capsPressed()
                                e.accepted = true
                            }
                        }

                        Item {
                            anchors.fill: parent
                            clip: true
                            visible: !root.showPwd && root.pwd.length > 0
                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                spacing: 0
                                Repeater {
                                    model: root.pwd.length
                                    delegate: Text {
                                        text: "●"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        color: Theme.text
                                        NumberAnimation on scale {
                                            from: 0.3
                                            to: 1.0
                                            duration: 150
                                            easing.type: Easing.OutBack
                                            running: true
                                        }
                                        NumberAnimation on opacity {
                                            from: 0.2
                                            to: 1.0
                                            duration: 110
                                            running: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf071"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: Theme.orange
                        visible: root.capsOn && !root.busy
                    }

                    Item {
                        width: 22; height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: root.showPwd ? "\uf070" : "\uf06e"
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: eyeMaRow.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.40)
                        }
                        MouseArea {
                            id: eyeMaRow
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showPwd = !root.showPwd
                        }
                    }

                    Rectangle {
                        width: 26; height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 13
                        color: goMaRow.containsMouse || goMaRow.pressed ? Theme.alpha(Theme.accent, 1.0) : Theme.alpha(Theme.accent, 0.85)
                        scale: goMaRow.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                        Text {
                            id: goGlyphRow
                            anchors.centerIn: parent
                            text: root.busy ? "\uf110" : "\uf061"
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: "#ffffff"
                        }
                        RotationAnimation on rotation {
                            target: goGlyphRow
                            running: root.busy
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                        MouseArea {
                            id: goMaRow
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.accepted()
                        }
                    }
                }

                Text {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 66 }
                    verticalAlignment: Text.AlignVCenter
                    text: root.busy ? I18n.t("checking") : (root.hasError ? root.errorMsg : I18n.t("password"))
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: root.busy ? Theme.alpha(Theme.accent, 0.8) : root.hasError ? "#ff6b60" : Qt.rgba(1, 1, 1, 0.40)
                    opacity: root.pwd === "" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                    elide: Text.ElideRight
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as Qt5Compat

// Сцена экрана блокировки (общая для реального и debug режимов).
// Фон: текущие обои (копия в $XDG_RUNTIME_DIR/qs-lock-bg.png, готовит
// лаунчер metro-lock через METRO_LOCK_BG; если обоев нет — тёмная заливка)
// + MultiEffect blur.
// Центр: редактируемая сетка тайлов (lock-layout.json), блок входа —
// виджет auth (LockAuth.qml): перетаскивается, ресайз 5x3…2x1,
// только горизонталь и квадрат.
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

    // ─── сетка виджетов ──────────────────────────────────────────────────
    property var layout: []
    property int contentH: 0
    property bool editMode: false
    property var authItem: null
    // поле 12x10 по центру экрана
    readonly property int cols: 12
    readonly property int rows: 10
    readonly property int step: Theme.unit + Theme.gap
    readonly property var packed: repack()

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
        if (h >= 5 && h < 11) return I18n.t("good_morning")
        if (h >= 11 && h < 17) return I18n.t("good_afternoon")
        if (h >= 17 && h < 23) return I18n.t("good_evening")
        return I18n.t("good_night")
    }

    function ruDate(d) {
        if (I18n.lang === "ru") {
            const days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
            const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
            return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
        } else {
            const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
        }
    }

    // ─── раскладка: дефолт, пак, драг ────────────────────────────────────
    function defaultLockLayout() {
        return [
            { "type": "auth", "w": 3, "h": 2, "x": 3, "y": 0 },
            { "type": "clock", "w": 2, "h": 2, "x": 6, "y": 0 },
            { "type": "weather", "w": 1, "h": 1, "x": 8, "y": 0 },
            { "type": "battery", "w": 1, "h": 1, "x": 8, "y": 1 },
            { "type": "media", "w": 3, "h": 1, "x": 3, "y": 2 },
            { "type": "sysinfo", "w": 3, "h": 1, "x": 6, "y": 2 }
        ]
    }

    // auth ровно один: нет — добавляем, несколько — оставляем первый
    function ensureAuth(l) {
        let seen = false
        const out = []
        for (let i = 0; i < l.length; i++) {
            if (l[i].type === "auth") {
                if (seen)
                    continue
                seen = true
            }
            out.push(l[i])
        }
        if (!seen)
            out.unshift({ "type": "auth", "w": 3, "h": 2 })
        return out
    }

    function rectHitsInit(occ, cx, cy, w, h) {
        for (let yy = cy; yy < cy + h; yy++)
            for (let xx = cx; xx < cx + w; xx++)
                if (occ[xx + "," + yy])
                    return true
        return false
    }

    // явная сетка: x/y у виджета, отсутствуют → auto first-fit
    function packGrid(lay) {
        const occupied = ({})
        const pos = []
        const pending = []
        for (let i = 0; i < lay.length; i++) {
            const it = lay[i]
            const w = it.w || 1
            const h = it.h || 1
            if (it.x !== undefined && it.y !== undefined && it.x >= 0 && it.y >= 0 && it.x + w <= cols && !rectHitsInit(occupied, it.x, it.y, w, h)) {
                for (let yy = it.y; yy < it.y + h; yy++)
                    for (let xx = it.x; xx < it.x + w; xx++)
                        occupied[xx + "," + yy] = true
                pos[i] = { "x": it.x, "y": it.y }
            } else {
                pending.push(i)
            }
        }
        for (let p = 0; p < pending.length; p++) {
            const i = pending[p]
            const w = lay[i].w || 1
            const h = lay[i].h || 1
            for (let cy = 0; cy + h <= root.rows; cy++) {
                let done = false
                for (let cx = 0; cx + w <= cols; cx++) {
                    if (!rectHitsInit(occupied, cx, cy, w, h)) {
                        for (let yy = cy; yy < cy + h; yy++)
                            for (let xx = cx; xx < cx + w; xx++)
                                occupied[xx + "," + yy] = true
                        pos[i] = { "x": cx, "y": cy }
                        done = true
                        break
                    }
                }
                if (done)
                    break
            }
        }
        let bottom = 0
        const out = []
        for (let i = 0; i < lay.length; i++) {
            const it = lay[i]
            const p = pos[i]
            if (!p)
                continue
            const w = it.w || 1
            const h = it.h || 1
            out.push({
                "i": i,
                "gx": p.x,
                "gy": p.y,
                "uw": w,
                "uh": h,
                "type": it.type,
                "x": p.x * step,
                "y": p.y * step,
                "w": Theme.tileW(w),
                "h": Theme.tileH(h)
            })
            bottom = Math.max(bottom, p.y * step + Theme.tileH(h))
        }
        return { "cells": out, "bottom": bottom }
    }

    function repack() {
        const r = packGrid(layout)
        contentH = r.bottom
        return r.cells
    }

    function rectHits(cx, cy, w, h, skipIdx) {
        const list = packed
        for (let k = 0; k < list.length; k++) {
            const o = list[k]
            if (o.i === skipIdx)
                continue
            if (cx < o.gx + o.uw && cx + w > o.gx && cy < o.gy + o.uh && cy + h > o.gy)
                return o
        }
        return null
    }

    function nearestFree(w, h, gcx, gry, skipIdx) {
        for (let r = 0; r < 60; r++) {
            for (let dy = -r; dy <= r; dy++) {
                const span = r - Math.abs(dy)
                for (let s = -span; s <= span; s++) {
                    const cx = gcx + s
                    const cy = gry + dy
                    if (cx < 0 || cy < 0 || cx + w > cols || cy + h > root.rows)
                        continue
                    if (!rectHits(cx, cy, w, h, skipIdx))
                        return { "x": cx, "y": cy }
                }
            }
        }
        return null
    }

    // Допустимые размеры. Первый элемент = дефолт для addWidget.
    // auth: только горизонталь и квадрат (w >= h), от 5x3 до 2x1.
    // Остальные виджеты: все разумные размеры, у каждого есть раскладка.
    function allowedSizes(type) {
        if (type === "auth")
            return [[3, 2], [5, 3], [4, 2], [2, 1], [3, 1], [2, 2]]
        if (type === "clock")
            return [[2, 2], [1, 1], [2, 1], [1, 2], [3, 2], [3, 1]]
        if (type === "weather")
            return [[1, 1], [2, 1], [1, 2], [2, 2], [3, 2], [3, 1]]
        if (type === "media")
            return [[3, 1], [2, 1], [1, 1], [2, 2], [3, 2], [1, 2]]
        if (type === "battery")
            return [[1, 1], [2, 1], [1, 2], [2, 2], [3, 1]]
        if (type === "greet")
            return [[2, 1], [3, 1], [4, 1], [2, 2]]
        if (type === "date")
            return [[2, 2], [1, 1], [2, 1], [3, 2], [3, 1], [1, 2]]
        if (type === "power")
            return [[3, 1], [4, 1], [2, 1], [2, 2]]
        if (type === "sysinfo")
            return [[3, 1], [2, 1], [4, 1], [3, 2], [2, 2]]
        return [[1, 1]]
    }

    // ── drag&drop ──
    property int dragIdx: -1
    property point dropTL: Qt.point(0, 0)

    function dropSpec(selfIdx, tlx, tly) {
        const it = layout[selfIdx]
        if (!it)
            return null
        const w = it.w || 1
        const h = it.h || 1
        const gcx = Math.max(0, Math.min(cols - w, Math.round(tlx / step)))
        const gry = Math.max(0, Math.min(root.rows - h, Math.round(tly / step)))
        let cur = null
        const list = packed
        for (let k = 0; k < list.length; k++) {
            if (list[k].i === selfIdx) {
                cur = list[k]
                break
            }
        }
        if (cur && cur.gx === gcx && cur.gy === gry)
            return null
        const hit = rectHits(gcx, gry, w, h, selfIdx)
        if (!hit)
            return { "mode": "move", "a": selfIdx, "x": gcx, "y": gry }
        if (hit.uw === w && hit.uh === h)
            return { "mode": "swap", "a": selfIdx, "b": hit.i }
        const spot = nearestFree(w, h, gcx, gry, selfIdx)
        if (!spot || (cur && spot.x === cur.gx && spot.y === cur.gy))
            return null
        return { "mode": "move", "a": selfIdx, "x": spot.x, "y": spot.y }
    }

    function buildPreview(spec) {
        const hy = []
        for (let j = 0; j < layout.length; j++)
            hy.push(Object.assign({}, layout[j]))
        if (spec.mode === "swap") {
            const a = Object.assign({}, hy[spec.a])
            const b = Object.assign({}, hy[spec.b])
            const tx = a.x
            const ty = a.y
            a.x = b.x
            a.y = b.y
            b.x = tx
            b.y = ty
            hy[spec.a] = a
            hy[spec.b] = b
        } else {
            hy[spec.a] = Object.assign({}, hy[spec.a], {
                "x": spec.x,
                "y": spec.y
            })
        }
        const p = packGrid(hy)
        const map = ({})
        let ghost = null
        for (let m = 0; m < p.cells.length; m++) {
            const c = p.cells[m]
            map[c.i] = { "x": c.x, "y": c.y }
            if (c.i === dragIdx)
                ghost = { "x": c.x, "y": c.y, "w": c.w, "h": c.h }
        }
        return { "map": map, "ghost": ghost }
    }

    readonly property var dragPreview: {
        if (dragIdx < 0 || dragIdx >= layout.length)
            return null
        const spec = dropSpec(dragIdx, dropTL.x, dropTL.y)
        return spec ? buildPreview(spec) : null
    }

    function removeWidget(i) {
        if (layout[i] && layout[i].type === "auth")
            return
        const l = layout.slice()
        l.splice(i, 1)
        saveLayout(l)
        layout = l
    }

    function resizeWidget(i, w, h) {
        let cur = null
        const list = packed
        for (let k = 0; k < list.length; k++) {
            if (list[k].i === i) {
                cur = list[k]
                break
            }
        }
        const l = layout.slice()
        const upd = Object.assign({}, l[i], { "w": w, "h": h })
        if (cur && rectHits(cur.gx, cur.gy, w, h, i)) {
            const spot = nearestFree(w, h, cur.gx, cur.gy, i)
            if (spot) {
                upd.x = spot.x
                upd.y = spot.y
            }
        }
        l[i] = upd
        saveLayout(l)
        layout = l
    }

    function addWidget(type) {
        if (type === "auth") {
            for (let i = 0; i < layout.length; i++)
                if (layout[i].type === "auth")
                    return
        }
        const sizes = allowedSizes(type)
        const l = layout.concat([{ "type": type, "w": sizes[0][0], "h": sizes[0][1] }])
        saveLayout(l)
        layout = l
    }

    function resetLayout() {
        const l = defaultLockLayout()
        saveLayout(l)
        layout = l
    }

    function compactLayout() {
        const l = layout.map(it => {
            const copy = Object.assign({}, it)
            delete copy.x
            delete copy.y
            return copy
        })
        const r = packGrid(l)
        const updated = []
        for (let i = 0; i < l.length; i++) {
            const cell = r.cells.find(c => c.i === i)
            const item = Object.assign({}, l[i])
            if (cell) {
                item.x = cell.gx
                item.y = cell.gy
            }
            updated.push(item)
        }
        saveLayout(updated)
        layout = updated
    }

    // write first, then assign: reassigning the layout rebuilds the Repeater
    // and kills the calling delegate mid-handler
    function saveLayout(arr) {
        const json = JSON.stringify(arr !== undefined ? arr : layout)
        pLayoutWrite.command = ["sh", "-c", "cat > \"$HOME/.config/quickshell/metro/lock-layout.json\" << 'QSEOF'\n" + json + "\nQSEOF"]
        pLayoutWrite.running = true
    }

    // ─── PAM ─────────────────────────────────────────────────────────────
    function submit() {
        if (root.busy || root.out || root.editMode)
            return
        const t = root.authItem ? root.authItem.pwd : ""
        if (t === "") {
            root.showError(I18n.t("enter_password"))
            if (root.authItem)
                root.authItem.focusField()
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
        root.showError(I18n.t("wrong_password") + root.attempts)
    }

    function showError(msg) {
        root.errorMsg = msg
        if (root.authItem) {
            root.authItem.shake()
            root.authItem.focusField()
        }
        errorReset.restart()
    }

    function finish() {
        if (root.out) return
        root.out = true
        outTimer.start()                   // гасим 300мс → сигнал хосту (unlock)
    }

    property bool out: false
    Timer { id: outTimer; interval: 300; onTriggered: root.finished() }
    Timer { id: errorReset; interval: 4000; onTriggered: { root.errorMsg = ""; root.accountMsg = false } }
    Timer { id: fakeTimer; interval: 450; onTriggered: root.finish() }

    PamContext {
        id: pam
        config: "hyprlock"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.authItem ? root.authItem.pwd : "")
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
            if (root.authItem)
                root.authItem.pwd = ""
        }
        onError: error => {
            root.busy = false
            root.showError(I18n.t("auth_error"))
        }
    }

    // ─── фон: обои + blur ──────────────────────────────────────────────
    // Путь прилетает от лаунчера через env METRO_LOCK_BG; пусто = нет обоев.
    readonly property string bgFile: Quickshell.env("METRO_LOCK_BG")
    Image {
        id: bgImg
        anchors { fill: parent; margins: -48 }
        source: root.bgFile !== "" ? "file://" + root.bgFile : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        opacity: root.out ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // Лёгкий блюр под стекло: обои читаются, а не «мыло».
    // (на session-lock композитор не блюрит — только MultiEffect)
    MultiEffect {
        anchors { fill: bgImg }
        source: bgImg
        blurEnabled: true
        blur: 0.12
        blurMax: 64
        brightness: -0.05
        saturation: -0.03
        contrast: 0.02
        opacity: bgImg.opacity
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.out ? 0 : 0.28
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // ─── центральная колонна: сетка тайлов ─────────────────────────────
    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -26
        spacing: 26
        opacity: root.out ? 0 : 1
        scale: root.out ? 0.96 : 1
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InQuad } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.InQuad } }

        Item {
            id: gridHost
            width: Theme.tileW(root.cols)
            height: Math.max(root.contentH, Theme.tileH(1))
            anchors.horizontalCenter: parent.horizontalCenter

            // ghost целевой позиции при драге
            Rectangle {
                id: dropGhost
                z: -1
                visible: root.editMode && root.dragPreview && root.dragPreview.ghost !== null
                radius: Theme.radius
                color: Theme.alpha(Theme.accent, 0.10)
                border.width: 1.5
                border.color: Theme.alpha(Theme.accent, 0.65)
                x: root.dragPreview && root.dragPreview.ghost ? root.dragPreview.ghost.x : 0
                y: root.dragPreview && root.dragPreview.ghost ? root.dragPreview.ghost.y : 0
                width: root.dragPreview && root.dragPreview.ghost ? root.dragPreview.ghost.w : 0
                height: root.dragPreview && root.dragPreview.ghost ? root.dragPreview.ghost.h : 0
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }

            Repeater {
                model: root.packed

                delegate: Item {
                    id: cell
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    z: dragArea.holding ? 1000 : 0

                    // stagger-вход
                    opacity: 0
                    transform: Translate { id: entT; y: 24 }
                    SequentialAnimation {
                        running: true
                        PauseAnimation { duration: cell.modelData.i * 55 }
                        ParallelAnimation {
                            NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: entT; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                        }
                    }

                    // слой 1: визуал (трансформируется)
                    Item {
                        id: visual
                        anchors.fill: parent
                        transform: [
                            Translate { id: dragShift; x: 0; y: 0 },
                            Translate {
                                id: prevShift
                                x: {
                                    const pv = root.dragPreview
                                    if (!pv || !root.editMode || cell.modelData.i === root.dragIdx)
                                        return 0
                                    const t = pv.map[cell.modelData.i]
                                    return t ? t.x - cell.x : 0
                                }
                                y: {
                                    const pv = root.dragPreview
                                    if (!pv || !root.editMode || cell.modelData.i === root.dragIdx)
                                        return 0
                                    const t = pv.map[cell.modelData.i]
                                    return t ? t.y - cell.y : 0
                                }
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                            }
                        ]

                        Loader {
                            id: ld
                            anchors.fill: parent
                            sourceComponent: {
                                const t = cell.modelData.type
                                if (t === "auth")
                                    return authComp
                                if (t === "clock")
                                    return clockTile
                                if (t === "greet")
                                    return greetTile
                                if (t === "weather")
                                    return weatherTile
                                if (t === "media")
                                    return mediaTile
                                if (t === "battery")
                                    return batteryTile
                                if (t === "date")
                                    return dateComp
                                if (t === "power")
                                    return powerComp
                                if (t === "sysinfo")
                                    return sysinfoComp
                                return emptyComp
                            }
                            onLoaded: {
                                if (cell.modelData.type === "auth")
                                    root.authItem = ld.item
                                const it = ld.item
                                if (it && it.hasOwnProperty("editRequested"))
                                    it.editRequested.connect(() => root.editMode = true)
                            }
                        }

                        // рамка выделения в edit-mode
                        Rectangle {
                            anchors.fill: parent
                            visible: root.editMode
                            radius: Theme.radius
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.alpha(Theme.accent, 0.55)
                        }
                    }

                    // слой 2: dragArea вне visual (mouse-координаты внутри
                    // трансформированного item дают обратную связь)
                    MouseArea {
                        id: dragArea
                        property bool holding: false
                        property point startPt: Qt.point(0, 0)
                        anchors.fill: parent
                        z: 1
                        enabled: root.editMode
                        cursorShape: holding ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            startPt = Qt.point(mouse.x, mouse.y)
                            holding = true
                            root.dragIdx = cell.modelData.i
                            root.dropTL = Qt.point(cell.x, cell.y)
                        }
                        onPositionChanged: mouse => {
                            if (!holding)
                                return
                            const dx = Math.max(-600, Math.min(600, mouse.x - startPt.x))
                            const dy = Math.max(-300, Math.min(500, mouse.y - startPt.y))
                            dragShift.x = dx
                            dragShift.y = dy
                            root.dropTL = Qt.point(cell.x + dx, cell.y + dy)
                        }
                        onReleased: {
                            holding = false
                            const tlx = cell.x + dragShift.x
                            const tly = cell.y + dragShift.y
                            dragShift.x = 0
                            dragShift.y = 0
                            const self = cell.modelData.i
                            root.dragIdx = -1
                            if (tly > root.contentH + Theme.gap + Theme.unit * 0.5)
                                return
                            const spec = root.dropSpec(self, tlx, tly)
                            if (!spec)
                                return
                            const l = root.layout.slice()
                            if (spec.mode === "swap") {
                                const a = Object.assign({}, l[spec.a])
                                const b = Object.assign({}, l[spec.b])
                                const tx = a.x
                                const ty = a.y
                                a.x = b.x
                                a.y = b.y
                                b.x = tx
                                b.y = ty
                                l[spec.a] = a
                                l[spec.b] = b
                            } else {
                                l[spec.a] = Object.assign({}, l[spec.a], {
                                    "x": spec.x,
                                    "y": spec.y
                                })
                            }
                            root.saveLayout(l)
                            root.layout = l
                        }
                        onCanceled: {
                            holding = false
                            dragShift.x = 0
                            dragShift.y = 0
                            root.dragIdx = -1
                        }
                    }

                    // слой 3: хром поверх dragArea
                    Item {
                        id: chrome
                        anchors.fill: parent
                        z: 2
                        transform: [
                            Translate { x: dragShift.x; y: dragShift.y },
                            Translate { x: prevShift.x; y: prevShift.y }
                        ]

                        // удалить (кроме auth)
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; margins: 4 }
                            visible: root.editMode && cell.modelData.type !== "auth"
                            width: 24
                            height: 24
                            radius: 12
                            color: delMa.containsMouse ? Theme.alpha(Theme.red, 0.95) : Theme.alpha(Theme.red, 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: Theme.text
                            }
                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeWidget(cell.modelData.i)
                            }
                        }

                        // ресайз-уголок
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
                            visible: root.editMode && root.allowedSizes(cell.modelData.type).length > 1
                            width: 22
                            height: 22
                            radius: 6
                            color: resizeMa.pressed ? Theme.alpha(Theme.accent, 0.9) : Qt.rgba(1, 1, 1, 0.18)
                            Text {
                                anchors.centerIn: parent
                                text: "\ue745"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: Theme.text
                            }
                            MouseArea {
                                id: resizeMa
                                property point startPt: Qt.point(0, 0)
                                property int newW: 0
                                property int newH: 0
                                anchors.fill: parent
                                cursorShape: Qt.SizeFDiagCursor
                                onPressed: mouse => {
                                    startPt = Qt.point(mouse.x, mouse.y)
                                    newW = cell.modelData.w
                                    newH = cell.modelData.h
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return
                                    const st = Theme.unit + Theme.gap
                                    newW = Math.max(1, Math.min(5, Math.round((cell.width + (mouse.x - startPt.x) + Theme.gap) / st)))
                                    newH = Math.max(1, Math.min(3, Math.round((cell.height + (mouse.y - startPt.y) + Theme.gap) / st)))
                                    const allowed = root.allowedSizes(cell.modelData.type)
                                    let ok = false
                                    for (let i = 0; i < allowed.length; i++)
                                        if (allowed[i][0] === newW && allowed[i][1] === newH)
                                            ok = true
                                    if (!ok) {
                                        newW = cell.modelData.w
                                        newH = cell.modelData.h
                                    }
                                }
                                onReleased: {
                                    if (newW !== cell.modelData.w || newH !== cell.modelData.h)
                                        root.resizeWidget(cell.modelData.i, newW, newH)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── бар редактирования ───────────────────────────────────────────
    Item {
        id: editBar
        anchors { bottom: parent.bottom; bottomMargin: 84; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width - 64, Math.max(chipsRow.width, toolsRow.width))
        height: chipsRow.height + 10 + toolsRow.height
        visible: opacity > 0.01
        opacity: root.editMode && !root.out ? 1 : 0
        enabled: root.editMode && !root.out
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Row {
            id: chipsRow
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            spacing: 8

            Repeater {
                model: [
                    { "type": "clock", "labelKey": "clock", "glyph": "\uf017" },
                    { "type": "date", "labelKey": "calendar", "glyph": "\uf133" },
                    { "type": "weather", "labelKey": "weather", "glyph": "\uf185" },
                    { "type": "media", "labelKey": "player", "glyph": "\uf001" },
                    { "type": "battery", "labelKey": "bat_short", "glyph": "\uf240" },
                    { "type": "power", "labelKey": "power", "glyph": "\uf011" },
                    { "type": "sysinfo", "labelKey": "sysinfo", "glyph": "\uf17c" },
                    { "type": "greet", "labelKey": "greeting", "glyph": "\uf007" }
                ]

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    width: chipLabel.width + 34
                    height: 30
                    radius: 15
                    color: chipMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: Theme.stroke

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: Theme.accent
                        }
                        Text {
                            id: chipLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t(chip.modelData.labelKey)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.text
                        }
                    }

                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addWidget(chip.modelData.type)
                    }
                }
            }
        }

        Row {
            id: toolsRow
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            spacing: 8

            // «Готово»
            Rectangle {
                width: doneLabel.width + 30
                height: 30
                radius: 15
                color: doneMa.containsMouse ? Theme.alpha(Theme.accent, 0.95) : Theme.alpha(Theme.accent, 0.8)
                border.width: 1
                border.color: Theme.accent
                scale: doneMa.pressed ? 0.94 : (doneMa.containsMouse ? 1.04 : 1.0)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf00c"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: "#ffffff"
                    }
                    Text {
                        id: doneLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("done")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                }
                MouseArea {
                    id: doneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editMode = false
                }
            }

            // «Уплотнить»
            Rectangle {
                width: compactLabel.width + 30
                height: 30
                radius: 15
                color: compactMa.containsMouse ? Theme.glassHover : Theme.glass
                border.width: 1
                border.color: Theme.stroke
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf0c9"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: Theme.accent
                    }
                    Text {
                        id: compactLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("compact")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }
                MouseArea {
                    id: compactMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.compactLayout()
                }
            }

            // «Сброс»
            Rectangle {
                width: resetLabel.width + 30
                height: 30
                radius: 15
                color: resetMa.containsMouse ? Theme.alpha(Theme.red, 0.25) : Theme.glass
                border.width: 1
                border.color: Theme.stroke
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf0e2"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: Theme.text
                    }
                    Text {
                        id: resetLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("reset")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }
                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.dangerArm) {
                            root.dangerArm = false
                            root.resetLayout()
                        } else {
                            root.dangerArm = true
                            disarmReset.restart()
                        }
                    }
                }
            }
        }
    }

    property bool dangerArm: false
    Timer {
        id: disarmReset
        interval: 2500
        onTriggered: root.dangerArm = false
    }

    // ─── компоненты тайлов ───────────────────────────────────────────────

    Component { id: emptyComp; Item {} }
    Component { id: authComp; LockAuth {} }
    Component { id: dateComp; LockDate {} }
    Component { id: powerComp; LockPower {} }
    Component { id: sysinfoComp; LockSysinfo {} }

    // привязки блока входа к состоянию сцены
    Binding { target: root.authItem; property: "userName"; value: root.userName; when: root.authItem !== null }
    Binding { target: root.authItem; property: "busy"; value: root.busy; when: root.authItem !== null }
    Binding { target: root.authItem; property: "errorMsg"; value: root.errorMsg; when: root.authItem !== null }
    Binding { target: root.authItem; property: "accountMsg"; value: root.accountMsg; when: root.authItem !== null }
    Binding { target: root.authItem; property: "capsOn"; value: root.capsOn; when: root.authItem !== null }
    Binding { target: root.authItem; property: "locked"; value: root.editMode || root.out; when: root.authItem !== null }

    Connections {
        target: root.authItem
        enabled: root.authItem !== null
        function onAccepted() { root.submit() }
        function onCapsPressed() { root.capsOn = !root.capsOn }
    }

    // hero-часы (+ мини и широкий варианты)
    Component {
        id: clockTile

        Rectangle {
            radius: Theme.radius
            color: Theme.alpha(Theme.accent, 0.92)
            border.width: Theme.isLiquidGlass ? 1.5 : 0
            border.color: Theme.stroke

            readonly property bool cMini: width < 130 && height < 130
            readonly property bool cTall: width < 130 && height >= 130
            readonly property bool cHero: width >= 250 && height >= 150

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onPressAndHold: root.editMode = true
            }

            Column {
                visible: !cMini && !cTall
                anchors.horizontalCenter: parent.horizontalCenter
                y: cHero ? 26 : (parent.height < 150 ? 12 : 34)
                spacing: 4
                width: parent.width

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "HH:mm")
                    font.family: Theme.headlineFont
                    font.pixelSize: cHero ? 64 : (parent.height < 150 ? 40 : 60)
                    color: Theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.ruDate(root.now)
                    font.family: Theme.fontFamily
                    font.pixelSize: cHero ? 14 : 13
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.80)
                }
            }

            // башня 1x2: время стопкой
            Column {
                visible: cTall
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "HH")
                    font.family: Theme.headlineFont
                    font.pixelSize: 34
                    color: Theme.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "mm")
                    font.family: Theme.headlineFont
                    font.pixelSize: 34
                    color: Qt.rgba(1, 1, 1, 0.75)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.now.getDate() + "." + (root.now.getMonth() + 1)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.80)
                }
            }

            Column {
                visible: cMini
                anchors.centerIn: parent
                spacing: 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "HH:mm")
                    font.family: Theme.headlineFont
                    font.pixelSize: 20
                    color: Theme.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.now.getDate() + "." + (root.now.getMonth() + 1)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.80)
                }
            }

            // секундная полоска (только left+bottom: с right-анкором
            // явный width игнорируется и полоска стоит на месте)
            Rectangle {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: 10
                    bottomMargin: 10
                }
                height: 3
                radius: Theme.isWP ? 0 : 1.5
                color: Qt.rgba(1, 1, 1, 0.55)
                width: (parent.width - 20) * (root.now.getSeconds() / 60)
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onPressAndHold: root.editMode = true
            }

            Column {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 2
                width: parent.width - 28

                Text {
                    text: root.greeting() + ","
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: Theme.textDim
                }

                Text {
                    width: parent.width
                    text: root.userName || "user"
                    font.family: Theme.fontFamily
                    font.pixelSize: parent.width > 200 ? 30 : 24
                    font.weight: Font.Light
                    color: Theme.text
                    elide: Text.ElideRight
                }
            }
        }
    }

    // погода: мини / широкая / hero
    Component {
        id: weatherTile

        Rectangle {
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            readonly property bool wMini: width < 130 && height < 130
            readonly property bool wTall: width < 130 && height >= 130
            readonly property bool wHero: width >= 250 && height >= 150
            readonly property bool wSquare: !wMini && !wTall && !wHero && height >= 150

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onPressAndHold: root.editMode = true
            }

            // 1x1 мини
            Column {
                visible: wMini
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

            // 2x1/3x1 широкая
            Row {
                visible: !wMini && !wTall && !wHero && !wSquare
                anchors { fill: parent; margins: 12 }
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.loaded ? Weather.glyph(Weather.code) : "\uf042"
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                    color: Theme.accent
                }

                Column {
                    width: parent.width - 44
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: Weather.loaded ? Math.round(Weather.temp) + "°" : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 26
                        font.weight: Font.Light
                        color: Theme.text
                    }

                    Text {
                        width: parent.width
                        text: (Weather.loaded ? Math.round(Weather.wind) + " " + I18n.t("ms") : "") + " · " + Weather.cityName
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }
            }

            // башня 1x2: всё стопкой
            Column {
                visible: wTall
                anchors.centerIn: parent
                spacing: 3
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
                    font.pixelSize: 24
                    font.weight: Font.Light
                    color: Theme.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.loaded ? Math.round(Weather.wind) + " " + I18n.t("ms") : Weather.cityName
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textDim
                }
            }

            // квадрат 2x2: hero-лайт стопкой
            Column {
                visible: wSquare
                anchors.centerIn: parent
                width: parent.width
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.loaded ? Weather.glyph(Weather.code) : "\uf042"
                    font.family: Theme.iconFont
                    font.pixelSize: 40
                    color: Theme.accent
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.loaded ? Math.round(Weather.temp) + "°" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: 32
                    font.weight: Font.Light
                    color: Theme.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.cityName
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: Theme.textDim
                    elide: Text.ElideRight
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // 3x2 hero
            Row {
                visible: wHero
                anchors { fill: parent; margins: 16 }
                spacing: 16

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.loaded ? Weather.glyph(Weather.code) : "\uf042"
                        font.family: Theme.iconFont
                        font.pixelSize: 52
                        color: Theme.accent
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.loaded ? Math.round(Weather.temp) + "°" : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 40
                        font.weight: Font.Light
                        color: Theme.text
                    }
                }

                Column {
                    width: parent.width - 100
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: Weather.loaded ? Weather.cityName : "…"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Weather.loaded ? (I18n.t("feels") + " " + Math.round(Weather.feelsLike) + "°") : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Weather.loaded ? (I18n.t("wind") + " " + Math.round(Weather.wind) + " " + I18n.t("ms") + " · " + Weather.humidity + "%") : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // медиа: транспорт prev/play/next + seek-бар.
    // Клик только по кнопкам — весь виджет кнопкой не является.
    Component {
        id: mediaTile

        Rectangle {
            id: mediaBg
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            readonly property bool mMini: width < 130 && height < 130
            readonly property bool mTall: width < 130 && height >= 130
            readonly property bool mBig: width >= 170 && height >= 150

            function fmt(s) {
                s = Math.max(0, Math.floor(s))
                return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onPressAndHold: root.editMode = true
            }

            // квадрат арта с маской (переиспользуется лоадерами)
            Component {
                id: artComp
                Item {
                    Image {
                        id: aImg
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle {
                        id: aMask
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        visible: false
                    }
                    Qt5Compat.OpacityMask {
                        anchors.fill: parent
                        source: aImg
                        maskSource: aMask
                        visible: Media.artUrl !== "" && aImg.status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke
                        visible: !(Media.artUrl !== "" && aImg.status === Image.Ready)
                        Text {
                            anchors.centerIn: parent
                            text: "\uf001"
                            font.family: Theme.iconFont
                            font.pixelSize: Math.max(12, Math.min(width, height) * 0.4)
                            color: Media.idle ? Qt.rgba(1, 1, 1, 0.25) : Theme.alpha(Theme.accent, 0.7)
                        }
                    }
                }
            }

            // транспорт prev/play/next (размеры задаёт ветка через onLoaded)
            Component {
                id: transportComp
                Row {
                    id: tRow
                    property int bSide: 24
                    property int bPlay: 30
                    property int gSide: 11
                    property int gPlay: 13
                    spacing: 8

                    Rectangle {
                        width: tRow.bSide; height: tRow.bSide
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevMa.containsMouse ? Theme.glassHover : Theme.glass
                        border.width: 1
                        border.color: Theme.stroke
                        scale: prevMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                        Text {
                            anchors.centerIn: parent
                            text: "\uf048"
                            font.family: Theme.iconFont
                            font.pixelSize: tRow.gSide
                            color: Theme.text
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("previous")
                        }
                    }

                    Rectangle {
                        width: tRow.bPlay; height: tRow.bPlay
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: playMa.pressed ? Theme.alpha(Theme.accent, 1.0) : playMa.containsMouse ? Theme.alpha(Theme.accent, 1.0) : Theme.alpha(Theme.accent, 0.85)
                        scale: playMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (Media.playStatus === "playing") ? 0 : 1
                            text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                            font.family: Theme.iconFont
                            font.pixelSize: tRow.gPlay
                            color: "#ffffff"
                        }
                        MouseArea {
                            id: playMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("play-pause")
                        }
                    }

                    Rectangle {
                        width: tRow.bSide; height: tRow.bSide
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextMa.containsMouse ? Theme.glassHover : Theme.glass
                        border.width: 1
                        border.color: Theme.stroke
                        scale: nextMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                        Text {
                            anchors.centerIn: parent
                            text: "\uf051"
                            font.family: Theme.iconFont
                            font.pixelSize: tRow.gSide
                            color: Theme.text
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.act("next")
                        }
                    }
                }
            }

            // seek-бар с драгом (таймкоды опционально через showTime)
            Component {
                id: seekComp
                Item {
                    id: sRoot
                    property bool showTime: false
                    property real dragFrac: -1
                    height: showTime ? 28 : 16

                    Item {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 16

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: 2.5
                            color: Qt.rgba(1, 1, 1, 0.15)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * (sRoot.dragFrac >= 0 ? sRoot.dragFrac : (Media.length > 0 ? Math.min(1, Media.pos / Media.length) : 0))
                            height: 5
                            radius: 2.5
                            color: Theme.accent
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * (sRoot.dragFrac >= 0 ? sRoot.dragFrac : (Media.length > 0 ? Math.min(1, Media.pos / Media.length) : 0)) - 5
                            width: 10; height: 10
                            radius: 5
                            color: Theme.accent
                            visible: seekMa.containsMouse || seekMa.pressed || sRoot.dragFrac >= 0
                        }

                        MouseArea {
                            id: seekMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: Media.length > 0
                            function frac(mouse) {
                                return Math.max(0, Math.min(1, mouse.x / width))
                            }
                            onPressed: mouse => sRoot.dragFrac = frac(mouse)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    sRoot.dragFrac = frac(mouse)
                            }
                            onReleased: mouse => {
                                const f = frac(mouse)
                                if (Media.length > 0)
                                    Media.seek(f * Media.length)
                                sRoot.dragFrac = -1
                            }
                        }
                    }

                    Text {
                        visible: sRoot.showTime
                        anchors { right: parent.right; bottom: parent.bottom }
                        text: Media.length > 0 ? (mediaBg.fmt(Media.pos) + " / " + mediaBg.fmt(Media.length)) : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }
                }
            }

            // idle: приглушённая нота
            Column {
                visible: Media.idle
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf001"
                    font.family: Theme.iconFont
                    font.pixelSize: mMini ? 22 : 26
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
                Text {
                    visible: !mMini
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("nothing_playing")
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: Qt.rgba(1, 1, 1, 0.30)
                }
            }

            // 1x1 мини: арт + круглая play-кнопка
            Item {
                visible: !Media.idle && mMini
                anchors.centerIn: parent
                width: 52; height: 52

                Loader {
                    anchors.fill: parent
                    sourceComponent: artComp
                }

                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: -6; bottomMargin: -6 }
                    width: 24; height: 24
                    radius: 12
                    color: miniPlayMa.pressed ? Theme.alpha(Theme.accent, 1.0) : Theme.alpha(Theme.accent, 0.9)
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.3)
                    Text {
                        anchors.centerIn: parent
                        text: (Media.playStatus === "playing") ? "\uf04c" : "\uf04b"
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: miniPlayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.act("play-pause")
                    }
                }
            }

            // полоса 2x1/3x1: арт + строка + транспорт + seek
            Row {
                visible: !Media.idle && !mMini && !mTall && !mBig
                anchors { fill: parent; margins: 10 }
                spacing: 10

                Loader {
                    width: 60; height: 60
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: artComp
                }

                Column {
                    width: parent.width - 70
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: Media.artist !== "" ? (Media.title + " — " + Media.artist) : Media.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Loader {
                        sourceComponent: transportComp
                        onLoaded: {
                            item.bSide = 22
                            item.bPlay = 26
                            item.gSide = 10
                            item.gPlay = 12
                        }
                    }

                    Loader {
                        width: parent.width
                        sourceComponent: seekComp
                    }
                }
            }

            // башня 1x2: арт + заголовок + транспорт + seek
            Column {
                visible: !Media.idle && mTall
                anchors { fill: parent; margins: 10 }
                spacing: 5

                Loader {
                    width: 60; height: 60
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: artComp
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Media.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideRight
                }

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: transportComp
                    onLoaded: {
                        item.bSide = 24
                        item.bPlay = 30
                        item.gSide = 11
                        item.gPlay = 13
                    }
                }

                Loader {
                    width: parent.width
                    sourceComponent: seekComp
                }
            }

            // большой 2x2/3x2: арт-ряд + транспорт + seek с таймкодами
            Column {
                visible: !Media.idle && mBig
                anchors { fill: parent; margins: 12 }
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 12

                    Loader {
                        id: bigArt
                        width: mediaBg.width >= 250 ? 96 : 64
                        height: mediaBg.width >= 250 ? 96 : 64
                        sourceComponent: artComp
                    }

                    Column {
                        width: parent.width - bigArt.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: Media.title
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        Text {
                            width: parent.width
                            text: Media.artist
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Qt.rgba(1, 1, 1, 0.75)
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: Media.playStatus === "paused" ? I18n.t("paused") : ""
                            visible: Media.playStatus === "paused"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: Theme.accent
                        }
                    }
                }

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: transportComp
                    onLoaded: {
                        item.bSide = 32
                        item.bPlay = 40
                        item.gSide = 13
                        item.gPlay = 16
                    }
                }

                Loader {
                    width: parent.width
                    sourceComponent: seekComp
                    onLoaded: item.showTime = true
                }
            }
        }
    }

    // батарея (1x1 + широкая 2x1)
    Component {
        id: batteryTile

        Rectangle {
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.stroke

            readonly property bool bWide: width >= 170

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onPressAndHold: root.editMode = true
            }

            Column {
                visible: !bWide
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
                    text: I18n.t("battery")
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Theme.textDim
                }
            }

            Row {
                visible: bWide
                anchors { fill: parent; margins: 12 }
                spacing: 12

                Rectangle {
                    width: 44; height: 44
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.radiusSmall
                    color: Theme.glass
                    border.width: 1
                    border.color: Theme.stroke
                    Text {
                        anchors.centerIn: parent
                        text: "\uf240"
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        color: root.batteryPct < 0 ? Theme.textDim :
                               root.batteryPct < 20 ? Theme.red :
                               root.batteryPct < 35 ? Theme.orange : Theme.accent
                    }
                }

                Column {
                    width: parent.width - 56
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: I18n.t("battery")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                        color: Theme.textDim
                    }

                    Text {
                        text: root.batteryPct >= 0 ? root.batteryPct + "%" : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.Light
                        color: Theme.text
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.batteryPct / 100))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
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
        if (e.key === Qt.Key_Escape) {
            if (root.editMode) {
                root.editMode = false     // сначала выход из редактирования
                e.accepted = true
            } else if (root.debug) {
                root.finished()
                e.accepted = true
            }
        } else if (e.key === Qt.Key_CapsLock) {
            root.capsOn = !root.capsOn
            e.accepted = true
        }
    }

    onEditModeChanged: {
        if (!root.editMode && root.authItem && !root.out)
            root.authItem.focusField()
    }

    // ─── данные: user@host, батарея, раскладка ──────────────────────────
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

    Process {
        id: pLayoutRead
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/metro/lock-layout.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let l = null
                try {
                    l = JSON.parse(text)
                } catch (e) {
                    l = null
                }
                if (!l || !l[0] || !l[0].type)
                    l = root.defaultLockLayout()
                root.layout = root.ensureAuth(l)
            }
        }
    }

    Process {
        id: pLayoutWrite
    }

    Component.onCompleted: {
        pLayoutRead.running = true
        focusTimer.start()
    }
    Timer {
        id: focusTimer
        interval: 120
        onTriggered: if (root.authItem) root.authItem.focusField()
    }
}

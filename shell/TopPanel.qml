import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

PanelBase {
    id: root

    slideDir: "top"
    property string expandMode: "none"
    property int cpuPct: 0
    property int ramPct: 0
    property string ramUsed: ""
    property string ramTotal: ""
    property int gpuPct: 0
    property int gpuTemp: 0
    property int batPct: 0
    property string batStatus: ""
    property bool batCharging: batStatus === "Charging"
    property string batTime: ""
    property int diskPct: 0
    property int diskFree: 0

    // ── раскладка виджетов ──
    property var layout: []
    property int contentH: 0
    property bool editMode: false
    property bool pickerOpen: false
    property bool execConfigOpen: false
    property int editExecIdx: -1
    property string cfgExecLabel: ""
    property string cfgExecCommand: ""
    property bool cfgExecInTerminal: true
    property string cfgExecIcon: "\uf120"
    property int cfgExecW: 1
    property int cfgExecH: 1

    // ВАЖНО: окно всегда 682 пока открыто. Анимация implicitHeight =
    // ресайз layer-surface каждый кадр (фризы, вспышки без блюра).
    // Раскрытие анимируется только фоном (topBg) внутри сцены.
    readonly property int winH: root.shown ? 682 : 215
    readonly property int cols: Math.max(6, Math.floor((width - 44 + Theme.gap) / (Theme.unit + Theme.gap)))
    readonly property int barH: editMode ? 52 : 36
    readonly property int shownH: editMode ? (16 + contentH + 12 + barH + 10) : (16 + contentH + 15)
    readonly property var packed: repack()

    implicitHeight: winH
    mask: Region {
        x: 0
        y: 0
        width: root.width
        height: root.expandMode !== "none" || root.pickerOpen || root.execConfigOpen ? 682 : root.shownH
    }

    onExpandModeChanged: {
        grace()
        if (expandMode === "weather" && !Weather.loaded)
            Weather.fetch()
    }

    onEditModeChanged: {
        if (!editMode) {
            pickerOpen = false
            execConfigOpen = false
            for (let i = 0; i < gridHost.children.length; i++) {
                const c = gridHost.children[i]
                if (c.resetWiggle)
                    c.resetWiggle()
            }
        }
    }

    Component.onCompleted: pLayoutRead.running = true

    function defaultLayout() {
        const apps = ["firefox", "kitty", "thunar", "spotify-launcher", "org.telegram.desktop", "obsidian", "chromium", "org.kde.kcalc"]
        const l = [{
                "type": "clock",
                "w": 2,
                "h": 2
            }, {
                "type": "weather",
                "w": 2,
                "h": 2
            }, {
                "type": "photo",
                "w": 2,
                "h": 2
            }]
        for (let i = 0; i < apps.length; i++)
            l.push({
                "type": "app",
                "appId": apps[i],
                "w": 1,
                "h": 1
            })
        l.push({
            "type": "cpu",
            "w": 1,
            "h": 1
        }, {
            "type": "ram",
            "w": 1,
            "h": 1
        }, {
            "type": "gpu",
            "w": 1,
            "h": 1
        }, {
            "type": "bat",
            "w": 1,
            "h": 1
        }, {
            "type": "ssd",
            "w": 1,
            "h": 1
        }, {
            "type": "power",
            "w": 1,
            "h": 1
        }, {
            "type": "player",
            "w": 2,
            "h": 1
        })
        return l
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
                    if (cx < 0 || cy < 0 || cx + w > cols)
                        continue
                    if (!rectHits(cx, cy, w, h, skipIdx))
                        return { "x": cx, "y": cy }
                }
            }
        }
        return null
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
                pos[i] = {
                    "x": it.x,
                    "y": it.y
                }
            } else {
                pending.push(i)
            }
        }
        for (let p = 0; p < pending.length; p++) {
            const i = pending[p]
            const w = lay[i].w || 1
            const h = lay[i].h || 1
            for (let cy = 0; cy < 200; cy++) {
                let done = false
                for (let cx = 0; cx + w <= cols; cx++) {
                    if (!rectHitsInit(occupied, cx, cy, w, h)) {
                        for (let yy = cy; yy < cy + h; yy++)
                            for (let xx = cx; xx < cx + w; xx++)
                                occupied[xx + "," + yy] = true
                        pos[i] = {
                            "x": cx,
                            "y": cy
                        }
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
                "appId": it.appId || "",
                "command": it.command || "",
                "label": it.label || "",
                "inTerminal": it.inTerminal !== undefined ? it.inTerminal : true,
                "iconGlyph": it.iconGlyph || "\uf120",
                "x": 22 + p.x * step,
                "y": 16 + p.y * step,
                "w": Theme.tileW(w),
                "h": Theme.tileH(h)
            })
            bottom = Math.max(bottom, p.y * step + Theme.tileH(h))
        }
        return { "cells": out, "bottom": bottom }
    }

    function rectHitsInit(occ, cx, cy, w, h) {
        for (let yy = cy; yy < cy + h; yy++)
            for (let xx = cx; xx < cx + w; xx++)
                if (occ[xx + "," + yy])
                    return true
        return false
    }

    function repack() {
        const r = packGrid(layout)
        contentH = r.bottom
        return r.cells
    }

    function allowedSizes(type) {
        return type === "weather" ? [[2, 2]] : [[1, 1], [2, 1], [2, 2]]
    }

    // ── drag&drop ──
    property int dragIdx: -1
    property point dropTL: Qt.point(0, 0)
    readonly property int step: Theme.unit + Theme.gap

    // семантика броска: move — точная ячейка под курсором (свободна или
    // ближайшая свободная), swap — обмен позициями с плиткой равного размера
    function dropSpec(selfIdx, tlx, tly) {
        const it = layout[selfIdx]
        if (!it)
            return null
        const w = it.w || 1
        const h = it.h || 1
        const gcx = Math.max(0, Math.min(cols - w, Math.round((tlx - 22) / step)))
        const gry = Math.max(0, Math.round((tly - 16) / step))
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
            map[c.i] = {
                "x": c.x,
                "y": c.y
            }
            if (c.i === dragIdx)
                ghost = {
                    "x": c.x,
                    "y": c.y,
                    "w": c.w,
                    "h": c.h
                }
        }
        return {
            "map": map,
            "ghost": ghost
        }
    }

    property string _specKey: ""
    property var _spec: null

    readonly property var dragPreview: {
        if (dragIdx < 0 || dragIdx >= layout.length) {
            _specKey = ""
            _spec = null
            return null
        }
        const spec = dropSpec(dragIdx, dropTL.x, dropTL.y)
        const key = spec ? spec.mode + ":" + spec.a + ":" + (spec.b !== undefined ? spec.b : spec.x + "," + spec.y) : "none"
        if (key !== _specKey) {
            _specKey = key
            _spec = spec ? buildPreview(spec) : null
        }
        return _spec
    }

    function removeWidget(i) {
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
        const upd = Object.assign({}, l[i], {
            "w": w,
            "h": h
        })
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
        const sizes = allowedSizes(type)
        const l = layout.concat([{
                "type": type,
                "w": sizes[sizes.length - 1][0],
                "h": sizes[sizes.length - 1][1]
            }])
        saveLayout(l)
        layout = l
    }

    function openExecConfig(idx) {
        editExecIdx = idx
        if (idx >= 0 && layout[idx]) {
            const it = layout[idx]
            cfgExecLabel = it.label || ""
            cfgExecCommand = it.command || ""
            cfgExecInTerminal = it.inTerminal !== undefined ? it.inTerminal : true
            cfgExecIcon = it.iconGlyph || "\uf120"
            cfgExecW = it.w || 1
            cfgExecH = it.h || 1
        } else {
            cfgExecLabel = ""
            cfgExecCommand = ""
            cfgExecInTerminal = true
            cfgExecIcon = "\uf120"
            cfgExecW = 1
            cfgExecH = 1
        }
        pickerOpen = false
        expandMode = "none"
        execConfigOpen = true
    }

    function saveExecConfig() {
        const cmd = cfgExecCommand.trim()
        if (!cmd)
            return
        const lbl = cfgExecLabel.trim()
        const term = cfgExecInTerminal
        const ico = cfgExecIcon || "\uf120"
        const l = layout.slice()
        if (editExecIdx >= 0 && editExecIdx < l.length) {
            l[editExecIdx] = Object.assign({}, l[editExecIdx], {
                "command": cmd,
                "label": lbl,
                "inTerminal": term,
                "iconGlyph": ico
            })
        } else {
            const sizes = allowedSizes("exec")
            l.push({
                "type": "exec",
                "w": cfgExecW || sizes[0][0],
                "h": cfgExecH || sizes[0][1],
                "command": cmd,
                "label": lbl,
                "inTerminal": term,
                "iconGlyph": ico
            })
        }
        saveLayout(l)
        layout = l
        execConfigOpen = false
    }

    function addAppWidget(appId) {
        const l = layout.concat([{
                "type": "app",
                "appId": appId,
                "w": 1,
                "h": 1
            }])
        saveLayout(l)
        layout = l
    }

    // write first, then assign: reassigning the layout rebuilds the Repeater
    // and kills the calling delegate mid-handler
    function saveLayout(arr) {
        const json = JSON.stringify(arr !== undefined ? arr : layout)
        pLayoutWrite.command = ["sh", "-c", "cat > \"$HOME/.config/quickshell/metro/layout.json\" << 'QSEOF'\n" + json + "\nQSEOF"]
        pLayoutWrite.running = true
    }

    function findApp(id) {
        const values = DesktopEntries.applications.values ?? []
        for (let i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i]
        }
        return null
    }

    function ruDate(d) {
        const days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
    }

    function ruMonth(d) {
        const monthsNom = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]
        return monthsNom[d.getMonth()] + " " + d.getFullYear()
    }

    onShownChanged: if (!shown) {
        expandMode = "none"
        pickerOpen = false
        execConfigOpen = false
    }

    anchors {
        top: true
        left: true
        right: true
    }

    // ── системные показатели ──
    Process {
        id: pCpu

        command: ["bash", "-c", "read _ a b c d e f g _ < /proc/stat; t1=$((a+b+c+d+e+f+g)); i1=$((d+e)); sleep 0.6; read _ a b c d e f g _ < /proc/stat; t2=$((a+b+c+d+e+f+g)); i2=$((d+e)); echo $(( 100 * ( (t2-t1) - (i2-i1) ) / (t2-t1) ))"]
        stdout: SplitParser {
            onRead: data => root.cpuPct = parseInt(data.trim()) || 0
        }
    }

    Process {
        id: pRam

        command: ["sh", "-c", "awk '$1==\"MemTotal:\"{t=$2} $1==\"MemAvailable:\"{a=$2} END{printf \"%d|%.1f|%.1f\", (t-a)*100/t, (t-a)/1048576, t/1048576}' /proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                const f = data.trim().split("|")
                root.ramPct = parseInt(f[0]) || 0
                if (f.length >= 3) {
                    root.ramUsed = f[1]
                    root.ramTotal = f[2]
                }
            }
        }
    }

    Process {
        id: pGpu

        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const f = data.trim().split(",")
                root.gpuPct = parseInt(f[0]) || 0
                root.gpuTemp = parseInt(f[1]) || 0
            }
        }
    }

    Process {
        id: pBat

        command: ["sh", "-c", "b=/sys/class/power_supply/BAT0; echo \"$(cat $b/capacity 2>/dev/null || echo 0)|$(cat $b/status 2>/dev/null)|$(cat $b/energy_now 2>/dev/null || echo 0)|$(cat $b/power_now 2>/dev/null || echo 0)|$(cat $b/energy_full 2>/dev/null || echo 0)\""]
        stdout: SplitParser {
            onRead: data => {
                const f = data.trim().split("|")
                root.batPct = parseInt(f[0]) || 0
                root.batStatus = f[1] ? f[1].trim() : ""
                const now = parseInt(f[2]) || 0
                const pw = parseInt(f[3]) || 0
                const full = parseInt(f[4]) || 0
                let hours = 0
                if (pw > 0) {
                    if (f[1] === "Discharging")
                        hours = now / pw
                    else if (f[1] === "Charging" && full > now)
                        hours = (full - now) / pw
                }
                root.batTime = hours > 0 ? Math.floor(hours) + ":" + String(Math.round((hours % 1) * 60)).padStart(2, "0") : ""
            }
        }
    }

    Process {
        id: pDisk

        command: ["sh", "-c", "df -P / | tail -1 | awk '{printf \"%s %s\", substr($5, 1, length($5)-1), $4/1048576}'"]
        stdout: SplitParser {
            onRead: data => {
                const f = data.trim().split(" ")
                root.diskPct = parseInt(f[0]) || 0
                root.diskFree = Math.round(parseFloat(f[1])) || 0
            }
        }
    }

    Process {
        id: pLayoutRead

        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/metro/layout.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let l = null
                try {
                    l = JSON.parse(text)
                } catch (e) {
                    l = null
                }
                if (!l || !l.length || !l[0].type)
                    l = root.defaultLayout()
                root.layout = l
            }
        }
    }

    Process {
        id: pLayoutWrite
    }

    Timer {
        interval: 2000
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pCpu.running = true
            pRam.running = true
            pGpu.running = true
            pBat.running = true
            pDisk.running = true
        }
    }

    Timer {
        id: clock

        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        property date date: new Date()
        onTriggered: date = new Date()
    }

    Rectangle {
        id: topBg

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: -18
        }
        height: (root.expandMode !== "none" || root.pickerOpen || root.execConfigOpen ? 682 : root.shownH) + 18
        radius: Theme.panelRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.stroke

        Behavior on height {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
    }

    // ── сетка виджетов ──
    Item {
        id: gridHost

        anchors.fill: parent

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

            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
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

                function resetWiggle() {
                    wiggle.angle = 0
                }

                opacity: root.open || root.editMode ? 1 : 0

                Behavior on opacity {
                    enabled: root.open && !root.editMode
                    SequentialAnimation {
                        PauseAnimation {
                            duration: (cell.modelData.i % 20) * 40
                        }

                        NumberAnimation {
                            duration: 180
                        }
                    }
                }

                Item {
                    id: visual

                    anchors.fill: parent
                    transform: [
                        Translate {
                            id: dragShift

                            x: 0
                            y: 0
                        },
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

                            Behavior on x {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutQuad
                                }
                            }

                            Behavior on y {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutQuad
                                }
                            }
                        },
                        Rotation {
                            id: wiggle

                            origin.x: cell.width / 2
                            origin.y: cell.height / 2
                            angle: 0
                        }
                    ]

                    SequentialAnimation {
                        id: wiggleAnim

                        running: root.editMode
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: wiggle
                            property: "angle"
                            from: -1.1
                            to: 1.1
                            duration: 280
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            target: wiggle
                            property: "angle"
                            from: 1.1
                            to: -1.1
                            duration: 280
                            easing.type: Easing.InOutSine
                        }
                    }

                    Loader {
                        id: ld

                        anchors.fill: parent
                        sourceComponent: {
                            const t = cell.modelData.type
                            if (t === "clock")
                                return clockComp
                            if (t === "weather")
                                return weatherComp
                            if (t === "photo")
                                return photoComp
                            if (t === "player")
                                return playerComp
                            if (t === "power")
                                return powerComp
                            if (t === "cpu")
                                return cpuComp
                            if (t === "ram")
                                return ramComp
                            if (t === "gpu")
                                return gpuComp
                            if (t === "bat")
                                return batComp
                            if (t === "ssd")
                                return ssdComp
                            if (t === "exec")
                                return execComp
                            if (t === "app")
                                return appComp
                            return emptyComp
                        }

                        onLoaded: {
                            if (ld.item && ld.item.hasOwnProperty("appId"))
                                ld.item.appId = cell.modelData.appId
                            if (ld.item && ld.item.hasOwnProperty("command"))
                                ld.item.command = cell.modelData.command || "echo 'hello'"
                            if (ld.item && ld.item.hasOwnProperty("label"))
                                ld.item.label = cell.modelData.label || ""
                            if (ld.item && ld.item.hasOwnProperty("inTerminal"))
                                ld.item.inTerminal = cell.modelData.inTerminal !== undefined ? cell.modelData.inTerminal : true
                            if (ld.item && cell.modelData.type === "exec" && ld.item.hasOwnProperty("iconGlyph"))
                                ld.item.iconGlyph = cell.modelData.iconGlyph || "\uf120"
                        }
                    }

                    Binding {
                        target: ld.item
                        property: "command"
                        value: cell.modelData.command || "echo 'hello'"
                        when: ld.status === Loader.Ready && ld.item && ld.item.hasOwnProperty("command")
                    }

                    Binding {
                        target: ld.item
                        property: "label"
                        value: cell.modelData.label || ""
                        when: ld.status === Loader.Ready && ld.item && ld.item.hasOwnProperty("label")
                    }

                    Binding {
                        target: ld.item
                        property: "inTerminal"
                        value: cell.modelData.inTerminal !== undefined ? cell.modelData.inTerminal : true
                        when: ld.status === Loader.Ready && ld.item && ld.item.hasOwnProperty("inTerminal")
                    }

                    Binding {
                        target: ld.item
                        property: "iconGlyph"
                        value: cell.modelData.iconGlyph || "\uf120"
                        when: ld.status === Loader.Ready && ld.item && cell.modelData.type === "exec" && ld.item.hasOwnProperty("iconGlyph")
                    }

                    Binding {
                        target: ld.item
                        property: "panelShown"
                        value: root.shown
                        when: ld.status === Loader.Ready && ld.item && ld.item.hasOwnProperty("panelShown")
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

                // dragArea вне visual: mouse-координаты внутри
                // трансформированного item дают обратную связь
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
                        const dx = Math.max(-root.width, Math.min(root.width, mouse.x - startPt.x))
                        const dy = Math.max(-200, Math.min(400, mouse.y - startPt.y))
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
                        if (tly > 16 + root.contentH + Theme.gap + Theme.unit * 0.5)
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

                // хром поверх dragArea, трансформы зеркалят visual
                Item {
                    id: chrome

                    anchors.fill: parent
                    z: 2
                    transform: [
                        Translate {
                            x: dragShift.x
                            y: dragShift.y
                        },
                        Translate {
                            x: prevShift.x
                            y: prevShift.y
                        },
                        Rotation {
                            origin.x: cell.width / 2
                            origin.y: cell.height / 2
                            angle: wiggle.angle
                        }
                    ]

                    // редактировать exec-виджет
                    Rectangle {
                        anchors {
                            right: parent.right
                            top: parent.top
                            rightMargin: 30
                            topMargin: 4
                        }
                        visible: root.editMode && cell.modelData.type === "exec"
                        width: 24
                        height: 24
                        radius: 12
                        color: editExecMa.containsMouse ? Theme.alpha(Theme.accent, 0.95) : Theme.alpha(Theme.accent, 0.7)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf013"
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                            color: "#0e1720"
                        }

                        MouseArea {
                            id: editExecMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openExecConfig(cell.modelData.i)
                        }
                    }

                    // удалить
                    Rectangle {
                        anchors {
                            right: parent.right
                            top: parent.top
                            margins: 4
                        }
                        visible: root.editMode
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
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 4
                        }
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
                                const step = Theme.unit + Theme.gap
                                newW = Math.max(1, Math.min(2, Math.round((cell.width + (mouse.x - startPt.x) + Theme.gap) / step)))
                                newH = Math.max(1, Math.min(2, Math.round((cell.height + (mouse.y - startPt.y) + Theme.gap) / step)))
                                const allowed = root.allowedSizes(cell.modelData.type)
                                let ok = false
                                for (let i = 0; i < allowed.length; i++)
                                    if (allowed[i][0] === newW && allowed[i][1] === newH)
                                        ok = true
                                if (!ok) {
                                    if (allowed.length === 1) {
                                        newW = allowed[0][0]
                                        newH = allowed[0][1]
                                    } else {
                                        newW = cell.modelData.w
                                        newH = cell.modelData.h
                                    }
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

    // ── пикер приложений ──
    Item {
        id: appPicker

        readonly property var allApps: {
            const vals = DesktopEntries.applications.values ?? []
            const arr = []
            for (let i = 0; i < vals.length; i++)
                arr.push({
                    "id": vals[i].id,
                    "name": vals[i].name,
                    "icon": vals[i].icon
                })
            arr.sort((a, b) => a.name.localeCompare(b.name))
            return arr
        }
        readonly property var filtered: {
            const q = pickSearch.text.toLowerCase()
            if (q === "")
                return allApps
            const out = []
            for (let i = 0; i < allApps.length; i++)
                if (allApps[i].name.toLowerCase().includes(q) || allApps[i].id.toLowerCase().includes(q))
                    out.push(allApps[i])
            return out
        }

        visible: opacity > 0.01
        opacity: root.editMode && root.pickerOpen ? 1 : 0
        enabled: root.editMode && root.pickerOpen

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 22
            rightMargin: 22
            topMargin: 252
        }
        height: 400

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.glassDeep
            border.width: 1
            border.color: Theme.stroke

            Item {
                id: pickHead

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Добавить приложение"
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    color: Theme.text
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: pickCloseMa.containsMouse ? Theme.alpha(Theme.red, 0.9) : Theme.glass

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.text
                    }

                    MouseArea {
                        id: pickCloseMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickerOpen = false
                    }
                }
            }

            Rectangle {
                id: pickSearchBg

                anchors {
                    left: parent.left
                    right: parent.right
                    top: pickHead.bottom
                    margins: 14
                }
                height: 40
                radius: Theme.radiusSmall
                color: Theme.glass
                border.width: 1
                border.color: Theme.stroke

                Text {
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
                    id: pickSearch

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

                    Keys.onEscapePressed: root.pickerOpen = false

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 2
                        radius: 1
                        color: Theme.accent
                        opacity: pickSearch.activeFocus ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                }
            }

            ListView {
                id: pickList

                anchors {
                    left: parent.left
                    right: parent.right
                    top: pickSearchBg.bottom
                    leftMargin: 14
                    rightMargin: 14
                    topMargin: 12
                    bottom: parent.bottom
                    bottomMargin: 14
                }
                clip: true
                model: appPicker.filtered
                boundsBehavior: Flickable.StopAtBounds
                spacing: 4

                NumberAnimation {
                    id: pickScrollAnim

                    target: pickList
                    property: "contentY"
                    duration: 200
                    easing.type: Easing.OutQuad
                }

                onDragStarted: pickScrollAnim.stop()
                onFlickStarted: pickScrollAnim.stop()

                function smoothScroll(dy) {
                    const max = Math.max(0, pickList.contentHeight - pickList.height)
                    pickScrollAnim.stop()
                    pickScrollAnim.to = Math.max(0, Math.min(max, pickList.contentY - dy * 1.9))
                    pickScrollAnim.restart()
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    scrollGestureEnabled: true
                    onWheel: wheel => pickList.smoothScroll(wheel.angleDelta.y)
                }

                delegate: Item {
                    id: pickRow

                    required property var modelData

                    width: pickList.width
                    height: 46

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: pickRowMa.containsMouse ? Theme.glassHover : "transparent"
                        border.width: 1
                        border.color: pickRowMa.containsMouse ? Theme.stroke : "transparent"
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            leftMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        width: 34
                        height: 34
                        radius: Theme.radiusSmall
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke

                        IconImage {
                            anchors.centerIn: parent
                            visible: pickRow.modelData.icon !== "" && Quickshell.hasThemeIcon(pickRow.modelData.icon)
                            implicitSize: 22
                            source: visible ? Quickshell.iconPath(pickRow.modelData.icon) : ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !(pickRow.modelData.icon !== "" && Quickshell.hasThemeIcon(pickRow.modelData.icon))
                            text: "\uf1b2"
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                            color: Theme.textDim
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 52
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: pickRow.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: pickRowMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.addAppWidget(pickRow.modelData.id)
                            root.pickerOpen = false
                        }
                    }
                }
            }
        }
    }

    // ── панель настройки виджета-команды ──
    Item {
        id: execConfig

        visible: opacity > 0.01
        opacity: root.editMode && root.execConfigOpen ? 1 : 0
        enabled: root.editMode && root.execConfigOpen

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 22
            rightMargin: 22
            topMargin: 252
        }
        height: 400

        Keys.onEscapePressed: root.execConfigOpen = false

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.glassDeep
            border.width: 1
            border.color: Theme.stroke

            // Шапка
            Item {
                id: execCfgHead

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                height: 32

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf120"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.editExecIdx >= 0 ? "Настройка команды" : "Добавить виджет-команду"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }

                // Пресеты (быстрые шаблоны)
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 230
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Шаблоны:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }

                    Repeater {
                        model: [
                            {
                                "label": "Обновление",
                                "cmd": "cachy-update",
                                "term": true,
                                "ico": "\uf021"
                            },
                            {
                                "label": "Шелл",
                                "cmd": "killall quickshell; quickshell &",
                                "term": false,
                                "ico": "\uf011"
                            },
                            {
                                "label": "Btop",
                                "cmd": "btop",
                                "term": true,
                                "ico": "\uf080"
                            },
                            {
                                "label": "Fastfetch",
                                "cmd": "fastfetch",
                                "term": true,
                                "ico": "\uf120"
                            },
                            {
                                "label": "Кэш",
                                "cmd": "rm -rf ~/.cache/*",
                                "term": false,
                                "ico": "\uf014"
                            }
                        ]

                        delegate: Rectangle {
                            id: presetChip

                            required property var modelData

                            width: presetTxt.width + 16
                            height: 24
                            radius: 12
                            color: presetMa.containsMouse ? Theme.glassHover : Theme.glass
                            border.width: 1
                            border.color: Theme.stroke

                            Row {
                                id: presetTxt

                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: presetChip.modelData.ico
                                    font.family: Theme.iconFont
                                    font.pixelSize: 9
                                    color: Theme.accent
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: presetChip.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: presetMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.cfgExecLabel = presetChip.modelData.label
                                    root.cfgExecCommand = presetChip.modelData.cmd
                                    root.cfgExecInTerminal = presetChip.modelData.term
                                    root.cfgExecIcon = presetChip.modelData.ico
                                }
                            }
                        }
                    }
                }

                // Крестик закрытия
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: execCfgCloseMa.containsMouse ? Theme.alpha(Theme.red, 0.9) : Theme.glass

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.text
                    }

                    MouseArea {
                        id: execCfgCloseMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.execConfigOpen = false
                    }
                }
            }

            // Основная зона формы и предпросмотра
            Row {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: execCfgHead.bottom
                    bottom: parent.bottom
                    margins: 14
                }
                spacing: 18

                // Левая колонка: форма ввода
                Column {
                    width: parent.width - 240
                    height: parent.height
                    spacing: 10

                    // 1. Поле Название
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "НАЗВАНИЕ (ОТОБРАЖЕНИЕ В ПЛИТКЕ)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.textDim
                        }

                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: Theme.radiusSmall
                            color: Theme.glass
                            border.width: 1
                            border.color: cfgLabelInput.activeFocus ? Theme.accent : Theme.stroke

                            Row {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\uf044"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: Theme.textDim
                                }

                                TextInput {
                                    id: cfgLabelInput

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 24
                                    text: root.cfgExecLabel
                                    onTextChanged: root.cfgExecLabel = text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: Theme.text
                                    clip: true
                                    cursorVisible: activeFocus

                                    Text {
                                        anchors.fill: parent
                                        visible: !cfgLabelInput.text && !cfgLabelInput.activeFocus
                                        text: "например: Обновление системы (или пусто для авто)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        color: Qt.rgba(1, 1, 1, 0.25)
                                    }
                                }
                            }
                        }
                    }

                    // 2. Поле Команда
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "КОМАНДА SHELL"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.textDim
                        }

                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: Theme.radiusSmall
                            color: Theme.glass
                            border.width: 1
                            border.color: cfgCmdInput.activeFocus ? Theme.accent : Theme.stroke

                            Row {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "$"
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: Theme.accent
                                }

                                TextInput {
                                    id: cfgCmdInput

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 24
                                    text: root.cfgExecCommand
                                    onTextChanged: root.cfgExecCommand = text
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    color: Theme.text
                                    clip: true
                                    cursorVisible: activeFocus

                                    Text {
                                        anchors.fill: parent
                                        visible: !cfgCmdInput.text && !cfgCmdInput.activeFocus
                                        text: "например: cachy-update или fastfetch"
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                        color: Qt.rgba(1, 1, 1, 0.25)
                                    }
                                }
                            }
                        }
                    }

                    // 3. Переключатель режима выполнения
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "СПОСОБ ВЫПОЛНЕНИЯ"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.textDim
                        }

                        Row {
                            width: parent.width
                            spacing: 10

                            // Режим: Терминал Kitty
                            Rectangle {
                                width: (parent.width - 10) / 2
                                height: 50
                                radius: Theme.radiusSmall
                                color: root.cfgExecInTerminal ? Theme.alpha(Theme.accent, 0.16) : termModeMa.containsMouse ? Theme.glassHover : Theme.glass
                                border.width: 1
                                border.color: root.cfgExecInTerminal ? Theme.accent : Theme.stroke

                                Row {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 12
                                    }
                                    spacing: 10

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: root.cfgExecInTerminal ? Theme.accent : Theme.glass
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf120"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: root.cfgExecInTerminal ? "#0e1720" : Theme.text
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Text {
                                            text: "В терминале (kitty)"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                        }

                                        Text {
                                            text: "Окно с выводом и --hold"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.textDim
                                        }
                                    }
                                }

                                MouseArea {
                                    id: termModeMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cfgExecInTerminal = true
                                }
                            }

                            // Режим: В фоне
                            Rectangle {
                                width: (parent.width - 10) / 2
                                height: 50
                                radius: Theme.radiusSmall
                                color: !root.cfgExecInTerminal ? Theme.alpha(Theme.accent, 0.16) : bgModeMa.containsMouse ? Theme.glassHover : Theme.glass
                                border.width: 1
                                border.color: !root.cfgExecInTerminal ? Theme.accent : Theme.stroke

                                Row {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 12
                                    }
                                    spacing: 10

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: !root.cfgExecInTerminal ? Theme.accent : Theme.glass
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf0e7"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: !root.cfgExecInTerminal ? "#0e1720" : Theme.text
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Text {
                                            text: "В фоне (тихо)"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                        }

                                        Text {
                                            text: "Без всплывающего окна"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.textDim
                                        }
                                    }
                                }

                                MouseArea {
                                    id: bgModeMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cfgExecInTerminal = false
                                }
                            }
                        }
                    }

                    // 4. Выбор иконки
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "ИКОНКА (ВЫБОР ИЛИ СВОЙ ГЛИФ)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.textDim
                        }

                        Row {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: ["\uf120", "\uf021", "\uf135", "\uf013", "\uf0e7", "\uf0ad", "\uf019", "\uf080", "\uf002", "\uf011", "\uf014", "\uf2db", "\uf1b2", "\uf0c7"]

                                delegate: Rectangle {
                                    id: icoChip

                                    required property var modelData
                                    readonly property bool isSel: root.cfgExecIcon === modelData

                                    width: 32
                                    height: 32
                                    radius: 6
                                    color: isSel ? Theme.alpha(Theme.accent, 0.3) : icoMa.containsMouse ? Theme.glassHover : Theme.glass
                                    border.width: 1
                                    border.color: isSel ? Theme.accent : Theme.stroke

                                    Text {
                                        anchors.centerIn: parent
                                        text: icoChip.modelData
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: icoChip.isSel ? Theme.accent : Theme.text
                                    }

                                    MouseArea {
                                        id: icoMa

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cfgExecIcon = icoChip.modelData
                                    }
                                }
                            }

                            // Поле для ввода своего глифа
                            Rectangle {
                                width: 44
                                height: 32
                                radius: 6
                                color: Theme.glass
                                border.width: 1
                                border.color: customIcoInput.activeFocus ? Theme.accent : Theme.stroke

                                TextInput {
                                    id: customIcoInput

                                    anchors.centerIn: parent
                                    text: root.cfgExecIcon
                                    onTextChanged: if (text)
                                        root.cfgExecIcon = text
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: Theme.text
                                    cursorVisible: activeFocus
                                }
                            }
                        }
                    }
                }

                // Правая колонка: предпросмотр и кнопки действий
                Column {
                    width: 220
                    height: parent.height
                    spacing: 10

                    // Выбор размера
                    Row {
                        width: parent.width
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Размер:"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                        }

                        Repeater {
                            model: [
                                {
                                    "lbl": "1x1",
                                    "w": 1,
                                    "h": 1
                                },
                                {
                                    "lbl": "2x1",
                                    "w": 2,
                                    "h": 1
                                },
                                {
                                    "lbl": "2x2",
                                    "w": 2,
                                    "h": 2
                                }
                            ]

                            delegate: Rectangle {
                                id: szChip

                                required property var modelData
                                readonly property bool isSel: root.cfgExecW === modelData.w && root.cfgExecH === modelData.h

                                width: 42
                                height: 22
                                radius: 4
                                color: isSel ? Theme.alpha(Theme.accent, 0.3) : szMa.containsMouse ? Theme.glassHover : Theme.glass
                                border.width: 1
                                border.color: isSel ? Theme.accent : Theme.stroke

                                Text {
                                    anchors.centerIn: parent
                                    text: szChip.modelData.lbl
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: szChip.isSel ? Font.Bold : Font.Normal
                                    color: szChip.isSel ? Theme.accent : Theme.text
                                }

                                MouseArea {
                                    id: szMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.cfgExecW = szChip.modelData.w
                                        root.cfgExecH = szChip.modelData.h
                                    }
                                }
                            }
                        }
                    }

                    // Контейнер предпросмотра
                    Rectangle {
                        width: parent.width
                        height: 180
                        radius: Theme.radius
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke
                        clip: true

                        Item {
                            anchors.centerIn: parent
                            width: Theme.tileW(root.cfgExecW)
                            height: Theme.tileH(root.cfgExecH)

                            ExecWidget {
                                anchors.fill: parent
                                command: root.cfgExecCommand !== "" ? root.cfgExecCommand : "echo 'hello'"
                                label: root.cfgExecLabel
                                iconGlyph: root.cfgExecIcon !== "" ? root.cfgExecIcon : "\uf120"
                                inTerminal: root.cfgExecInTerminal
                            }
                        }
                    }

                    // Кнопка сохранения / добавления
                    Rectangle {
                        id: saveBtn

                        width: parent.width
                        height: 40
                        radius: Theme.radiusSmall
                        color: saveMa.containsMouse ? Theme.accent : Theme.alpha(Theme.accent, 0.88)
                        scale: saveMa.pressed ? 0.96 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 80
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf00c"
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                color: "#0e1720"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.editExecIdx >= 0 ? "Сохранить" : "Добавить виджет"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#0e1720"
                            }
                        }

                        MouseArea {
                            id: saveMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveExecConfig()
                        }
                    }

                    // Кнопка отмены
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.radiusSmall
                        color: cancelMa.containsMouse ? Theme.glassHover : Theme.glass
                        border.width: 1
                        border.color: Theme.stroke

                        Text {
                            anchors.centerIn: parent
                            text: "Отмена"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textDim
                        }

                        MouseArea {
                            id: cancelMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.execConfigOpen = false
                        }
                    }
                }
            }
        }
    }

    // ── нижняя панель: edit-toggle + палитра ──
    Item {
        id: bottomBar

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 22
            rightMargin: 22
            topMargin: root.shownH - bottomBar.height - 10
        }
        height: root.barH - 14

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: root.editMode

            Repeater {
                model: [
                    {
                        "type": "clock",
                        "label": "часы",
                        "glyph": "\uf017"
                    },
                    {
                        "type": "weather",
                        "label": "погода",
                        "glyph": "\uf185"
                    },
                    {
                        "type": "photo",
                        "label": "фото",
                        "glyph": "\uf03e"
                    },
                    {
                        "type": "player",
                        "label": "плеер",
                        "glyph": "\uf001"
                    },
                    {
                        "type": "cpu",
                        "label": "CPU",
                        "glyph": "\uf2db"
                    },
                    {
                        "type": "ram",
                        "label": "RAM",
                        "glyph": "\ue266"
                    },
                    {
                        "type": "gpu",
                        "label": "GPU",
                        "glyph": "\uf109"
                    },
                    {
                        "type": "bat",
                        "label": "BAT",
                        "glyph": "\uf240"
                    },
                    {
                        "type": "ssd",
                        "label": "SSD",
                        "glyph": "\uf0c7"
                    },
                    {
                        "type": "power",
                        "label": "питание",
                        "glyph": "\uf011"
                    },
                    {
                        "type": "exec",
                        "label": "команда",
                        "glyph": "\uf120"
                    },
                    {
                        "type": "app",
                        "label": "приложение",
                        "glyph": "\uf00a"
                    }
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
                            text: chip.modelData.label
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
                        onClicked: {
                            if (chip.modelData.type === "app") {
                                root.pickerOpen = !root.pickerOpen
                                if (root.pickerOpen)
                                    pickSearch.forceActiveFocus()
                            } else if (chip.modelData.type === "exec") {
                                root.openExecConfig(-1)
                            } else {
                                root.addWidget(chip.modelData.type)
                            }
                        }
                    }
                }
            }
        }
    }

    // вертикальная кнопка «изменить/готово» в правом верхнем углу панели
    Rectangle {
        id: editBtn

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 15
            rightMargin: 15
        }
        width: 40
        height: editLabel.width + 30
        radius: 30
        color: root.editMode ? Theme.alpha(Theme.accent, 0.85) : editMa.containsMouse ? Theme.glassHover : Theme.glass
        border.width: 2
        border.color: Theme.stroke

        Text {
            id: editLabel

            anchors.centerIn: parent
            rotation: 0
            text: root.editMode ? "\uf00c" : "\uf044"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: root.editMode ? "#0e1720" : Theme.text
        }

        MouseArea {
            id: editMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editMode = !root.editMode
        }
    }

    // ── фабрики виджетов ──
    Component {
        id: emptyComp

        Item {
        }
    }

    Component {
        id: clockComp

        ClockW {
        }
    }

    Component {
        id: weatherComp

        WeatherW {
        }
    }

    Component {
        id: photoComp

        PhotoWidget {
        }
    }

    Component {
        id: playerComp

        PlayerWidget {
        }
    }

    Component {
        id: powerComp

        PowerWidget {
            onOpenRequested: powerMenu.open()
        }
    }

    Component {
        id: cpuComp

        CpuW {
        }
    }

    Component {
        id: ramComp

        RamW {
        }
    }

    Component {
        id: gpuComp

        GpuW {
        }
    }

    Component {
        id: batComp

        BatW {
        }
    }

    Component {
        id: ssdComp

        SsdW {
        }
    }

    Component {
        id: appComp

        AppW {
        }
    }

    Component {
        id: execComp

        ExecWidget {
        }
    }

    component SysW: TileFrame {
        id: sys

        required property string kind
        readonly property bool isWide: width >= 120
        readonly property bool isTall: height >= 120

        readonly property real val: kind === "cpu" ? root.cpuPct / 100 : kind === "ram" ? root.ramPct / 100 : kind === "gpu" ? root.gpuPct / 100 : kind === "bat" ? root.batPct / 100 : root.diskPct / 100

        readonly property string iconGlyph: {
            if (kind === "cpu")
                return "\uf2db"
            if (kind === "ram")
                return "\ue266"
            if (kind === "gpu")
                return "\uf108"
            if (kind === "bat") {
                if (root.batCharging)
                    return "\uf0e7"
                if (val > 0.85)
                    return "\uf240"
                if (val > 0.60)
                    return "\uf241"
                if (val > 0.35)
                    return "\uf242"
                if (val > 0.15)
                    return "\uf243"
                return "\uf244"
            }
            return "\uf0c7"
        }

        readonly property string shortTitle: kind === "cpu" ? "ЦП" : kind === "ram" ? "ОЗУ" : kind === "gpu" ? "GPU" : kind === "bat" ? "АКБ" : "SSD"
        readonly property string longTitle: kind === "cpu" ? "Процессор" : kind === "ram" ? "Память" : kind === "gpu" ? "Графика" : kind === "bat" ? "Батарея" : "Диск"

        readonly property string subTxt: {
            if (kind === "gpu")
                return root.gpuTemp > 0 ? (root.gpuTemp + "°C") : ""
            if (kind === "bat") {
                if (root.batCharging)
                    return "Зарядка"
                if (root.batStatus === "Full")
                    return "100%"
                if (root.batTime !== "")
                    return root.batTime
                return ""
            }
            if (kind === "ssd")
                return root.diskFree > 0 ? (root.diskFree + "G") : ""
            if (kind === "ram")
                return root.ramUsed !== "" ? (root.ramUsed + " / " + root.ramTotal + " GB") : ""
            return root.cpuPct > 70 ? "Нагрузка" : "Норма"
        }

        readonly property color fillCol: {
            if (kind === "cpu")
                return root.cpuPct > 80 ? Theme.red : root.cpuPct > 50 ? Theme.orange : Theme.accent
            if (kind === "ram")
                return root.ramPct > 85 ? Theme.red : root.ramPct > 60 ? Theme.orange : Theme.teal
            if (kind === "gpu")
                return root.gpuPct > 80 ? Theme.red : root.gpuPct > 50 ? Theme.orange : Theme.purple
            if (kind === "bat")
                return root.batCharging ? Theme.lime : (root.batPct < 15 ? Theme.red : root.batPct < 30 ? Theme.orange : Theme.lime)
            return root.diskPct > 90 ? Theme.red : root.diskPct > 75 ? Theme.orange : Theme.teal
        }

        property real dispValue: val
        property color dispColor: fillCol

        Behavior on dispValue {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        Behavior on dispColor {
            ColorAnimation {
                duration: 400
            }
        }

        // Мягкий акцентный градиент в нижней части плитки
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.16
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }

                GradientStop {
                    position: 1.0
                    color: Theme.alpha(sys.dispColor, 0.5)
                }
            }
        }

        // ── 1x1 Компактный вид ──
        Item {
            anchors.fill: parent
            anchors.margins: 8
            visible: !sys.isWide && !sys.isTall

            // Верхний ряд: Иконка + Мини-бейдж (темп/зарядка)
            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: sys.iconGlyph
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: sys.dispColor
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: sys.kind === "gpu" && root.gpuTemp > 0 ? (root.gpuTemp + "°") : (sys.kind === "bat" && root.batCharging ? "\uf0e7" : (sys.kind === "bat" ? root.batTime : ""))
                    font.family: sys.kind === "bat" && root.batCharging ? Theme.iconFont : Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: sys.kind === "bat" && root.batCharging ? Theme.lime : Theme.textDim
                }
            }

            // Центр: Чёткое число процентов
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: Math.round(sys.dispValue * 100) + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Light
                color: Theme.text
            }

            // Низ: Название + Аккуратная полоска трекера
            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: 3

                Text {
                    text: sys.shortTitle
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textDim
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(255, 255, 255, 0.08)

                    Rectangle {
                        width: Math.max(3, parent.width * Math.min(1, Math.max(0, sys.dispValue)))
                        height: parent.height
                        radius: 1.5
                        color: sys.dispColor

                        Behavior on width {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        // ── 2x1 Широкий вид ──
        Item {
            anchors.fill: parent
            anchors.margins: 12
            visible: sys.isWide && !sys.isTall

            Row {
                anchors.fill: parent
                spacing: 12

                // Иконка в акриловой плашке
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: Theme.radiusSmall
                    color: Theme.glass
                    border.width: 1
                    border.color: Theme.stroke

                    Text {
                        anchors.centerIn: parent
                        text: sys.iconGlyph
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        color: sys.dispColor
                    }
                }

                // Инфо-колонка
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44 - 12
                    spacing: 3

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.right: statusSubTxt.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: sys.shortTitle === "АКБ" ? "Батарея" : (sys.shortTitle === "ЦП" ? "Процессор" : (sys.shortTitle === "ОЗУ" ? "Память" : sys.longTitle))
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }

                        Text {
                            id: statusSubTxt

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: sys.subTxt
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: sys.kind === "bat" && root.batCharging ? Theme.lime : Theme.textDim
                        }
                    }

                    Text {
                        text: Math.round(sys.dispValue * 100) + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.Light
                        color: Theme.text
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            width: Math.max(4, parent.width * Math.min(1, Math.max(0, sys.dispValue)))
                            height: parent.height
                            radius: 2
                            color: sys.dispColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 500
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 2x2 Большой вид ──
        Item {
            anchors.fill: parent
            anchors.margins: 14
            visible: sys.isWide && sys.isTall

            Column {
                width: parent.width
                spacing: 10

                // Верхний ряд
                Row {
                    width: parent.width
                    height: 46

                    Rectangle {
                        width: 46
                        height: 46
                        radius: Theme.radiusSmall
                        color: Theme.glass
                        border.width: 1
                        border.color: Theme.stroke

                        Text {
                            anchors.centerIn: parent
                            text: sys.iconGlyph
                            font.family: Theme.iconFont
                            font.pixelSize: 22
                            color: sys.dispColor
                        }
                    }

                    Item {
                        width: parent.width - 46
                        height: parent.height

                        Column {
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Text {
                                text: sys.longTitle
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                text: sys.kind === "bat" ? (root.batCharging ? "Заряжается" : (root.batStatus === "Full" ? "Полный заряд" : (root.batTime !== "" ? ("Осталось ~" + root.batTime) : "Разряжается"))) : (sys.subTxt !== "" ? sys.subTxt : (Math.round(sys.dispValue * 100) + "% нагрузка"))
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: sys.kind === "bat" && root.batCharging ? Theme.lime : Theme.textDim
                            }
                        }
                    }
                }

                // Центральный процент
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Text {
                        text: Math.round(sys.dispValue * 100)
                        font.family: Theme.fontFamily
                        font.pixelSize: 46
                        font.weight: Font.Light
                        color: Theme.text
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Light
                        color: Theme.textDim
                    }
                }

                // Нижний прогресс бар и подписи
                Column {
                    width: parent.width
                    spacing: 4

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            width: Math.max(6, parent.width * Math.min(1, Math.max(0, sys.dispValue)))
                            height: parent.height
                            radius: 3
                            color: sys.dispColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 500
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 12

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "0%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.textDim
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: sys.kind === "ram" && root.ramTotal !== "" ? (root.ramUsed + " / " + root.ramTotal + " GB") : "100%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.textDim
                        }
                    }
                }
            }
        }
    }

    component CpuW: SysW {
        kind: "cpu"
    }

    component RamW: SysW {
        kind: "ram"
    }

    component GpuW: SysW {
        kind: "gpu"
    }

    component BatW: SysW {
        kind: "bat"
    }

    component SsdW: SysW {
        kind: "ssd"
    }

    component ClockW: Rectangle {
        id: clk

        property bool showCal: false
        readonly property bool large: width >= 170 && height >= 170

        radius: Theme.radius
        color: Theme.alpha(Theme.accent, 0.92)

        transform: Scale {
            id: clockScale

            origin.x: clk.width / 2
            origin.y: clk.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: calFlip

            NumberAnimation {
                target: clockScale
                property: "xScale"
                to: 0
                duration: 200
                easing.type: Easing.InQuad
            }

            ScriptAction {
                script: clk.showCal = !clk.showCal
            }

            NumberAnimation {
                target: clockScale
                property: "xScale"
                to: 1
                duration: 200
                easing.type: Easing.OutBack
            }
        }

        Connections {
            target: root

            function onShownChanged() {
                if (!root.shown)
                    clk.showCal = false
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: clk.large
            cursorShape: clk.large ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: calFlip.restart()
        }

        Column {
            anchors.centerIn: parent
            visible: !clk.showCal
            spacing: clk.large ? 2 : 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                font.family: Theme.fontFamily
                font.pixelSize: clk.large ? 58 : clk.width > 100 ? 34 : 24
                font.weight: Font.Light
                color: Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: clk.width > 100
                text: clk.large ? ruDate(clock.date) : Qt.formatDate(clock.date, "d MMM")
                font.family: Theme.fontFamily
                font.pixelSize: clk.large ? 13 : 11
                color: Theme.text
            }
        }

        // секундная полоска (только крупные версии)
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 12
            }
            visible: clk.large && !clk.showCal
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.25)

            Rectangle {
                width: parent.width * (clock.date.getSeconds() / 60)
                height: parent.height
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.9)

                Behavior on width {
                    NumberAnimation {
                        duration: 950
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        // мини-календарь (заменяет часы по клику, только 2x2)
        Item {
            anchors.fill: parent
            visible: clk.showCal

            Text {
                anchors {
                    top: parent.top
                    topMargin: 12
                    horizontalCenter: parent.horizontalCenter
                }
                text: ruMonth(clock.date)
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.text
            }

            Grid {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: 6
                }
                columns: 7
                spacing: 1

                Repeater {
                    model: {
                        const now = clock.date
                        const days = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
                        const first = new Date(now.getFullYear(), now.getMonth(), 1).getDay()
                        const shift = (first + 6) % 7
                        const cells = []
                        for (let i = 0; i < shift; i++)
                            cells.push(0)
                        for (let d = 1; d <= days; d++)
                            cells.push(d)
                        return cells
                    }

                    delegate: Item {
                        required property int modelData

                        width: 22
                        height: 20

                        Rectangle {
                            anchors.centerIn: parent
                            width: 17
                            height: 17
                            radius: 8.5
                            visible: modelData === clock.date.getDate()
                            color: Theme.text
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: modelData > 0
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: modelData === clock.date.getDate() ? Theme.accent : Theme.text
                        }
                    }
                }
            }

            Text {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 10
                    horizontalCenter: parent.horizontalCenter
                }
                text: ruDate(clock.date)
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.text
            }
        }
    }

    component WeatherW: TileFrame {
        id: weatherTile

        property bool alt: false

        transform: Scale {
            id: weatherScale

            origin.x: weatherTile.width / 2
            origin.y: weatherTile.height / 2
            xScale: 1
        }

        Timer {
            interval: 6000
            running: root.open
            repeat: true
            onTriggered: weatherFlip.restart()
        }

        SequentialAnimation {
            id: weatherFlip

            NumberAnimation {
                target: weatherScale
                property: "xScale"
                to: 0
                duration: 240
                easing.type: Easing.InQuad
            }

            ScriptAction {
                script: weatherTile.alt = !weatherTile.alt
            }

            NumberAnimation {
                target: weatherScale
                property: "xScale"
                to: 1
                duration: 240
                easing.type: Easing.OutQuad
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.loaded ? Weather.glyph(Weather.code) : "\uf0595"
                font.family: Theme.iconFont
                font.pixelSize: 42
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
                text: !Weather.loaded ? "загрузка..." : weatherTile.alt ? "ветер " + Weather.wind.toFixed(1) + " м/с" : Weather.text(Weather.code)
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textDim
            }
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: 12
                bottom: parent.bottom
                bottomMargin: 10
            }
            text: Weather.city
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 12
                bottom: parent.bottom
                bottomMargin: 10
            }
            text: !Weather.loaded ? "" : weatherTile.alt ? Weather.humidity + "%" : Math.round(Weather.feelsLike) + "° ощущ."
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textDim
        }

        onClicked: root.expandMode = root.expandMode === "weather" ? "none" : "weather"
    }

    component AppW: TileFrame {
        id: appTile

        property string appId: ""
        property var app: null

        onAppIdChanged: app = root.findApp(appId)
        Component.onCompleted: app = root.findApp(appId)

        Column {
            anchors.centerIn: parent
            spacing: 6

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: appTile.height > 100 ? 56 : appTile.width > 100 ? 40 : 30
                height: width

                IconImage {
                    anchors.centerIn: parent
                    visible: appTile.app && appTile.app.icon !== "" && Quickshell.hasThemeIcon(appTile.app.icon)
                    implicitSize: parent.width
                    source: appTile.app && appTile.app.icon !== "" && Quickshell.hasThemeIcon(appTile.app.icon) ? Quickshell.iconPath(appTile.app.icon) : ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !(appTile.app && appTile.app.icon !== "" && Quickshell.hasThemeIcon(appTile.app.icon))
                    text: "\uf1b2"
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: Theme.textDim
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: appTile.width - 12
                text: appTile.app ? appTile.app.name : appTile.appId
                font.family: Theme.fontFamily
                font.pixelSize: appTile.height > 100 ? 12 : 10
                color: Theme.text
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        onClicked: {
            if (app) {
                app.execute()
                root.open = false
            }
        }
    }

    // ── раскрытие погоды ──
    Item {
        id: expandArea

        readonly property bool expanded: root.expandMode !== "none"

        visible: root.open && opacity > 0.01
        opacity: expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: expandArea.expanded ? 120 : 100
            }
        }

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: 252
            leftMargin: 22
            rightMargin: 22
        }
        height: 400

        WeatherDetail {
            visible: root.expandMode === "weather"
            opacity: root.expandMode === "weather" ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }
    }

    // ── окно питания ──
    PowerMenu {
        id: powerMenu
    }
}

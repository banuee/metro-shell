import QtQuick
import Quickshell
import Quickshell.Io

Flickable {
    id: root

    clip: true
    contentHeight: col.height + 24
    boundsBehavior: Flickable.StopAtBounds

    property var win

    // Sub-tab selection: 0=wifi, 1=saved_wifi, 2=dns, 3=proxy, 4=bluetooth
    property int currentTab: 0

    // Wi-Fi live state
    property bool wifiOn: false
    property string wifiSsid: ""
    property string wifiDev: ""
    property var networks: []
    property var knownWifi: []

    // Network Details
    property var netDetails: ({ "ipv4": "—", "ipv6": "—", "gateway": "—", "mac": "—", "active_device": "—", "interfaces": [] })
    property string publicIp: "—"
    property bool checkingPublicIp: false

    // Saved Wi-Fi with Passwords
    property var savedWifiList: []
    property var revealedList: []
    property string copiedSsid: ""

    // DNS state
    property var dnsInfo: ({ "connection": "", "device": "", "mode": "dhcp", "configured_servers": [], "active_servers": [], "ignore_auto": false })
    property string selectedDnsPreset: "dhcp"
    property string customDns1: ""
    property string customDns2: ""
    property string dnsStatus: ""

    // Proxy state
    property var proxyInfo: ({ "mode": "none", "http_host": "", "http_port": 8080, "https_host": "", "https_port": 8080, "socks_host": "", "socks_port": 1080, "autoconfig_url": "", "ignore_hosts": "" })
    property string proxyMode: "none"
    property string proxyStatus: ""

    // Bluetooth
    property bool btOn: false
    property var btDevices: []
    property bool scanning: false
    property int scanTicks: 0

    // Экранирование для подстановки внутрь ДВОЙНЫХ кавычек sh.
    // Закрывает: " \ $ ` — этого достаточно, т.к. внутри "..." sh раскрывает
    // только $ и ` (и " \). НЕ использовать результат внутри '...'!
    function esc(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`")
    }

    function splitT(l) {
        const parts = []
        let cur = "", i = 0
        while (i < l.length) {
            if (l[i] === "\\" && l[i + 1] === ":") {
                cur += ":"
                i += 2
                continue
            }
            if (l[i] === ":") {
                parts.push(cur)
                cur = ""
                i++
                continue
            }
            cur += l[i]
            i++
        }
        parts.push(cur)
        return parts
    }

    function refresh() {
        // Wi-Fi basics
        pWl.command = ["sh", "-c", "echo p=$(nmcli radio wifi 2>/dev/null); echo d=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | head -n1 | cut -d: -f1); echo n=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep ':802-11-wireless:' | head -n1 | cut -d: -f1)"]
        pWl.running = true
        pNet.command = ["sh", "-c", "LC_ALL=C nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        pNet.running = true
        pKnown.command = ["sh", "-c", "LC_ALL=C nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep 802-11-wireless"]
        pKnown.running = true

        // Backend calls
        pNetDetails.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py net info"]
        pNetDetails.running = true

        pSavedWifi.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py wifi saved"]
        pSavedWifi.running = true

        pDnsInfo.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py dns get"]
        pDnsInfo.running = true

        pProxyInfo.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py proxy get"]
        pProxyInfo.running = true

        refreshBt()
    }

    function refreshBt() {
        pBt.command = ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -i 'Powered'; echo ---; bluetoothctl devices Paired 2>/dev/null; echo ---; bluetoothctl devices Connected 2>/dev/null"]
        pBt.running = true
        pAllBt.command = ["sh", "-c", "bluetoothctl devices 2>/dev/null"]
        pAllBt.running = true
    }

    function startScan() {
        if (!btOn || scanning)
            return
        scanning = true
        scanTicks = 5
        pScan.command = ["sh", "-c", "bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &"]
        pScan.running = true
        scanTimer.restart()
    }

    function connectWifi(ssid, pw) {
        let cmd = "nmcli dev wifi connect \"" + esc(ssid) + "\""
        if (pw !== "")
            cmd += " password \"" + esc(pw) + "\""
        win.run(cmd)
        delay.interval = 3000
        delay.restart()
    }

    function toggleSavedAutoconnect(name, curVal) {
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py wifi autoconnect \"" + esc(name) + "\" " + (!curVal ? "true" : "false"))
        delay.interval = 800
        delay.restart()
    }

    function forgetSavedNetwork(name) {
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py wifi forget \"" + esc(name) + "\"")
        delay.interval = 800
        delay.restart()
    }

    function toggleShowPassword(name) {
        if (revealedList.indexOf(name) >= 0) {
            revealedList = revealedList.filter(n => n !== name)
        } else {
            revealedList = revealedList.concat([name])
        }
    }

    function copyPassword(ssid, pw) {
        // двойные кавычки + esc (в одинарных esc не работает — был breakout)
        win.run("printf '%s' \"" + esc(pw) + "\" | wl-copy")
        copiedSsid = ssid
        copyTimer.restart()
    }

    function applyDns() {
        dnsStatus = I18n.t("loading")
        const conn = dnsInfo.connection || wifiSsid
        let cmd = "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py dns set \"" + esc(conn) + "\" \"" + selectedDnsPreset + "\""
        if (selectedDnsPreset === "custom") {
            cmd += " \"" + esc(customDns1) + "\" \"" + esc(customDns2) + "\""
        }
        win.run(cmd)
        delayDns.restart()
    }

    function applyProxy() {
        proxyStatus = I18n.t("loading")
        const payload = {
            "mode": proxyMode,
            "http_host": httpHostInput.text,
            "http_port": parseInt(httpPortInput.text) || 8080,
            "https_host": httpsHostInput.text,
            "https_port": parseInt(httpsPortInput.text) || 8080,
            "socks_host": socksHostInput.text,
            "socks_port": parseInt(socksPortInput.text) || 1080,
            "autoconfig_url": pacUrlInput.text,
            "ignore_hosts": ignoreHostsInput.text
        }
        const jsonStr = JSON.stringify(payload).replace(/"/g, '\\"')
        win.run("python3 $HOME/.config/quickshell/metro-settings/settings_backend.py proxy set \"" + jsonStr + "\"")
        delayProxy.restart()
    }

    function fetchPublicIp() {
        checkingPublicIp = true
        pPublicIp.command = ["sh", "-c", "python3 $HOME/.config/quickshell/metro-settings/settings_backend.py net public-ip"]
        pPublicIp.running = true
    }

    // Timers
    Timer { id: delay; interval: 1500; onTriggered: refresh() }
    Timer { id: copyTimer; interval: 2200; onTriggered: copiedSsid = "" }
    Timer { id: delayDns; interval: 1800; onTriggered: { refresh(); dnsStatus = I18n.t("success") } }
    Timer { id: delayProxy; interval: 1200; onTriggered: { refresh(); proxyStatus = I18n.t("success") } }
    Timer {
        id: scanTimer
        interval: 2000
        repeat: true
        onTriggered: {
            root.refreshBt()
            root.scanTicks--
            if (root.scanTicks <= 0) {
                stop()
                root.scanning = false
            }
        }
    }

    // Processes
    Process { id: pScan; command: ["true"] }
    Process {
        id: pWl
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (line.indexOf("p=") === 0) root.wifiOn = line.slice(2).trim() === "enabled"
                    else if (line.indexOf("d=") === 0) root.wifiDev = line.slice(2).trim()
                    else if (line.indexOf("n=") === 0) root.wifiSsid = line.slice(2).trim()
                }
            }
        }
    }
    Process {
        id: pNet
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                const seen = {}
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue
                    const f = root.splitT(line)
                    if (f.length < 4) continue
                    const active = f[0] === "*"
                    const ssid = f[1].trim()
                    const sig = parseInt(f[2]) || 0
                    const sec = f[3].trim()
                    if (!ssid || seen[ssid]) continue
                    seen[ssid] = true
                    list.push({ active: active, ssid: ssid, signal: sig, sec: sec })
                }
                list.sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) || b.signal - a.signal)
                root.networks = list
            }
        }
    }
    Process {
        id: pKnown
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const f = root.splitT(line)
                    if (f[0] && f[0].trim()) list.push(f[0].trim())
                }
                root.knownWifi = list
            }
        }
    }
    Process {
        id: pSavedWifi
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.savedWifiList = JSON.parse(text)
                } catch (e) {
                    root.savedWifiList = []
                }
            }
        }
    }
    Process {
        id: pNetDetails
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.netDetails = JSON.parse(text)
                } catch (e) {}
            }
        }
    }
    Process {
        id: pPublicIp
        stdout: StdioCollector {
            onStreamFinished: {
                root.checkingPublicIp = false
                try {
                    const res = JSON.parse(text)
                    root.publicIp = res.public_ip || "—"
                } catch (e) {
                    root.publicIp = "—"
                }
            }
        }
    }
    Process {
        id: pDnsInfo
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    root.dnsInfo = res
                    root.selectedDnsPreset = res.mode || "dhcp"
                    if (res.mode === "custom" && res.configured_servers) {
                        root.customDns1 = res.configured_servers[0] || ""
                        root.customDns2 = res.configured_servers[1] || ""
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: pProxyInfo
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    root.proxyInfo = res
                    root.proxyMode = res.mode || "none"
                    httpHostInput.text = res.http_host || ""
                    httpPortInput.text = String(res.http_port || 8080)
                    httpsHostInput.text = res.https_host || ""
                    httpsPortInput.text = String(res.https_port || 8080)
                    socksHostInput.text = res.socks_host || ""
                    socksPortInput.text = String(res.socks_port || 1080)
                    pacUrlInput.text = res.autoconfig_url || ""
                    ignoreHostsInput.text = res.ignore_hosts || "localhost, 127.0.0.1, ::1"
                } catch (e) {}
            }
        }
    }
    Process {
        id: pBt
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---")
                root.btOn = /Powered:\s*yes/i.test(parts[0] || "")
                const pairedMacs = {}
                const connMacs = {}
                for (const l of (parts[1] || "").split("\n")) {
                    const m = l.match(/Device\s+([0-9A-F:]{17})\s+(.*)/i)
                    if (m) pairedMacs[m[1]] = m[2].trim()
                }
                for (const l of (parts[2] || "").split("\n")) {
                    const m = l.match(/Device\s+([0-9A-F:]{17})\s+(.*)/i)
                    if (m) connMacs[m[1]] = m[2].trim()
                }
                const devs = []
                for (const mac in pairedMacs) {
                    devs.push({
                        mac: mac,
                        name: pairedMacs[mac] || mac,
                        paired: true,
                        connected: !!connMacs[mac]
                    })
                }
                devs.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
                root.btDevices = devs
            }
        }
    }
    Process {
        id: pAllBt
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.scanning) return
                const devs = root.btDevices.slice()
                const existing = {}
                for (const d of devs) existing[d.mac] = true
                for (const l of text.split("\n")) {
                    const m = l.match(/Device\s+([0-9A-F:]{17})\s+(.*)/i)
                    if (m && !existing[m[1]]) {
                        devs.push({ mac: m[1], name: m[2].trim() || m[1], paired: false, connected: false })
                        existing[m[1]] = true
                    }
                }
                root.btDevices = devs
            }
        }
    }

    Component.onCompleted: refresh()

    Column {
        id: col
        width: root.width
        spacing: 14

        // ─── Sub-Navigation Pills ───
        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    { id: 0, label: I18n.t("tab_wifi"), glyph: "\uf1eb" },
                    { id: 1, label: I18n.t("tab_saved_wifi"), glyph: "\uf023" },
                    { id: 2, label: I18n.t("tab_dns"), glyph: "\uf0ac" },
                    { id: 3, label: I18n.t("tab_proxy"), glyph: "\uf233" },
                    { id: 4, label: I18n.t("tab_bluetooth"), glyph: "\uf293" }
                ]

                Rectangle {
                    id: tabPill
                    required property var modelData
                    width: (col.width - 4 * 6) / 5
                    height: 38
                    radius: 8
                    color: root.currentTab === tabPill.modelData.id ? Theme.alpha(Theme.accent, 0.9) : (tabMa.containsMouse ? Theme.glassHover : Theme.glass)
                    border.width: 1
                    border.color: root.currentTab === tabPill.modelData.id ? Theme.accent : Theme.stroke
                    scale: tabMa.pressed ? 0.95 : (tabMa.containsMouse ? 1.015 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabPill.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: root.currentTab === tabPill.modelData.id ? "#fff" : Theme.accent
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabPill.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: root.currentTab === tabPill.modelData.id ? Font.DemiBold : Font.Normal
                            color: root.currentTab === tabPill.modelData.id ? "#fff" : Theme.text
                            elide: Text.ElideRight
                            width: tabPill.width - 32
                        }
                    }

                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = tabPill.modelData.id
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 0: WI-FI & NETWORK DETAILS
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 0
            width: parent.width
            spacing: 12

            Text {
                text: "WI-FI"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: 8
                color: Theme.glass

                KitToggle {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.wifiOn
                    onToggled: c => {
                        root.win.run("nmcli radio wifi " + (c ? "on" : "off"))
                        delay.interval = 1200
                        delay.restart()
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 70
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: root.wifiOn ? (root.wifiSsid === "" ? I18n.t("not_connected") : root.wifiSsid) : I18n.t("wifi_off")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: root.wifiSsid ? Font.DemiBold : Font.Normal
                        color: root.wifiOn ? Theme.text : Theme.textDim
                    }
                    Text {
                        text: root.networks.length + " " + I18n.t("networks_found")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96
                    height: 32
                    radius: 6
                    color: rescanMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08)
                    scale: rescanMa.pressed ? 0.94 : (rescanMa.containsMouse ? 1.03 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "\uf021"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.text }
                        Text { text: I18n.t("refresh"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.text }
                    }

                    MouseArea {
                        id: rescanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.win.run("nmcli dev wifi rescan")
                            delay.interval = 1800
                            delay.restart()
                        }
                    }
                }
            }

            // Wi-Fi network rows
            Repeater {
                model: root.wifiOn ? root.networks : []

                Rectangle {
                    id: netRow
                    required property var modelData
                    width: parent.width
                    height: 44
                    radius: 8
                    color: netMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: netRow.modelData.active ? Theme.alpha(Theme.accent, 0.5) : (netMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Theme.stroke)
                    scale: netMa.pressed ? 0.98 : (netMa.containsMouse ? 1.008 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    MouseArea {
                        id: netMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const nd = netRow.modelData
                            if (nd.active) {
                                root.win.run("nmcli dev disconnect " + root.wifiDev)
                            } else if (nd.sec !== "" && root.knownWifi.indexOf(nd.ssid) < 0) {
                                root.win.askText(I18n.t("password") + " «" + nd.ssid + "»", I18n.t("password"), pw => root.connectWifi(nd.ssid, pw))
                            } else {
                                root.connectWifi(nd.ssid, "")
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: netRow.modelData.active ? "\uf058" : (netRow.modelData.sec !== "" ? "\uf023" : "\uf09c")
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: netRow.modelData.active ? Theme.accent : Theme.textDim
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: netOps.left
                        anchors.rightMargin: 8
                        text: netRow.modelData.ssid
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: netRow.modelData.active ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        color: netRow.modelData.active ? Theme.text : Theme.textDim
                    }

                    Row {
                        id: netOps
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            visible: root.knownWifi.indexOf(netRow.modelData.ssid) >= 0 && !netRow.modelData.active
                            width: ftxt.width + 16
                            height: 26
                            radius: 5
                            color: forgetMa.containsMouse ? Theme.alpha(Theme.red, 0.55) : Qt.rgba(1, 1, 1, 0.06)
                            scale: forgetMa.pressed ? 0.92 : (forgetMa.containsMouse ? 1.05 : 1.0)

                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Text {
                                id: ftxt
                                anchors.centerIn: parent
                                text: I18n.t("forget")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                            }

                            MouseArea {
                                id: forgetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.win.run("nmcli connection delete id \"" + root.esc(netRow.modelData.ssid) + "\"")
                                    delay.interval = 1200
                                    delay.restart()
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRow.modelData.signal + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textDim
                        }
                    }
                }
            }

            Item { width: 1; height: 6 }

            // Network Information Card
            Text {
                text: I18n.t("network_details")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Rectangle {
                width: parent.width
                height: netInfoCol.implicitHeight + 24
                radius: 10
                color: Theme.glass

                Column {
                    id: netInfoCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 8

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 8

                        // Local IP
                        Row {
                            spacing: 8
                            Text { text: I18n.t("local_ip"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textDim; width: 110 }
                            Text { text: root.netDetails.ipv4 || "—"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                        }

                        // Gateway
                        Row {
                            spacing: 8
                            Text { text: I18n.t("gateway"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textDim; width: 110 }
                            Text { text: root.netDetails.gateway || "—"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.text }
                        }

                        // MAC Address
                        Row {
                            spacing: 8
                            Text { text: I18n.t("mac_addr"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textDim; width: 110 }
                            Text { text: root.netDetails.mac || "—"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textDim }
                        }

                        // Public IP with on-demand check
                        Row {
                            spacing: 8
                            Text { text: I18n.t("public_ip"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textDim; width: 110 }
                            Text {
                                text: root.checkingPublicIp ? I18n.t("checking_ip") : root.publicIp
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.accent
                            }
                            Rectangle {
                                width: pubTxt.width + 18
                                height: 22
                                radius: 4
                                color: pubMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08)
                                Text { id: pubTxt; anchors.centerIn: parent; text: I18n.t("fetch_public_ip"); font.family: Theme.fontFamily; font.pixelSize: 10; color: Theme.text }
                                MouseArea { id: pubMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fetchPublicIp() }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 1: SAVED WI-FI NETWORKS & PASSWORDS
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 1
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("saved_networks_title")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Text {
                text: I18n.t("saved_networks_desc")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.text
            }

            Text {
                visible: root.savedWifiList.length === 0
                text: I18n.t("no_saved_networks")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.textDim
            }

            Repeater {
                model: root.savedWifiList

                Rectangle {
                    id: savedCard
                    required property var modelData
                    width: parent.width
                    height: 56
                    radius: 8
                    color: Theme.glass
                    border.width: 1
                    border.color: savedCard.modelData.active ? Theme.alpha(Theme.accent, 0.4) : Theme.stroke

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: savedCard.modelData.active ? "\uf058" : "\uf1eb"
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: savedCard.modelData.active ? Theme.accent : Theme.textDim
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 8
                                Text {
                                    text: savedCard.modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                                Rectangle {
                                    visible: savedCard.modelData.active
                                    width: actBadge.width + 8
                                    height: 16
                                    radius: 3
                                    color: Theme.alpha(Theme.accent, 0.3)
                                    Text { id: actBadge; anchors.centerIn: parent; text: I18n.t("connected"); font.family: Theme.fontFamily; font.pixelSize: 9; color: Theme.accent }
                                }
                            }

                            Row {
                                spacing: 8
                                Text {
                                    text: savedCard.modelData.security
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textDim
                                }
                                Text {
                                    text: "·"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textDim
                                }
                                Text {
                                    text: root.revealedList.indexOf(savedCard.modelData.name) >= 0 ? (savedCard.modelData.password || "—") : "••••••••"
                                    font.family: root.revealedList.indexOf(savedCard.modelData.name) >= 0 ? "Monospace" : Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: root.revealedList.indexOf(savedCard.modelData.name) >= 0 ? Font.DemiBold : Font.Normal
                                    color: root.revealedList.indexOf(savedCard.modelData.name) >= 0 ? Theme.accent : Theme.textDim
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Show/Hide password toggle button
                        Rectangle {
                            width: showPwTxt.width + 16
                            height: 28
                            radius: 6
                            color: showPwMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: root.revealedList.indexOf(savedCard.modelData.name) >= 0 ? "\uf070" : "\uf06e"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
                                    color: Theme.text
                                }
                                Text {
                                    id: showPwTxt
                                    text: root.revealedList.indexOf(savedCard.modelData.name) >= 0 ? I18n.t("hide_password") : I18n.t("show_password")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: showPwMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleShowPassword(savedCard.modelData.name)
                            }
                        }

                        // Copy Password button
                        Rectangle {
                            visible: !!savedCard.modelData.password
                            width: copyPwTxt.width + 16
                            height: 28
                            radius: 6
                            color: root.copiedSsid === savedCard.modelData.name ? Theme.alpha(Theme.lime, 0.3) : (copyPwMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.06))

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: root.copiedSsid === savedCard.modelData.name ? "\uf00c" : "\uf0c5"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
                                    color: root.copiedSsid === savedCard.modelData.name ? Theme.lime : Theme.text
                                }
                                Text {
                                    id: copyPwTxt
                                    text: root.copiedSsid === savedCard.modelData.name ? I18n.t("copied") : I18n.t("copy")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: root.copiedSsid === savedCard.modelData.name ? Theme.lime : Theme.text
                                }
                            }

                            MouseArea {
                                id: copyPwMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyPassword(savedCard.modelData.name, savedCard.modelData.password)
                            }
                        }

                        // Auto-connect toggle
                        Rectangle {
                            width: autoConnTxt.width + 16
                            height: 28
                            radius: 6
                            color: savedCard.modelData.autoconnect ? Theme.alpha(Theme.accent, 0.25) : Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                id: autoConnTxt
                                anchors.centerIn: parent
                                text: I18n.t("autoconnect")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: savedCard.modelData.autoconnect ? Theme.accent : Theme.textDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSavedAutoconnect(savedCard.modelData.name, savedCard.modelData.autoconnect)
                            }
                        }

                        // Delete / Forget button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: delSavedMa.containsMouse ? Theme.alpha(Theme.red, 0.6) : Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: delSavedMa.containsMouse ? "#fff" : Theme.textDim
                            }

                            MouseArea {
                                id: delSavedMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.forgetSavedNetwork(savedCard.modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 2: DNS CONFIGURATION
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 2
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("dns_title")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Text {
                text: I18n.t("dns_desc")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.text
            }

            Rectangle {
                width: parent.width
                height: 48
                radius: 8
                color: Theme.glass

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text { text: "\uf0ac"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.accent }
                    Text { text: I18n.t("active_connection"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textDim }
                    Text { text: root.dnsInfo.connection || root.wifiSsid || "—"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: "·"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textDim }
                    Text { text: I18n.t("current_dns"); font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textDim }
                    Text { text: (root.dnsInfo.active_servers || []).join(", ") || "—"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.accent }
                }
            }

            Text {
                text: I18n.t("dns_mode")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Repeater {
                model: [
                    { id: "dhcp", label: I18n.t("dns_dhcp"), sub: I18n.t("dns_dhcp_sub"), glyph: "\uf015" },
                    { id: "cloudflare", label: I18n.t("dns_cloudflare"), sub: I18n.t("dns_cloudflare_sub"), glyph: "\uf0e7" },
                    { id: "google", label: I18n.t("dns_google"), sub: I18n.t("dns_google_sub"), glyph: "\uf1a0" },
                    { id: "quad9", label: I18n.t("dns_quad9"), sub: I18n.t("dns_quad9_sub"), glyph: "\uf132" },
                    { id: "adguard", label: I18n.t("dns_adguard"), sub: I18n.t("dns_adguard_sub"), glyph: "\uf05e" },
                    { id: "custom", label: I18n.t("dns_custom"), sub: I18n.t("dns_custom_sub"), glyph: "\uf013" }
                ]

                Rectangle {
                    id: dnsCard
                    required property var modelData
                    width: parent.width
                    height: 52
                    radius: 8
                    color: root.selectedDnsPreset === dnsCard.modelData.id ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: root.selectedDnsPreset === dnsCard.modelData.id ? Theme.accent : Theme.stroke

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "transparent"
                            border.width: 2
                            border.color: root.selectedDnsPreset === dnsCard.modelData.id ? Theme.accent : Qt.rgba(1, 1, 1, 0.3)
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: Theme.accent
                                anchors.centerIn: parent
                                visible: root.selectedDnsPreset === dnsCard.modelData.id
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: dnsCard.modelData.label; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                            Text { text: dnsCard.modelData.sub; font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.textDim }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDnsPreset = dnsCard.modelData.id
                    }
                }
            }

            // Custom DNS inputs
            Column {
                visible: root.selectedDnsPreset === "custom"
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: d1In.activeFocus ? Theme.accent : Theme.stroke

                        TextInput {
                            id: d1In
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Monospace"
                            font.pixelSize: 13
                            color: Theme.text
                            text: root.customDns1
                            onTextChanged: root.customDns1 = text
                        }
                        Text { visible: d1In.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("primary_dns"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: d2In.activeFocus ? Theme.accent : Theme.stroke

                        TextInput {
                            id: d2In
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Monospace"
                            font.pixelSize: 13
                            color: Theme.text
                            text: root.customDns2
                            onTextChanged: root.customDns2 = text
                        }
                        Text { visible: d2In.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("secondary_dns"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.dnsStatus !== ""
                    text: root.dnsStatus
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.lime
                }

                Rectangle {
                    width: applyDnsTxt.width + 24
                    height: 36
                    radius: 8
                    color: Theme.alpha(Theme.accent, applyDnsMa.pressed ? 0.95 : 0.8)

                    Text {
                        id: applyDnsTxt
                        anchors.centerIn: parent
                        text: I18n.t("apply_dns")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#fff"
                    }

                    MouseArea {
                        id: applyDnsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyDns()
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 3: SYSTEM PROXY
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 3
            width: parent.width
            spacing: 12

            Text {
                text: I18n.t("proxy_title")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Text {
                text: I18n.t("proxy_desc")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.text
            }

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        { id: "none", label: I18n.t("proxy_none"), glyph: "\uf05e" },
                        { id: "manual", label: I18n.t("proxy_manual"), glyph: "\uf013" },
                        { id: "auto", label: I18n.t("proxy_auto"), glyph: "\uf0ac" }
                    ]

                    Rectangle {
                        id: proxyPill
                        required property var modelData
                        width: (col.width - 2 * 8) / 3
                        height: 52
                        radius: 8
                        color: root.proxyMode === proxyPill.modelData.id ? Theme.glassHover : Theme.glass
                        border.width: 1
                        border.color: root.proxyMode === proxyPill.modelData.id ? Theme.accent : Theme.stroke

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: proxyPill.modelData.glyph; font.family: Theme.iconFont; font.pixelSize: 14; color: root.proxyMode === proxyPill.modelData.id ? Theme.accent : Theme.textDim }
                            Text { text: proxyPill.modelData.label; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.proxyMode = proxyPill.modelData.id
                        }
                    }
                }
            }

            // Manual proxy inputs
            Column {
                visible: root.proxyMode === "manual"
                width: parent.width
                spacing: 10

                // HTTP Proxy
                Row {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: parent.width - 108
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: httpHostInput.activeFocus ? Theme.accent : Theme.stroke
                        TextInput { id: httpHostInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                        Text { visible: httpHostInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("http_proxy") + " (" + I18n.t("host") + ")"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                    Rectangle {
                        width: 100
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: httpPortInput.activeFocus ? Theme.accent : Theme.stroke
                        TextInput { id: httpPortInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                        Text { visible: httpPortInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("port"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                }

                // HTTPS Proxy
                Row {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: parent.width - 108
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: httpsHostInput.activeFocus ? Theme.accent : Theme.stroke
                        TextInput { id: httpsHostInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                        Text { visible: httpsHostInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("https_proxy") + " (" + I18n.t("host") + ")"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                    Rectangle {
                        width: 100
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: httpsPortInput.activeFocus ? Theme.accent : Theme.stroke
                        TextInput { id: httpsPortInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                        Text { visible: httpsPortInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("port"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                }

                // SOCKS5 Proxy
                Row {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: parent.width - 108
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: socksHostInput.activeFocus ? Theme.accent : Theme.stroke
                        TextInput { id: socksHostInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                        Text { visible: socksHostInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("socks_proxy") + " (" + I18n.t("host") + ")"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                    Rectangle {
                        width: 100
                        height: 42
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: socksPortInput.activeFocus ? Theme.accent : Theme.stroke
                        TextInput { id: socksPortInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                        Text { visible: socksPortInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("port"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                    }
                }

                // Ignore Hosts
                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: ignoreHostsInput.activeFocus ? Theme.accent : Theme.stroke
                    TextInput { id: ignoreHostsInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 12; color: Theme.text }
                    Text { visible: ignoreHostsInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("ignore_hosts"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
                }
            }

            // Auto PAC URL input
            Rectangle {
                visible: root.proxyMode === "auto"
                width: parent.width
                height: 42
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: 1
                border.color: pacUrlInput.activeFocus ? Theme.accent : Theme.stroke
                TextInput { id: pacUrlInput; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; font.family: "Monospace"; font.pixelSize: 13; color: Theme.text }
                Text { visible: pacUrlInput.text === ""; anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter; text: I18n.t("pac_url"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.alpha(Theme.text, 0.35) }
            }

            Row {
                anchors.right: parent.right
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.proxyStatus !== ""
                    text: root.proxyStatus
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.lime
                }

                Rectangle {
                    width: applyProxyTxt.width + 24
                    height: 36
                    radius: 8
                    color: Theme.alpha(Theme.accent, applyProxyMa.pressed ? 0.95 : 0.8)

                    Text {
                        id: applyProxyTxt
                        anchors.centerIn: parent
                        text: I18n.t("apply_proxy")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#fff"
                    }

                    MouseArea {
                        id: applyProxyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyProxy()
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // TAB 4: BLUETOOTH
        // ═════════════════════════════════════════════════════════════
        Column {
            visible: root.currentTab === 4
            width: parent.width
            spacing: 12

            Text {
                text: "BLUETOOTH"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2
                color: Theme.textDim
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: 8
                color: Theme.glass

                KitToggle {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.btOn
                    onToggled: c => {
                        root.win.run("bluetoothctl power " + (c ? "on" : "off"))
                        delay.interval = 1200
                        delay.restart()
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 70
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.btOn ? (root.scanning ? I18n.t("searching_devices") : root.btDevices.filter(d => d.connected).length + " " + I18n.t("connected_count")) : I18n.t("bt_off")
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: root.btOn ? Theme.text : Theme.textDim
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96
                    height: 32
                    radius: 6
                    color: scanMa.containsMouse ? Theme.glassHover : Qt.rgba(1, 1, 1, 0.08)
                    scale: scanMa.pressed ? 0.94 : (scanMa.containsMouse ? 1.03 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "\uf002"
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                            color: Theme.text
                            scale: root.scanning ? 1.2 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        }
                        Text { text: root.scanning ? I18n.t("scanning") : I18n.t("scan"); font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.text }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startScan()
                    }
                }
            }

            Repeater {
                model: root.btOn ? root.btDevices : []

                Rectangle {
                    id: btRow
                    required property var modelData
                    width: parent.width
                    height: 48
                    radius: 8
                    color: btMa.containsMouse ? Theme.glassHover : Theme.glass
                    border.width: 1
                    border.color: btRow.modelData.connected ? Theme.alpha(Theme.accent, 0.5) : (btMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Theme.stroke)
                    scale: btMa.pressed ? 0.98 : (btMa.containsMouse ? 1.008 : 1.0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    MouseArea { id: btMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: btRow.modelData.connected ? Theme.accent : (btRow.modelData.paired ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.08))
                        scale: btRow.modelData.connected ? 1.3 : 1.0

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: btRow.modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: btRow.modelData.connected ? Font.DemiBold : Font.Normal
                            color: btRow.modelData.connected ? Theme.text : Theme.textDim
                        }
                        Text {
                            text: btRow.modelData.mac
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: bTxt.width + 18
                            height: 28
                            radius: 6
                            color: btOpMa.containsMouse ? Theme.alpha(Theme.accent, 0.6) : Qt.rgba(1, 1, 1, 0.08)
                            scale: btOpMa.pressed ? 0.92 : (btOpMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Text {
                                id: bTxt
                                anchors.centerIn: parent
                                text: btRow.modelData.connected ? I18n.t("disconnect") : (btRow.modelData.paired ? I18n.t("connect") : I18n.t("pair"))
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            MouseArea {
                                id: btOpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = btRow.modelData
                                    if (d.connected) {
                                        root.win.run("bluetoothctl disconnect " + d.mac)
                                    } else if (d.paired) {
                                        root.win.run("bluetoothctl connect " + d.mac)
                                    } else {
                                        root.win.run("bluetoothctl pair " + d.mac + " && bluetoothctl trust " + d.mac + " && bluetoothctl connect " + d.mac)
                                    }
                                    delay.interval = 2000
                                    delay.restart()
                                }
                            }
                        }

                        // Remove / Unpair button
                        Rectangle {
                            visible: btRow.modelData.paired
                            width: 28
                            height: 28
                            radius: 6
                            color: unpairMa.containsMouse ? Theme.alpha(Theme.red, 0.6) : Qt.rgba(1, 1, 1, 0.06)
                            scale: unpairMa.pressed ? 0.92 : (unpairMa.containsMouse ? 1.08 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: unpairMa.containsMouse ? "#fff" : Theme.textDim
                            }

                            MouseArea {
                                id: unpairMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.win.run("bluetoothctl remove " + btRow.modelData.mac)
                                    delay.interval = 1200
                                    delay.restart()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

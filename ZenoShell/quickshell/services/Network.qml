pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool wifiOn: false
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property string activeSecurity: ""

    property var networks: []     // all of them, the active one first
    property var others: []       // all except the active one
    property var known: []        // saved profiles
    property string wifiDevice: ""

    property bool scanning: false
    property string connecting: ""
    property string connectError: ""
    property bool usedPassword: false
    property string lastTried: ""

    readonly property int level: !connected ? 0 : levelFor(strength)

    function levelFor(sig) { return sig > 66 ? 3 : sig > 33 ? 2 : 1 }

    // Splits an nmcli -t line, honoring escaped colons
    function splitTerse(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++ }
            else if (ch === ":") { out.push(cur); cur = "" }
            else cur += ch
        }
        out.push(cur)
        return out
    }

    function refresh() { proc.running = true }

    function scan() {
        scanning = true
        scanProc.running = true
        scanTimer.restart()
    }

    function setWifi(on) {
        wifiOn = on
        setProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        setProc.running = true
    }

    function connectTo(name, password) {
        connectError = ""
        connecting = name
        lastTried = name
        usedPassword = password !== ""
        if (password !== "")
            connectProc.command = ["nmcli", "device", "wifi", "connect", name, "password", password]
        else if (known.indexOf(name) >= 0)
            connectProc.command = ["nmcli", "connection", "up", "id", name]
        else
            connectProc.command = ["nmcli", "device", "wifi", "connect", name]
        connectProc.running = true
    }

    function disconnectActive() {
        if (wifiDevice === "") return
        discProc.command = ["nmcli", "device", "disconnect", wifiDevice]
        discProc.running = true
    }

    function handleError(msg) {
        const m = msg.trim()
        if (m === "") return
        connectError = /secrets|password/i.test(m) ? "Wrong password"
                       : (m.split("\n")[0].replace(/^Error: /, "") || "Connection failed")
        // the failed attempt leaves a useless profile: delete it
        if (usedPassword) {
            delProc.command = ["nmcli", "connection", "delete", "id", lastTried]
            delProc.running = true
        }
    }

    Process {
        id: proc
        command: ["sh", "-c",
            "nmcli radio wifi; nmcli -t -f IN-USE,SIGNAL,SSID,SECURITY device wifi list --rescan no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                root.wifiOn = lines[0].trim() === "enabled"

                const nets = {}
                for (let i = 1; i < lines.length; i++) {
                    if (lines[i] === "") continue
                    const f = root.splitTerse(lines[i])
                    if (f.length < 4 || f[2] === "") continue

                    const inUse = f[0] === "*"
                    const sig = parseInt(f[1]) || 0
                    const sec = f[3] === "--" ? "" : f[3]
                    const prev = nets[f[2]]

                    if (!prev) {
                        nets[f[2]] = { ssid: f[2], signal: sig, security: sec, inUse: inUse }
                    } else {
                        if (inUse) prev.inUse = true
                        if (sig > prev.signal) { prev.signal = sig; prev.security = sec }
                    }
                }

                const all = []
                for (const k in nets) all.push(nets[k])
                all.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))

                root.networks = all
                root.others = all.filter(n => !n.inUse)

                const act = (all.length > 0 && all[0].inUse) ? all[0] : null
                root.connected = act !== null
                root.ssid = act ? act.ssid : ""
                root.strength = act ? act.signal : 0
                root.activeSecurity = act ? act.security : ""
            }
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i] === "") continue
                    const f = root.splitTerse(lines[i])
                    if (f.length >= 2 && (f[1] === "wifi" || f[1].indexOf("wireless") >= 0))
                        list.push(f[0])
                }
                root.known = list
            }
        }
    }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const f = root.splitTerse(lines[i])
                    if (f.length >= 2 && f[1] === "wifi") { root.wifiDevice = f[0]; return }
                }
            }
        }
    }

    Process { id: scanProc }

    Timer {
        id: scanTimer
        interval: 3500
        onTriggered: {
            root.scanning = false
            root.refresh()
        }
    }

    Process {
        id: setProc
        onExited: root.refresh()
    }

    Process {
        id: connectProc
        stderr: StdioCollector {
            onStreamFinished: root.handleError(text)
        }
        onExited: {
            root.connecting = ""
            root.refresh()
            knownProc.running = true
        }
    }

    Process {
        id: discProc
        onExited: root.refresh()
    }

    Process {
        id: delProc
        onExited: knownProc.running = true
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        knownProc.running = true
        devProc.running = true
    }
}

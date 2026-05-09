import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Keyed by SSID: { ssid, signal, security, connected, saved }
    property var networks: ({})
    property string connectedSsid: ""
    property bool wifiEnabled: true
    property bool busy: false
    property string lastError: ""

    property var _savedNames: ({})

    signal scanFinished()
    signal connectResult(string ssid, bool ok, string error)

    readonly property int connectedSignal: {
        const n = networks[connectedSsid]
        return n ? n.signal : 0
    }

    function _isSecured(sec) {
        return sec && sec !== "--" && sec !== ""
    }

    // nmcli 0..100 → 0..3 icon level (none/weak/medium/full).
    function signalLevel(s) {
        return s >= 70 ? 3 : s >= 40 ? 2 : s > 0 ? 1 : 0
    }

    function scan() {
        if (!scanProc.running) scanProc.running = true
    }

    function connect(ssid, password) {
        if (busy) return
        busy = true
        lastError = ""
        connectProc.targetSsid = ssid
        if (password && password.length > 0) {
            connectProc.command = ["nmcli", "-t", "device", "wifi", "connect", ssid, "password", password]
        } else {
            connectProc.command = ["nmcli", "-t", "device", "wifi", "connect", ssid]
        }
        connectProc.running = true
    }

    function disconnect(ssid) {
        if (busy || !ssid) return
        busy = true
        lastError = ""
        disconnectProc.command = ["nmcli", "-t", "connection", "down", "id", ssid]
        disconnectProc.running = true
    }

    function setWifiEnabled(enabled) {
        radioProc.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
        radioProc.running = true
        wifiEnabled = enabled
    }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        running: false
        property string _stderr: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {}
                const lines = text.split('\n')
                for (const line of lines) {
                    const trimmed = line.trim()
                    if (trimmed) names[trimmed] = true
                }
                root._savedNames = names
            }
        }
        stderr: StdioCollector { onStreamFinished: savedProc._stderr = text }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[NetworkService] saved-connections query failed (exit",
                    code + "):", savedProc._stderr.trim() || "(no stderr)")
            }
        }
    }

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", "auto"]
        running: false
        property string _stderr: ""
        stderr: StdioCollector { onStreamFinished: scanProc._stderr = text }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[NetworkService] scan failed (exit",
                    code + "):", scanProc._stderr.trim() || "(no stderr)")
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                function parseFields(line) {
                    const out = []
                    let cur = ""
                    for (let i = 0; i < line.length; i++) {
                        const c = line[i]
                        if (c === '\\' && i + 1 < line.length && line[i + 1] === ':') {
                            cur += ':'
                            i++
                        } else if (c === ':') {
                            out.push(cur)
                            cur = ""
                        } else {
                            cur += c
                        }
                    }
                    out.push(cur)
                    return out
                }

                const result = {}
                let connected = ""
                const lines = text.split('\n')
                for (const line of lines) {
                    if (!line) continue
                    const parts = parseFields(line)
                    if (parts.length < 4) continue
                    const inUse  = parts[0]
                    const ssid   = parts[1]
                    const sec    = parts[2]
                    const signal = parseInt(parts[3], 10) || 0
                    if (!ssid) continue
                    const prev = result[ssid]
                    if (!prev || signal > prev.signal) {
                        result[ssid] = {
                            ssid: ssid,
                            signal: signal,
                            security: sec,
                            secured: root._isSecured(sec),
                            connected: inUse === "*",
                            saved: ssid in root._savedNames
                        }
                    }
                    if (inUse === "*") connected = ssid
                }
                root.networks = result
                root.connectedSsid = connected
                root.scanFinished()
            }
        }
    }

    Process {
        id: connectProc
        running: false
        property string targetSsid: ""
        property string _stderr: ""
        property bool _timedOut: false
        stderr: StdioCollector { onStreamFinished: connectProc._stderr = text }
        onStarted: {
            connectProc._timedOut = false
            // Reset so a second connect whose nmcli writes no stderr doesn't
            // surface the prior run's error message via lastError.
            connectProc._stderr = ""
            connectTimeout.restart()
        }
        onExited: (code, status) => {
            connectTimeout.stop()
            if (connectProc._timedOut) return
            root.busy = false
            const stderr = connectProc._stderr.trim()
            const ok = code === 0
            let msg = ""
            if (!ok) {
                if (stderr === "" && code === 127) msg = "nmcli not installed"
                else if (stderr.indexOf("Secrets were required") >= 0) msg = "Incorrect password"
                else if (stderr.indexOf("No network with SSID") >= 0) msg = "Network not found"
                else if (stderr.indexOf("not authorized") >= 0) msg = "Permission denied"
                else msg = stderr || ("Connect failed (exit " + code + ")")
                console.warn("[NetworkService] connect failed (exit",
                    code + "):", stderr || "(no stderr)")
            }
            root.lastError = msg
            root.connectResult(connectProc.targetSsid, ok, msg)
            savedProc.running = true
            root.scan()
        }
    }

    // Guards against a hung `nmcli connect` (portal, slow DHCP) — without this,
    // `busy` would stay true forever and every subsequent connect attempt is
    // silently dropped by the `if (busy) return` guard in connect().
    Timer {
        id: connectTimeout
        interval: 30000
        repeat: false
        onTriggered: {
            // Process already exited on its own — onExited has/will fire the
            // real connectResult; don't emit a stale timeout signal over it.
            if (!connectProc.running) return
            console.warn("[NetworkService] connect timed out after 30s, killing")
            connectProc._timedOut = true
            connectProc.running = false
            root.busy = false
            root.lastError = "Connect timed out"
            // Refresh saved-names + network list, mirroring onExited so
            // UI state isn't stale for up to 15s (next periodic scan).
            savedProc.running = true
            root.scan()
            root.connectResult(connectProc.targetSsid, false, root.lastError)
        }
    }

    Process {
        id: disconnectProc
        running: false
        property string _stderr: ""
        stderr: StdioCollector { onStreamFinished: disconnectProc._stderr = text }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[NetworkService] disconnect failed (exit",
                    code + "):", disconnectProc._stderr.trim() || "(no stderr)")
            }
            root.busy = false
            savedProc.running = true
            root.scan()
        }
    }

    Process {
        id: radioProc
        running: false
        property string _stderr: ""
        stderr: StdioCollector { onStreamFinished: radioProc._stderr = text }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[NetworkService] radio toggle failed (exit",
                    code + "):", radioProc._stderr.trim() || "(no stderr)")
            }
            root.scan()
        }
    }

    Component.onCompleted: { savedProc.running = true; scan() }
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.scan()
    }
}

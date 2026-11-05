pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property var outputs: []        // [{name, width, height, hz, scale, x, y, modes}]
    property string focused: ""
    property bool hasMirror: false       // wl-mirror installato
    property string mirrorFrom: ""
    property string mirrorTo: ""
    property bool identifying: false
    property bool dirty: false           // there is a change to save for niri

    readonly property string niriOutputsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri/quickshell-outputs.kdl"

    // Hyprland: same idea, a Lua module that hyprland.lua loads (~/.config/hypr/quickshell-outputs.lua)
    readonly property string hyprOutputsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/quickshell-outputs.lua"

    function isInternal(n) {
        return n.indexOf("eDP") === 0 || n.indexOf("LVDS") === 0 || n.indexOf("DSI") === 0
    }

    function onList() {
        const out = []
        for (let i = 0; i < outputs.length; i++) if (outputs[i].on) out.push(outputs[i])
        return out
    }

    // Logical size of a monitor (even when off: from the preferred mode)
    function lsize(o) {
        if (o.lw > 0 && o.lh > 0) return { w: o.lw, h: o.lh }
        const m = /^(\d+)x(\d+)/.exec(o.pref || "")
        return m ? { w: parseInt(m[1]), h: parseInt(m[2]) } : { w: 1920, h: 1080 }
    }

    // Reference monitor for positioning "name": the built-in screen first, then the other active ones
    function refFor(name) {
        const l = onList().filter(o => o.name !== name)
        for (let i = 0; i < l.length; i++) if (isInternal(l[i].name)) return l[i]
        return l.length > 0 ? l[0] : null
    }

    // Where "name" is relative to the reference: left | right | above | below | ""
    function sideOf(name) {
        const o = find(name)
        const r = refFor(name)
        if (!o || !r || !o.on) return ""
        const a = lsize(o), b = lsize(r)
        if (o.x >= r.x + b.w) return "right"
        if (o.x + a.w <= r.x) return "left"
        if (o.y >= r.y + b.h) return "below"
        if (o.y + a.h <= r.y) return "above"
        return ""
    }

    function toast(summary, body) {
        Toast.push({ kind: "notification", app: "Displays", summary: summary, body: body || "",
                     tone: "accent", duration: 4000 })
    }

    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // ---- Per-compositor commands ----
    function hyprMon(o, ov) {
        ov = ov || {}
        let l = "hl.monitor({ output = \"" + o.name + "\""
        if (ov.disabled) {
            l += ", disabled = true"
        } else {
            const mode = ov.mode || (o.width + "x" + o.height + "@" + o.hz.toFixed(2))
            const x = ov.x !== undefined ? ov.x : o.x
            const y = ov.y !== undefined ? ov.y : o.y
            l += ", mode = \"" + mode + "\", position = \"" + (ov.auto ? "auto" : x + "x" + y)
                 + "\", scale = " + (ov.scale || o.scale || 1)
            if (ov.transform !== undefined) l += ", transform = " + ov.transform
            if (ov.mirror) l += ", mirror = \"" + ov.mirror + "\""
        }
        return "hyprctl eval " + q(l + " })")
    }

    function cmdOn(o) {
        if (Compositor.isNiri) return "niri msg output " + q(o.name) + " on"
        return hyprMon(o, { mode: "preferred", auto: true, scale: 1 })
    }
    function cmdOff(o) {
        if (Compositor.isNiri) return "niri msg output " + q(o.name) + " off"
        return hyprMon(o, { disabled: true })
    }
    function cmdPos(o, x, y) {
        if (Compositor.isNiri) return "niri msg output " + q(o.name) + " position set " + x + " " + y
        return hyprMon(o, { x: x, y: y })
    }
    function cmdTransform(o, deg) {
        if (Compositor.isNiri) return "niri msg output " + q(o.name) + " transform " + (deg === 0 ? "normal" : deg)
        return hyprMon(o, { transform: deg / 90 })
    }

    // Runs the commands in sequence and refreshes the list; on niri then saves the file
    function exec(cmds, delay) {
        if (cmds.length === 0) return
        dirty = true
        refreshTimer.interval = delay || 600
        Quickshell.execDetached(["sh", "-c", cmds.join(" ; ")])
        refreshTimer.restart()
    }

    // ---- Monitor actions ----
    function setEnabled(name, on) {
        const o = find(name)
        if (!o) return
        if (!on && onList().length <= 1) {
            toast("Can't turn off the last screen", "Turn another one on first")
            return
        }
        exec([on ? cmdOn(o) : cmdOff(o)], on ? 1200 : 600)
    }

    function setTransform(name, deg) {
        const o = find(name)
        if (o) exec([cmdTransform(o, deg)])
    }

    // Puts "name" to the left/right/above/below the reference monitor
    function place(name, side) {
        const o = find(name)
        const r = refFor(name)
        if (!o || !r) return
        const a = lsize(o), b = lsize(r)
        const pos = {}
        const on = onList()
        for (let i = 0; i < on.length; i++) pos[on[i].name] = { x: on[i].x, y: on[i].y }
        if (side === "right") pos[name] = { x: r.x + b.w, y: r.y }
        else if (side === "left") pos[name] = { x: r.x - a.w, y: r.y }
        else if (side === "above") pos[name] = { x: r.x, y: r.y - a.h }
        else pos[name] = { x: r.x, y: r.y + b.h }

        let minX = 1e9, minY = 1e9
        for (const k in pos) { minX = Math.min(minX, pos[k].x); minY = Math.min(minY, pos[k].y) }
        const cmds = []
        for (let i = 0; i < on.length; i++) {
            const n = on[i].name
            const x = pos[n].x - minX, y = pos[n].y - minY
            if (x !== on[i].x || y !== on[i].y) cmds.push(cmdPos(on[i], x, y))
        }
        exec(cmds)
    }

    // All on, in a row from the left: built-in screen first
    function extend() {
        const list = outputs.slice()
        list.sort((a, b) => (isInternal(b.name) ? 1 : 0) - (isInternal(a.name) ? 1 : 0))
        const cmds = []
        for (let i = 0; i < list.length; i++) if (!list[i].on) cmds.push(cmdOn(list[i]))
        if (cmds.length > 0) cmds.push("sleep 1")
        let x = 0
        for (let i = 0; i < list.length; i++) {
            cmds.push(cmdPos(list[i], x, 0))
            x += lsize(list[i]).w
        }
        exec(cmds, cmds.length > list.length ? 1800 : 700)
    }

    function onlyInternal() {
        let inner = null
        for (let i = 0; i < outputs.length; i++) if (isInternal(outputs[i].name)) { inner = outputs[i]; break }
        if (!inner) { toast("No built-in screen found"); return }
        const cmds = []
        if (!inner.on) cmds.push(cmdOn(inner), "sleep 1")
        for (let i = 0; i < outputs.length; i++)
            if (outputs[i].name !== inner.name && outputs[i].on) cmds.push(cmdOff(outputs[i]))
        exec(cmds, 1500)
    }

    function onlyExternal() {
        const ext = outputs.filter(o => !isInternal(o.name))
        if (ext.length === 0) { toast("No external screen connected"); return }
        const cmds = []
        let x = 0
        for (let i = 0; i < ext.length; i++) if (!ext[i].on) cmds.push(cmdOn(ext[i]))
        if (cmds.length > 0) cmds.push("sleep 1")
        for (let i = 0; i < ext.length; i++) { cmds.push(cmdPos(ext[i], x, 0)); x += lsize(ext[i]).w }
        for (let i = 0; i < outputs.length; i++)
            if (isInternal(outputs[i].name) && outputs[i].on) cmds.push(cmdOff(outputs[i]))
        exec(cmds, 1800)
    }

    // Mirror: native on Hyprland, on niri wl-mirror is used fullscreen on the other monitor
    function mirror(src, dst) {
        if (Compositor.isHyprland) {
            const d = find(dst)
            if (d) exec([hyprMon(d, { mode: "preferred", auto: true, scale: 1, mirror: src })])
            root.mirrorFrom = src
            root.mirrorTo = dst
            return
        }
        if (!hasMirror) {
            toast("wl-mirror is missing", "sudo pacman -S wl-mirror")
            return
        }
        mirrorProc.running = false
        pendingMirror = { src: src, dst: dst }
        mirrorStart.restart()
    }

    property var pendingMirror: null

    function stopMirror() {
        if (Compositor.isHyprland) {
            const d = find(mirrorTo)
            if (d) exec([hyprMon(d, { mode: "preferred", auto: true, scale: 1, mirror: "none" })])
            mirrorFrom = ""
            mirrorTo = ""
            return
        }
        mirrorProc.running = false
        mirrorFrom = ""
        mirrorTo = ""
    }

    function identify() {
        identifying = true
        identTimer.restart()
    }

    // On niri runtime changes are lost on every config reload:
    // I write them to the file included by config.kdl (~/.config/niri/quickshell-outputs.kdl)
    function writeKdl() {
        if (!Compositor.isNiri || outputs.length === 0) return
        const t = { "Normal": "normal", "90": "90", "180": "180", "270": "270" }
        let s = "// managed by Quickshell (Monitors page)"
        for (let i = 0; i < outputs.length; i++) {
            const o = outputs[i]
            s += "\noutput \"" + o.name + "\" {"
            if (!o.on) {
                s += "\n    off\n}"
                continue
            }
            if (o.width > 0) s += "\n    mode \"" + o.width + "x" + o.height + "@" + o.hz.toFixed(3) + "\""
            s += "\n    scale " + o.scale
            const tr = (o.transform || "Normal").replace(/^Flipped(\d+)$/, "flipped-$1").replace(/^Flipped$/, "flipped")
            const tv = t[o.transform] || (/^flipped/.test(tr) ? tr : "normal")
            s += "\n    transform \"" + tv + "\""
            s += "\n    position x=" + o.x + " y=" + o.y + "\n}"
        }
        Quickshell.execDetached(["sh", "-c", "[ -e \"$2\" ] && printf '%s\\n' \"$1\" > \"$2\"", "sh", s, niriOutputsPath])
    }

    // Hyprland: changes made at runtime are lost on logout; the file below is loaded by hyprland.lua
    function writeLua() {
        if (!Compositor.isHyprland || outputs.length === 0) return
        let s = "-- managed by Quickshell (Monitors page): position, scale and rotation of the monitors\n"
        s += "local M = {}\n\nfunction M.apply()"
        for (let i = 0; i < outputs.length; i++) {
            const o = outputs[i]
            if (!o.on) {
                s += "\n    hl.monitor({ output = \"" + o.name + "\", disabled = true })"
                continue
            }
            const t = parseInt(o.transform) || 0
            s += "\n    hl.monitor({ output = \"" + o.name + "\", mode = \"" + o.width + "x" + o.height + "@" + o.hz.toFixed(2)
                 + "\", position = \"" + o.x + "x" + o.y + "\", scale = " + o.scale + ", transform = " + t + " })"
        }
        s += "\nend\n\nreturn M"
        Quickshell.execDetached(["sh", "-c", "[ -e \"$2\" ] && printf '%s\\n' \"$1\" > \"$2\"", "sh", s, hyprOutputsPath])
    }

    function refresh() {
        if (!mirrorCheck.running) mirrorCheck.running = true
        if (Compositor.isNiri) monProc.command = ["niri", "msg", "--json", "outputs"]
        else monProc.command = ["hyprctl", "monitors", "all", "-j"]
        monProc.running = true
    }

    function find(name) {
        for (let i = 0; i < outputs.length; i++) if (outputs[i].name === name) return outputs[i]
        return null
    }

    // "1920x1200@144.00Hz" -> "1920x1200@144"
    function normMode(s) {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(s)
        return m ? m[1] + "x" + m[2] + "@" + Math.round(parseFloat(m[3])) : s
    }

    // "1920x1200@144.00Hz" -> "1920×1200 @ 144 Hz"
    function prettyMode(s) {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(s)
        return m ? m[1] + "×" + m[2] + " @ " + Math.round(parseFloat(m[3])) + " Hz" : s
    }

    // Modes without duplicates, from largest to smallest
    function uniqueModes(modes) {
        const seen = {}
        const out = []
        for (let i = 0; i < modes.length; i++) {
            const k = normMode(modes[i])
            if (seen[k]) continue
            seen[k] = true
            out.push(modes[i])
        }
        out.sort((a, b) => {
            const ma = /^(\d+)x(\d+)@([\d.]+)/.exec(a)
            const mb = /^(\d+)x(\d+)@([\d.]+)/.exec(b)
            if (!ma || !mb) return 0
            return (mb[1] * mb[2] - ma[1] * ma[2]) || (parseFloat(mb[3]) - parseFloat(ma[3]))
        })
        return out
    }

    // In Lua configs "hyprctl keyword" does not exist: "hyprctl eval" is used (session only)
    function applyMonitor(o, mode, scale) {
        const lua = "hl.monitor({ output = \"" + o.name + "\", mode = \"" + mode
                    + "\", position = \"" + o.x + "x" + o.y + "\", scale = " + scale + " })"
        applyProc.command = ["hyprctl", "eval", lua]
        applyProc.running = true
    }

    function setScale(name, s) {
        const o = find(name)
        if (!o) return
        if (Compositor.isNiri) {
            applyProc.command = ["niri", "msg", "output", name, "scale", String(s)]
            applyProc.running = true
            dirty = true
            return
        }
        applyMonitor(o, o.width + "x" + o.height + "@" + o.hz.toFixed(2), s)
    }

    function setMode(name, modeStr) {
        const o = find(name)
        if (!o) return
        if (Compositor.isNiri) {
            applyProc.command = ["niri", "msg", "output", name, "mode", modeStr.replace(/Hz$/, "")]
            applyProc.running = true
            dirty = true
            return
        }
        applyMonitor(o, modeStr.replace(/Hz$/, ""), o.scale)
    }

    // niri: {"eDP-1": {modes: [{width, height, refresh_rate (mHz), is_preferred}], current_mode,
    //                 logical: {x, y, width, height, scale, transform} | null (off)}}
    function parseNiri(data) {
        const list = []
        const names = Object.keys(data)
        for (let i = 0; i < names.length; i++) {
            const o = data[names[i]]
            const ms = o.modes || []
            const modes = ms.map(m => m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3) + "Hz")
            const cur = (ms.length > 0 && o.current_mode !== null && o.current_mode !== undefined)
                        ? ms[o.current_mode] : null
            let pref = ""
            for (let k = 0; k < ms.length; k++)
                if (ms[k].is_preferred) { pref = ms[k].width + "x" + ms[k].height + "@" + (ms[k].refresh_rate / 1000).toFixed(3); break }
            const lg = o.logical
            list.push({
                name: names[i],
                label: ((o.make || "") + " " + (o.model || "")).trim(),
                on: !!lg,
                width: cur ? cur.width : 0,
                height: cur ? cur.height : 0,
                hz: cur ? cur.refresh_rate / 1000 : 0,
                scale: lg ? lg.scale : 1,
                x: lg ? lg.x : 0,
                y: lg ? lg.y : 0,
                lw: lg ? lg.width : 0,
                lh: lg ? lg.height : 0,
                transform: lg ? String(lg.transform) : "Normal",
                pref: pref,
                modes: modes
            })
        }
        root.outputs = list
        root.focused = Compositor.focusedMonitor
    }

    Process {
        id: monProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (Compositor.isNiri) {
                        root.parseNiri(data)
                        root.afterRefresh()
                        return
                    }
                    const list = []
                    let foc = ""
                    for (let i = 0; i < data.length; i++) {
                        const m = data[i]
                        const rot = (m.transform || 0) % 2 === 1
                        const lw = Math.round((rot ? m.height : m.width) / (m.scale || 1))
                        const lh = Math.round((rot ? m.width : m.height) / (m.scale || 1))
                        list.push({
                            name: m.name,
                            label: ((m.make || "") + " " + (m.model || "")).trim(),
                            on: !m.disabled,
                            width: m.width,
                            height: m.height,
                            hz: m.refreshRate,
                            scale: m.scale,
                            x: m.x,
                            y: m.y,
                            lw: m.disabled ? 0 : lw,
                            lh: m.disabled ? 0 : lh,
                            transform: String(m.transform || 0),
                            pref: m.width + "x" + m.height + "@" + (m.refreshRate || 60).toFixed(2),
                            modes: m.availableModes || []
                        })
                        if (m.focused) foc = m.name
                    }
                    root.outputs = list
                    root.focused = foc
                    root.afterRefresh()
                } catch (e) {
                    console.log("hyprctl monitors:", e)
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: refreshTimer.restart()
    }

    // The compositor takes a moment to apply the change
    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refresh()
    }

    // After each read: if there was a change, save it
    function afterRefresh() {
        if (!dirty) return
        dirty = false
        writeKdl()
        writeLua()
    }

    Process {
        id: mirrorCheck
        command: ["sh", "-c", "command -v wl-mirror >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root.hasMirror = text.trim() === "yes"
        }
    }

    Process {
        id: mirrorProc
        onRunningChanged: if (!running && !mirrorStart.running) { root.mirrorFrom = ""; root.mirrorTo = "" }
    }

    Timer {
        id: mirrorStart
        interval: 350
        onTriggered: {
            const m = root.pendingMirror
            if (!m) return
            root.mirrorFrom = m.src
            root.mirrorTo = m.dst
            mirrorProc.command = ["wl-mirror", "--fullscreen", "--fullscreen-output", m.dst, m.src]
            mirrorProc.running = true
        }
    }

    Timer {
        id: identTimer
        interval: 2600
        onTriggered: root.identifying = false
    }
}

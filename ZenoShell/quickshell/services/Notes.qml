pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Calendar notes, with reminders:
//  - the evening before (at dayBeforeHour)
//  - at the note's time (if it has no time: at allDayHour on the same day)
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/share/quickshell-calendar.json"

    // ---- Reminder times (edit them here) ----
    readonly property int dayBeforeHour: 18
    readonly property int allDayHour: 9

    property var events: []             // [{id, date, time, title, desc, firedPrev, firedAt}]
    property bool canSave: true         // false if the file exists but can't be read: don't overwrite it
    property bool loaded: false
    property bool hasNotifySend: false

    // ---------- Utilities ----------
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function keyOf(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function keyOfYMD(y, m, d) { return y + "-" + pad(m + 1) + "-" + pad(d) }

    function whenOf(e) {
        const p = e.date.split("-")
        let h = allDayHour
        let mi = 0
        if (e.time) {
            const t = e.time.split(":")
            h = parseInt(t[0])
            mi = parseInt(t[1])
        }
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]), h, mi)
    }

    function prevDueOf(e) {
        const p = e.date.split("-")
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]) - 1, dayBeforeHour, 0)
    }

    // A new (or edited) note must not trigger already "expired" alerts
    function arm(e) {
        const now = new Date()
        e.firedPrev = prevDueOf(e) <= now
        e.firedAt = whenOf(e) <= now
        return e
    }

    // ---------- Data access ----------
    readonly property var byDate: {
        const m = {}
        for (let i = 0; i < events.length; i++) {
            const e = events[i]
            if (!m[e.date]) m[e.date] = []
            m[e.date].push(e)
        }
        for (const k in m)
            m[k].sort((a, b) => (a.time || "99:99").localeCompare(b.time || "99:99"))
        return m
    }

    function forDate(key) { return byDate[key] || [] }
    function count(key) { return forDate(key).length }

    // ---------- Changes ----------
    function add(dateKey, time, title, desc) {
        const ev = arm({
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            date: dateKey,
            time: time || "",
            title: title,
            desc: desc || ""
        })
        events = events.concat([ev])
        save()
        check()
    }

    function update(id, fields) {
        events = events.map(e => e.id === id ? arm(Object.assign({}, e, fields)) : e)
        save()
    }

    function remove(id) {
        events = events.filter(e => e.id !== id)
        save()
    }

    // ---------- File ----------
    FileView {
        id: store
        path: root.path
        blockLoading: true
    }

    function load() {
        let raw = ""
        try { raw = store.text() } catch (e) {}
        if (raw && raw.trim() !== "") {
            try {
                const d = JSON.parse(raw)
                events = d.events || []
            } catch (e) {
                canSave = false
                console.log("calendar: unreadable file, NOT overwriting it:", e)
            }
        }
    }

    function save() {
        if (!canSave) return
        const json = JSON.stringify({ version: 1, events: events }, null, 1)
        // backup copy + atomic write
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" && { [ -f \"$2\" ] && cp \"$2\" \"$2.bak\"; "
            + "printf '%s' \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"; }",
            "sh", json, path])
    }

    // ---------- Reminders ----------
    function send(summary, body, urgency) {
        if (hasNotifySend) {
            Quickshell.execDetached(["notify-send", "-a", "Calendar", "-u", urgency,
                                     "-t", "15000", summary, body])
        } else {
            // without libnotify: toast only
            Toast.push({
                kind: "notification",
                app: "Calendar",
                summary: summary,
                body: body,
                tone: urgency === "critical" ? "danger" : "accent",
                duration: 12000
            })
        }
    }

    function test() {
        send("Tomorrow · Test", "At 18:00\nThis is a test reminder", "normal")
    }

    function check() {
        if (!loaded) return
        const now = new Date()
        let changed = false

        for (let i = 0; i < events.length; i++) {
            const e = events[i]
            const p = e.date.split("-")
            const endOfDay = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]) + 1, 0, 0)
            if (now >= endOfDay) continue               // day already past

            const at = whenOf(e)

            if (!e.firedAt && now >= at) {
                e.firedAt = true
                e.firedPrev = true
                send("Now · " + e.title,
                     (e.time ? "At " + e.time : "Today") + (e.desc ? "\n" + e.desc : ""),
                     "critical")
                changed = true
            } else if (!e.firedPrev && now >= prevDueOf(e) && now < at) {
                e.firedPrev = true
                send("Tomorrow · " + e.title,
                     (e.time ? "At " + e.time : "All day") + (e.desc ? "\n" + e.desc : ""),
                     "normal")
                changed = true
            }
        }

        if (changed) save()
    }

    // is notify-send available? (otherwise use the toast)
    Process {
        command: ["sh", "-c", "command -v notify-send"]
        running: true
        onExited: exitCode => root.hasNotifySend = (exitCode === 0)
    }

    Timer {
        id: tick
        interval: 30000
        repeat: true
        onTriggered: root.check()
    }

    // Starts after a few seconds: time to find out whether notify-send exists
    Timer {
        interval: 3000
        running: true
        onTriggered: {
            root.loaded = true
            root.check()
            tick.start()
        }
    }

    Component.onCompleted: load()
}

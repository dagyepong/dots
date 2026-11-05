pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    // ---------- Timer (countdown) ----------
    property int timerTotal: 300              // configured duration (seconds)
    property real timerEnd: 0                 // end instant (ms) while running
    property real timerLeftMs: 300000         // ms left when stopped or paused
    property bool timerRunning: false
    property bool timerDone: false

    // ---------- Cronometro ----------
    property real swStart: 0
    property real swElapsedMs: 0
    property bool swRunning: false
    property var laps: []                     // total times at each lap (ms)

    property real now: Date.now()

    readonly property real timerRemainingMs: timerRunning ? Math.max(0, timerEnd - now) : timerLeftMs
    readonly property real swMs: swRunning ? swElapsedMs + (now - swStart) : swElapsedMs

    function pad(n) { return (n < 10 ? "0" : "") + n }

    function fmtTimer(ms) {
        const s = Math.ceil(ms / 1000)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const ss = s % 60
        return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(ss)
    }

    function fmtSw(ms) {
        const t = Math.floor(ms / 100)
        return pad(Math.floor(t / 600)) + ":" + pad(Math.floor(t / 10) % 60) + "." + (t % 10)
    }

    readonly property string timerText: fmtTimer(timerRemainingMs)
    readonly property string swText: fmtSw(swMs)

    readonly property string lapsText: {
        if (laps.length === 0) return "No laps"
        let s = ""
        const n = Math.min(2, laps.length)
        for (let i = 0; i < n; i++) {
            const idx = laps.length - 1 - i
            const lapMs = laps[idx] - (idx > 0 ? laps[idx - 1] : 0)
            s += (i > 0 ? "\n" : "") + "Lap " + (idx + 1) + " · " + fmtSw(lapMs)
                 + "   (total " + fmtSw(laps[idx]) + ")"
        }
        return s
    }

    // ---------- Timer ----------
    function quick(sec) {
        now = Date.now()
        timerTotal = sec
        timerLeftMs = sec * 1000
        timerDone = false
        timerEnd = now + timerLeftMs
        timerRunning = true
    }

    function addTime(sec) {
        now = Date.now()
        timerDone = false
        if (timerRunning) {
            timerEnd = Math.max(now, timerEnd + sec * 1000)
        } else {
            timerLeftMs = Math.max(0, timerLeftMs + sec * 1000)
            timerTotal = Math.round(timerLeftMs / 1000)
        }
    }

    function timerToggle() {
        now = Date.now()
        if (timerRunning) {
            timerLeftMs = Math.max(0, timerEnd - now)
            timerRunning = false
        } else {
            if (timerLeftMs <= 0) timerLeftMs = timerTotal * 1000
            if (timerLeftMs <= 0) return
            timerDone = false
            timerEnd = now + timerLeftMs
            timerRunning = true
        }
    }

    function timerReset() {
        timerRunning = false
        timerDone = false
        timerLeftMs = timerTotal * 1000
    }

    function finish() {
        timerRunning = false
        timerLeftMs = 0
        timerDone = true
        Notes.send("Timer finished", fmtTimer(timerTotal * 1000) + " elapsed", "critical")
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/alarm.sh")])
    }

    // ---------- Cronometro ----------
    function swToggle() {
        now = Date.now()
        if (swRunning) {
            swElapsedMs += now - swStart
            swRunning = false
        } else {
            swStart = now
            swRunning = true
        }
    }

    function swLap() {
        if (!swRunning) return
        laps = laps.concat([swMs])
    }

    function swReset() {
        swRunning = false
        swElapsedMs = 0
        laps = []
    }

    Timer {
        interval: 100
        running: root.timerRunning || root.swRunning
        repeat: true
        onTriggered: {
            root.now = Date.now()
            if (root.timerRunning && root.now >= root.timerEnd) root.finish()
        }
    }
}

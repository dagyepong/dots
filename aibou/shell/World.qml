import QtQuick

// What all characters share: the screen strip, colours, settings and the ball.
Item {
    id: w

    property real areaW: 1920
    property real areaH: 1080
    property var insets: ({ left: 0, right: 0, top: 0, bottom: 0 })
    readonly property real floorY: areaH - insets.bottom

    property color primary: "#fe640b"
    property color bubbleBg: "#221b18"
    property color bubbleText: "#ede0db"
    property color outline: "#8a7f7b"
    property bool dark: true
    property color glassTint: "#1a1412"      // the terminal background
    property real glassOpacity: 0.65         // DMS frameOpacity, which termfx follows
    property color frameColor: glassTint     // the frame as DMS draws it (frameColor), at glassOpacity
    property string wallpaper: ""            // shown in the gap under a lifted window
    property string lang: "en"           // de, ja or en (from DMS, via aiboud)
    // the text for the language: Japanese falls back to English where none is given
    function tr(de, en, ja) { return lang === "de" ? de : lang === "ja" && ja !== undefined ? ja : en }
    property bool onBattery: false

    // settings from plugin_settings.json ("aibou"), defaults here
    property var settings: ({})
    function opt(key, dflt) { return settings[key] === undefined ? dflt : settings[key] }
    readonly property string skin1: opt("skin1", "kuro")
    readonly property string skin2: opt("skin2", "none")
    readonly property string skin3: opt("skin3", "none")
    readonly property string skin4: opt("skin4", "none")
    readonly property string skin5: opt("skin5", "none")
    // a friend he called at the liveliest activity: in the first free place,
    // not saved, gone again after a while ("" = none)
    property string guest: ""
    readonly property int guestSlot: skin2 === "none" ? 1 : skin3 === "none" ? 2 : skin4 === "none" ? 3 : skin5 === "none" ? 4 : -1
    function look(i, saved) { return saved !== "none" ? saved : guest !== "" && guestSlot === i ? guest : "none" }
    readonly property bool hands: opt("hands", true)
    readonly property bool gaze: opt("gaze", true)
    // the jump rope: its two ends (x on the screen, y up from the floor) and
    // where it is in its turn (0: up over the head, pi: under the feet)
    property bool jrOn: false
    property string jrPlace: "stage"       // where they play: home (behind the windows) or stage
    property real jrAX: 0
    property real jrAY: 0
    property real jrBX: 0
    property real jrBY: 0
    property real jrPhase: 0
    property real jrTop: 90                // how high it goes over the jumper (px above the floor)
    property bool jrSlack: false           // stopped: lying on the floor
    property var pointerHolder: null       // the one hanging on the pointer
    property real commandAt: 0            // the last command from the chat or the legend
    property bool dnd: false              // DMS's do not disturb: all melt into the frame and keep still
    signal setOption(string key, string value)   // saved by aiboud into the plugin settings
    readonly property var activities: ["minimal", "calm", "normal", "lively", "max"]
    property string activityTest: ""      // for tests (aibou activity …), not saved
    readonly property string activity: activityTest !== "" ? activityTest : opt("activity", "normal")
    readonly property bool games: opt("games", true)
    readonly property real sleepAfter: opt("sleepAfter", 8)
    readonly property bool sleepAnim: opt("sleepAnim", true)
    readonly property bool notifications: opt("notifications", false)
    readonly property bool chat: opt("chat", true)
    readonly property bool batterySaver: opt("batterySaver", true)
    readonly property bool front: opt("front", false)
    // while you work, melt into the screen frame instead of roaming:
    // auto (while busy) | always (the frame is home) | off
    readonly property string dock: opt("dock", "auto")
    // where: frame (the bottom edge where he stands) | bar (the side of a bar
    // on the left or right) | both (whichever is nearer)
    readonly property string dockAt: opt("dockAt", "both")
    property string barEdge: ""          // left | right | top | bottom | "" (from DMS)
    readonly property bool barSide: barEdge === "left" || barEdge === "right"
    // in the bar: a dome bulging out of it (bump) or only the face inside it (flat)
    readonly property string barStyle: opt("barStyle", "bump")
    // where in the bar there is room for his face (screen y of its centre),
    // found by aiboud in a capture of the bar; -1: not known or no room, then
    // he bulges out after all
    property real barSpot: -1
    readonly property bool barFlat: barStyle === "flat" && barSpot > 0
    // faces in the flat bar: a place for each (screen y of the face, bottom up)
    property var barSlots: []
    property bool barHide: false           // the faces out of the bar for a moment, to measure it bare
    readonly property int barFaces: cast.filter(c => c.active && c.place === "dock" && c.dockSide === "bar").length
    signal barSpotWanted()
    onBarStyleChanged: if (barStyle === "flat") barSpotWanted()
    // in the frame he takes the frame's colour (frame) or keeps his own (own)
    readonly property string dockTint: opt("dockTint", "frame")
    // his colour: his own (own), the accent colour (accent, changes with it) or a fixed one (custom)
    readonly property string tintMode: opt("tint", "own")
    readonly property color tintColor: opt("tintColor", "#7aa2f7")
    // a thin ring around him: off, or in the accent colour
    readonly property bool ring: opt("outline", "off") === "accent"
    // sweating under load, angry about crashes
    readonly property bool moods: opt("moods", true)
    readonly property string model: opt("model", "haiku")
    readonly property bool saving: batterySaver && onBattery

    // eye colour that reads on a body of colour c
    function inkFor(c) {
        const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return l > 0.5 ? "#2b2730" : "#f4efe8"
    }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── how the machine is doing (from aiboud) ─────────────────────
    property real cpu: 0
    property real ram: 0
    property real temp: 0
    property real strain: 0            // 0 … 1: sweat
    readonly property real sweat: moods ? strain : 0
    signal trouble(string kind, string name)

    // ── music (from aiboud): he dances to the beat ─────────────────
    readonly property bool dance: opt("dance", true)
    property bool music: false
    readonly property real bornAt: Date.now()   // the scene's start: newcomers then are no news
    // the machine: recording, battery, and news from aiboud (Brain.onMachine)
    property bool recordingOn: false
    property int batteryLevel: -1
    property bool charging: false
    signal news(string kind, var data)
    // tag: who is "it", until when the game runs, until when nobody moves (after a touch)
    property var tagIt: null
    property real raceGoal: 0
    property int raceDir: 1
    property var raceWinner: null
    property real tagUntil: 0
    property real tagFreeze: 0

    // ── a banana peel: dropped from the top, it lies on the floor for a
    // minute, and whoever walks over it slips (Brain.slipOnPeel)
    property bool peelOn: false
    property bool peelDown: false
    property real peelX: 0
    property real peelY: 0
    property real peelVX: 0
    property real peelVY: 0
    property real peelRot: 0
    property var peelBy: null
    property real peelT: 0
    signal peelLanded()
    function dropPeel(x, y, by) {
        peelX = x; peelY = y; peelVX = (Math.random() - 0.5) * 60; peelVY = 0; peelRot = 0
        peelBy = by; peelDown = false; peelOn = true
        peelT = Date.now()
    }
    Timer {
        interval: 16; repeat: true
        running: world.peelOn && !world.peelDown
        onTriggered: {
            const now = Date.now(), dt = Math.min(0.04, (now - world.peelT) / 1000)
            world.peelT = now
            world.peelVY += 1400 * dt
            world.peelX += world.peelVX * dt
            world.peelY += world.peelVY * dt
            world.peelRot += 220 * dt
            if (world.peelY >= world.floorY - 3) {
                world.peelY = world.floorY - 3
                world.peelRot = 0
                world.peelDown = true
                peelGone.restart()
                world.peelLanded()
            }
        }
    }
    Timer { id: peelGone; interval: 60000; onTriggered: world.peelOn = false }
    // whoever moves over it on the floor slips, once; the peel flies off
    Timer {
        interval: 50; repeat: true
        running: world.peelOn && world.peelDown
        onTriggered: {
            for (const c of world.active) {
                if ((c.place !== "home" && c.place !== "stage") || !c.moving || c.held || c.flying || c.lift > 10) continue
                if (Math.abs(c.x0 - world.peelX) > 13) continue
                world.peelOn = false
                // Arai picks it up; everybody else slips
                if (c.brain && c.skin === "arai") c.brain.tidyPeel()
                else if (c.brain) c.brain.slipOnPeel(c.gazeX >= 0 ? 1 : -1)
                return
            }
        }
    }
    property real bpm: 0                 // tempo of the music, 0 while unknown
    signal beat(real strength)

    // a popout folded out of a bar (from DMS), {side, x, y, w, h, screen} or null
    property var popout: null
    // DMS draws his domes as part of its frame (dms-leiste-patch 14): then he
    // only paints his face on them
    property bool frameHost: false
    property bool frameOffsets: false      // DMS draws a dome at a popout's edge too
    property bool frameCorners: false      // ... as a round bump on its corner
    property int frameDomes: 3             // how many domes DMS draws (the rest draw their own)

    // every character, set by the shell
    property var cast: []
    readonly property var active: cast.filter(c => c.active)

    // ── windows, from niri (output-local, active workspaces) ───────
    property string outputName: ""
    property real gap: 10
    property var wins: []
    property bool winsKnown: false      // false: niri without the window-positions patch
    property bool fullscreen: false     // a fullscreen window: nothing of his over it
    // the window in front of a body at x (half width `half`) that reaches down
    // to the floor, or null. Between two windows: the one covering most of him.
    function windowOver(x, half) {
        if (!winsKnown)
            return { x: insets.left, w: areaW - insets.left - insets.right, bottom: floorY - gap }
        const h = half || 0
        let best = null, bestCover = 0
        for (const w of wins) {
            if (w.output !== outputName) continue
            const cover = Math.min(x + h, w.x + w.w) - Math.max(x - h, w.x)
            if (cover < 0 || (h === 0 && (x < w.x || x > w.x + w.w))) continue
            const bottom = w.y + w.h
            if (bottom < floorY - gap - 40) continue
            if (!best || cover > bestCover + 0.5 || (Math.abs(cover - bestCover) <= 0.5 && bottom > best.bottom)) {
                best = { x: w.x, w: w.w, bottom: bottom }
                bestCover = cover
            }
        }
        return best
    }

    // two windows side by side that both cover a good part of him, or null
    function windowPair(x, half) {
        if (!winsKnown) return null
        const near = []
        for (const w of wins) {
            if (w.output !== outputName || w.y + w.h < floorY - gap - 40) continue
            const cover = Math.min(x + half, w.x + w.w) - Math.max(x - half, w.x)
            if (cover > half * 0.5) near.push({ x: w.x, w: w.w, bottom: w.y + w.h })
        }
        if (near.length !== 2) return null
        near.sort((a, b) => a.x - b.x)
        // really side by side, with only the gap between them
        if (near[1].x - (near[0].x + near[0].w) > gap * 3) return null
        return near
    }

    // ── the cloth: the bottom of a window, lifted by a hand ────────
    property var clothWin: ({ x: 0, w: 100, bottom: 100 })
    property var clothWin2: null         // the second window, when he lifts two
    property string clothMode: "lift"    // lift | curtain (two windows slide aside)
    property real clothPush: 0
    property bool clothPrep: false       // stage shown, capture under way
    property bool clothActive: false
    property real clothLift: 0
    property real clothX: 0
    property var clothFor: null
    property bool clothUnder: true       // the character is behind the cloth
    property bool pusher: false          // the hand at the cloth's edge
    property bool capturing: false       // hide the character while the screen is captured
    readonly property bool clothBusy: clothPrep || clothActive
    signal clothRequest(var who, bool up)
    signal clothDone(var who, bool up)

    // ── the chat window ───────────────────────────────────────────
    property bool chatOpen: false
    property bool chatAway: false          // the chat window open without him (ChatWindow.away)
    signal chatHopOut(var who)
    property bool chatBusy: false
    property string chatModel: model     // what the running session uses
    // what the chat can talk to: Claude Code's three models, then the other
    // providers from the settings page ("p:<id>")
    readonly property var providers: { const v = opt("providers", []); return Array.isArray(v) ? v : [] }
    readonly property var modelChoices: ["haiku", "sonnet", "opus"].concat(providers.map(p => "p:" + p.id))
    function modelLabel(m) {
        const fixed = { haiku: "Haiku", sonnet: "Sonnet", opus: "Opus" }
        if (fixed[m]) return fixed[m]
        const p = providers.find(x => "p:" + x.id === m)
        return p ? p.name : m
    }
    onModelChanged: chatModel = model
    // who: me | him | note | tool | action; pending: his answer is still arriving;
    // actions: aid, phase (ask running done failed declined blocked), out
    property ListModel chatLog: ListModel {}
    function logAdd(who, text, extra) {
        const e = { who: who, text: text, pending: false, aid: "", phase: "", out: "" }
        if (extra) for (const k in extra) e[k] = extra[k]
        chatLog.append(e)
    }
    function logFind(aid) {
        for (let i = chatLog.count - 1; i >= 0; i--) if (chatLog.get(i).aid === aid) return i
        return -1
    }
    signal chatJumpIn(var who)
    signal chatJumpOut(var who)
    signal chatSeated(var who)
    signal chatLeft(var who)

    // ── the ball ──────────────────────────────────────────────────
    property bool ballOut: false
    property real ballX: 0
    property real ballH: 0
    property real ballVX: 0
    property real ballVY: 0
    property real ballSpin: 0
    property real ballAlpha: 0
    readonly property real ballR: 11
    readonly property bool ballMoving: ballOut && (Math.abs(ballVX) > 4 || ballH > 0.5 || Math.abs(ballVY) > 4)
    property int players: 0

    function throwIn(x) {
        ballHolder = null
        ballX = Math.max(insets.left + 40, Math.min(areaW - insets.right - 40, x))
        ballH = 120; ballVX = 0; ballVY = 0
        ballOut = true
        ballAlpha = 1
    }
    function takeAway() {
        ballHolder = null
        ballAlpha = 0
        ballGone.start()
    }
    Timer { id: ballGone; interval: 450; onTriggered: w.ballOut = false }
    function kick(dir, power) {
        ballVX = dir * (260 + power * 520)
        ballVY = 260 + power * 420
    }

    // ── held and thrown ───────────────────────────────────────────
    // in someone's hands: it sits between them above his head, and the physics rest
    property var ballHolder: null
    property var ballThrower: null          // who threw it last (no catching his own at once)
    property real ballThrownAt: 0
    readonly property real ballGravity: 1500
    // how high the ball may fly above the floor in the strip it is drawn in
    property real ballCeil: 180
    // where his hands hold it: between them (screen x, height of its bottom
    // above the floor), from the same offsets the hands are drawn with
    function bodyH(c) { return c.bodyH }
    function handsX(c) { return c.x0 + (c.handLX + c.handRX) / 2 }
    function holdHeight(c) { return c.lift + bodyH(c) * 0.34 - (c.handLY + c.handRY) / 2 - ballR }
    function holdBall(c) {
        ballHolder = c
        ballVX = 0; ballVY = 0
    }
    // let go at his hands with this speed (px/s, up is positive)
    function throwBall(c, vx, vy) {
        ballX = handsX(c)
        ballH = holdHeight(c)
        ballThrower = c
        ballThrownAt = Date.now()
        ballHolder = null
        ballVX = vx; ballVY = vy
    }
    // the speed for a lob from c to land at x at height hc, under the ceiling
    function lob(c, x, hc) {
        const g = ballGravity, h0 = holdHeight(c), dx = x - c.x0
        let t = Math.max(0.45, Math.min(1.1, Math.abs(dx) / 650))
        let vy = (hc - h0 + 0.5 * g * t * t) / t
        const top = ballCeil - 2 * ballR
        if (h0 + vy * vy / (2 * g) > top) {
            vy = Math.sqrt(Math.max(0, 2 * g * (top - h0)))
            t = (vy + Math.sqrt(vy * vy + 2 * g * Math.max(0, h0 - hc))) / g
        }
        return { vx: dx / t, vy: vy }
    }
    // where the ball comes down to height hc (walls folded back), or null
    function landingX(hc) {
        const g = ballGravity, h = ballH, vy = ballVY
        const disc = vy * vy + 2 * g * (h - hc)
        if (disc < 0) return null
        const t = (vy + Math.sqrt(disc)) / g
        if (t < 0) return null
        const lo = insets.left + ballR, hi = areaW - insets.right - ballR, span = hi - lo
        let x = ballX + ballVX * t - lo
        x = ((x % (2 * span)) + 2 * span) % (2 * span)
        return lo + (x > span ? 2 * span - x : x)
    }
    signal ballNear(var c)                  // the ball reaches c's hands in flight
    // in the user's hand (pointer): it follows it, nobody else can have it
    property bool ballInHand: false
    property var ballTrail: []
    function handGrab(x, h) {
        if (ballHolder) { ballHolder.stopBall(); ballHolder.mood = "surprised"; ballHolder = null }
        ballInHand = true
        ballVX = 0; ballVY = 0
        ballTrail = []
        handMove(x, h)
    }
    function handMove(x, h) {
        if (!ballInHand) return
        const now = Date.now()
        ballTrail = ballTrail.filter(p => now - p.t < 90).concat([{ t: now, x: x, h: h }])
        ballX = Math.max(insets.left + ballR, Math.min(areaW - insets.right - ballR, x))
        ballH = Math.max(0, Math.min(ballCeil - 2 * ballR, h))
    }
    function handThrow() {
        if (!ballInHand) return
        const a = ballTrail[0], b = ballTrail[ballTrail.length - 1]
        const dt = a && b ? Math.max(16, b.t - a.t) / 1000 : 1
        ballVX = a && b ? Math.max(-2600, Math.min(2600, (b.x - a.x) / dt)) : 0
        ballVY = a && b ? Math.max(-2600, Math.min(2600, (b.h - a.h) / dt)) : 0
        ballThrower = null
        ballInHand = false
        // nudge the physics awake even if let go at rest in the air
        if (ballH > 0.5 && Math.abs(ballVY) < 5) ballVY = -5
    }
    // sixty steps a second are enough for the ball (the screen would draw 165)
    property real ballT: 0
    Timer {
        interval: 16
        repeat: true
        running: w.ballMoving && !w.ballHolder && !w.ballInHand
        onRunningChanged: w.ballT = Date.now()
        onTriggered: {
            const now = Date.now()
            const dt = Math.min((now - w.ballT) / 1000, 0.05)
            w.ballT = now
            w.ballVY -= w.ballGravity * dt
            let h = w.ballH + w.ballVY * dt
            if (h <= 0) {
                h = 0
                w.ballVY = Math.abs(w.ballVY) > 90 ? -w.ballVY * 0.55 : 0
                w.ballVX *= 0.86
            }
            // the top of the strip it flies in: off it like off a wall
            if (h > w.ballCeil - 2 * w.ballR) { h = w.ballCeil - 2 * w.ballR; w.ballVY = -Math.abs(w.ballVY) * 0.5 }
            let x = w.ballX + w.ballVX * dt
            const lo = w.insets.left + w.ballR, hi = w.areaW - w.insets.right - w.ballR
            if (x < lo) { x = lo; w.ballVX = Math.abs(w.ballVX) * 0.8 }
            if (x > hi) { x = hi; w.ballVX = -Math.abs(w.ballVX) * 0.8 }
            if (h === 0) w.ballVX *= Math.pow(0.35, dt)
            if (Math.abs(w.ballVX) < 4 && h === 0) w.ballVX = 0
            w.ballSpin += w.ballVX * dt / w.ballR * 57.3
            w.ballX = x
            w.ballH = h
            // in reach of a player's raised hands
            if (h > 0) {
                for (const c of w.cast) {
                    if (!c.active || !c.brain || c.brain.doing !== "play") continue
                    if (c === w.ballThrower && now - w.ballThrownAt < 600) continue
                    const top = c.lift + c.size * 1.45, low = c.lift + c.size * 0.55
                    if (Math.abs(x - c.x0) < c.size * 0.6 && h + w.ballR > low && h < top) { w.ballNear(c); break }
                }
            }
        }
    }
    Behavior on ballAlpha { NumberAnimation { duration: 400 } }
}

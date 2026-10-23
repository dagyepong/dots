import QtQuick

// Everything a figure is, in one place. The three windows only draw it.
// Gestures are short animations at the screen's pace; anything that runs
// for long (sleeping breath, the "z") steps on a slow timer instead, so a
// sleeping figure costs ten frames a second and not 165.
Item {
    id: st
    required property var world
    property int slot: 0
    property var brain: null
    property string skin: "kuro"         // kuro | mochi | shiro | momo | robo | bao | none
    readonly property bool active: skin !== "none"
    readonly property string name: skin === "none" ? "Kuro" : skin.charAt(0).toUpperCase() + skin.slice(1)

    // ── where ─────────────────────────────────────────────────────
    readonly property var insets: world.insets
    readonly property real floorY: world.floorY
    readonly property real minX: insets.left + size * 0.7
    readonly property real maxX: world.areaW - insets.right - size * 0.7

    property real size: skin === "kumo" ? 74 : skin === "mochi" || skin === "bao" ? 68 : 58
    // height of the body for its width, and whether it has the round face with a mouth
    readonly property real bodyK: ({ mochi: 0.84, bao: 0.84, robo: 0.92, kumo: 0.7, tako: 0.94, hiyoko: 0.96 })[skin] || 1
    // Kumo floats a little over the floor, and niri blurs what is behind it
    // like behind Kuro's glass (but without his dark tint)
    readonly property real hover: skin === "kumo" && place !== "dock" ? 7 : 0
    readonly property bool blurBehind: glass || skin === "kumo"
    readonly property bool cakeFace: ["mochi", "bao", "kumo", "tako"].indexOf(skin) >= 0
    property real x0: world.areaW * (0.6 - slot * 0.17)   // centre of the body
    property real lift: 0                // height above the floor while hopping
    property real sink: 0                // 0 standing on the floor, 1 gone below it
    property string place: "home"        // home | stage | dock (in the frame) | chat (in the chat window) | sky (climbing)
    // off the floor (place sky): where his feet are on the screen, and which
    // way is down for him: 0 floor, 90 the left wall, -90 the right wall,
    // 180 the top edge
    property real y0: world.floorY
    property real surfaceRot: 0
    property bool moving: slipAnim.running || driftAnim.running || brachAnim.running || hopAnim.running || rollAnim.running || placeAnim.running || meltAnim.running || barInAnim.running || barOutAnim.running || riseAnim.running || undockAnim.running || glideAnim.running || pullAnim.running
    // where he rests; the click area follows this instead of every frame
    property real restX: x0
    onMovingChanged: if (!moving) restX = x0

    // ── colour: his own, the accent colour or a fixed one ─────────
    // each figure has its own (tint1 … tint5); the old shared setting is the fallback
    readonly property string tintMode: world.opt("tint" + (slot + 1), world.tintMode)
    readonly property bool tinted: tintMode !== "own"
    readonly property color tint: tintMode === "accent" ? world.primary : world.opt("tintColor" + (slot + 1), world.tintColor)
    readonly property bool glass: skin === "kuro"
    // Kuro is glass: the window tint (or his colour) at the frame's opacity
    // furious: the glass itself glows red (the other figures get a red overlay, Creature.qml)
    property real heat: mood === "angry" && level >= 3 ? 1 : 0
    Behavior on heat { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
    // eyes that read on his glass: what shows is his fill over what lies
    // behind; behind is usually dark (blurred windows, the frame), so a thin
    // fill keeps light eyes, a dense light one (a white window colour at full
    // opacity, a white accent) gets dark ones
    readonly property color glassInk: {
        const f = glassFill
        const l = (0.2126 * f.r + 0.7152 * f.g + 0.0722 * f.b) * f.a + 0.08 * (1 - f.a)
        return l > 0.45 ? "#2b2730" : "#f4efe8"
    }
    readonly property color glassFill: Qt.tint(world.alpha(tinted ? tint : world.glassTint, world.glassOpacity),
                                               Qt.rgba(0.95, 0.18, 0.14, 0.62 * heat))

    // ── body ──────────────────────────────────────────────────────
    property real sx: 1
    property real sy: 1
    property real rot: 0
    property real lean: 0

    // ── face ──────────────────────────────────────────────────────
    property real gazeX: 0               // -1 … 1
    property real gazeY: 0
    property real lid: 1                 // 1 open, 0 closed
    property string mood: "neutral"      // see Face.qml
    // what the face shows: with nothing else on his mind a hard-working
    // machine squeezes his eyes shut (> <)
    readonly property string shownMood: mood === "neutral" && world.sweat >= 0.7 ? "strained" : mood
    // how strongly: 1 a little (annoyed, glum, uneasy), 2 as before, 3 very
    // (furious, crying, terrified). A plain `mood = …` means level 2; feel()
    // starts lower and climbs when the same feeling comes again.
    property int level: 2
    property bool feeling: false
    onMoodChanged: if (!feeling) level = 2
    function feel(m, start) {
        feeling = true
        level = m === mood ? Math.min(3, level + 1) : Math.max(1, Math.min(3, start || 1))
        mood = m
        feeling = false
        calmTimer.restart()
    }
    // the strongest level fades by itself; the rest goes back to calm as before
    Timer {
        id: calmTimer
        interval: 5000; repeat: true
        running: st.level >= 3 && !st.held
        onTriggered: st.level = 2
    }
    // what the brain's timers call to go back to neutral: false while the
    // feeling is still strong (or another one has taken over)
    function calm(m) {
        if (m && mood !== m) return true
        if (level >= 3) return false
        mood = "neutral"
        return true
    }
    onLevelChanged: react()
    // ── gestures that go with a strong feeling, on the floor ───────
    // scared: hands over his face, peeking through now and then; crying:
    // wiping the tears, one side then the other; blushing: hands on his
    // cheeks, swaying shyly. Every 2.6 s while it lasts.
    readonly property string feelGesture: (place !== "home" && place !== "stage") || sleeping ? ""
        : mood === "scared" && level >= 2 ? "cover"
        : mood === "sad" && level >= 3 ? "wipe"
        : mood === "blush" && level >= 2 ? "cheeks" : ""
    property int wipeSide: 1
    // hands in front of his face (gestures, food, covering his eyes): drawn
    // over the body then, else behind it
    property bool coverEyes: false
    readonly property bool handsFront: feelGesture !== "" || snackOut || bananaOut || coverEyes || polishAnim.running
    Timer {
        interval: 2600; repeat: true; triggeredOnStart: true
        running: st.feelGesture !== "" && st.active
        onTriggered: {
            if (st.moving || st.holding || waveAnim.running || cheerAnim.running || fistAnim.running) return
            st.useHands(2800)
            if (st.feelGesture === "cover") coverAnim.restart()
            else if (st.feelGesture === "wipe") { st.wipeSide = -st.wipeSide; wipeAnim.restart() }
            else cheeksAnim.restart()
        }
        onRunningChanged: if (!running) { coverAnim.stop(); wipeAnim.stop(); cheeksAnim.stop(); st.handLX = 0; st.handRX = 0; st.handLY = 0; st.handRY = 0; st.lean = 0 }
    }
    SequentialAnimation {
        id: coverAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.44; duration: 140 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.44; duration: 140 }
            NumberAnimation { target: st; property: "handLY"; to: -st.bodyH * 0.38; duration: 140 }
            NumberAnimation { target: st; property: "handRY"; to: -st.bodyH * 0.38; duration: 140 }
        }
        PauseAnimation { duration: 900 }
        // a peek between the fingers
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.3; duration: 120 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.3; duration: 120 }
        }
        PauseAnimation { duration: 450 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.44; duration: 120 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.44; duration: 120 }
        }
    }
    SequentialAnimation {
        id: wipeAnim
        NumberAnimation { target: st; property: st.wipeSide > 0 ? "handRY" : "handLY"; to: -st.bodyH * 0.36; duration: 180 }
        SequentialAnimation {
            loops: 3
            NumberAnimation { target: st; property: st.wipeSide > 0 ? "handRX" : "handLX"; to: -st.wipeSide * st.size * 0.3; duration: 140; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: st.wipeSide > 0 ? "handRX" : "handLX"; to: -st.wipeSide * st.size * 0.18; duration: 140; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 220 }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 220 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 260 }
        }
    }
    SequentialAnimation {
        id: cheeksAnim
        ParallelAnimation {
            // on the cheeks, below the eyes
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.24; duration: 160 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.24; duration: 160 }
            NumberAnimation { target: st; property: "handLY"; to: -st.bodyH * 0.06; duration: 160 }
            NumberAnimation { target: st; property: "handRY"; to: -st.bodyH * 0.06; duration: 160 }
        }
        NumberAnimation { target: st; property: "lean"; to: 6; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "lean"; to: -6; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "lean"; to: 0; duration: 420; easing.type: Easing.InOutSine }
    }
    function react() {
        if (level < 3) return
        if (mood === "angry") shakeFist()
        else if (mood === "happy") cheer()
    }
    // fright from level 2: he trembles, a little or hard (30 steps a second)
    property real tremble: 0
    Timer {
        interval: 33; repeat: true
        running: st.mood === "scared" && st.level >= 2 && st.active && !st.sleeping
        onTriggered: st.tremble = (Math.random() * 2 - 1) * (st.level >= 3 ? 2 : 1)
        onRunningChanged: if (!running) st.tremble = 0
    }
    property bool sleeping: false
    property bool thinking: false
    property real zPhase: 0
    property real breath: 0

    // ── hands: offsets from their resting place, and how tucked in ─
    property real handLX: 0
    property real handLY: 0
    property real handRX: 0
    property real handRY: 0
    property real tuck: 0                // 1 hands hidden in the body (rolling)
    // hands are only out while something needs them
    property real handsOut: 0
    readonly property color handColor: tinted ? tint : ({ mochi: "#f1e4d6", kuro: "#2a2420", shiro: "#ece8e2", momo: "#ffbfa6", robo: "#a9b1bc", bao: "#f4ecdc",
                                                                   neko: "#f7b47a", kumo: "#f4f8fc", tako: "#ff8a99", hiyoko: "#ffdf5c", arai: "#a0a0aa" })[skin] || "#f1e4d6"
    function useHands(ms) {
        if (handsOut < 1 && !handsIn.running) { handsIn.stop(); handsAway.stop(); handsIn.start() }
        handsTimer.interval = ms || 1100
        handsTimer.restart()
    }
    NumberAnimation { id: handsIn; target: st; property: "handsOut"; to: 1; duration: 180; easing.type: Easing.OutBack }
    NumberAnimation {
        id: handsAway; target: st; property: "handsOut"; to: 0; duration: 220; easing.type: Easing.InQuad
        // put away: they come out from their usual place next time
        onFinished: if (st.handsOut === 0 && !st.hanging) { st.handLX = 0; st.handLY = 0; st.handRX = 0; st.handRY = 0 }
    }
    Timer {
        id: handsTimer
        onTriggered: {
            if (st.thinking || waveAnim.running || cheerAnim.running || st.holding) { restart(); return }
            handsIn.stop(); handsAway.start()
        }
    }
    property bool holding: false         // holding something up (the cloth)

    signal hopDone()
    signal rollDone()
    signal placeDone()

    // ── hop ───────────────────────────────────────────────────────
    property real hopTarget: x0
    property real hopHeight: 22
    property int hopDur: 300

    function hop(target, height) {
        if (moving) return false
        // the cloud does not hop: it drifts there (jumps for real only when high)
        if (skin === "kumo" && (height || 22) <= 30) return drift(target, false)
        hopTarget = Math.max(minX, Math.min(maxX, target))
        hopHeight = height || 22
        hopDur = 230 + hopHeight * 4
        gazeX = hopTarget > x0 ? 0.8 : -0.8
        hopAnim.start()
        return true
    }

    SequentialAnimation {
        id: hopAnim
        // gathers itself
        ParallelAnimation {
            NumberAnimation { target: st; property: "sx"; to: 1.16; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sy"; to: 0.84; duration: 90; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "x0"; to: st.hopTarget; duration: st.hopDur; easing.type: Easing.Linear }
            SequentialAnimation {
                NumberAnimation { target: st; property: "lift"; to: st.hopHeight; duration: st.hopDur / 2; easing.type: Easing.OutQuad }
                NumberAnimation { target: st; property: "lift"; to: 0; duration: st.hopDur / 2; easing.type: Easing.InQuad }
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: st; property: "sx"; to: 0.9; duration: st.hopDur * 0.3; easing.type: Easing.OutQuad }
                    NumberAnimation { target: st; property: "sy"; to: 1.13; duration: st.hopDur * 0.3; easing.type: Easing.OutQuad }
                }
                ParallelAnimation {
                    NumberAnimation { target: st; property: "sx"; to: 1; duration: st.hopDur * 0.4 }
                    NumberAnimation { target: st; property: "sy"; to: 1; duration: st.hopDur * 0.4 }
                }
            }
        }
        // lands, squashes, settles
        ParallelAnimation {
            NumberAnimation { target: st; property: "sx"; to: 1.2; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sy"; to: 0.8; duration: 70; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
        onFinished: st.hopDone()
    }

    // ── roll: whole turns, so he ends upright ─────────────────────
    property real rollTarget: x0
    property real rollTo: 0
    property int rollDur: 800

    // ── drifting: how the cloud gets about instead of hopping or rolling ──
    // smoothly along, bobbing up a little and leaning into the way; a step
    // ends with hopDone, a long way with rollDone, like the moves it replaces
    property real driftTarget: 0
    property int driftMs: 400
    property real driftLean: 0
    property bool driftLong: false
    SequentialAnimation {
        id: driftAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "x0"; to: st.driftTarget; duration: st.driftMs; easing.type: Easing.InOutSine }
            SequentialAnimation {
                NumberAnimation { target: st; property: "lift"; to: 4; duration: st.driftMs / 2; easing.type: Easing.InOutSine }
                NumberAnimation { target: st; property: "lift"; to: 0; duration: st.driftMs / 2; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
                NumberAnimation { target: st; property: "lean"; to: st.driftLean; duration: st.driftMs * 0.3; easing.type: Easing.OutSine }
                PauseAnimation { duration: st.driftMs * 0.4 }
                NumberAnimation { target: st; property: "lean"; to: 0; duration: st.driftMs * 0.3; easing.type: Easing.InOutSine }
            }
        }
        ScriptAction { script: if (st.driftLong) st.rollDone(); else st.hopDone() }
    }
    function drift(target, long) {
        driftTarget = Math.max(minX, Math.min(maxX, target))
        const dist = driftTarget - x0
        // about as quick as the hops and rolls it replaces, so games and chases still work
        driftMs = long ? 420 + Math.abs(dist) * 2.4 : 260 + Math.abs(dist) * 2.2
        driftLean = Math.sign(dist) * (long ? 8 : 5)
        driftLong = long
        gazeX = Math.sign(dist) * 0.6
        driftAnim.start()
        return true
    }
    function roll(target) {
        if (moving) return false
        if (skin === "kumo") return drift(target, true)
        rollTarget = Math.max(minX, Math.min(maxX, target))
        const dist = rollTarget - x0
        const turns = Math.max(1, Math.round(Math.abs(dist) / (Math.PI * size * 0.9)))
        rollTo = rot + Math.sign(dist) * 360 * turns
        rollDur = 420 + Math.abs(dist) * 2.2
        gazeX = Math.sign(dist) * 0.6
        rollAnim.start()
        return true
    }

    SequentialAnimation {
        id: rollAnim
        NumberAnimation { target: st; property: "tuck"; to: 1; duration: 90 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "x0"; to: st.rollTarget; duration: st.rollDur; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "rot"; to: st.rollTo; duration: st.rollDur; easing.type: Easing.InOutSine }
            SequentialAnimation {
                NumberAnimation { target: st; property: "sy"; to: 0.93; duration: 120 }
                PauseAnimation { duration: Math.max(0, st.rollDur - 240) }
                NumberAnimation { target: st; property: "sy"; to: 1; duration: 120 }
            }
        }
        // a little dizzy wobble at the end
        NumberAnimation { target: st; property: "lean"; to: 7; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "lean"; to: -4; duration: 150; easing.type: Easing.InOutQuad }
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 220; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "tuck"; to: 0; duration: 220; easing.type: Easing.OutBack }
        }
        onFinished: { st.rot = st.rot % 360; st.rollDone() }
    }

    // ── a jump on the spot (joy, surprise) ────────────────────────
    // a dance step to the beat: a short hop, a little to one side
    property real pulse: 0               // the dome in the frame swells to the beat
    NumberAnimation { id: pulseAnim; target: st; property: "pulse"; to: 0; duration: 300; easing.type: Easing.OutQuad }
    // ── gliding: one smooth move to a point, turning to a surface ─
    property real glideX: 0
    property real glideY: 0
    property real glideRot: 0
    property int glideMs: 300
    property int glideEase: Easing.InOutQuad
    signal glideDone()
    SequentialAnimation {
        id: glideAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "x0"; to: st.glideX; duration: st.glideMs; easing.type: st.glideEase }
            NumberAnimation { target: st; property: "y0"; to: st.glideY; duration: st.glideMs; easing.type: st.glideEase }
            NumberAnimation { target: st; property: "surfaceRot"; to: st.glideRot; duration: st.glideMs; easing.type: Easing.InOutSine }
            SequentialAnimation {
                // a little push off and back onto the surface
                NumberAnimation { target: st; property: "lift"; to: 7; duration: st.glideMs * 0.45; easing.type: Easing.OutQuad }
                NumberAnimation { target: st; property: "lift"; to: 0; duration: st.glideMs * 0.55; easing.type: Easing.InQuad }
            }
        }
        ScriptAction { script: st.glideDone() }
    }
    function glide(x, y, r, ms, ease) {
        glideX = x; glideY = y; glideRot = r
        glideMs = ms || 300
        glideEase = ease === undefined ? Easing.InOutQuad : ease
        glideAnim.restart()
    }
    // pulling himself along a wall or the top edge, hand over hand like on a
    // ladder (dir: -1 / 1 along his own x). The hands hold the frame itself
    // (screen grips at its edge), both ahead of him: the lower one comes off,
    // swings out in an arc and grips past the upper one, then he pulls
    // himself up while both hold where they are
    property real pullDir: 1
    property real pullReach: 0
    property bool pullLeft: false        // the left hand reaches this time
    property real pullFromX: 0
    property real pullFromY: 0
    property real pullToX: 0
    property real pullToY: 0
    property real pullOutX: 0            // away from the surface (screen)
    property real pullOutY: 0
    property real pullT: 0               // 0 … 1 the reaching hand on its way
    onPullTChanged: {
        if (!pullAnim.running) return
        const e = pullT, out = Math.sin(Math.PI * e) * size * 0.32
        const x = pullFromX + (pullToX - pullFromX) * e + pullOutX * out
        const y = pullFromY + (pullToY - pullFromY) * e + pullOutY * out
        if (pullLeft) { gLX = x; gLY = y } else { gRX = x; gRY = y }
    }
    // a point in his own frame on the screen (his frame turns round his feet)
    function toScreen(lx, ly) {
        const a = surfaceRot * Math.PI / 180
        return { x: x0 + lx * Math.cos(a) - ly * Math.sin(a), y: y0 + lx * Math.sin(a) + ly * Math.cos(a) }
    }
    // how far ahead of his middle a screen point is, along dir
    function aheadOf(px, py, dir) {
        const a = surfaceRot * Math.PI / 180
        return dir * ((px - x0) * Math.cos(a) + (py - y0) * Math.sin(a))
    }
    // a little into the frame, where his feet are against it
    readonly property real gripDepth: size * 0.05
    function releaseGrips() { if (!hanging) { gripTo(-1, 0, 220); gripTo(1, 0, 220) } }
    signal pullDone()
    SequentialAnimation {
        id: pullAnim
        ScriptAction { script: st.useHands(1400) }
        // the reaching hand: off the frame, out in an arc and onto it again ahead
        NumberAnimation { target: st; property: "pullT"; from: 0; to: 1; duration: 260; easing.type: Easing.InOutQuad }
        ScriptAction { script: st.jolt() }
        PauseAnimation { duration: 50 }
        // he pulls himself up to his hands; they stay where they hold
        ParallelAnimation {
            NumberAnimation { target: st; property: "x0"; to: st.glideX; duration: st.glideMs; easing.type: Easing.InOutQuad }
            NumberAnimation { target: st; property: "y0"; to: st.glideY; duration: st.glideMs; easing.type: Easing.InOutQuad }
            SequentialAnimation {
                NumberAnimation { target: st; property: "sx"; to: 0.9; duration: st.glideMs * 0.5 }
                NumberAnimation { target: st; property: "sx"; to: 1; duration: st.glideMs * 0.5 }
            }
        }
        ScriptAction { script: st.glideDone() }
    }
    // dist: how far the body moves (screen), along: his own x direction
    function pullTo(x, y, along) {
        glideX = x; glideY = y
        glideMs = 280
        pullDir = along
        pullReach = Math.hypot(x - x0, y - y0)
        const out = toScreen(0, -1)
        pullOutX = out.x - x0; pullOutY = out.y - y0
        const hi = size * 0.62
        // new on this surface: both hands onto the frame, ahead of him
        if (gripKL < 1 && gripKR < 1) {
            handLX = 0; handLY = 0; handRX = 0; handRY = 0
            const l = toScreen(along * hi, gripDepth), r = toScreen(along * Math.max(size * 0.15, hi - pullReach), gripDepth)
            // the hand that is ahead anyway takes the upper hold
            const leftAhead = along < 0
            const up = leftAhead ? "L" : "R"
            if (up === "L") { gLX = l.x; gLY = l.y; gRX = r.x; gRY = r.y } else { gRX = l.x; gRY = l.y; gLX = r.x; gLY = r.y }
            gripTo(-1, 1, 200); gripTo(1, 1, 200)
        }
        // the lower hand reaches; it grips so far ahead that it is the upper one once he is up
        pullLeft = aheadOf(gLX, gLY, along) < aheadOf(gRX, gRY, along)
        pullFromX = pullLeft ? gLX : gRX; pullFromY = pullLeft ? gLY : gRY
        const to = toScreen(along * (hi + pullReach), gripDepth)
        pullToX = to.x; pullToY = to.y
        pullT = 0
        pullAnim.restart()
    }

    // ── hanging: from a rope or by the hands from the top edge ────
    // A pendulum around (pivotX, pivotY): the hands hang ropeLen below it,
    // the feet hangLen further. theta (radians) is the angle from straight
    // down; the body hangs along the line, so the figure turns with it.
    // Swinging steps at 60 fps only while there is something to swing.
    readonly property real bodyH: size * bodyK
    readonly property real hangLen: bodyH * 1.12
    property bool hanging: false
    property real pivotX: 0
    property real pivotY: 0
    property real ropeLen: 0
    property real theta: 0
    property real omega: 0
    property real pump: 0                // a push with each swing (rad/s²)
    property real swingAmp: 0.4          // pumping stops adding once the swing is this wide (rad)
    property real damping: 0.6
    property int oneHand: 0              // hangs by one hand (1 the right, -1 the left), the other is free
    onThetaChanged: if (hanging && !rePivoting) hangPlace()
    onPivotXChanged: if (hanging && !rePivoting) hangPlace()
    onRopeLenChanged: if (hanging) hangPlace()
    function hangPlace() {
        const l = ropeLen + hangLen
        x0 = pivotX + l * Math.sin(theta)
        y0 = pivotY + l * Math.cos(theta)
        surfaceRot = -theta * 180 / Math.PI
        // both hands up at the grip (in his own frame: hangLen above the feet)
        const up = -hangLen + bodyH * 0.34
        const w = size
        if (oneHand >= 0) { handRY = up; handRX = -w * 0.5 + (oneHand > 0 ? w * 0.04 : 0) + gripSpread }
        if (oneHand <= 0) { handLY = up; handLX = w * 0.5 - (oneHand < 0 ? w * 0.04 : 0) - gripSpread }
    }
    // start hanging from (px, py) wherever he is now: the rope takes the rest
    function hangFrom(px, py) {
        // stopAll ends everything, the rope he hangs on too: keep that
        const keepRope = rope
        stopAll()
        rope = keepRope
        place = "sky"
        pivotX = px; pivotY = py
        const dx = x0 - px, dy = y0 - py
        ropeLen = Math.max(0, Math.hypot(dx, dy) - hangLen)
        theta = Math.atan2(dx, dy)
        omega = 0
        hanging = true
        useHands(600000)
        hangPlace()
    }
    // (the rope goes with it: left behind, it would hang from the hook to where
    // the gun once was)
    // the hands this far apart from the middle of the grip (round the
    // pointer's arrow, one on each side of it)
    property real gripSpread: 0
    function stopHanging() {
        hanging = false; pump = 0; omega = 0; oneHand = 0; rope = false; gripSpread = 0
        onBar = false; brachAnim.stop(); gripLAnim.stop(); gripRAnim.stop(); gripKL = 0; gripKR = 0
        swingTimer.stop()
        handLX = 0; handLY = 0; handRX = 0; handRY = 0
        handsTimer.interval = 400; handsTimer.restart()
    }
    // the pendulum: gravity like a throw, a little damping, and a push now
    // and then in the direction he swings (pumping)
    readonly property bool swinging: hanging && (Math.abs(omega) > 0.02 || Math.abs(theta) > 0.01 || pump > 0)
    property real swingT: 0
    Timer {
        id: swingTimer
        interval: 16; repeat: true
        running: st.swinging && !st.scripted
        onTriggered: {
            const now = Date.now()
            const dt = Math.min(0.04, (now - st.swingT) / 1000 || 0.016)
            st.swingT = now
            const l = st.ropeLen + st.hangLen * 0.6, g = 2600
            let a = -(g / l) * Math.sin(st.theta) - st.damping * st.omega
            // pumping like on a swing: a push in the direction he moves, less
            // and less as the swing gets as wide as wanted, so it grows swing
            // by swing instead of in one go
            if (st.pump > 0) {
                const energy = 0.5 * st.omega * st.omega + (g / l) * (1 - Math.cos(st.theta))
                const amp = Math.acos(Math.max(-1, 1 - energy * l / g))
                a += st.pump * (st.omega >= 0 ? 1 : -1) * Math.max(0, 1 - amp / st.swingAmp)
            }
            st.omega += a * dt
            let th = st.theta + st.omega * dt
            // a soft end: bounces back a little instead of sticking there
            if (Math.abs(th) > 1.35) { th = Math.sign(th) * 1.35; st.omega = -st.omega * 0.3 }
            st.theta = th
            if (st.pump === 0 && Math.abs(st.omega) < 0.02 && Math.abs(st.theta) < 0.01) { st.omega = 0; st.theta = 0 }
            st.swing(st.theta, st.omega)
        }
        onRunningChanged: if (running) st.swingT = Date.now()
    }
    signal swing(real theta, real omega)
    property bool scripted: false        // an animation moves theta, not the pendulum
    // tangential speed of his middle, for letting go (px/s)
    function swingVelocity() {
        const l = ropeLen + hangLen * 0.6
        return { vx: omega * l * Math.cos(theta), vy: -omega * l * Math.sin(theta) }
    }

    // the rope: from the pivot (the hook) down to his hands; while it flies
    // up it runs from the gun to ropeShot of the way to the hook
    property bool rope: false
    property real ropeShot: 1
    property real hookX: 0
    property real hookY: 0
    property real gunX: 0
    property real gunY: 0
    NumberAnimation { id: shotAnim; target: st; property: "ropeShot"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
    signal hooked()
    Connections { target: shotAnim; function onFinished() { st.hooked() } }
    // the grappling gun in his right hand, aimed at gunAim degrees (0 up)
    property real gun: 0
    property real gunAim: 0
    NumberAnimation { id: gunAnim; target: st; property: "gun"; duration: 180; easing.type: Easing.OutBack }
    function drawGun(on) { gunAnim.to = on ? 1 : 0; gunAnim.restart() }
    // where his right hand is on the screen (standing upright), and the
    // gun's muzzle in it: Creature.qml draws the gun there, 21 px long
    // before its scale (size / 58 · 1.45), turned by gunAim
    function rightHand() {
        return { x: x0 + size * (0.36 + 0.2 * handsOut) * sx + handRX,
                 y: y0 - lift + sink * (bodyH + 14) - bodyH + bodyH * 0.66 + handRY }
    }
    function muzzle() {
        const h = rightHand(), len = 21 * size / 58 * 1.45 * gun
        const a = gunAim * Math.PI / 180
        return { x: h.x + len * Math.sin(a), y: h.y - len * Math.cos(a) }
    }
    // turns the gun towards (hx, hy), before the shot
    NumberAnimation { id: aimAnim; target: st; property: "gunAim"; duration: 300; easing.type: Easing.OutQuad }
    function aimAt(hx, hy) {
        const h = rightHand()
        aimAnim.to = Math.atan2(hx - h.x, h.y - hy) * 180 / Math.PI
        aimAnim.restart()
    }
    // shoots the hook to (hx, hy): the rope runs out of the muzzle
    function shoot(hx, hy) {
        hookX = hx; hookY = hy
        const m = muzzle()
        gunX = m.x; gunY = m.y
        rope = true
        ropeShot = 0
        shotAnim.restart()
        jolt()
    }

    // ── holding on to spots on the screen (the top edge) ─────────
    // gripKL / gripKR 1: that hand sits on (gLX, gLY) / (gRX, gRY) on the
    // screen whatever the body does under it (swinging, swinging through);
    // 0: it follows handLX/LY as usual. Creature mixes the two.
    property real gLX: 0
    property real gLY: 0
    property real gRX: 0
    property real gRY: 0
    property real gripKL: 0
    property real gripKR: 0
    NumberAnimation { id: gripLAnim; target: st; property: "gripKL"; easing.type: Easing.OutQuad }
    NumberAnimation { id: gripRAnim; target: st; property: "gripKR"; easing.type: Easing.OutQuad }
    function gripTo(side, k, ms) {
        const an = side < 0 ? gripLAnim : gripRAnim
        an.stop(); an.to = k; an.duration = ms; an.start()
    }
    // a hand's resting place in his own frame (as Creature puts it)
    function handBase(side) {
        return { x: side * size * (0.36 + 0.2 * handsOut) * sx,
                 y: -bodyH - lift - hover + sink * (bodyH + 14) + bodyH * 0.66 + (side < 0 ? lift * 0.18 : -lift * 0.12) }
    }
    // the offset that puts that hand on (px, py) on the screen: his frame is
    // turned by surfaceRot round his feet
    function gripOffset(side, px, py) {
        const a = surfaceRot * Math.PI / 180, dx = px - x0, dy = py - y0, b = handBase(side)
        return { x: dx * Math.cos(a) + dy * Math.sin(a) - b.x, y: -dx * Math.sin(a) + dy * Math.cos(a) - b.y }
    }
    readonly property var gripL: gripKL > 0 ? gripOffset(-1, gLX, gLY) : null
    readonly property var gripR: gripKR > 0 ? gripOffset(1, gRX, gRY) : null

    // by both hands from the top edge, apart like on monkey bars: he swings
    // between them and the hands stay where they hold. One hand off
    // (oneHand), he swings under the other; back on, it takes hold next to it.
    property bool onBar: false
    readonly property real barSpread: size * 0.62
    property bool rePivoting: false
    function takeBar() {
        if (!hanging) return
        onBar = true
        gLY = pivotY; gRY = pivotY
        gLX = pivotX - barSpread / 2; gRX = pivotX + barSpread / 2
        if (oneHand >= 0) gripTo(1, 1, 220)
        if (oneHand <= 0) gripTo(-1, 1, 220)
        rePivot()
    }
    // back to holding a rope (abseiling): both hands on it above his head
    function leaveBar() {
        if (!onBar) return
        onBar = false
        const mid = oneHand > 0 ? gRX : oneHand < 0 ? gLX : (gLX + gRX) / 2
        oneHand = 0
        movePivot(mid)
        gripTo(-1, 0, 200); gripTo(1, 0, 200)
    }
    onOneHandChanged: if (onBar && hanging && !brachAnim.running) rePivot()
    function rePivot() {
        if (oneHand > 0) { gripTo(-1, 0, 160); movePivot(gRX); return }
        if (oneHand < 0) { gripTo(1, 0, 160); movePivot(gLX); return }
        // the free hand takes hold again beside the other, on the side it is
        if (gripKL < 1 && gripKR >= 1) { gLX = gRX + (gLX < gRX ? -1 : 1) * barSpread; gLY = gRY; gripTo(-1, 1, 200) }
        else if (gripKR < 1 && gripKL >= 1) { gRX = gLX + (gRX < gLX ? -1 : 1) * barSpread; gRY = gLY; gripTo(1, 1, 200) }
        movePivot((gLX + gRX) / 2)
    }
    // the pendulum hangs from px now; his feet stay where they are, so he
    // swings over to under it by himself
    function movePivot(px) {
        const fx = x0, fy = y0
        rePivoting = true
        pivotX = px
        theta = Math.atan2(fx - px, fy - pivotY)
        rePivoting = false
        hangPlace()
    }

    // hand over hand along the top edge: a little swing back, the hand behind
    // lets go, he swings forward under the one ahead and the free hand
    // reaches past it for the next hold; both hold, he comes under the
    // middle, and next time the other hand goes (they take turns leading)
    property real brStep: 0
    property real brA: 0
    property bool brLeft: false          // the left hand reaches this time
    property real brHold: 0              // where the hand ahead holds
    property real brFrom: 0              // where the reaching hand let go
    property real brTo: 0                // where it takes hold
    property real brT: 0                 // 0 … 1 on its way
    // the reaching hand: down past his head on the way and up to the edge
    onBrTChanged: {
        if (!brachAnim.running) return
        const e = brT, x = brFrom + (brTo - brFrom) * e, y = pivotY + Math.sin(Math.PI * e) * bodyH * 0.42
        if (brLeft) { gLX = x; gLY = y } else { gRX = x; gRY = y }
    }
    // where a hand holds above his head in his own frame (on a rope, or regripping)
    function gripX(left) { return left ? size * 0.5 : -size * 0.5 }
    readonly property real gripY: -hangLen + bodyH * 0.34
    signal brachiated()
    SequentialAnimation {
        id: brachAnim
        ScriptAction { script: { st.scripted = true; st.omega = 0 } }
        // swinging back a little for the momentum, both hands still on
        NumberAnimation { target: st; property: "theta"; to: -st.brA * 0.55; duration: 300; easing.type: Easing.InOutSine }
        // the hand behind lets go: forward under the one ahead, the free hand past it
        ParallelAnimation {
            NumberAnimation { target: st; property: "pivotX"; to: st.brHold; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "theta"; to: st.brA; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "brT"; from: 0; to: 1; duration: 480; easing.type: Easing.InOutQuad }
        }
        ScriptAction { script: st.jolt() }
        // both hold: his body comes under the middle and swings out a little
        ParallelAnimation {
            NumberAnimation { target: st; property: "pivotX"; to: (st.brHold + st.brTo) / 2; duration: 340; easing.type: Easing.OutSine }
            NumberAnimation { target: st; property: "theta"; to: st.brA * 0.3; duration: 340; easing.type: Easing.OutSine }
        }
        ScriptAction { script: { st.brLeft = !st.brLeft; st.omega = 0; st.scripted = false; st.brachiated() } }
    }
    // hanging still: one hand lets go, shakes out and grips again, then the other
    SequentialAnimation {
        id: regripAnim
        ScriptAction { script: { st.oneHand = st.brLeft ? 1 : -1; st.hangPlace() } }
        NumberAnimation { target: st; property: st.brLeft ? "handLY" : "handRY"; to: st.gripY + st.bodyH * 0.45; duration: 220; easing.type: Easing.OutQuad }
        SequentialAnimation {
            loops: 3
            NumberAnimation { target: st; property: st.brLeft ? "handLX" : "handRX"; to: st.gripX(st.brLeft) + (st.brLeft ? 1 : -1) * st.size * 0.12; duration: 90 }
            NumberAnimation { target: st; property: st.brLeft ? "handLX" : "handRX"; to: st.gripX(st.brLeft) + (st.brLeft ? 1 : -1) * st.size * 0.02; duration: 90 }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: st.brLeft ? "handLY" : "handRY"; to: st.gripY; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: st.brLeft ? "handLX" : "handRX"; to: st.gripX(st.brLeft); duration: 200 }
        }
        ScriptAction { script: { st.jolt(); st.oneHand = 0; st.hangPlace(); st.brLeft = !st.brLeft } }
        PauseAnimation { duration: 350 }
        ScriptAction { script: if (st.regripTwice) { st.regripTwice = false; regripAgain.start() } }
    }
    Timer { id: regripAgain; interval: 10; onTriggered: if (st.hanging && st.oneHand === 0) regripAnim.restart() }
    property bool regripTwice: false
    function regrip() { if (!hanging || oneHand !== 0 || brachAnim.running) return false; regripTwice = true; regripAnim.restart(); return true }
    function brachiate(dir) {
        if (!onBar) takeBar()
        if (oneHand !== 0) { oneHand = 0 }
        // the hand behind reaches; it grips one step ahead of the other
        brLeft = (gLX - gRX) * dir < 0
        brHold = brLeft ? gRX : gLX
        brFrom = brLeft ? gLX : gRX
        const room = dir > 0 ? maxX - brHold : brHold - minX
        brStep = Math.min(size * 0.85, Math.max(0, room))
        if (brStep < size * 0.3) { brachiated(); return false }
        brTo = brHold + dir * brStep
        brA = dir * Math.min(0.55, 0.22 + brStep / (2 * (ropeLen + hangLen)))
        brT = 0
        brachAnim.restart()
        return true
    }
    // a free hand scratches his head (hanging by the other)
    SequentialAnimation {
        id: scratchAnim
        loops: 5
        NumberAnimation { target: st; property: st.oneHand > 0 ? "handLY" : "handRY"; to: -st.bodyH * 0.62; duration: 110 }
        NumberAnimation { target: st; property: st.oneHand > 0 ? "handLY" : "handRY"; to: -st.bodyH * 0.5; duration: 110 }
    }
    // side 1: the right hand holds on, the left one scratches
    function scratch(side) {
        oneHand = side
        useHands(600000)
        hangPlace()
        if (side > 0) { handLX = size * 0.06; handLY = -bodyH * 0.5 } else { handRX = -size * 0.06; handRY = -bodyH * 0.5 }
        scratchAnim.restart()
    }

    // ── a banana, eaten hanging by one hand ───────────────────────
    // banana: 1 whole … 0 eaten; peeled: 0 … 1 the peel opens. The free hand
    // holds it at his mouth; at the end the peel drops (World.dropPeel).
    property real banana: 0
    property real peeled: 0
    property bool bananaOut: false
    signal bananaDone()
    SequentialAnimation {
        id: bananaAnim
        ScriptAction { script: { st.bananaOut = true; st.banana = 1; st.peeled = 0 } }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: st; property: "peeled"; to: 0.5; duration: 300 }
        PauseAnimation { duration: 200 }
        NumberAnimation { target: st; property: "peeled"; to: 1; duration: 300 }
        // three bites, a little chewing between them
        SequentialAnimation {
            loops: 3
            PauseAnimation { duration: 350 }
            ScriptAction { script: { st.banana = Math.max(0, st.banana - 0.34); st.jolt() } }
            NumberAnimation { target: st; property: "sy"; to: 0.94; duration: 120 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 120 }
            NumberAnimation { target: st; property: "sy"; to: 0.95; duration: 120 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 120 }
        }
        PauseAnimation { duration: 300 }
        ScriptAction { script: { st.bananaOut = false; st.bananaDone() } }
    }
    function eatBanana(side) {
        oneHand = side
        useHands(600000)
        hangPlace()
        // the free hand at his mouth
        if (side > 0) { handLX = size * 0.28; handLY = -bodyH * 0.14 } else { handRX = -size * 0.28; handRY = -bodyH * 0.14 }
        bananaAnim.restart()
    }

    // ── a snack on the floor: both hands at his mouth, three bites ──
    // snackKind by figure (Creature draws it): bun, dango, onigiri, oil can
    readonly property string snackKind: ({ bao: "bun", mochi: "dango", robo: "oil", momo: "dango", neko: "fish", hiyoko: "seeds", arai: "berries" })[skin] || "onigiri"
    property real snack: 0               // 1 whole … 0 gone
    property bool snackOut: false
    signal snackDone()
    SequentialAnimation {
        id: snackAnim
        ScriptAction { script: { st.useHands(8000); st.snackOut = true; st.snack = 1
                                 st.handLX = st.size * 0.42; st.handRX = -st.size * 0.42
                                 st.handLY = -st.bodyH * 0.12; st.handRY = -st.bodyH * 0.12; st.gazeY = 0.6 } }
        PauseAnimation { duration: 600 }
        SequentialAnimation {
            loops: 3
            ScriptAction { script: { st.snack = Math.max(0, st.snack - 0.34); st.mood = "happy"; st.jolt() } }
            NumberAnimation { target: st; property: "sy"; to: 0.93; duration: 120 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 120 }
            NumberAnimation { target: st; property: "sy"; to: 0.95; duration: 120 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 120 }
            PauseAnimation { duration: 450 }
        }
        ScriptAction { script: { st.snackOut = false; st.handLX = 0; st.handRX = 0; st.handLY = 0; st.handRY = 0; st.gazeY = 0; st.snackDone() } }
    }
    // Hiyoko pecks seeds off the floor in front of her instead
    SequentialAnimation {
        id: peckAnim
        ScriptAction { script: { st.snackOut = true; st.snack = 1; st.gazeY = 0.8 } }
        PauseAnimation { duration: 300 }
        SequentialAnimation {
            loops: 4
            NumberAnimation { target: st; property: "lean"; to: st.peckDir * 24; duration: 110; easing.type: Easing.OutQuad }
            ScriptAction { script: { st.snack = Math.max(0, st.snack - 0.25); st.jolt() } }
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 150; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: 260 }
        }
        ScriptAction { script: { st.snackOut = false; st.gazeY = 0; st.mood = "happy"; st.snackDone() } }
    }
    property real peckDir: 1
    function eatSnack() {
        if (moving) return
        if (snackKind === "seeds") { peckDir = gazeX < 0 ? -1 : 1; peckAnim.restart() }
        else snackAnim.restart()
    }

    // ── Robo's repairs: kneels, taps the frame with a wrench, sparks fly ──
    property bool tooling: false
    property real sparkT: 0              // seconds, for the sparks (Creature)
    signal repaired()
    Timer { interval: 33; repeat: true; running: st.tooling; onTriggered: st.sparkT = (st.sparkT + 0.033) % 60 }
    SequentialAnimation {
        id: repairAnim
        ScriptAction { script: { st.useHands(12000); st.tooling = true; st.gazeY = 0.9 } }
        NumberAnimation { target: st; property: "sy"; to: 0.82; duration: 200 }
        SequentialAnimation {
            loops: 7
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.25; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handRY"; to: st.size * 0.12; duration: 110; easing.type: Easing.InQuad }
            ScriptAction { script: st.jolt() }
            PauseAnimation { duration: 120 }
        }
        NumberAnimation { target: st; property: "sy"; to: 1; duration: 220; easing.type: Easing.OutBack }
        ScriptAction { script: { st.tooling = false; st.handRY = 0; st.gazeY = 0; st.repaired() } }
    }
    function repair() { if (!moving) repairAnim.restart() }

    // ── more hobbies: juggling, yoga, polishing ───────────────────
    // juggle: three balls in the air over his head (Creature draws them by jugT)
    property bool juggling: false
    property real jugT: 0
    property int jugDrops: 0             // how many he drops at the end (0 or 1)
    // a cascade: each ball flies from one hand to the other, the hands take
    // turns, each catches low and outside and throws high and inside
    readonly property real jugCycle: 1.2      // s for one ball to go round
    Timer {
        interval: 16; repeat: true; running: st.juggling
        onTriggered: {
            st.jugT += 0.016
            const c = st.jugT / st.jugCycle
            // the left hand throws at c = 0, 1/3, 2/3, the right one half a step later
            const ql = (c * 3) % 1, qr = (c * 3 + 0.5) % 1
            st.handLX = st.jugHandX(ql) ; st.handLY = st.jugHandY(ql)
            st.handRX = -st.jugHandX(qr); st.handRY = st.jugHandY(qr)
        }
    }
    // hand phase q: 0 throws (up, in front of his belly), swings out and down to
    // catch the next ball (q 0.5), back in to throw it. Where the left hand is
    // from his middle (jugX/jugY), and as the offset from where hands rest
    function jugX(q) { return -size * (0.2 + 0.14 * (1 - Math.cos(q * Math.PI * 2))) }
    function jugY(q) { return -size * 0.1 * Math.cos(q * Math.PI * 2) - size * 0.06 }
    function jugHandX(q) { return jugX(q) + size * (0.36 + 0.2 * handsOut) * sx }
    function jugHandY(q) { return jugY(q) }
    signal hobbyDone()
    SequentialAnimation {
        id: juggleAnim
        ScriptAction { script: { st.useHands(9000); st.juggling = true; st.jugT = 0; st.gazeY = -0.8 } }
        PauseAnimation { duration: 6000 }
        ScriptAction { script: { st.juggling = false; st.gazeY = 0; st.handLX = 0; st.handLY = 0; st.handRX = 0; st.handRY = 0; st.hobbyDone() } }
    }
    function juggle() { if (!moving) juggleAnim.restart() }
    // yoga: up on his toes, arms over his head, leaning left and right, a breath
    SequentialAnimation {
        id: yogaAnim
        ScriptAction { script: { st.useHands(9000); st.mood = "sleepy" } }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 0.62; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.62; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.2; duration: 700 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.2; duration: 700 }
            NumberAnimation { target: st; property: "sy"; to: 1.12; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "sx"; to: 0.92; duration: 700; easing.type: Easing.InOutSine }
        }
        NumberAnimation { target: st; property: "lean"; to: 16; duration: 1100; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: st; property: "lean"; to: -16; duration: 1600; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: st; property: "lean"; to: 0; duration: 1100; easing.type: Easing.InOutSine }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 800 }
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 800 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 800 }
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 800 }
        }
        ScriptAction { script: st.hobbyDone() }
    }
    function yoga() { if (!moving) yogaAnim.restart() }
    // polishing his glass: a hand circles over his body, then a sparkle
    property bool shiny: false
    SequentialAnimation {
        id: polishAnim
        ScriptAction { script: { st.useHands(7000); st.gazeY = 0.6 } }
        SequentialAnimation {
            loops: 6
            ParallelAnimation {
                NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.42; duration: 200; easing.type: Easing.InOutSine }
                NumberAnimation { target: st; property: "handRY"; to: -st.bodyH * 0.45; duration: 200; easing.type: Easing.InOutSine }
            }
            ParallelAnimation {
                NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.2; duration: 200; easing.type: Easing.InOutSine }
                NumberAnimation { target: st; property: "handRY"; to: -st.bodyH * 0.2; duration: 200; easing.type: Easing.InOutSine }
            }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 250 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 250 }
        }
        ScriptAction { script: { st.gazeY = 0; st.shiny = true; st.pop("star"); st.hobbyDone() } }
        PauseAnimation { duration: 1400 }
        ScriptAction { script: st.shiny = false }
    }
    function polish() { if (!moving) { towards = 1; polishAnim.restart() } }

    // ── slipping on a peel: the feet go, he lands on his back ─────
    property real slipDir: 1
    property real slipTo: 0
    signal slipped()
    SequentialAnimation {
        id: slipAnim
        ScriptAction { script: { st.useHands(2200); st.handLY = -st.size * 0.4; st.handRY = -st.size * 0.4 } }
        ParallelAnimation {
            NumberAnimation { target: st; property: "rot"; to: -st.slipDir * 95; duration: 180; easing.type: Easing.InQuad }
            SequentialAnimation {
                NumberAnimation { target: st; property: "lift"; to: 18; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: st; property: "lift"; to: 0; duration: 140; easing.type: Easing.InQuad }
            }
            NumberAnimation { target: st; property: "x0"; to: st.slipTo; duration: 250 }
        }
        ScriptAction { script: st.jolt() }
        NumberAnimation { target: st; property: "sy"; to: 0.85; duration: 80 }
        NumberAnimation { target: st; property: "sy"; to: 1; duration: 160 }
        PauseAnimation { duration: 900 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "rot"; to: 0; duration: 380; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 300 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 300 }
        }
        ScriptAction { script: st.slipped() }
    }
    function slip(dir) {
        hopAnim.stop(); rollAnim.stop()
        sx = 1; sy = 1; lean = 0; lift = 0
        slipDir = dir || 1
        slipTo = Math.max(minX, Math.min(maxX, x0 + slipDir * 26))
        mood = "surprised"
        slipAnim.restart()
    }

    // ── reaching out to the side while hanging (a high five up there) ─
    property real reachTheta: 0
    signal reached()
    SequentialAnimation {
        id: reachAnim
        ScriptAction { script: st.scripted = true }
        NumberAnimation { target: st; property: "theta"; to: st.reachTheta; duration: 480; easing.type: Easing.InOutSine }
        ScriptAction { script: st.reached() }
        PauseAnimation { duration: 160 }
        // let go of the swing: the pendulum carries him back
        ScriptAction { script: { st.omega = 0; st.scripted = false } }
    }
    // dir: where the other one hangs; he holds on with the far hand and
    // reaches with the near one
    function reachTo(dir) {
        oneHand = -dir
        useHands(600000)
        hangPlace()
        if (dir > 0) { handRX = size * 0.3; handRY = -hangLen + bodyH * 0.5 } else { handLX = -size * 0.3; handLY = -hangLen + bodyH * 0.5 }
        reachTheta = dir * 0.6
        reachAnim.restart()
    }
    // a short call next to him, for a moment ("uh uh ah ah!")
    property string shout: ""
    Timer { id: shoutTimer; interval: 1800; onTriggered: st.shout = "" }
    // long enough to read: short calls a moment, sentences longer
    function call(text) { shout = text; shoutTimer.interval = Math.min(7000, 1500 + text.length * 70); shoutTimer.restart() }

    // in the frame: a small hand comes out of the dome towards a neighbour
    property real dockPokeDir: 0
    property real dockPoke: 0
    SequentialAnimation {
        id: dockPokeAnim
        NumberAnimation { target: st; property: "dockPoke"; to: 1; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 }
        NumberAnimation { target: st; property: "dockPoke"; to: 0.55; duration: 110 }
        NumberAnimation { target: st; property: "dockPoke"; to: 1; duration: 110 }
        PauseAnimation { duration: 160 }
        NumberAnimation { target: st; property: "dockPoke"; to: 0; duration: 220; easing.type: Easing.InQuad }
    }
    function pokeFromDock(dir) { dockPokeDir = dir; dockPokeAnim.restart() }
    SequentialAnimation {
        id: beatHandAnim
        NumberAnimation { target: st; property: "dockPoke"; to: 0.75; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "dockPoke"; to: 0; duration: 170; easing.type: Easing.InQuad }
    }

    // ── dance moves ───────────────────────────────────────────────
    // what he likes to dance: weights per move, by figure
    // (the tempo decides which moves fit at all, see Brain.danceStep; these
    // weigh them, a move missing here counts 1)
    readonly property var danceStyle: ({
        kuro:  { hop: 2, arms: 3, sway: 3, spin: 1, twist: 3, bang: 2 },
        shiro: { hop: 4, arms: 2, sway: 1, spin: 2, clap: 3, step: 3 },
        mochi: { hop: 1, arms: 1, sway: 4, spin: 1, twist: 2, bounce: 3 },
        momo:  { hop: 4, arms: 2, sway: 1, spin: 3, step: 2, clap: 2 },
        robo:  { robot: 6, arms: 2, spin: 1, bang: 3, clap: 1, sway: 0.3, twist: 0.3 },
        bao:   { sway: 4, arms: 2, hop: 1, bounce: 4, clap: 2 }
    })[skin] || ({ hop: 1, arms: 1, sway: 1 })
    // one hand (side -1 / 1) or both (0) thrown up, then down again
    property int armSide: 1
    property real armHeight: 0
    SequentialAnimation {
        id: armAnim
        ScriptAction { script: st.useHands(900) }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLY"; to: st.armSide <= 0 ? -st.armHeight : 0; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handRY"; to: st.armSide >= 0 ? -st.armHeight : 0; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handLX"; to: st.armSide <= 0 ? -3 : 0; duration: 110 }
            NumberAnimation { target: st; property: "handRX"; to: st.armSide >= 0 ? 3 : 0; duration: 110 }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 200; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 200; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 200 }
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 200 }
        }
    }
    function armUp(side, strength) {
        armSide = side
        armHeight = size * (0.45 + 0.35 * strength)
        armAnim.restart()
    }
    // a little squash to the beat, feet on the floor
    SequentialAnimation {
        id: bobAnim
        NumberAnimation { target: st; property: "sy"; to: 0.9; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "sy"; to: 1; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }
    function bob() { if (!moving) bobAnim.restart() }
    // leaning to one side with both hands out
    SequentialAnimation {
        id: swayAnim
        ScriptAction { script: st.useHands(900) }
        NumberAnimation { target: st; property: "lean"; to: st.swayTo; duration: 180; easing.type: Easing.InOutSine }
    }
    property real swayTo: 0
    function sway(side) { swayTo = side * 9; swayAnim.restart() }
    // a full turn on the spot
    NumberAnimation { id: spinAnim; target: st; property: "rot"; duration: 420; easing.type: Easing.InOutQuad }
    function spin(side) {
        if (moving || spinAnim.running) return
        spinAnim.to = rot + side * 360
        spinAnim.restart()
        useHands(500)
    }
    // stiff and square: one hand out sideways, the head turned the other way
    SequentialAnimation {
        id: robotAnim
        ScriptAction { script: st.useHands(900) }
        ParallelAnimation {
            NumberAnimation { target: st; property: st.armSide > 0 ? "handRX" : "handLX"; to: st.armSide * st.size * 0.3; duration: 60 }
            NumberAnimation { target: st; property: st.armSide > 0 ? "handRY" : "handLY"; to: -st.size * 0.2; duration: 60 }
            NumberAnimation { target: st; property: "gazeX"; to: -st.armSide; duration: 60 }
            NumberAnimation { target: st; property: "lean"; to: st.armSide * 4; duration: 60 }
        }
        PauseAnimation { duration: 140 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 60 }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 60 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 60 }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 60 }
        }
    }
    function robotStep(side) { armSide = side; robotAnim.restart() }
    // claps: both hands meet in front of him
    SequentialAnimation {
        id: clapAnim
        ScriptAction { script: st.useHands(900) }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.34; duration: 70; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.34; duration: 70; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 0.14; duration: 70 }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.14; duration: 70 }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 200 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 200 }
        }
    }
    function clap() { clapAnim.restart() }
    // a twist: leans and turns a little, the hands the other way
    property real twistTo: 0
    ParallelAnimation {
        id: twistAnim
        ScriptAction { script: st.useHands(900) }
        NumberAnimation { target: st; property: "lean"; to: st.twistTo * 8; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "rot"; to: st.twistTo * 6; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "handLX"; to: -st.twistTo * st.size * 0.12; duration: 120 }
        NumberAnimation { target: st; property: "handRX"; to: -st.twistTo * st.size * 0.12; duration: 120 }
    }
    function twist(side) { if (moving) return; twistTo = side; twistAnim.restart() }
    // a step to the side and back on the next beat
    function stepSide(side) {
        if (moving) return
        hopTarget = Math.max(minX, Math.min(maxX, x0 + side * 11))
        hopHeight = 4
        hopDur = 170
        gazeX = side * 0.4
        hopAnim.start()
    }
    // fast music: a nod, the whole body squashed for an instant
    SequentialAnimation {
        id: bangAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 0.86; duration: 55; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sx"; to: 1.08; duration: 55; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "gazeY"; to: 0.9; duration: 55 }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2 }
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 150 }
            NumberAnimation { target: st; property: "gazeY"; to: 0; duration: 150 }
        }
    }
    function bang() { if (!moving) bangAnim.restart() }
    // a big jump with both arms up
    function bigJump(strength) {
        if (moving) return
        armUp(0, 1)
        hop(x0, 26 + strength * 18)
    }
    // boxing: a fast punch to the side he looks, the other fist up as guard
    property int punchSide: 1
    SequentialAnimation {
        id: punchAnim
        ScriptAction { script: st.useHands(900) }
        ParallelAnimation {
            NumberAnimation { target: st; property: st.punchSide > 0 ? "handRX" : "handLX"; to: st.punchSide * st.size * 0.5; duration: 60; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: st.punchSide > 0 ? "handRY" : "handLY"; to: -st.size * 0.22; duration: 60 }
            NumberAnimation { target: st; property: st.punchSide > 0 ? "handLY" : "handRY"; to: -st.size * 0.34; duration: 60 }
            NumberAnimation { target: st; property: st.punchSide > 0 ? "handLX" : "handRX"; to: st.punchSide * st.size * 0.12; duration: 60 }
            NumberAnimation { target: st; property: "lean"; to: st.punchSide * 6; duration: 60 }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 160 }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 160 }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.12; duration: 160 }
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 0.12; duration: 160 }
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 160 }
        }
    }
    function punch(side) { punchSide = side; gazeX = side; punchAnim.restart() }
    // down into the knees, then up again
    SequentialAnimation {
        id: squatAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 0.74; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sx"; to: 1.16; duration: 90; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 220; easing.type: Easing.OutBack }
        }
    }
    function squat() { if (!moving) { squatAnim.restart(); useHands(600); handLY = st.size * 0.05; handRY = st.size * 0.05 } }
    // moonwalk: glides backwards without lifting off, leaning
    NumberAnimation { id: slideAnim; target: st; property: "x0"; duration: 260; easing.type: Easing.InOutSine }
    function slide(side) {
        if (moving) return
        slideAnim.to = Math.max(minX, Math.min(maxX, x0 + side * 16))
        lean = -side * 5
        gazeX = -side
        slideAnim.restart()
    }
    // bouncing on the spot, a hand up now and then
    function bounce(strength, side) { bob(); if (strength > 0.5) armUp(side, strength * 0.5) }
    function danceRest() {
        swayAnim.stop(); twistAnim.stop()
        lean = 0
        if (!moving) rot = 0
    }

    // ── dancing in the frame ──────────────────────────────────────
    // Two hands of their own and a face that moves: positions in his size,
    // along the edge (x) and out of the frame (y, negative is outwards),
    // drawn by DockBlob.qml. At rest they sit at the dome's foot.
    readonly property real dRestX: 0.62
    readonly property real dRestY: -0.22
    property real dLX: -dRestX
    property real dLY: dRestY
    property real dRX: dRestX
    property real dRY: dRestY
    property real dockHands: 0           // 0 hidden in the dome, 1 out
    property real faceLift: 0            // px outwards
    property real faceTilt: 0            // degrees
    property real faceSpin: 0
    NumberAnimation { id: dHandsIn; target: st; property: "dockHands"; to: 1; duration: 120; easing.type: Easing.OutBack }
    NumberAnimation { id: dHandsOut; target: st; property: "dockHands"; to: 0; duration: 260; easing.type: Easing.InQuad }
    Timer { id: dHandsTimer; interval: 1100; onTriggered: { dHandsIn.stop(); dHandsOut.start(); st.faceTilt = 0 } }
    function dockHandsOut() {
        dHandsOut.stop()
        if (dockHands < 1 && !dHandsIn.running) dHandsIn.start()
        dHandsTimer.restart()
    }
    // where the hands go for a move, and back to rest after it
    property var dTo: [0, 0, 0, 0]
    property int dIn: 80
    property int dBack: 180
    SequentialAnimation {
        id: dMoveAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "dLX"; to: st.dTo[0]; duration: st.dIn; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "dLY"; to: st.dTo[1]; duration: st.dIn; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "dRX"; to: st.dTo[2]; duration: st.dIn; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "dRY"; to: st.dTo[3]; duration: st.dIn; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "dLX"; to: -st.dRestX; duration: st.dBack; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "dLY"; to: st.dRestY; duration: st.dBack; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "dRX"; to: st.dRestX; duration: st.dBack; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "dRY"; to: st.dRestY; duration: st.dBack; easing.type: Easing.InOutSine }
        }
    }
    function dHands(lx, ly, rx, ry, tin, tback) {
        dockHandsOut()
        dTo = [lx, ly, rx, ry]
        dIn = tin || 80; dBack = tback || 180
        dMoveAnim.restart()
    }
    SequentialAnimation {
        id: peekAnim
        NumberAnimation { target: st; property: "faceLift"; to: st.size * 0.28; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "faceLift"; to: 0; duration: 240; easing.type: Easing.OutBounce }
    }
    NumberAnimation { id: tiltAnim; target: st; property: "faceTilt"; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { id: faceSpinAnim; target: st; property: "faceSpin"; from: 0; to: 360; duration: 420; easing.type: Easing.InOutQuad }
    // one move on one beat; `side` alternates
    function dockMove(move, strength, side, beat) {
        pulse = 0.5 + strength * 0.5; pulseAnim.restart()
        switch (move) {
        case "up":      // both hands thrown up out of the dome
            dHands(-0.38, -0.95 - strength * 0.25, 0.38, -0.95 - strength * 0.25, 90, 200); break
        case "box":     // a quick punch to one side, the other hand on guard
            if (side > 0) dHands(-0.5, -0.5, 1.15, -0.32, 60, 150)
            else dHands(-1.15, -0.32, 0.5, -0.5, 60, 150)
            break
        case "clap":    // hands meet above his head
            dHands(-0.06, -0.8, 0.06, -0.8, 85, 170); break
        case "wave":    // both hands up, swaying with the beat
            dHands(-0.38 + side * 0.25, -0.9, 0.38 + side * 0.25, -0.9, 120, 220)
            tiltAnim.to = side * 10; tiltAnim.restart(); break
        case "peek":    // the face hops out of the dome
            peekAnim.restart(); if (beat % 2) dHands(-0.7, -0.55, 0.7, -0.55, 90, 200); break
        case "spin":
            if (beat % 4 === 0) faceSpinAnim.restart()
            else peekAnim.restart()
            break
        case "tilt":
            tiltAnim.to = side * 16; tiltAnim.restart()
            dHands(side < 0 ? -0.9 : -0.55, side < 0 ? -0.6 : -0.3, side > 0 ? 0.9 : 0.55, side > 0 ? -0.6 : -0.3, 100, 200)
            break
        default:        // bob: the face nods out a little
            faceLift = st.size * 0.1; peekAnim.restart()
        }
    }

    function beatStep(strength, side) {
        if (place === "dock") {
            pulse = 0.6 + strength * 0.4; pulseAnim.restart()
            // a hand pops out of the dome, left and right in turns
            if (!dockPokeAnim.running) { dockPokeDir = side; beatHandAnim.restart() }
            return
        }
        if (moving) return
        hopTarget = Math.max(minX, Math.min(maxX, x0 + side * 6))
        hopHeight = 6 + strength * 16
        hopDur = 150 + hopHeight * 3
        gazeX = side * 0.5
        hopAnim.start()
    }
    function jump(height) {
        if (moving) return false
        return hop(x0, height || 30)
    }

    // ── breath: a gesture every 12–24 s, not a loop ───────────────
    SequentialAnimation {
        id: breathAnim
        PropertyAction { target: st; property: "gazeY"; value: -0.5 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 1.035; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "sx"; to: 0.985; duration: 520; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 700; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 700; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "gazeY"; to: 0; duration: 500 }
        }
    }
    Timer {
        interval: 12000 + Math.random() * 12000
        // not in the frame: the dome does not show it, and every gesture costs
        // a few hundred frames at 165 Hz
        running: st.active && !st.sleeping && st.mood !== "happy" && st.place !== "dock"
        repeat: true
        onTriggered: { interval = 12000 + Math.random() * 12000; if (!st.moving) breathAnim.start() }
    }

    // ── blink ─────────────────────────────────────────────────────
    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: st; property: "lid"; to: 0; duration: 60 }
        NumberAnimation { target: st; property: "lid"; to: 1; duration: 90 }
    }
    Timer {
        interval: 4000
        running: st.active && !st.sleeping
        repeat: true
        onTriggered: {
            interval = (st.place === "dock" ? 5000 : 2500) + Math.random() * 4000
            blinkAnim.start()
            // now and then a double blink
            if (Math.random() < 0.15) Qt.callLater(() => blinkAnim.start())
        }
    }

    // ── sleeping: ten steps a second ──────────────────────────────
    Timer {
        interval: 200
        running: st.active && st.sleeping && st.world.sleepAnim
        repeat: true
        onTriggered: {
            st.zPhase = (st.zPhase + 0.056) % 1
            st.breath = Math.sin(st.zPhase * Math.PI * 2)
        }
    }
    onSleepingChanged: { breath = 0; if (sleeping) { lid = 0 } else { lid = 1 } }

    // ── going below the floor and coming up again ─────────────────
    property real placeTo: 0
    property string placeAfter: "home"
    function dive(then) {
        placeAfter = then
        placeTo = 1
        if (then === "dock" && dockSide === "bar") {
            // into the bar: up its edge as a drop, in at his place
            barSide = world.barEdge === "left" ? -1 : 1
            barEdgeX = barSide < 0 ? insets.left : world.areaW - insets.right
            meltX = barEdgeX - barSide * size * 0.45
            barTopY = barDockY
            barSlideMs = Math.max(350, Math.min(1400, (world.floorY - size * 0.6 - barTopY) * 1.6))
            barInAnim.start()
        }
        else if (then === "dock") {
            const side = 0
            squashSide = side
            meltX = side < 0 ? insets.left + size * 0.45 : side > 0 ? world.areaW - insets.right - size * 0.45 : x0
            meltAnim.start()
        }
        else placeAnim.start()
    }
    property real squashSide: 0          // -1 / 1: squashes towards his left / right side
    property real meltX: x0
    // into the frame he does not sink but melts: spreads into a puddle, runs
    // into the frame while the dome grows there, and only then (riseInDock)
    // do his eyes come up in it
    property bool melting: false         // the dome is wanted already (shell.frameBody)
    SequentialAnimation {
        id: meltAnim
        // on the floor: spreads into a puddle; at a bar: presses against its
        // side, a little up towards where his dome comes out
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: st.squashSide !== 0 ? 1.12 : 0.55; duration: 380; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sx"; to: st.squashSide !== 0 ? 0.7 : 1.35; duration: 380; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sink"; to: st.squashSide !== 0 ? 0 : 0.12; duration: 380; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "x0"; to: st.meltX; duration: 380; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "lift"; to: st.squashSide !== 0 ? st.size * 0.35 : 0; duration: 380; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: st.melting = true }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: st.squashSide !== 0 ? 1.3 : 0.1; duration: 420; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "sx"; to: st.squashSide !== 0 ? 0.08 : 1.85; duration: 420; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "sink"; to: st.squashSide !== 0 ? 0 : 0.4; duration: 420; easing.type: Easing.InQuad }
        }
        ScriptAction { script: {
            st.sink = 1; st.sx = 1; st.sy = 1; st.lift = 0; st.squashSide = 0
            st.x0 = Math.max(st.minX, Math.min(st.maxX, st.x0)); st.restX = st.x0
            st.place = st.placeAfter; st.placeDone()
        } }
        onStopped: { st.squashSide = 0; if (st.place !== "dock") st.melting = false }
    }
    // the bar: pressed against its side at the bottom he becomes a drop, turns
    // his feet onto its edge (as when climbing a wall), runs up it wobbling to
    // where his dome comes out and melts flat into it there. Out again the
    // same way down.
    property real barSide: -1            // the bar on the left (-1) or right (1)
    property real barEdgeX: 0
    property real barTopY: 0             // where his dome sits (barDockY when it started)
    property real barSlideMs: 600
    SequentialAnimation {
        id: barInAnim
        // to its foot, gathering
        ParallelAnimation {
            NumberAnimation { target: st; property: "x0"; to: st.meltX; duration: 280; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "sx"; to: 0.82; duration: 280 }
            NumberAnimation { target: st; property: "sy"; to: 1.12; duration: 280 }
        }
        ScriptAction { script: { st.y0 = st.world.floorY; st.surfaceRot = 0; st.place = "sky" } }
        // onto the edge, feet against it, stretched into a drop
        ParallelAnimation {
            NumberAnimation { target: st; property: "surfaceRot"; to: st.barSide < 0 ? 90 : -90; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "x0"; to: st.barEdgeX; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "y0"; to: st.world.floorY - st.size * 0.6; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "sx"; to: 1.25; duration: 260 }
            NumberAnimation { target: st; property: "sy"; to: 0.76; duration: 260 }
        }
        // up, looking where he goes (up the edge is his own -x on the left side)
        ScriptAction { script: st.gazeX = st.barSide < 0 ? -0.8 : 0.8 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "y0"; to: st.barTopY; duration: st.barSlideMs; easing.type: Easing.InOutSine }
            SequentialAnimation {
                loops: 3
                NumberAnimation { target: st; property: "sx"; to: 1.4; duration: st.barSlideMs / 6; easing.type: Easing.InOutSine }
                NumberAnimation { target: st; property: "sx"; to: 1.18; duration: st.barSlideMs / 6; easing.type: Easing.InOutSine }
            }
        }
        // there: the dome is wanted, he flattens into the bar
        ScriptAction { script: { st.melting = true; st.gazeX = 0 } }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 0.08; duration: 380; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "sx"; to: 1.55; duration: 380; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: {
            st.sink = 1; st.sx = 1; st.sy = 1; st.lift = 0; st.surfaceRot = 0
            st.x0 = Math.max(st.minX, Math.min(st.maxX, st.meltX)); st.restX = st.x0
            st.y0 = st.world.floorY
            st.place = st.placeAfter; st.placeDone()
        } }
        onStopped: if (st.place === "sky" && !st.hanging) { st.surfaceRot = 0; st.sx = 1; st.sy = 1 }
    }
    SequentialAnimation {
        id: barOutAnim
        NumberAnimation { target: st; property: "dockRise"; to: 1.15; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "dockRise"; to: 0; duration: 200; easing.type: Easing.InQuad }
        // a drop comes out of the bar where the dome was
        ScriptAction { script: {
            st.sink = 0; st.sx = 1.55; st.sy = 0.08
            st.x0 = st.barEdgeX; st.y0 = st.barTopY
            st.surfaceRot = st.barSide < 0 ? 90 : -90
            st.place = "sky"
            st.gazeX = st.barSide < 0 ? 0.8 : -0.8
        } }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 0.76; duration: 300; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "sx"; to: 1.25; duration: 300 }
        }
        // down the edge
        ParallelAnimation {
            NumberAnimation { target: st; property: "y0"; to: st.world.floorY - st.size * 0.6; duration: st.barSlideMs; easing.type: Easing.InQuad }
            SequentialAnimation {
                loops: 3
                NumberAnimation { target: st; property: "sx"; to: 1.4; duration: st.barSlideMs / 6; easing.type: Easing.InOutSine }
                NumberAnimation { target: st; property: "sx"; to: 1.18; duration: st.barSlideMs / 6; easing.type: Easing.InOutSine }
            }
        }
        // off the edge onto the floor, round again
        ParallelAnimation {
            NumberAnimation { target: st; property: "surfaceRot"; to: 0; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "x0"; to: st.meltX; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "y0"; to: st.world.floorY; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 280; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 280; easing.type: Easing.OutBack }
        }
        ScriptAction { script: {
            st.gazeX = 0; st.surfaceRot = 0; st.restX = st.x0
            st.place = st.undockTo; st.placeDone()
        } }
        onStopped: if (st.place === "sky" && !st.hanging) { st.surfaceRot = 0; st.sx = 1; st.sy = 1 }
    }

    // the dome stays wanted until his own rise takes over
    onDockRiseChanged: if (dockRise > 0.05) melting = false
    function surface() {
        placeTo = 0
        placeAnim.start()
    }
    // a dive (into or out of a place) still under way is called off: he
    // stays where he is, fully there (else it would move him at its end)
    function stopPlace() { if (placeAnim.running) { placeAnim.stop(); sink = 0; sx = 1; sy = 1 } }
    SequentialAnimation {
        id: placeAnim
        ScriptAction { script: { if (st.placeTo === 1) { st.sx = 0.86; st.sy = 1.16 } } }
        NumberAnimation {
            target: st; property: "sink"; to: st.placeTo
            duration: st.placeTo === 1 ? 260 : 520
            easing.type: st.placeTo === 1 ? Easing.InBack : Easing.OutBack
            easing.overshoot: 1.6
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sx"; to: st.placeTo === 1 ? 1 : 1.14; duration: 80 }
            NumberAnimation { target: st; property: "sy"; to: st.placeTo === 1 ? 1 : 0.88; duration: 80 }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
        }
        onFinished: {
            if (st.placeTo === 1) st.place = st.placeAfter
            st.placeDone()
        }
    }

    // ── the frame: melted into it, only a dome with eyes shows ─────
    // in:  dive("dock"), then the dome rises (riseInDock)
    // out: the dome sinks, he comes up as himself wherever `then` is
    property real dockRise: 0
    property string dockSide: "frame"    // frame: bottom edge; bar: the side of the bar; far: the side across from it; top
    property string undockTo: "home"
    // leaving the frame by any way: the dome is gone, so the next dive grows it anew
    onPlaceChanged: {
        // hands that held the frame let go once he is off it
        if (place !== "sky" && !hanging && (gripKL > 0 || gripKR > 0)) { gripLAnim.stop(); gripRAnim.stop(); gripKL = 0; gripKR = 0 }
        if (place !== "dock") { shiftTo = 0; barYAt = -1; dockRise = 0; if (!meltAnim.running) melting = false; shiftAnim.stop(); dockShift = 0 }
    }
    signal dockDone()
    // pushed along by a popout that folds out of the bar (dashboard ...): he
    // slides with it, slow at first, then fast, and bumps a little at the end
    // where his dome sits on the bar's edge (screen y): above the corner, so its
    // lower curve stays clear of the frame's rounding; the next figure above him
    // his place among those at the bar (not his number among all figures)
    readonly property int barRank: world.cast.filter(o => o.active && o !== st && o.place === "dock"
                                                         && o.dockSide === "bar" && o.barYAt <= 0 && o.slot < slot).length
    // put there by hand (screen y), else by rank
    property real barYAt: -1
    readonly property real barStep: size * 1.95 + 8
    readonly property real barDockY: {
        if (barYAt > 0) return barYAt
        // places from the corner up, leaving out those put there by hand
        const hand = world.cast.filter(o => o.active && o !== st && o.place === "dock" && o.dockSide === "bar" && o.barYAt > 0)
                               .map(o => o.barYAt)
        const base = world.floorY - size * 1.1
        let n = 0
        for (let k = 0; k < 20; k++) {
            const y = base - k * barStep
            if (hand.some(h => Math.abs(h - y) < barStep)) continue
            if (n++ === barRank) return y
        }
        return base
    }
    property real dockShift: 0           // px from the bar's edge outwards
    property real shiftTo: 0
    readonly property bool shifting: shiftAnim.running
    SequentialAnimation {
        id: shiftAnim
        // quick, to keep up with the popout as it folds out (DMS moves his
        // dome with it; his face follows)
        // out: DMS tells before the popout shows (its surface maps a little
        // later), so he waits for it; back in: it is already folding away
        PauseAnimation { duration: st.shiftTo > st.dockShift && st.dockShift < 1 ? 160 : 0 }
        NumberAnimation { target: st; property: "dockShift"; to: st.shiftTo; duration: st.shiftTo < st.dockShift ? 130 : 200; easing.type: Easing.OutCubic }
    }
    // where DMS shows his dome while a popout covers his place (screen px)
    property real cornerX: 0
    property real cornerY: 0
    property bool cornerMode: false      // on the corner (else at the popout's edge)
    property real shiftMax: 0            // how far the last push went
    function shiftDock(to) {
        if (to > 0) shiftMax = to
        if (Math.abs(to - dockShift) < 1) return
        shiftTo = to
        shiftAnim.restart()
    }
    // the same on the floor: shoved sideways, accelerating
    property real shoveTo: 0
    SequentialAnimation {
        id: shoveAnim
        NumberAnimation { target: st; property: "x0"; to: st.shoveTo; duration: 380; easing.type: Easing.InQuad }
        NumberAnimation { target: st; property: "sx"; to: 0.86; duration: 70 }
        NumberAnimation { target: st; property: "sx"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        ScriptAction { script: st.restX = st.x0 }
    }
    function shove(to) {
        shoveTo = Math.max(minX, Math.min(maxX, to))
        shoveAnim.restart()
    }
    readonly property bool undocking: undockAnim.running || barOutAnim.running
    function riseInDock() { undockAnim.stop(); riseAnim.start() }
    function stopDockAnims() { riseAnim.stop(); undockAnim.stop(); barOutAnim.stop() }
    function undock(then) {
        if (place !== "dock") return
        undockTo = then
        riseAnim.stop()
        if (dockSide === "bar") {
            // out of the bar as a drop, down its edge
            barSide = world.barEdge === "left" ? -1 : 1
            barEdgeX = barSide < 0 ? insets.left : world.areaW - insets.right
            meltX = barEdgeX - barSide * size * 0.6
            barTopY = barDockY
            barSlideMs = Math.max(350, Math.min(1200, (world.floorY - size * 0.6 - barTopY) * 1.3))
            barOutAnim.start()
            return
        }
        undockAnim.start()
    }
    SequentialAnimation {
        id: riseAnim
        NumberAnimation { target: st; property: "dockRise"; to: 1.12; duration: 340; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "dockRise"; to: 0.94; duration: 160; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "dockRise"; to: 1; duration: 200; easing.type: Easing.OutQuad }
        onFinished: st.dockDone()
    }
    SequentialAnimation {
        id: undockAnim
        NumberAnimation { target: st; property: "dockRise"; to: 1.15; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "dockRise"; to: 0; duration: 200; easing.type: Easing.InQuad }
        ScriptAction { script: { st.sink = 1; st.place = st.undockTo; st.surface() } }
    }

    // ── waving: the right hand goes up and swings ─────────────────
    // a poke with the hand on that side (dir -1 left, 1 right)
    property real pokeDir: 1
    SequentialAnimation {
        id: pokeAnim
        ScriptAction { script: st.useHands(1200) }
        PauseAnimation { duration: 140 }
        NumberAnimation { target: st; property: st.pokeDir > 0 ? "handRX" : "handLX"; to: st.pokeDir * 14; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: st.pokeDir > 0 ? "handRX" : "handLX"; to: 0; duration: 140 }
        NumberAnimation { target: st; property: st.pokeDir > 0 ? "handRX" : "handLX"; to: st.pokeDir * 14; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: st.pokeDir > 0 ? "handRX" : "handLX"; to: 0; duration: 180 }
    }
    function poke(dir) { pokeDir = dir; pokeAnim.restart() }
    // bumped from above while melted into the frame: the dome jolts
    function jolt() { pulse = 1; pulseAnim.restart() }
    function wave() { useHands(); if (!waveAnim.running) waveAnim.start() }
    SequentialAnimation {
        id: waveAnim
        NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.42; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "handRX"; to: 6; duration: 130; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "handRX"; to: -3; duration: 150; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "handRX"; to: 6; duration: 150; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "handRX"; to: -3; duration: 150; easing.type: Easing.InOutSine }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 220 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 260; easing.type: Easing.OutBack }
        }
    }
    // furious: a fist raised beside the head, shaking at whoever it was
    property int fistSide: 1
    SequentialAnimation {
        id: fistAnim
        ScriptAction { script: st.useHands(1500) }
        NumberAnimation { target: st; property: st.fistSide > 0 ? "handRY" : "handLY"; to: -st.size * 0.52; duration: 140; easing.type: Easing.OutQuad }
        SequentialAnimation {
            loops: 5
            NumberAnimation { target: st; property: st.fistSide > 0 ? "handRX" : "handLX"; to: st.fistSide * 6; duration: 65; easing.type: Easing.InOutSine }
            NumberAnimation { target: st; property: st.fistSide > 0 ? "handRX" : "handLX"; to: -st.fistSide * 1; duration: 65; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: st.fistSide > 0 ? "handRX" : "handLX"; to: 0; duration: 200 }
            NumberAnimation { target: st; property: st.fistSide > 0 ? "handRY" : "handLY"; to: 0; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 240 }
        }
    }
    function shakeFist(side) {
        if ((place !== "home" && place !== "stage") || held || flying || sleeping) return
        fistSide = side || (gazeX < 0 ? -1 : 1)
        lean = fistSide * 3
        fistAnim.restart()
    }
    // and again now and then, as long as he stays furious
    Timer {
        interval: 2600; repeat: true
        running: st.mood === "angry" && st.level >= 3 && st.active
        onTriggered: if (!st.moving) st.shakeFist()
    }
    // ── together: a kiss, a hug, a high five ──────────────────────
    // `towards` is the side the other one stands on; `popT` lifts a heart
    // or a star from between the two (drawn in Creature.qml)
    property int towards: 1
    property real popT: 0
    property string popKind: ""
    property bool kissing: false
    NumberAnimation {
        id: popAnim; target: st; property: "popT"; from: 0; to: 1; duration: 1400; easing.type: Easing.OutQuad
        onFinished: st.popKind = ""
    }
    function pop(kind) { popKind = kind; popAnim.restart() }
    SequentialAnimation {
        id: kissAnim
        ScriptAction { script: st.kissing = true }
        NumberAnimation { target: st; property: "lean"; to: st.towards * 15; duration: 280; easing.type: Easing.OutQuad }
        ScriptAction { script: st.pop("heart") }
        PauseAnimation { duration: 420 }
        NumberAnimation { target: st; property: "lean"; to: 0; duration: 340; easing.type: Easing.OutBack }
        ScriptAction { script: st.kissing = false }
    }
    function kiss(side) {
        if (moving) return false
        towards = side
        gazeX = side
        kissAnim.restart()
        return true
    }
    // both hands round the other one, a little sway, and let go
    SequentialAnimation {
        id: hugAnim
        ScriptAction { script: st.useHands(2000) }
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: st.towards * 7; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: st.towards > 0 ? "handRX" : "handLX"; to: st.towards * st.size * 0.42; duration: 260 }
            NumberAnimation { target: st; property: st.towards > 0 ? "handLX" : "handRX"; to: st.towards * st.size * 0.62; duration: 300 }
            NumberAnimation { target: st; property: "handLY"; to: st.size * 0.02; duration: 260 }
            NumberAnimation { target: st; property: "handRY"; to: st.size * 0.02; duration: 260 }
        }
        NumberAnimation { target: st; property: "lean"; to: st.towards * 10; duration: 300; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "lean"; to: st.towards * 6; duration: 300; easing.type: Easing.InOutSine }
        NumberAnimation { target: st; property: "lean"; to: st.towards * 10; duration: 300; easing.type: Easing.InOutSine }
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 300; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 260 }
        }
    }
    function hug(side) {
        if (moving) return false
        towards = side
        gazeX = side
        hugAnim.restart()
        return true
    }
    // the near hand up and across; the one who started it makes the star
    property bool fiveAnswer: false
    SequentialAnimation {
        id: fiveAnim
        ScriptAction { script: st.useHands(1300) }
        ParallelAnimation {
            NumberAnimation { target: st; property: st.towards > 0 ? "handRY" : "handLY"; to: -st.size * 0.62; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: st.towards > 0 ? "handRX" : "handLX"; to: st.towards * st.size * 0.05; duration: 220 }
            NumberAnimation { target: st; property: "lean"; to: -st.towards * 4; duration: 220 }
        }
        PauseAnimation { duration: 120 }
        ParallelAnimation {
            NumberAnimation { target: st; property: st.towards > 0 ? "handRX" : "handLX"; to: st.towards * st.size * 0.3; duration: 90; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "lean"; to: st.towards * 6; duration: 90 }
        }
        ScriptAction { script: { if (!st.fiveAnswer) st.pop("star"); st.jolt() } }
        PauseAnimation { duration: 160 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 300; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 300; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 300; easing.type: Easing.OutBack }
        }
        ScriptAction { script: st.feel("happy", 3) }
    }
    function highFive(side, answer) {
        if (moving) return false
        towards = side
        gazeX = side
        fiveAnswer = !!answer
        fiveAnim.restart()
        return true
    }

    // thinking: a hand at the chin
    onThinkingChanged: { if (thinking) useHands(); handLX = thinking ? st.size * 0.22 : 0; handLY = thinking ? -st.size * 0.18 : 0 }
    // both hands up, for joy
    function cheer() { useHands(); if (!cheerAnim.running) cheerAnim.start() }
    SequentialAnimation {
        id: cheerAnim
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 0.45; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.45; duration: 150; easing.type: Easing.OutQuad }
        }
        PauseAnimation { duration: 500 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 260; easing.type: Easing.OutBack }
        }
    }

    // ── tickled, held and thrown by the pointer ───────────────────
    // a tickle: he squirms and giggles, with a little hop
    // again and again: he laughs harder and harder, until it is too much
    // and he gets cross (and crosser)
    function tickle() {
        if (moving || tickleAnim.running) return
        if (mood === "angry" || mood === "happy" && level >= 3) feel("angry")
        else feel("happy", 2)
        if (mood === "angry") { useHands(900); jump(8); return }
        useHands(900)
        tickleAnim.start()
    }
    SequentialAnimation {
        id: tickleAnim
        loops: 1
        NumberAnimation { target: st; property: "lean"; to: -9; duration: 60 }
        NumberAnimation { target: st; property: "lean"; to: 9; duration: 90 }
        NumberAnimation { target: st; property: "lean"; to: -7; duration: 90 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: 6; duration: 90 }
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 0.3; duration: 90 }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.3; duration: 90 }
        }
        NumberAnimation { target: st; property: "lean"; to: -4; duration: 90 }
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 140 }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 220; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 220; easing.type: Easing.OutBack }
        }
        ScriptAction { script: st.jump(10) }
    }
    // in the frame: the dome wriggles
    function tickleDome() { jolt(); pokeFromDock(Math.random() < 0.5 ? -1 : 1) }

    // held by the pointer (he hangs from it) and flying after a throw
    property bool held: false
    property bool flying: false
    // everything that moves him stops, he is himself and upright
    function stopAll() {
        for (const a of [hopAnim, rollAnim, driftAnim, glideAnim, pullAnim, placeAnim, meltAnim, barInAnim, barOutAnim, riseAnim, undockAnim,
                         shiftAnim, shoveAnim, bobAnim, swayAnim, spinAnim, robotAnim, tickleAnim, settleAnim, fistAnim, kissAnim, hugAnim, fiveAnim, clapAnim, twistAnim, bangAnim,
                         punchAnim, squatAnim, slideAnim, dMoveAnim, peekAnim, tiltAnim, faceSpinAnim]) a.stop()
        brachAnim.stop(); regripAnim.stop(); regripAgain.stop(); scratchAnim.stop(); shotAnim.stop(); bananaAnim.stop(); slipAnim.stop(); reachAnim.stop()
        snackAnim.stop(); peckAnim.stop(); repairAnim.stop(); snackOut = false; tooling = false
        coverAnim.stop(); wipeAnim.stop(); cheeksAnim.stop()
        juggleAnim.stop(); yogaAnim.stop(); polishAnim.stop(); juggling = false; shiny = false
        bananaOut = false
        hanging = false; pump = 0; omega = 0; oneHand = 0; scripted = false; rope = false; gun = 0
        onBar = false; gripLAnim.stop(); gripRAnim.stop(); gripKL = 0; gripKR = 0
        sink = 0; lift = 0; lean = 0; sx = 1; sy = 1; dockShift = 0; dockRise = 0; tuck = 0
        handLX = 0; handLY = 0; handRX = 0; handRY = 0
        rot = 0; surfaceRot = 0
    }
    // after a flight: turns the shortest way back upright
    NumberAnimation { id: settleAnim; target: st; property: "rot"; to: 0; duration: 260; easing.type: Easing.OutBack }
    function settle() {
        rot = ((rot % 360) + 540) % 360 - 180
        settleAnim.restart()
    }

    // ── the ball in his hands ─────────────────────────────────────
    // hands above his head, holding it (or raised to catch it)
    function handsUp() {
        useHands(100000)
        handLX = size * 0.4; handRX = -size * 0.4
        handLY = -size * 0.85; handRY = -size * 0.85
    }
    function handsDown() {
        handLX = 0; handRX = 0; handLY = 0; handRY = 0
        useHands(300)
    }
    signal ballGrabbed()                 // the hands have it (pick-up)
    signal ballReleased()                // the throw lets go
    // bends down, takes it from the floor and lifts it above his head
    // the hands go to either side of it (dx: the ball from his centre, r its radius)
    property real grabLX: 0
    property real grabRX: 0
    property real grabY: 0
    function pickUp(dx, r) {
        if (grabAnim.running || throwAnim.running) return
        const base = size * 0.56 * 1.12, hand = size * 0.11
        grabLX = dx - r - hand + base
        grabRX = dx + r + hand - base
        // his hands' height above the floor is 0.34 of his body less the offset
        const h = bodyH
        grabY = h * 0.34 - r
        gazeX = Math.max(-1, Math.min(1, dx / 30)); gazeY = 0.9
        grabAnim.start()
    }
    SequentialAnimation {
        id: grabAnim
        ScriptAction { script: st.useHands(100000) }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 0.8; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sx"; to: 1.12; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handLX"; to: st.grabLX - st.size * 0.12; duration: 160 }
            NumberAnimation { target: st; property: "handRX"; to: st.grabRX + st.size * 0.12; duration: 160 }
            NumberAnimation { target: st; property: "handLY"; to: st.grabY; duration: 160 }
            NumberAnimation { target: st; property: "handRY"; to: st.grabY; duration: 160 }
        }
        // the hands close round it
        ParallelAnimation {
            NumberAnimation { target: st; property: "handLX"; to: st.grabLX; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handRX"; to: st.grabRX; duration: 90; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: { st.ballGrabbed(); st.gazeY = -0.6 } }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 1.06; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "sx"; to: 0.96; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.4; duration: 220 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.4; duration: 220 }
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 0.85; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 0.85; duration: 220; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: st; property: "sy"; to: 1; duration: 140 }
            NumberAnimation { target: st; property: "sx"; to: 1; duration: 140 }
        }
        ScriptAction { script: st.gazeY = 0 }
    }
    // aims (a moment), leans back, then forward and lets go
    property real throwDir: 1
    property int aimMs: 400
    function throwBall(dir, aim) {
        throwDir = dir; aimMs = aim
        gazeX = dir * 0.9
        throwAnim.restart()
    }
    SequentialAnimation {
        id: throwAnim
        PauseAnimation { duration: st.aimMs }
        // back
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: -st.throwDir * 14; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.4 - st.throwDir * st.size * 0.25; duration: 200 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.4 - st.throwDir * st.size * 0.25; duration: 200 }
        }
        // and through
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: st.throwDir * 12; duration: 110; easing.type: Easing.InQuad }
            NumberAnimation { target: st; property: "handLX"; to: st.size * 0.4 + st.throwDir * st.size * 0.35; duration: 110 }
            NumberAnimation { target: st; property: "handRX"; to: -st.size * 0.4 + st.throwDir * st.size * 0.35; duration: 110 }
            NumberAnimation { target: st; property: "handLY"; to: -st.size * 1.0; duration: 110 }
            NumberAnimation { target: st; property: "handRY"; to: -st.size * 1.0; duration: 110 }
        }
        ScriptAction { script: st.ballReleased() }
        ParallelAnimation {
            NumberAnimation { target: st; property: "lean"; to: 0; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: st; property: "handLX"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handRX"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handLY"; to: 0; duration: 260 }
            NumberAnimation { target: st; property: "handRY"; to: 0; duration: 260 }
        }
        ScriptAction { script: st.useHands(200) }
    }
    readonly property bool busyWithBall: grabAnim.running || throwAnim.running
    function stopBall() { grabAnim.stop(); throwAnim.stop(); lean = 0; sx = 1; sy = 1; handsDown() }
}

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// The tile pictures for the legend in the chat window and the previews on the
// settings page: every figure in every mood (with its levels) and in a pose
// for each action, pairs as Kuro and Shiro. Drawn on a clear ground and saved
// as PNG under shell/thumbs/ (the DMS plugin links to them), then it quits.
//
//     qs -p shell/thumbs.qml   (from the repository)
//     (THUMBS_ONLY=climb,monkey: only these pictures; THUMBS_SKINS=neko: only these figures)
//
// The poses are set directly (hands, lean, props), not played, so the
// pictures come out the same every time.
ShellRoot {
    id: root
    readonly property string out: Quickshell.shellDir + "/thumbs"
    readonly property var skins: ["kuro", "mochi", "shiro", "momo", "robo", "bao", "neko", "kumo", "tako", "hiyoko", "arai"]
    readonly property var moods: [
        ["neutral", 2], ["happy", 1], ["happy", 2], ["happy", 3], ["angry", 1], ["angry", 2], ["angry", 3],
        ["sad", 1], ["sad", 2], ["sad", 3], ["scared", 1], ["scared", 2], ["scared", 3],
        ["blush", 1], ["blush", 2], ["blush", 3], ["shy", 2], ["surprised", 2], ["sleepy", 2],
        ["smug", 2], ["proud", 2], ["curious", 2], ["strained", 2], ["asleep", 2]
    ]
    readonly property var actions: ["jump", "spin", "wave", "cheer", "box", "squat", "tickle", "dance", "sleep",
        "wake", "dock", "out", "front", "back", "climb", "walk", "roll", "play", "grapple", "monkey", "swing",
        "banana", "juggle", "yoga", "polish", "snack", "repair", "nap"]
    readonly property var pairs: ["frog", "rope", "kiss", "hug", "five", "greet", "duet", "quarrel", "poke", "tag", "hide", "race",
        "rps", "airfive"]

    // the jobs: [kind, skin, name, mood, level]
    property var jobs: []
    property int at: 0
    Component.onCompleted: {
        const j = []
        for (const s of skins) {
            for (const m of moods) j.push(["mood", s, m[0] + (m[0] === "neutral" || ["shy", "surprised", "sleepy", "smug", "proud", "curious", "strained", "asleep"].indexOf(m[0]) >= 0 ? "" : m[1]), m[0], m[1]])
            for (const a of actions) j.push(["action", s, a, "", 2])
        }
        for (const p of pairs) j.push(["pair", "kuro", p, "", 2])
        // THUMBS_ONLY=frog,rope: only these pictures (by name)
        const only = (Quickshell.env("THUMBS_ONLY") || "").split(",").filter(x => x)
        // THUMBS_SKINS=neko,kumo: only these figures (pairs stay Kuro and Shiro)
        const sk = (Quickshell.env("THUMBS_SKINS") || "").split(",").filter(x => x)
        jobs = j.filter(x => (!only.length || only.indexOf(x[2]) >= 0) && (!sk.length || x[0] !== "pair" && sk.indexOf(x[1]) >= 0))
        step.start()
    }

    World {
        id: world
        areaW: 400; areaH: 300
        cast: [a, b]
        glassOpacity: 0.92
    }
    Character { id: a; world: world; slot: 0; skin: "kuro" }
    Character { id: b; world: world; slot: 1; skin: "shiro" }

    PanelWindow {
        id: win
        anchors { left: true; bottom: true }
        implicitWidth: 420; implicitHeight: 420
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "aibou-thumbs"
        mask: Region {}

        Item {
            id: stage
            width: 420; height: 420
            // one figure in the middle, or two side by side; feet near the bottom,
            // room above for jumps, raised arms, hearts and curses (scaled 2×
            // around the bottom middle)
            // cut at the floor like the scene does (the feet stand on y = 380
            // after scaling); whoever sinks in (frame, hiding) goes into a frame strip
            Item {
                width: parent.width
                height: 386
                clip: true
                Item {
                    id: holder
                    width: 420; height: 420
                    scale: 2
                    transformOrigin: Item.Bottom
                    Creature { id: ca; st: a; x: root.frogPose ? 214 : root.ropePose ? 210 - 55 : root.pairJob ? 210 - 34 : 210; y: 400; z: 2 }
                    Creature { id: cb; st: b; visible: root.pairJob; x: root.frogPose ? 222 : root.ropePose ? 210 + 14 : 210 + 34; y: 400; z: 1 }
                    // the skipping rope: from Kuro's right hand under Shiro's feet to the edge
                    Shape {
                        id: ropeShape
                        visible: root.ropePose
                        z: 3
                        preferredRendererType: Shape.CurveRenderer
                        readonly property real hx: ca.x + a.size * 0.56 + a.handRX
                        readonly property real hy: 400 - a.bodyH * 0.34 + a.handRY
                        ShapePath {
                            strokeColor: "#5a1a20"; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            startX: ropeShape.hx; startY: ropeShape.hy
                            PathQuad { x: 290; y: 400 - 22; controlX: 238; controlY: 414 }
                        }
                        ShapePath {
                            strokeColor: "#e8505b"; strokeWidth: 1.3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            startX: ropeShape.hx; startY: ropeShape.hy
                            PathQuad { x: 290; y: 400 - 22; controlX: 238; controlY: 414 }
                        }
                    }
                }
            }
            // what he holds on to: the top edge (monkey) or a wall (climb),
            // in the frame colour; holder scales 2× round the bottom middle
            Rectangle {
                visible: root.barY > 0
                x: 210 - 150; width: 300; height: 10; radius: 5
                y: 420 - (420 - root.barY) * 2 - height
                color: "#3a3a40"
            }
            Rectangle {
                visible: root.wallX > 0
                x: 210 + (root.wallX - 210) * 2; width: 10; radius: 5
                y: 150; height: 386 - 150
                color: "#3a3a40"
            }
            Rectangle {
                visible: root.frameStrip
                x: 40; width: 340; y: 380; height: 10; radius: 5
                color: "#3a3a40"
            }
        }
    }
    property bool pairJob: false
    property bool frogPose: false
    property bool ropePose: false
    property bool frameStrip: false
    property real barY: 0                // the top edge under holder's y (0 none)
    property real wallX: 0               // a wall at holder's x (0 none)

    function reset(st) {
        st.stopAll()
        st.feeling = true; st.mood = "neutral"; st.level = 2; st.feeling = false
        st.sleeping = false; st.thinking = false; st.lid = 1; st.gazeX = 0; st.gazeY = 0
        st.handsOut = 0; st.handLX = 0; st.handLY = 0; st.handRX = 0; st.handRY = 0
        st.lean = 0; st.rot = 0; st.lift = 0; st.sx = 1; st.sy = 1; st.sink = 0; st.tremble = 0
        st.gun = 0; st.rope = false; st.bananaOut = false; st.snackOut = false; st.tooling = false
        st.juggling = false; st.shiny = false; st.popKind = ""; st.kissing = false; st.oneHand = 0
        st.coverEyes = false; st.place = "home"
    }
    function hands(st, lx, ly, rx, ry) {
        st.handsOut = 1
        st.handLX = lx * st.size; st.handLY = ly * st.size; st.handRX = rx * st.size; st.handRY = ry * st.size
    }
    // a hand at (x, y) from his feet, in his sizes (hands out, upright body)
    function handAt(st, side, x, y) {
        st.handsOut = 1
        const hx = x * st.size - side * st.size * 0.56
        const hy = y * st.size + st.bodyH * 0.34 + st.lift * (side < 0 ? 0.82 : 1.12)
        if (side < 0) { st.handLX = hx; st.handLY = hy } else { st.handRX = hx; st.handRY = hy }
    }
    function feel(st, m, l) { st.feeling = true; st.mood = m; st.level = l; st.feeling = false }

    // a pose for each action (one figure)
    function pose(st, name) {
        // the cloud does not climb or swing: for those it floats up
        if (st.skin === "kumo" && ["climb", "monkey", "grapple", "swing"].indexOf(name) >= 0) {
            st.lift = 34; st.gazeY = -1; hands(st, -0.08, -0.25, 0.08, -0.25); feel(st, "happy", 2); return
        }
        if (st.skin === "kumo" && name === "box") { hands(st, 0.1, -0.3, 0.34, -0.2); st.lean = 6; st.gazeX = 1; feel(st, "angry", 2); return }
        switch (name) {
        case "jump": st.lift = 26; st.sx = 0.9; st.sy = 1.12; hands(st, -0.05, -0.5, 0.05, -0.5); feel(st, "happy", 2); break
        case "spin": st.rot = 35; hands(st, -0.1, -0.2, 0.1, 0.1); feel(st, "happy", 2); break
        case "wave": hands(st, 0, 0, 0.1, -0.42); feel(st, "happy", 2); break
        case "cheer": hands(st, 0, -0.45, 0, -0.45); feel(st, "happy", 3); break
        case "box": hands(st, 0.12, -0.34, 0.5, -0.22); st.lean = 6; st.gazeX = 1; feel(st, "angry", 2); break
        case "squat": st.sy = 0.76; st.sx = 1.16; hands(st, 0, 0.05, 0, 0.05); break
        case "tickle": st.lean = 8; hands(st, 0, -0.3, 0, -0.3); feel(st, "happy", 3); break
        case "dance": hands(st, -0.05, -0.55, 0, 0); st.lean = -7; feel(st, "happy", 2); break
        case "sleep": case "nap": st.sleeping = true; st.lid = 0; st.zPhase = 0.3; break
        case "wake": hands(st, 0, -0.45, 0, -0.45); feel(st, "happy", 2); break
        case "dock": st.sink = 0.38; break
        case "out": st.lift = 18; hands(st, -0.05, -0.4, 0.05, -0.4); feel(st, "happy", 2); break
        case "front": hands(st, 0, 0, 0.1, -0.42); st.gazeY = 0.3; feel(st, "happy", 1); break
        case "back": st.gazeX = -1; st.lean = -4; break
        case "climb": {
            // on a wall to his right, feet against it: both hands on the wall
            // above him, the lower one about to reach past the upper one
            st.place = "sky"; st.rot = -90; st.lift = st.size * 0.1
            const w = st.bodyH / 2 / st.size + 0.06, top = (st.bodyH + st.lift) / st.size
            handAt(st, 1, w, -top - 0.62)
            handAt(st, -1, w, -top - 0.12)
            root.wallX = 210 + st.bodyH / 2 + st.size * 0.06 + st.size * 0.11
            feel(st, "happy", 2); break
        }
        case "walk": st.lift = 10; st.gazeX = 1; st.sx = 0.92; st.sy = 1.08; break
        case "roll": st.rot = 140; st.gazeX = 1; break
        case "play": hands(st, -0.1, -0.62, 0.1, -0.62); feel(st, "happy", 2); break
        case "grapple": st.gun = 1; st.gunAim = 18; hands(st, 0, 0, 0.04, -0.45); st.gazeY = -1; feel(st, "curious", 2); break
        case "monkey": {
            // swinging along the top edge: hanging from the left hand, the
            // right one reaches ahead for the next hold
            st.place = "sky"; st.rot = -14
            const g = st.bodyH * 1.12 / st.size
            handAt(st, -1, -0.32, -g)
            handAt(st, 1, 0.62, -g + 0.16)
            root.barY = 400 - g * st.size - st.size * 0.11
            feel(st, "happy", 2); break
        }
        case "swing": hands(st, 0.42, -0.95, -0.42, -0.95); st.rot = 28; feel(st, "happy", 3); break
        case "banana": st.bananaOut = true; st.banana = 0.66; st.peeled = 1; st.oneHand = 1; hands(st, 0.28, -0.14, -0.42, -0.95); feel(st, "happy", 2); break
        case "juggle": st.juggling = true; st.jugT = 0.4; hands(st, 0, -0.18, 0, 0); st.gazeY = -0.8; feel(st, "happy", 2); break
        case "yoga": hands(st, 0.2, -0.62, -0.2, -0.62); st.sy = 1.12; st.sx = 0.92; st.lean = 12; feel(st, "sleepy", 2); break
        case "polish": hands(st, 0, 0, -0.32, -0.38); st.shiny = true; st.popKind = "star"; st.popT = 0.25; st.towards = 1; feel(st, "smug", 2); break
        case "snack":
            // Hiyoko pecks seeds off the floor instead
            if (st.skin === "hiyoko") { st.snackOut = true; st.snack = 0.75; st.peckDir = 1; st.lean = 22; st.gazeY = 0.8; feel(st, "happy", 2); break }
            st.snackOut = true; st.snack = 0.7; hands(st, 0.42, -0.12, -0.42, -0.12); st.gazeY = 0.6; feel(st, "happy", 2); break
        case "repair": st.tooling = true; st.sparkT = 0.3; st.sy = 0.84; hands(st, 0, 0, 0, 0.12); st.gazeY = 0.9; break
        }
    }
    // a pose for each pair action (a: Kuro on the left, b: Shiro on the right)
    function posePair(name) {
        a.gazeX = 1; b.gazeX = -1
        switch (name) {
        case "kiss": a.kissing = true; a.lean = 15; feel(b, "blush", 3); a.popKind = "heart"; a.popT = 0.3; a.towards = 1; break
        case "hug": hands(a, 0, 0.02, 0.42, 0.02); a.lean = 7; hands(b, -0.42, 0.02, 0, 0.02); b.lean = -7; feel(a, "happy", 2); feel(b, "blush", 2); break
        case "five": hands(a, 0, 0, 0.3, -0.62); hands(b, -0.3, -0.62, 0, 0); a.popKind = "star"; a.popT = 0.2; a.towards = 1; feel(a, "happy", 3); feel(b, "happy", 3); break
        case "greet": hands(a, 0, 0, 0.1, -0.42); feel(a, "happy", 2); feel(b, "happy", 2); break
        case "duet": hands(a, 0, 0, 0, -0.55); hands(b, 0, -0.55, 0, 0); a.lean = 6; b.lean = -6; feel(a, "happy", 2); feel(b, "happy", 2); break
        case "quarrel": hands(a, 0.12, -0.34, 0.5, -0.22); feel(a, "angry", 3); feel(b, "angry", 2); break
        case "poke": hands(a, 0, 0, 0.42, -0.1); feel(a, "smug", 2); feel(b, "surprised", 2); break
        case "tag": a.lift = 12; a.gazeX = 1; b.lift = 18; b.gazeX = 1; hands(b, -0.1, -0.4, 0.1, -0.4); feel(a, "happy", 2); feel(b, "scared", 1); break
        case "hide": hands(a, 0.42, -0.38, -0.42, -0.38); a.coverEyes = true; b.sink = 0.38; feel(b, "sleepy", 2); break
        case "race": a.lift = 14; b.lift = 6; a.gazeX = 1; b.gazeX = 1; feel(a, "happy", 3); feel(b, "happy", 2); break
        case "rps": hands(a, 0, 0, 0.2, -0.3); hands(b, -0.2, -0.3, 0, 0); feel(a, "curious", 2); feel(b, "smug", 2); break
        case "frog":
            // Kuro leaps over Shiro crouched as the buck
            a.lift = 44; a.gazeX = 1; a.sx = 0.92; a.sy = 1.1; hands(a, 0.3, -0.5, 0.42, -0.2); feel(a, "happy", 3)
            b.sy = 0.78; b.sx = 1.14; hands(b, 0.08, 0.2, -0.08, 0.2); b.gazeX = -1; b.gazeY = -0.3; feel(b, "happy", 2)
            root.frogPose = true; break
        case "rope":
            // Shiro jumps, the rope under her feet; Kuro turns it
            a.gazeX = 1; hands(a, 0.3, 0.02, 0.06, -0.15); feel(a, "happy", 2)
            b.lift = 16; b.gazeX = 0; feel(b, "happy", 3)
            root.ropePose = true; break
        case "airfive": a.rot = 20; b.rot = -20; hands(a, 0.42, -0.95, 0.3, -0.62); hands(b, -0.3, -0.62, -0.42, -0.95); a.popKind = "star"; a.popT = 0.2; a.towards = 1; feel(a, "happy", 3); feel(b, "happy", 3); break
        }
    }

    Timer {
        id: step
        interval: 160
        onTriggered: {
            if (root.at >= root.jobs.length) { Qt.quit(); return }
            const j = root.jobs[root.at]
            root.reset(a); root.reset(b)
            root.pairJob = j[0] === "pair"
            root.frogPose = false; root.ropePose = false; root.barY = 0; root.wallX = 0
            root.frameStrip = j[2] === "dock" || j[2] === "hide"
            a.skin = j[1]
            if (j[0] === "mood") {
                if (j[3] === "asleep") { a.sleeping = true; a.lid = 0 }
                else root.feel(a, j[3], j[4])
            } else if (j[0] === "action") root.pose(a, j[2])
            else root.posePair(j[2])
            grab.restart()
        }
    }
    Timer {
        id: grab
        interval: 140
        onTriggered: {
            const j = root.jobs[root.at]
            const dir = j[0] === "pair" ? "pair" : j[1]
            const path = root.out + "/" + dir + "/" + j[2] + ".png"
            stage.grabToImage(res => {
                res.saveToFile(path)
                root.at++
                step.start()
            })
        }
    }
}

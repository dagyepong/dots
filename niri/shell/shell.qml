import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Aibou: small companions (Kuro, Mochi, Shiro and friends) that live behind the windows.
//   home   background layer inside niri's backdrop, under every window
//   touch  bottom layer, input only where a character sits
//   stage  top layer, while somebody is over the windows
// All three are strips along the bottom edge, not the whole screen.
ShellRoot {
    id: shell

    readonly property var screen: {
        const want = Quickshell.env("AIBOU_OUTPUT")
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++) if (list[i].name === want) return list[i]
        return list.length > 0 ? list[0] : null
    }

    World {
        id: world
        areaW: shell.screen ? shell.screen.width : 1920
        areaH: shell.screen ? shell.screen.height : 1080
        cast: [c0, c1, c2, c3, c4]
        outputName: shell.screen ? shell.screen.name : ""
    }
    Character { id: c0; world: world; slot: 0; skin: world.skin1 === "none" ? "kuro" : world.skin1; brain: b0 }
    Character { id: c1; world: world; slot: 1; skin: world.look(1, world.skin2); brain: b1 }
    Character { id: c2; world: world; slot: 2; skin: world.look(2, world.skin3); brain: b2 }
    Character { id: c3; world: world; slot: 3; skin: world.look(3, world.skin4); brain: b3 }
    Character { id: c4; world: world; slot: 4; skin: world.look(4, world.skin5); brain: b4 }
    Brain { id: b0; st: c0; main: true }
    Brain { id: b1; st: c1 }
    Brain { id: b2; st: c2 }
    Brain { id: b3; st: c3 }
    Brain { id: b4; st: c4 }
    readonly property var brains: [b0, b1, b2, b3, b4]
    readonly property var main: b0

    // settings: front pins everybody over the windows
    Connections {
        target: world
        function onFrontChanged() { for (const b of shell.brains) if (b.st.active) b.setFront(world.front) }
    }
    // a character that is switched off goes home and stops
    function activeChanged(i) {
        const c = world.cast[i], b = brains[i]
        if (!c.active) { b.stopPlay(); b.pinned = false; c.place = "home"; c.sink = 0; c.dockRise = 0; b.doing = "idle" }
        else {
            c.x0 = Math.max(c.minX, Math.min(c.maxX, world.areaW * (0.6 - i * 0.17))); c.restX = c.x0
            if (world.front) b.setFront(true)
        }
    }
    Connections { target: c1; function onActiveChanged() { shell.activeChanged(1) } }
    Connections { target: c2; function onActiveChanged() { shell.activeChanged(2) } }
    Connections { target: c3; function onActiveChanged() { shell.activeChanged(3) } }
    Connections { target: c4; function onActiveChanged() { shell.activeChanged(4) } }

    // ── the daemon ────────────────────────────────────────────────
    Process {
        id: daemon
        command: ["python3", "-u", Quickshell.shellDir + "/../daemon/aiboud"]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: line => shell.onDaemon(line) }
        stderr: SplitParser { onRead: line => console.warn(line) }
        onExited: restartDaemon.start()
    }
    Timer { id: restartDaemon; interval: 3000; onTriggered: daemon.running = true }
    function tell(obj) { if (daemon.running) daemon.write(JSON.stringify(obj) + "\n") }
    Connections {
        target: world
        function onSetOption(key, value) { shell.tell({ t: "setOption", key: key, value: value }) }
        // somebody hangs on the pointer: every movement of it, for a smooth swing
        function onPointerHolderChanged() { shell.tell({ t: "pointerFast", on: world.pointerHolder !== null }) }
    }

    function onDaemon(line) {
        let m
        try { m = JSON.parse(line) } catch (e) { return }
        switch (m.t) {
        case "hello": world.lang = m.lang === "de" || m.lang === "ja" ? m.lang : "en"; break
        case "settings": world.settings = m.values; break
        case "history":
            if (world.chatLog.count === 0)
                for (const e of m.list) world.logAdd(e.who, e.who === "him" ? e.text.replace(/\n\[Aktion\] .*/g, "") : e.text)
            break
        case "insets":
            world.insets = { left: m.left, right: m.right, top: m.top, bottom: m.bottom }
            world.barEdge = m.bar || ""
            if (m.gap !== undefined) world.gap = m.gap
            for (const c of world.cast) { c.x0 = Math.max(c.minX, Math.min(c.maxX, c.x0)); c.restX = c.x0 }
            break
        case "colors":
            if (m.primary) {
                world.primary = m.primary; world.bubbleBg = m.surface; world.bubbleText = m.text
                world.outline = m.outline; world.dark = m.dark
                if (m.base) world.glassTint = m.base
                if (m.glass !== undefined) world.glassOpacity = m.glass
                if (m.frame) world.frameColor = m.frame
            }
            break
        case "power": world.onBattery = !m.mains; break
        case "dnd": world.dnd = m.on; break
        case "load":
            world.cpu = m.cpu; world.ram = m.ram; world.temp = m.temp || 0
            world.strain = m.strain
            break
        case "barspot":
            // the bar changed beside the faces: measure it once without them
            if (m.gaps !== undefined && m.dirty && !world.barHide) { world.barHide = true; barBare.start() }
            else if (m.gaps !== undefined) { shell.packBarFaces(m.gaps || []); world.barHide = false }
            else world.barSpot = m.y === null || m.y === undefined ? -1 : m.y
            break
        case "trouble":
            if (world.chatOpen && world.moods) chatNote(main.say(m.kind).replace("%1", m.name))
            world.trouble(m.kind, m.name)
            break
        case "recording": world.recordingOn = m.on; world.news("recording", m); break
        case "download": world.news("download", m); break
        case "battery": world.batteryLevel = m.level; world.charging = m.charging; world.news("battery", m); break
        case "updates": world.news("updates", m); break
        case "jobDone": world.news("job", m); break
        case "locked": world.news("locked", m); break
        case "usb": world.news("usb", m); break
        // the eyes are drawn in the ring's colour: black on the white ring (dark mode)
        case "kuroWall": shell.kuroOn = m.on; shell.kuroLight = !m.light; break
        case "restack": shell.restack(); break
        case "mic": world.news("mic", m); break
        case "windows": world.wins = m.list; world.winsKnown = m.known; world.fullscreen = !!m.fullscreen; break
        case "wallpaper": world.wallpaper = m.path || ""; break
        case "music": commands.stopFake(); world.music = m.on; break
        // a shell line from the chat window: output as it comes, then the exit code
        case "shellOut": {
            const i = world.logFind(m.id)
            if (i >= 0) world.chatLog.setProperty(i, "out", (world.chatLog.get(i).out + m.text).slice(-20000))
            break
        }
        case "shellDone": {
            const i = world.logFind(m.id)
            if (i >= 0) {
                const e = world.chatLog.get(i)
                world.chatLog.setProperty(i, "phase", m.code === 0 ? "done" : "failed")
                if (m.code !== 0) world.chatLog.setProperty(i, "out", e.out + (e.out && !e.out.endsWith("\n") ? "\n" : "") + "[exit " + m.code + "]")
            }
            break
        }
        case "frameHost":
            world.frameHost = m.on
            world.frameOffsets = !!m.offsets
            world.frameCorners = !!m.corners
            world.frameDomes = m.domes || 3
            break
        case "beat": world.bpm = m.bpm || 0; world.beat(m.s); break
        case "pointer": follow(m.x, m.y); break
        case "activity": for (const b of brains) b.activity(); break
        case "notify":
            if (world.chatOpen) chatNote((m.app ? m.app + ": " : "") + m.summary)
            else main.notify(m)
            // the bell in the bar gets its dot: the faces left there look again
            if (world.barFlat) barAfterNotify.restart()
            break
        case "thinking":
            world.chatBusy = true
            world.logAdd("him", "", { pending: true })
            c0.thinking = true; c0.mood = "curious"
            break
        case "delta": {
            const i = lastPending()
            if (i >= 0) world.chatLog.setProperty(i, "text", world.chatLog.get(i).text + m.text)
            if (c0.thinking) c0.thinking = false
            break
        }
        case "say": {
            const i = lastPending()
            if (i >= 0) { world.chatLog.setProperty(i, "text", m.text); world.chatLog.setProperty(i, "pending", false) }
            world.chatBusy = false
            main.reply(m.text, m.mood, m.level || 0)
            break
        }
        case "error": {
            const i = lastPending()
            const t = world.tr("Ich komme gerade nicht an mein Hirn … (" + (m.text || "Fehler") + ")",
                               "I couldn't reach my brain … (" + (m.text || "error") + ")",
                               "いま頭が働かないみたい … (" + (m.text || "エラー") + ")")
            if (i >= 0) { world.chatLog.setProperty(i, "text", t); world.chatLog.setProperty(i, "pending", false) }
            world.chatBusy = false
            main.failed()
            break
        }
        case "model": world.chatModel = m.name; break
        case "tool": {
            // before his answer, which is already waiting as an empty entry
            const i = lastPending()
            const e = { who: "tool", text: m.what || m.name, pending: false, aid: "", phase: "", out: "" }
            if (i >= 0 && world.chatLog.get(i).text === "") world.chatLog.insert(i, e)
            else world.chatLog.append(e)
            break
        }
        case "actions":
            for (const a of m.list)
                world.logAdd("action", a.cmd, { aid: a.id, phase: a.blocked ? "blocked" : "ask", out: a.blocked || "" })
            break
        case "ranOut": {
            const i = world.logFind(m.id)
            if (i >= 0 && world.chatLog.get(i).phase === "running") world.chatLog.setProperty(i, "out", m.out)
            break
        }
        case "ran": {
            const i = world.logFind(m.id)
            if (i >= 0) {
                world.chatLog.setProperty(i, "phase", m.code === 0 ? "done" : "failed")
                world.chatLog.setProperty(i, "out", (m.code === 0 ? "" : "exit " + m.code + "\n") + (m.out || ""))
            }
            break
        }
        }
    }
    function lastPending() {
        for (let i = world.chatLog.count - 1; i >= 0; i--) if (world.chatLog.get(i).pending) return i
        return -1
    }
    function chatNote(text) { world.logAdd("note", text) }
    // the domes DMS draws in its frame: in the frame's colour, risen or melting in (not while
    // he sinks out again), not pushed aside by a popout, not flat in the bar.
    // Every figure keeps its own place in the list (DMS matches its domes by
    // place): one not in the frame is sent with no height at its last spot, so
    // its dome sinks where it was, the others stay, and walking about outside
    // the frame changes nothing.
    property var bodyKept: [null, null, null, null, null]
    function frameBody(c, i) {
        const bar = c.dockSide === "bar", far = c.dockSide === "far"
        // pushed out by a popout: DMS can draw him at its edge (it moves him along with
        // the popout by itself), else he draws himself
        const shown = c.active && i < world.frameDomes && (c.place === "dock" && c.dockRise >= 0.01 || c.melting) && !c.undocking
                      && (c.dockShift <= 0 || world.frameOffsets && bar)
                      && world.dockTint === "frame" && !(bar && world.barFlat)
        const w = Math.round(c.size * 1.2), f = Math.round(c.size * 0.3)
        if (!shown) {
            const k = bodyKept[i]
            return k ? Object.assign({}, k, { h: 0 }) : { screen: world.outputName, side: "bottom", p: 0, w: w, h: 0, f: f }
        }
        const b = { screen: world.outputName,
                    side: bar ? world.barEdge : far ? (world.barEdge === "left" ? "right" : "left") : c.dockSide === "top" ? "top" : "bottom",
                    p: Math.round(bar || far ? c.barDockY : c.x0), w: w, h: Math.round(c.size * (bar || far ? 0.66 : 0.46)), f: f,
                    held: c.held }
        bodyKept[i] = b
        return b
    }
    readonly property string frameBodies: JSON.stringify([frameBody(c0, 0), frameBody(c1, 1), frameBody(c2, 2), frameBody(c3, 3), frameBody(c4, 4)])
    // at most every 40 ms (a dome dragged along an edge changes all the time)
    onFrameBodiesChanged: if (!frameBodiesLater.running) frameBodiesLater.start()
    Timer { id: frameBodiesLater; interval: 40; onTriggered: shell.tell({ t: "frameBodies", list: JSON.parse(shell.frameBodies) }) }
    // look for room in the bar for a face; while he already sits there, his
    // own rows count as free
    function askBarSpot() {
        if (!world.barSide) return
        const left = world.barEdge === "left"
        const bw = left ? world.insets.left : world.insets.right
        // every free stretch; the rows of the faces already there count as free
        // (unless they are hidden for a bare look), only as high as a face: an
        // icon that turns up right beside one must show, or it stays under it
        const s = c0.size, fh = s * 0.72
        const had = world.barFlat && !world.barHide ? world.barSlots.map(y => [y - fh * 0.5, y + fh * 0.5]) : []
        shell.tell({ t: "barspot", x: left ? 0 : world.areaW - bw, w: bw,
                     top: world.insets.top + 12, bottom: world.floorY,
                     need: s * 0.72, gaps: true, skip: had.length ? had : null })
    }
    // the faces faded out: now the bar alone
    Timer { id: barBare; interval: 260; onTriggered: shell.askBarSpot() }
    Timer { id: barAfterNotify; interval: 1500; onTriggered: shell.askBarSpot() }
    // a face for each figure in the bar: bottom up, as many in a stretch as fit,
    // then the next stretch; not room for all of them: domes instead
    property var lastGaps: []
    function packBarFaces(gaps) {
        const n = Math.max(1, world.barFaces), s = c0.size, fh = s * 0.72, step = s * 0.9
        const slots = []
        shell.lastGaps = gaps
        for (const g of gaps) {
            for (let y = g[1] - fh / 2; y - fh / 2 >= g[0] && slots.length < n; y -= step) slots.push(y)
            if (slots.length >= n) break
        }
        world.barSlots = slots.length >= n ? slots : []
        world.barSpot = slots.length >= n ? slots[0] : -1
    }
    // one more or one less face in the bar: a stretch that fits them all
    Connections { target: world; function onBarFacesChanged() { if (world.barStyle === "flat" && world.barFaces > 0) shell.askBarSpot() } }
    Connections {
        target: world
        function onBarSpotWanted() { shell.askBarSpot() }
    }
    // icons in the bar come and go (tray, notifications): look again now and then
    // (a capture of the bar takes a few ms)
    Timer {
        interval: 15000; repeat: true
        running: world.barStyle === "flat" && world.cast.some(c => c.active && c.place === "dock" && c.dockSide === "bar")
        onTriggered: shell.askBarSpot()
    }
    Connections {
        target: b0
        function onChatOpened() { shell.tell({ t: "warm" }) }
    }
    Timer {
        interval: 2500; running: true
        onTriggered: {
            if (!world.front) { shell.main.hello(); return }
            for (const b of shell.brains) if (b.st.active) b.setFront(true)
        }
    }

    // eyes follow the pointer when it is near; quantised, so a moving
    // pointer far away does not make anyone redraw
    readonly property real homeFloor: 230 - world.insets.bottom
    // the world under a name no property hides (inside the loaders `world` may be one)
    readonly property var theWorld: world
    // another backdrop surface came after ours: build ours again, on top
    function restack() {
        homeLoader.active = false
        kuroLoader.active = false
        Qt.callLater(() => { homeLoader.active = true; kuroLoader.active = true })
    }
    function follow(gx, gy) {
        if (world.chatOpen) chatWin.pointerAt(gx, gy)
        if (shell.kuroOn && kuroLoader.item) kuroLoader.item.look(gx - (shell.screen ? shell.screen.x : 0), gy - (shell.screen ? shell.screen.y : 0))
        if (!shell.screen) return
        const x = gx - shell.screen.x, y = gy - shell.screen.y
        for (const b of brains) if (b.st.active) b.pointerMoved(x, y)
        if (!world.gaze) return
        const q = v => Math.round(Math.max(-1, Math.min(1, v)) * 8) / 8
        for (let i = 0; i < 3; i++) {
            const c = world.cast[i], b = brains[i]
            if (!c.active || c.moving || c.sleeping || c.thinking || c.place === "chat" || b.doing === "play" || b.doing === "meet") continue
            // from where his eyes are: in the bar the dome sits on its edge
            const inBar = c.place === "dock" && c.dockSide === "bar"
            const ex = inBar ? (world.barEdge === "left" ? world.insets.left : world.areaW - world.insets.right) : c.x0
            const ey = inBar ? c.barDockY : world.floorY - c.size * 0.45
            // anywhere on the screen: the direction to the pointer, fully turned
            // once it is a little away, finer close by
            const dx = x - ex, dy = y - ey
            const d = Math.hypot(dx, dy) + 90
            const tx = q(dx / d * 1.25), ty = q(dy / d * 1.25)
            if (tx !== c.gazeX) c.gazeX = tx
            if (ty !== c.gazeY) c.gazeY = ty
        }
    }

    // On a figure: a click tickles him, a double click opens the chat (the
    // first one) or makes the others wave, press and move picks him up (throw
    // him by letting go while moving). Right: sleep / wake, middle: play.
    function clicked(i, button) {
        const b = brains[i]
        if (b.st.held || b.st.flying) return
        // up at the top: a click makes him let go; while climbing he is busy
        if (b.st.place === "dock" && b.st.dockSide === "top") { b.drop(); return }
        if (b.st.place === "sky") return
        if (button === Qt.RightButton) {
            if (b.st.place === "stage" && i === 0 && b.doing !== "idle") b.leaveStage(); else b.toggleSleep()
        } else if (button === Qt.MiddleButton) {
            if (b.doing === "play") b.stopPlay(); else { b.wake(true); if (world.games) b.startPlay() }
        } else { b.wake(true); b.tickle() }
    }
    function doubleClicked(i) {
        const b = brains[i]
        if (b.st.held || b.st.flying || b.st.place === "sky") return
        b.wake(true)
        if (i === 0) b.openChat()
        else b.whenFree(() => { b.st.wave(); b.st.jump(14) })
    }
    // the ball: pick it up with the pointer, throw it by letting go while moving
    component BallHit: Item {
        id: bh
        required property real floor           // the floor in this surface
        required property string where          // where the ball has to be drawn
        readonly property bool on: world.ballOut && world.ballAlpha > 0.5 && shell.ballPlace === where
        readonly property var holder: world.ballHolder
        readonly property real bx: holder ? world.handsX(holder) : world.ballX
        readonly property real bhh: holder ? world.holdHeight(holder) : world.ballH
        width: on ? world.ballR * 3.2 : 0
        height: width
        x: bx - width / 2
        y: floor - bhh - world.ballR - height / 2
        MouseArea {
            anchors.fill: parent
            cursorShape: world.ballInHand ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            function local(m) { const p = mapToItem(null, m.x, m.y); return { x: p.x, h: bh.floor - p.y - world.ballR } }
            onPressed: m => { const p = local(m); world.handGrab(p.x, p.h) }
            onPositionChanged: m => { const p = local(m); world.handMove(p.x, p.h) }
            onReleased: world.handThrow()
            onCanceled: world.handThrow()
        }
    }
    component FigMouse: MouseArea {
        id: fm
        required property int idx
        required property real winTop          // the surface's top on the screen
        readonly property var b: shell.brains[idx]
        property bool dragged: false
        property point pressAt: Qt.point(0, 0)
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        preventStealing: true
        cursorShape: dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        function screenAt(m) { const p = fm.mapToItem(null, m.x, m.y); return Qt.point(p.x, p.y + fm.winTop) }
        onPressed: m => { dragged = false; pressAt = screenAt(m) }
        onPositionChanged: m => {
            if (!(m.buttons & Qt.LeftButton)) return
            const p = screenAt(m)
            if (!dragged && Math.hypot(p.x - pressAt.x, p.y - pressAt.y) > 8) {
                dragged = true
                clickWait.stop()
                b.wake(true)
                b.grab(pressAt.x, pressAt.y)
            }
            if (dragged) b.drag(p.x, p.y)
        }
        onReleased: m => { if (dragged) b.release() }
        onCanceled: if (dragged) b.release()
        onClicked: m => {
            if (dragged) return
            if (m.button !== Qt.LeftButton) { shell.clicked(idx, m.button); return }
            clickWait.restart()
        }
        onDoubleClicked: m => {
            if (dragged || m.button !== Qt.LeftButton) return
            clickWait.stop()
            shell.doubleClicked(idx)
        }
        Timer { id: clickWait; interval: 260; onTriggered: shell.clicked(fm.idx, Qt.LeftButton) }
    }

    // popouts DMS reports (dms-leiste-patch 13): a file it writes, watched here
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/aibou-popout"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text().trim()
            if (t !== "") shell.setPopout(t)
        }
    }
    function setPopout(state) {
        const f = state.split(" ")
        world.popout = f.length >= 5 && f[0] !== "zu"
            ? { side: f[0], x: +f[1], y: +f[2], w: +f[3], h: +f[4], screen: f[5] || "" } : null
    }

    // the ball lives where the first player is
    readonly property string ballPlace: {
        if (world.ballHolder) return world.ballHolder.place
        for (const b of brains) if (b.doing === "play") return b.st.place
        return "home"
    }
    // the ball flies no higher than the strip it is drawn in
    Binding { target: world; property: "ballCeil"; value: (shell.ballPlace === "stage" ? stage.floor : shell.homeFloor) - 4 }

    // ── the cloth ─────────────────────────────────────────────────
    // Coming to the front, he lifts the bottom of the screen like a cloth and
    // steps out from under it; going back, the other way round. The cloth is a
    // screen capture of the strip, bent by shaders/cloth.vert.
    property var clothWho: null
    property string clothForce: ""
    property bool clothUp: true
    Connections {
        target: world
        function onClothRequest(who, up) {
            shell.clothWho = who
            shell.clothUp = up
            const win = world.windowOver(who.x0, who.size * 0.5) || { x: world.insets.left, w: world.areaW - world.insets.left - world.insets.right, bottom: world.floorY - world.gap }
            // right between two windows: now and then he lifts both, one with each
            // hand, and comes out through the gap
            const pair = world.windowPair(who.x0, who.size * 0.5)
            // for tests (aibou clothTest lift|curtain|single): the next one is that
            const r = shell.clothForce === "curtain" ? 0 : shell.clothForce === "lift" ? 0.5 : shell.clothForce === "single" ? 0.9 : Math.random()
            shell.clothForce = ""
            world.clothMode = pair && r < 0.4 ? "curtain" : "lift"
            if (pair && r < 0.8) {
                world.clothWin = pair[0]
                world.clothWin2 = pair[1]
                who.x0 = (pair[0].x + pair[0].w + pair[1].x) / 2
                who.restX = who.x0
            } else {
                world.clothWin2 = null
                // still hidden behind it: move him fully under the window he lifts,
                // so the neighbour does not cover half of him
                const lo = win.x + who.size * 0.6, hi = win.x + win.w - who.size * 0.6
                if (lo < hi && (who.x0 < lo || who.x0 > hi)) { who.x0 = Math.max(lo, Math.min(hi, who.x0)); who.restX = who.x0 }
                world.clothWin = win
            }
            world.clothX = who.x0
            world.clothFor = who
            world.clothPrep = true
            // hide him for the capture either way: behind a see-through window he
            // would end up in the picture and ride along on the cloth
            world.capturing = true
            clothCapture.start()
        }
    }
    Timer {
        id: clothCapture
        interval: 60
        onTriggered: { scv.captureFrame(); clothGo.start() }
    }
    Timer {
        id: clothGo
        interval: 110
        onTriggered: {
            world.capturing = false
            world.clothLift = 0
            world.clothUnder = shell.clothUp
            world.pusher = true
            world.clothActive = true
            world.clothPrep = false
            world.clothPush = 0
            const curtain = world.clothMode === "curtain"
            if (shell.clothUp) { shell.clothWho.place = "stage"; shell.clothWho.sink = 1; (curtain ? curtainIn : clothIn).start() }
            else (curtain ? curtainOut : clothOut).start()
        }
    }
    SequentialAnimation {
        id: clothIn
        NumberAnimation { target: world; property: "clothLift"; to: 16; duration: 170; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 140 }
        ParallelAnimation {
            NumberAnimation { target: world; property: "clothLift"; to: shell.clothWho ? shell.clothWho.size * 1.5 : 90; duration: 480; easing.type: Easing.OutBack }
            NumberAnimation { target: shell.clothWho; property: "sink"; to: 0; duration: 440; easing.type: Easing.OutQuad }
        }
        PauseAnimation { duration: 220 }
        ScriptAction { script: { world.clothUnder = false; shell.clothWho.jump(12) } }
        PauseAnimation { duration: 120 }
        NumberAnimation { target: world; property: "clothLift"; to: 0; duration: 520; easing.type: Easing.OutBounce }
        ScriptAction { script: shell.clothFinish() }
    }
    SequentialAnimation {
        id: clothOut
        NumberAnimation { target: world; property: "clothLift"; to: shell.clothWho ? shell.clothWho.size * 1.5 : 90; duration: 420; easing.type: Easing.OutBack }
        ScriptAction { script: { world.clothUnder = true } }
        NumberAnimation { target: shell.clothWho; property: "sink"; to: 1; duration: 300; easing.type: Easing.InQuad }
        NumberAnimation { target: world; property: "clothLift"; to: 0; duration: 460; easing.type: Easing.OutBounce }
        ScriptAction { script: { shell.clothWho.place = "home"; shell.clothWho.sink = 0; shell.clothFinish() } }
    }
    // between two windows: they slide aside at the bottom like a curtain and he
    // steps through the opening
    SequentialAnimation {
        id: curtainIn
        NumberAnimation { target: world; property: "clothPush"; to: 10; duration: 160; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 120 }
        ParallelAnimation {
            NumberAnimation { target: world; property: "clothPush"; to: shell.clothWho ? shell.clothWho.size * 0.95 : 60; duration: 460; easing.type: Easing.OutBack }
            NumberAnimation { target: shell.clothWho; property: "sink"; to: 0; duration: 420; easing.type: Easing.OutQuad }
        }
        PauseAnimation { duration: 200 }
        ScriptAction { script: { world.clothUnder = false; shell.clothWho.jump(12) } }
        PauseAnimation { duration: 140 }
        NumberAnimation { target: world; property: "clothPush"; to: 0; duration: 560; easing.type: Easing.OutBounce }
        ScriptAction { script: shell.clothFinish() }
    }
    SequentialAnimation {
        id: curtainOut
        NumberAnimation { target: world; property: "clothPush"; to: shell.clothWho ? shell.clothWho.size * 0.95 : 60; duration: 400; easing.type: Easing.OutBack }
        ScriptAction { script: { world.clothUnder = true } }
        NumberAnimation { target: shell.clothWho; property: "sink"; to: 1; duration: 300; easing.type: Easing.InQuad }
        NumberAnimation { target: world; property: "clothPush"; to: 0; duration: 480; easing.type: Easing.OutBounce }
        ScriptAction { script: { shell.clothWho.place = "home"; shell.clothWho.sink = 0; shell.clothFinish() } }
    }
    function clothFinish() {
        const who = clothWho, up = clothUp
        world.clothActive = false
        world.pusher = false
        world.clothFor = null
        world.clothWin2 = null
        world.clothMode = "lift"
        world.clothPush = 0
        clothWho = null
        if (up) who.wave()
        world.clothDone(who, up)
    }

    // glass characters get a blur region where their body is
    component GlassSpot: Item {
        required property var c
        required property string where
        required property real floor
        readonly property bool on: c.active && c.blurBehind && c.place === where && c.sink < 0.95
                                   && !(world.capturing && where === "stage")
        // 2 px inside his outline: the region reaches niri a frame late, so
        // while he moves a full-size one shows a light rim beside him
        readonly property real inset: 2
        width: on ? c.size * c.sx - 2 * inset : 0
        height: on ? c.bodyH * c.sy - 2 * inset : 0
        x: c.x0 - width / 2
        y: floor - height - inset - c.lift - c.hover + c.sink * (c.bodyH + 14)
    }

    // a short call next to a figure's head, on whichever surface he is
    // drawn: onTop for the sky (in front, in the air), else the backdrop
    component ShoutText: Text {
        required property var c
        property real floorY: 0
        property bool onTop: false
        readonly property bool up: c.place === "sky"
        readonly property bool here: onTop ? (c.place === "sky" || c.place === "stage") : c.place === "home"
        visible: c.active && c.shout !== "" && here && !world.fullscreen
        text: c.shout
        // hanging: beside his head along the rope; standing: beside his head
        x: up ? c.x0 - Math.sin(c.theta) * c.bodyH * 0.8 + c.size * 0.55 : c.x0 + c.size * 0.5
        y: (up ? c.y0 - Math.cos(c.theta) * c.bodyH * 0.8 : floorY - c.lift - c.hover - c.bodyH * 1.1) - height / 2
        color: world.dark ? "#ffe9a8" : "#5a3d10"
        style: Text.Outline
        styleColor: world.dark ? "#1a1412" : "white"
        font.pixelSize: 15
        font.bold: true
        font.italic: true
    }

    // ── home: behind everything ───────────────────────────────────
    // Built anew when another backdrop surface was opened after it and lies
    // over it (AudioFX after a profile switch): the newest lies on top
    // (restack, aiboud's layer watch).
    LazyLoader {
        id: homeLoader
        active: true
    PanelWindow {
        id: home
        screen: shell.screen
        readonly property real floor: height - world.insets.bottom
        anchors { left: true; right: true; bottom: true }
        implicitHeight: 230
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "aibou"
        mask: Region {}
        BackgroundEffect.blurRegion: Region {
            shape: RegionShape.Ellipse; item: hg0
            Region { shape: RegionShape.Ellipse; item: hg1 }
            Region { shape: RegionShape.Ellipse; item: hg2 }
            Region { shape: RegionShape.Ellipse; item: hg3 }
            Region { shape: RegionShape.Ellipse; item: hg4 }
        }
        GlassSpot { id: hg0; c: c0; where: "home"; floor: home.floor }
        GlassSpot { id: hg1; c: c1; where: "home"; floor: home.floor }
        GlassSpot { id: hg2; c: c2; where: "home"; floor: home.floor }
        GlassSpot { id: hg3; c: c3; where: "home"; floor: home.floor }
        GlassSpot { id: hg4; c: c4; where: "home"; floor: home.floor }

        Item {
            width: parent.width
            height: home.floor
            clip: true
            Ball { world: shell.theWorld; z: 3; y: home.floor; visible: shell.theWorld.ballAlpha > 0.01 && shell.ballPlace === "home" }
            // a figure is only built in the window where it is: a hidden one
            // still makes its window redraw with every blink
            Repeater {
                model: world.cast
                Loader {
                    id: hl
                    required property var modelData
                    active: modelData.active && modelData.place === "home"
                    visible: !(world.capturing && world.clothFor === modelData)
                    x: modelData.x0; y: home.floor
                    sourceComponent: Creature { st: hl.modelData }
                }
            }
            ShoutText { c: c0; floorY: home.floor; z: 4 }
            ShoutText { c: c1; floorY: home.floor; z: 4 }
            ShoutText { c: c2; floorY: home.floor; z: 4 }
            ShoutText { c: c3; floorY: home.floor; z: 4 }
            ShoutText { c: c4; floorY: home.floor; z: 4 }
            JumpRope { z: -1; front: false; floor: home.floor; where: "home" }
            JumpRope { z: 3; front: true; floor: home.floor; where: "home" }
        }
    }
    }

    // ── touch: clicks on whoever sits at home ─────────────────────
    PanelWindow {
        id: touch
        screen: shell.screen
        readonly property real floor: height - world.insets.bottom
        anchors { left: true; right: true; bottom: true }
        implicitHeight: 230
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "aibou-touch"
        mask: Region {
            item: hit0
            Region { item: ballHitHome }
            Region { item: hit1 }
            Region { item: hit2 }
            Region { item: hit3 }
            Region { item: hit4 }
        }
        component HomeHit: Item {
            id: hh
            required property var c
            required property int idx
            readonly property bool on: c.active && c.place === "home" && !c.moving || c.held
            width: on ? c.size * 1.1 : 0
            height: on ? c.size * 0.95 : 0
            x: c.restX - width / 2
            y: touch.floor - height
            FigMouse { idx: hh.idx; winTop: world.areaH - touch.implicitHeight }
        }
        BallHit { id: ballHitHome; floor: touch.floor; where: "home" }
        HomeHit { id: hit0; c: c0; idx: 0 }
        HomeHit { id: hit1; c: c1; idx: 1 }
        HomeHit { id: hit2; c: c2; idx: 2 }
        HomeHit { id: hit3; c: c3; idx: 3 }
        HomeHit { id: hit4; c: c4; idx: 4 }
    }

    // ── the frame: his dome, on a surface of its own ─────────────
    // niri blurs it with xray (layer-rule in config.kdl): the blurred wallpaper
    // shows behind his glass, as behind the frame, so the frame's colour fits
    // at once. Same place and size as the stage; never takes input.
    PanelWindow {
        id: dockWin
        screen: shell.screen
        // always mapped: unmapping a Quickshell window can crash Qt
        // (QWaylandWindow::handleScreensChanged, null screen). Empty, it costs nothing.
        visible: true
        // one pixel at the far left, under the bar's own glass, keeps the
        // region from ever being empty (empty means the whole surface)
        Item { id: blurAnchor; x: 0; y: 0; width: 1; height: 1 }
        // the whole screen high: put in the bar by hand, he can sit anywhere along it
        anchors { left: true; right: true; top: true; bottom: true }
        // dockPos is in stage coordinates; this surface starts that much higher
        readonly property real lift: world.areaH - stage.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        // above DMS's frame, which draws the domes he paints his face on
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aibou-dock"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            item: dhit0
            Region { item: dhit1 }
            Region { item: dhit2 }
            Region { item: dhit3 }
            Region { item: dhit4 }
        }
        DockHit { id: dhit0; c: c0; idx: 0; winLift: dockWin.lift }
        DockHit { id: dhit1; c: c1; idx: 1; winLift: dockWin.lift }
        DockHit { id: dhit2; c: c2; idx: 2; winLift: dockWin.lift }
        DockHit { id: dhit3; c: c3; idx: 3; winLift: dockWin.lift }
        DockHit { id: dhit4; c: c4; idx: 4; winLift: dockWin.lift }
        BackgroundEffect.blurRegion: Region {
            item: blurAnchor
            Region { item: blob0.slices[0] || null }
            Region { item: blob0.slices[1] || null }
            Region { item: blob0.slices[2] || null }
            Region { item: blob0.slices[3] || null }
            Region { item: blob0.slices[4] || null }
            Region { item: blob0.slices[5] || null }
            Region { item: blob0.slices[6] || null }
            Region { item: blob0.slices[7] || null }
            Region { item: blob0.slices[8] || null }
            Region { item: blob0.slices[9] || null }
            Region { item: blob0.slices[10] || null }
            Region { item: blob0.slices[11] || null }
            Region { item: blob1.slices[0] || null }
            Region { item: blob1.slices[1] || null }
            Region { item: blob1.slices[2] || null }
            Region { item: blob1.slices[3] || null }
            Region { item: blob1.slices[4] || null }
            Region { item: blob1.slices[5] || null }
            Region { item: blob1.slices[6] || null }
            Region { item: blob1.slices[7] || null }
            Region { item: blob1.slices[8] || null }
            Region { item: blob1.slices[9] || null }
            Region { item: blob1.slices[10] || null }
            Region { item: blob1.slices[11] || null }
            Region { item: blob2.slices[0] || null }
            Region { item: blob2.slices[1] || null }
            Region { item: blob2.slices[2] || null }
            Region { item: blob2.slices[3] || null }
            Region { item: blob2.slices[4] || null }
            Region { item: blob2.slices[5] || null }
            Region { item: blob2.slices[6] || null }
            Region { item: blob2.slices[7] || null }
            Region { item: blob2.slices[8] || null }
            Region { item: blob2.slices[9] || null }
            Region { item: blob2.slices[10] || null }
            Region { item: blob2.slices[11] || null }
            Region { item: blob3.slices[0] || null }
            Region { item: blob3.slices[1] || null }
            Region { item: blob3.slices[2] || null }
            Region { item: blob3.slices[3] || null }
            Region { item: blob3.slices[4] || null }
            Region { item: blob3.slices[5] || null }
            Region { item: blob3.slices[6] || null }
            Region { item: blob3.slices[7] || null }
            Region { item: blob3.slices[8] || null }
            Region { item: blob3.slices[9] || null }
            Region { item: blob3.slices[10] || null }
            Region { item: blob3.slices[11] || null }
            Region { item: blob4.slices[0] || null }
            Region { item: blob4.slices[1] || null }
            Region { item: blob4.slices[2] || null }
            Region { item: blob4.slices[3] || null }
            Region { item: blob4.slices[4] || null }
            Region { item: blob4.slices[5] || null }
            Region { item: blob4.slices[6] || null }
            Region { item: blob4.slices[7] || null }
            Region { item: blob4.slices[8] || null }
            Region { item: blob4.slices[9] || null }
            Region { item: blob4.slices[10] || null }
            Region { item: blob4.slices[11] || null }
        }
        Loader {
            id: blob0
            readonly property point at: stage.dockPos(c0)
            // the blur slices, empty while he is not in the frame
            readonly property var slices: item ? item.slices : []
            active: c0.active && c0.place === "dock" && c0.dockSide !== "top" && !world.fullscreen
            x: at.x; y: at.y + dockWin.lift
            sourceComponent: DockBlob {
                st: c0
                visible: c0.dockRise > 0.01
                turn: stage.dockTurn(c0)
            }
        }
        Loader {
            id: blob1
            readonly property point at: stage.dockPos(c1)
            // the blur slices, empty while he is not in the frame
            readonly property var slices: item ? item.slices : []
            active: c1.active && c1.place === "dock" && c1.dockSide !== "top" && !world.fullscreen
            x: at.x; y: at.y + dockWin.lift
            sourceComponent: DockBlob {
                st: c1
                visible: c1.dockRise > 0.01
                turn: stage.dockTurn(c1)
            }
        }
        Loader {
            id: blob2
            readonly property point at: stage.dockPos(c2)
            // the blur slices, empty while he is not in the frame
            readonly property var slices: item ? item.slices : []
            active: c2.active && c2.place === "dock" && c2.dockSide !== "top" && !world.fullscreen
            x: at.x; y: at.y + dockWin.lift
            sourceComponent: DockBlob {
                st: c2
                visible: c2.dockRise > 0.01
                turn: stage.dockTurn(c2)
            }
        }
        Loader {
            id: blob3
            readonly property point at: stage.dockPos(c3)
            // the blur slices, empty while he is not in the frame
            readonly property var slices: item ? item.slices : []
            active: c3.active && c3.place === "dock" && c3.dockSide !== "top" && !world.fullscreen
            x: at.x; y: at.y + dockWin.lift
            sourceComponent: DockBlob {
                st: c3
                visible: c3.dockRise > 0.01
                turn: stage.dockTurn(c3)
            }
        }
        Loader {
            id: blob4
            readonly property point at: stage.dockPos(c4)
            // the blur slices, empty while he is not in the frame
            readonly property var slices: item ? item.slices : []
            active: c4.active && c4.place === "dock" && c4.dockSide !== "top" && !world.fullscreen
            x: at.x; y: at.y + dockWin.lift
            sourceComponent: DockBlob {
                st: c4
                visible: c4.dockRise > 0.01
                turn: stage.dockTurn(c4)
            }
        }
    }

    // ── the Kuro wallpaper's eyes: blinking, following the pointer ──
    // The wallpaper (kuro-dunkel/-hell.png from tools/kuro_wallpaper.py) has the ring and
    // open eyes; this small surface lies exactly over the eyes, in the backdrop
    // like the wallpaper (niri rule "aibou-wall"), and draws them alive. Its
    // proportions are the script's: ring 0.30 of the screen height, eyes 6 × 15
    // of 58 units, ±9.5 apart, 3 % above the middle. Empty when another
    // wallpaper is up; a DMS restart may put the wallpaper over it, then the
    // still eyes of the picture show.
    LazyLoader {
        id: kuroLoader
        active: true
    PanelWindow {
        id: kuroEyes
        readonly property bool on: shell.kuroOn
        readonly property bool light: shell.kuroLight
        screen: shell.screen
        readonly property real sw: shell.screen ? shell.screen.width : 2560
        readonly property real sh: shell.screen ? shell.screen.height : 1600
        readonly property real k: sh * 0.30 / 58
        // room around the eyes for looking up and down and for the glow
        implicitWidth: Math.ceil(2 * 17 * k + 120)
        implicitHeight: Math.ceil(21 * k + 120)
        anchors { left: true; top: true }
        margins.left: Math.round(sw / 2 - implicitWidth / 2)
        margins.top: Math.round(sh / 2 - sh * 0.30 * 0.03 - implicitHeight / 2)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "aibou-wall"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        visible: true          // always mapped (see dockWin)
        color: "transparent"
        readonly property color ink: light ? "black" : "white"
        property real lid: 1
        property real gaze: 0
        property real gazeY: 0
        property real pulse: 0               // the glow beats with the music
        Behavior on gaze { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }
        Behavior on gazeY { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }
        NumberAnimation { id: eyePulse; target: kuroEyes; property: "pulse"; from: 1; to: 0; duration: 380; easing.type: Easing.OutQuad }
        Connections {
            target: world
            function onBeat(s) { if (kuroEyes.on) eyePulse.restart() }
        }
        function look(x, y) {
            const q = v => Math.round(Math.max(-1, Math.min(1, v)) * 8) / 8
            const g = q((x - sw / 2) / (sw * 0.35)), gy = q((y - sh / 2) / (sh * 0.35))
            if (g !== gaze) gaze = g
            if (gy !== gazeY) gazeY = gy
        }
        // the wallpaper is the ring alone: the eyes are drawn here on a clear
        // ground, with a soft glow of their own (AudioFX's glow finds only
        // the ring in the picture)
        Item {
            id: eyePair
            anchors.fill: parent
            visible: false
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    width: 6 * kuroEyes.k
                    height: 15 * kuroEyes.k * Math.max(0.15, kuroEyes.lid)
                    radius: width / 2
                    x: kuroEyes.width / 2 + modelData * 9.5 * kuroEyes.k + kuroEyes.gaze * 4 * kuroEyes.k - width / 2
                    y: kuroEyes.height / 2 + kuroEyes.gazeY * 3 * kuroEyes.k - height / 2
                    color: kuroEyes.ink
                    antialiasing: true
                }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: eyePair
            visible: kuroEyes.on
            shadowEnabled: true
            shadowColor: kuroEyes.ink
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: 0.45 + 0.5 * kuroEyes.pulse
            blurMax: 48
        }
        SequentialAnimation {
            id: wallBlink
            NumberAnimation { target: kuroEyes; property: "lid"; to: 0; duration: 80; easing.type: Easing.InQuad }
            NumberAnimation { target: kuroEyes; property: "lid"; to: 1; duration: 100; easing.type: Easing.OutQuad }
        }
        Timer {
            interval: 4000; repeat: true
            running: kuroEyes.on
            onTriggered: {
                interval = 2500 + Math.random() * 4500
                wallBlink.restart()
                if (Math.random() < 0.2) Qt.callLater(() => wallBlink.restart())
            }
        }
    }
    }
    property bool kuroOn: false
    property bool kuroLight: false

    // ── the sky: the whole screen, for climbing and hanging at the top ──
    // Empty most of the time; a surface this size only costs while something
    // moves on it.
    PanelWindow {
        id: sky
        screen: shell.screen
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aibou-sky"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        function upThere(c) { return c.active && (c.place === "sky" || (c.place === "dock" && c.dockSide === "top")) }
        // Kuro's glass up here too: an ellipse on his body, which is turned
        // with the surface he holds on to (its middle is half his height
        // from his feet, along his own "up"); 2 px inside his outline like below
        component SkyGlass: Item {
            required property var c
            readonly property bool on: c.active && c.blurBehind && c.place === "sky" && !world.fullscreen
            readonly property real a: c.surfaceRot * Math.PI / 180
            readonly property real up: c.bodyH * 0.5 + c.lift
            readonly property real inset: 2
            width: on ? c.size * c.sx - 2 * inset : 0
            height: on ? c.bodyH * c.sy - 2 * inset : 0
            x: c.x0 + Math.sin(a) * up - width / 2
            y: c.y0 - Math.cos(a) * up - height / 2
        }
        SkyGlass { id: kg0; c: c0 }
        SkyGlass { id: kg1; c: c1 }
        SkyGlass { id: kg2; c: c2 }
        SkyGlass { id: kg3; c: c3 }
        SkyGlass { id: kg4; c: c4 }
        // never an empty region (see the note on aibou-dock): a pixel in the corner
        Item { id: skyAnchor; x: 0; y: 0; width: 1; height: 1 }
        BackgroundEffect.blurRegion: Region {
            item: skyAnchor
            Region { shape: RegionShape.Ellipse; item: kg0 }
            Region { shape: RegionShape.Ellipse; item: kg1 }
            Region { shape: RegionShape.Ellipse; item: kg2 }
            Region { shape: RegionShape.Ellipse; item: kg3 }
            Region { shape: RegionShape.Ellipse; item: kg4 }
        }
        // always mapped (see dockWin); empty while nobody is up there
        visible: true
        mask: Region {
            item: skyHit0
            Region { item: skyHit1 }
            Region { item: skyHit2 }
            Region { item: skyHit3 }
            Region { item: skyHit4 }
        }
        // only built while needed: an idle figure in a hidden item still makes
        // this full-screen surface redraw whenever his eyes move
        component SkyFigure: Loader {
            id: sf
            required property var c
            active: c.active && c.place === "sky" && !world.fullscreen
            x: c.x0; y: c.y0
            rotation: c.surfaceRot
            sourceComponent: Creature { st: sf.c }
        }
        // the rope from the hook to his hands, and the hook itself; while it
        // flies up it runs from the gun to wherever the hook is
        component Rope: Item {
            id: rp
            required property var c
            visible: c.active && c.rope && !world.fullscreen
            readonly property real handX: c.hanging ? c.pivotX + c.ropeLen * Math.sin(c.theta) : c.gunX
            readonly property real handY: c.hanging ? c.pivotY + c.ropeLen * Math.cos(c.theta) : c.gunY
            readonly property real tipX: c.hanging ? c.hookX : c.gunX + (c.hookX - c.gunX) * c.ropeShot
            readonly property real tipY: c.hanging ? c.hookY : c.gunY + (c.hookY - c.gunY) * c.ropeShot
            Shape {
                preferredRendererType: Shape.CurveRenderer
                // a dark edge under a light strand, so it shows on any window
                ShapePath {
                    strokeColor: Qt.rgba(0.12, 0.09, 0.07, 0.75); strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: rp.handX; startY: rp.handY
                    PathLine { x: rp.tipX; y: rp.tipY }
                }
                ShapePath {
                    strokeColor: "#d9b98c"; strokeWidth: 2.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: rp.handX; startY: rp.handY
                    PathLine { x: rp.tipX; y: rp.tipY }
                }
                // the hook: a claw whose prongs point up and bite into the frame
                // above the edge (its shank hangs just below the edge)
                ShapePath {
                    strokeColor: Qt.rgba(0.12, 0.09, 0.07, 0.7); strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: rp.tipX - 7; startY: rp.tipY - 7
                    PathQuad { x: rp.tipX; y: rp.tipY + 2; controlX: rp.tipX - 7; controlY: rp.tipY + 2 }
                    PathQuad { x: rp.tipX + 7; y: rp.tipY - 7; controlX: rp.tipX + 7; controlY: rp.tipY + 2 }
                }
                ShapePath {
                    strokeColor: "#d4d9e0"; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: rp.tipX - 7; startY: rp.tipY - 7
                    PathQuad { x: rp.tipX; y: rp.tipY + 2; controlX: rp.tipX - 7; controlY: rp.tipY + 2 }
                    PathQuad { x: rp.tipX + 7; y: rp.tipY - 7; controlX: rp.tipX + 7; controlY: rp.tipY + 2 }
                }
            }
        }
        // the banana peel, falling or lying on the floor
        Item {
            visible: world.peelOn && !world.fullscreen
            x: world.peelX; y: world.peelY
            rotation: world.peelRot
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 5; height: 12; radius: 2.5
                    x: -2.5; y: -2
                    color: "#ffd23f"
                    border.width: 1; border.color: "#b8860b"
                    transformOrigin: Item.Top
                    // lying flat the flaps spread out on the floor
                    rotation: (index - 1) * (world.peelDown ? 70 : 40) + (world.peelDown ? 180 : 0)
                }
            }
            Rectangle { x: -3; y: -4; width: 6; height: 5; radius: 2; color: "#8a6a1a" }
        }
        Rope { c: c0 }
        Rope { c: c1 }
        Rope { c: c2 }
        Rope { c: c3 }
        Rope { c: c4 }
        // his shadow stays on the floor while he is up in the air: smaller and
        // fainter the higher he is, gone above ~350 px; not while he holds on to
        // a side wall or the top (no floor beneath that matters then)
        component FloorShadow: Rectangle {
            required property var c
            readonly property real h: Math.max(0, world.floorY - (c.y0 - c.lift))
            readonly property real k: Math.max(0, 1 - h / 350)
            visible: c.active && c.place === "sky" && k > 0.02 && Math.abs(c.surfaceRot) < 60 && !world.fullscreen
            width: c.size * 0.9 * (0.45 + 0.55 * k)
            height: 7 * (0.6 + 0.4 * k)
            radius: height / 2
            x: c.x0 - width / 2
            y: world.floorY - height / 2
            color: "black"
            opacity: 0.22 * k
        }
        FloorShadow { c: c0 }
        FloorShadow { c: c1 }
        FloorShadow { c: c2 }
        FloorShadow { c: c3 }
        FloorShadow { c: c4 }
        // a short call next to his head ("uh uh ah ah!"): up here only for
        // those in front of the windows or in the air; behind the windows the
        // backdrop draws it (home), so the windows cover it like him
        component Shout: ShoutText {
            floorY: world.floorY
            onTop: true
        }
        Shout { c: c0 }
        Shout { c: c1 }
        Shout { c: c2 }
        Shout { c: c3 }
        Shout { c: c4 }
        SkyFigure { c: c0 }
        SkyFigure { c: c1 }
        SkyFigure { c: c2 }
        SkyFigure { c: c3 }
        SkyFigure { c: c4 }
        // melted into the top edge: DMS draws the dome, he paints his face
        component TopBlob: Loader {
            id: tb
            required property var c
            active: c.active && c.place === "dock" && c.dockSide === "top" && !world.fullscreen
            x: c.x0; y: world.insets.top
            sourceComponent: DockBlob {
                st: tb.c
                turn: 180
                visible: tb.c.dockRise > 0.01
            }
        }
        TopBlob { c: c0 }
        TopBlob { c: c1 }
        TopBlob { c: c2 }
        TopBlob { c: c3 }
        TopBlob { c: c4 }
        component SkyHit: Item {
            id: kh
            required property var c
            required property int idx
            readonly property bool on: (sky.upThere(c) && !c.moving && !c.flying || c.held) && !world.fullscreen
            readonly property bool atTop: c.place === "dock"
            width: on ? c.size * 1.2 : 0
            height: on ? c.size * (atTop ? 0.6 : 1.2) : 0
            x: c.x0 - width / 2
            y: atTop ? world.insets.top : c.y0 - height / 2
            FigMouse { idx: kh.idx; winTop: 0 }
        }
        SkyHit { id: skyHit0; c: c0; idx: 0 }
        SkyHit { id: skyHit1; c: c1; idx: 1 }
        SkyHit { id: skyHit2; c: c2; idx: 2 }
        SkyHit { id: skyHit3; c: c3; idx: 3 }
        SkyHit { id: skyHit4; c: c4; idx: 4 }
    }

    // ── stage: over the windows ───────────────────────────────────
    PanelWindow {
        id: stage
        screen: shell.screen
        readonly property real floor: height - world.insets.bottom
        // always mapped, empty and click-through while nobody is up there:
        // unmapping it while the screen capture held a frame crashed Qt
        // (QWaylandWindow::handleScreensChanged, null screen)
        visible: true
        anchors { left: true; right: true; bottom: true }
        implicitHeight: 520
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "aibou-stage"
        WlrLayershell.keyboardFocus: b0.bubbleChat && b0.bubbleShown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region {
            item: shit0
            Region { item: shit1 }
            Region { item: shit2 }
            Region { item: shit3 }
            Region { item: shit4 }
            Region { item: ballHitStage }
            Region { item: bubble.shown > 0.05 ? bubble : null }
        }
        BackgroundEffect.blurRegion: Region {
            shape: RegionShape.Ellipse; item: sg0
            Region { shape: RegionShape.Ellipse; item: sg1 }
            Region { shape: RegionShape.Ellipse; item: sg2 }
            Region { shape: RegionShape.Ellipse; item: sg3 }
            Region { shape: RegionShape.Ellipse; item: sg4 }
        }
        // blur under a glass dome in the frame: an ellipse centred on the
        // frame edge, so only its upper half lies over the windows
        // where a docked character's dome starts, in stage coordinates
        function dockPos(c) {
            // the frame's side across from the bar (put there by hand)
            if (c.dockSide === "far")
                return Qt.point(world.barEdge === "left" ? world.areaW - world.insets.right : world.insets.left,
                                c.barDockY - (world.areaH - stage.height))
            if (c.dockSide !== "bar") return Qt.point(c.x0, stage.floor)
            // pushed outwards by a popout from the bar (dashboard ...)
            const x = world.barEdge === "left" ? world.insets.left + c.dockShift : world.areaW - world.insets.right - c.dockShift
            // only his face in the bar: where there is room between its icons
            if (world.barFlat)
                // the spot is the middle of the stretch for all of them: from its
                // bottom up, one face each
                // (the dock surface is as high as the screen: up the whole bar)
                return Qt.point(x, Math.max(world.insets.top + c.size * 0.5, world.barSlots[c.barRank] || world.barSpot) - (world.areaH - stage.height))
            // just above the corner where bar and frame meet: he sinks into the
            // floor there and comes out of the bar right beside it
            const y = c.barDockY - (world.areaH - stage.height)
            // pushed by a popout that DMS puts him on a corner of: his face goes
            // there, over the way the push goes (back the same way)
            if (world.frameCorners && c.cornerMode && c.shiftMax > 0 && c.dockShift > 0 && world.dockTint === "frame") {
                const t = Math.min(1, c.dockShift / c.shiftMax)
                const face = c.size * 0.37 * (world.barEdge === "left" ? 1 : -1)
                const cx = c.cornerX - face, cy = c.cornerY - (world.areaH - stage.height)
                const bx = world.barEdge === "left" ? world.insets.left : world.areaW - world.insets.right
                return Qt.point(bx + (cx - bx) * t, y + (cy - y) * t)
            }
            return Qt.point(x, y)
        }
        function dockTurn(c) {
            if (c.dockSide === "far") return world.barEdge === "left" ? -90 : 90
            return c.dockSide !== "bar" ? 0 : world.barEdge === "left" ? 90 : -90
        }
        // a quadratic curve between the two ends; its middle goes up over the
        // jumper's head (phase 0) and down to the floor (pi), lies there when slack
        component JumpRope: Shape {
            id: jr
            property bool front: true
            property real floor: 0
            property string where: "stage"
            readonly property var w: shell.theWorld
            readonly property bool inFront: Math.sin(jr.w.jrPhase) > 0 || jr.w.jrSlack
            visible: jr.w.jrOn && jr.w.jrPlace === where && !jr.w.fullscreen && inFront === front
            preferredRendererType: Shape.CurveRenderer
            readonly property real m: (jr.w.jrAY + jr.w.jrBY) / 2
            readonly property real dTop: -jr.w.jrTop - m
            readonly property real dBot: -2 - m
            readonly property real d: jr.w.jrSlack ? dBot : (dTop + dBot) / 2 + (dTop - dBot) / 2 * Math.cos(jr.w.jrPhase)
            // a red skipping rope with a dark edge, so it shows on light and dark alike
            ShapePath {
                strokeColor: "#5a1a20"; strokeWidth: 4.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: jr.w.jrAX; startY: jr.floor + jr.w.jrAY
                PathQuad {
                    x: jr.w.jrBX; y: jr.floor + jr.w.jrBY
                    controlX: (jr.w.jrAX + jr.w.jrBX) / 2
                    controlY: jr.floor + jr.m + 2 * jr.d
                }
            }
            ShapePath {
                strokeColor: "#e8505b"; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: jr.w.jrAX; startY: jr.floor + jr.w.jrAY
                PathQuad {
                    x: jr.w.jrBX; y: jr.floor + jr.w.jrBY
                    controlX: (jr.w.jrAX + jr.w.jrBX) / 2
                    controlY: jr.floor + jr.m + 2 * jr.d
                }
            }
        }
        component DockHit: Item {
            id: dh
            required property var c
            required property int idx
            readonly property bool on: (c.active && c.place === "dock" && c.dockSide !== "top" && c.dockRise > 0.9 && !c.moving || c.held) && !world.fullscreen
            readonly property bool side: c.dockSide === "bar" || c.dockSide === "far"
            // the side edge he sits on is the left one
            readonly property bool onLeft: (world.barEdge === "left") === (c.dockSide === "bar")
            readonly property point at: stage.dockPos(c)
            property real winLift: 0             // how much higher his surface reaches than the stage
            width: !on ? 0 : side ? c.size * 0.5 : c.size * 1.3
            height: !on ? 0 : side ? c.size * 1.3 : c.size * 0.5
            // flat in the bar: the face sits inside it
            readonly property bool inBar: c.dockSide === "bar" && world.barFlat
            x: !side ? at.x - width / 2 : onLeft !== inBar ? at.x : at.x - width
            y: (side ? at.y - height / 2 : at.y - height) + winLift
            FigMouse { idx: dh.idx; winTop: world.areaH - stage.implicitHeight - dh.winLift }
        }
        GlassSpot { id: sg0; c: c0; where: "stage"; floor: stage.floor }
        GlassSpot { id: sg1; c: c1; where: "stage"; floor: stage.floor }
        GlassSpot { id: sg2; c: c2; where: "stage"; floor: stage.floor }
        GlassSpot { id: sg3; c: c3; where: "stage"; floor: stage.floor }
        GlassSpot { id: sg4; c: c4; where: "stage"; floor: stage.floor }

        // the screen as captured, source of the cloth
        ScreencopyView {
            id: scv
            captureSource: shell.screen
            live: false
            width: world.areaW
            height: world.areaH
            y: -(world.areaH - stage.height)
            opacity: 0
        }

        Item {
            width: parent.width
            height: stage.floor
            clip: true
            Ball { world: world; z: 3; y: stage.floor; visible: world.ballAlpha > 0.01 && shell.ballPlace === "stage" }
            // the space under the lifted cloth: the wallpaper, as if the window
            // really were lifted off the desktop. Opaque: the real window is
            // still there underneath and would show through twice. The cloth
            // covers it everywhere except under the bulge.
            Item {
                id: clothGap
                readonly property var rightWin: world.clothWin2 || world.clothWin
                readonly property bool curtain: world.clothMode === "curtain"
                visible: world.clothActive
                z: 0
                opacity: 1
                // out to the focus ring beside the window too (it lies outside its
                // edge), or at a corner its upright stroke stays standing
                x: curtain ? world.clothX - world.clothPush - 4 : Math.max(world.clothWin.x - stage.ringMargin, world.clothX - 150)
                width: curtain ? world.clothPush * 2 + 8 : Math.min(rightWin.x + rightWin.w + stage.ringMargin, world.clothX + 150) - x
                y: stage.clothBottom - height
                height: curtain ? (world.clothFor ? world.clothFor.size * 1.8 : 100) : world.clothLift + 40
                clip: true
                // without a wallpaper: dark, lighter towards the frame
                Rectangle {
                    anchors.fill: parent
                    visible: wall.status !== Image.Ready
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0.02, 0.018, 0.016, 1) }
                        GradientStop { position: 1; color: Qt.rgba(world.glassTint.r * 0.7, world.glassTint.g * 0.7, world.glassTint.b * 0.7, 1) }
                    }
                }
                // the wallpaper at its place on the screen (DMS fills the screen with it)
                Image {
                    id: wall
                    source: world.wallpaper !== "" ? "file://" + world.wallpaper : ""
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(world.areaW, world.areaH)
                    fillMode: Image.PreserveAspectCrop
                    x: -clothGap.x
                    y: -clothGap.y - (world.areaH - stage.height)
                    width: world.areaW
                    height: world.areaH
                }
                // the lifted edge casts a soft shadow onto it
                Rectangle {
                    width: parent.width
                    height: Math.min(parent.height, 46)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
                    }
                }
            }
            Repeater {
                model: world.cast
                Loader {
                    id: sl
                    required property var modelData
                    active: modelData.active && modelData.place === "stage"
                    z: world.clothActive && world.clothFor === modelData && world.clothUnder ? 0.5 : 2
                    visible: !(world.capturing && world.clothFor === modelData)
                    x: modelData.x0; y: stage.floor
                    sourceComponent: Creature { st: sl.modelData }
                }
            }
            // the jump rope, behind the figures or in front of them as it goes round
            JumpRope { z: 1.5; front: false; floor: stage.floor }
            JumpRope { z: 2.5; front: true; floor: stage.floor }
            // one cloth per window; between two windows the left hand holds the
            // left one, the right hand the right one
            ClothPiece { win: world.clothWin; hand: world.clothWin2 ? -1 : 1; z: 1 }
            ClothPiece { win: world.clothWin2; hand: 1; z: 1 }
        }
        // niri draws the focus ring just outside the window: the cloth takes it along
        readonly property real ringMargin: 3
        readonly property real clothBottom: world.clothWin.bottom + ringMargin - (world.areaH - stage.height)
        component ClothPiece: Item {
            id: cp
            property var win: null           // { x, w, bottom }
            property real hand: 1            // which side of him the hand is on
            readonly property real bottomLocal: win ? win.bottom - (world.areaH - stage.height) : 0
            visible: world.clothActive && win !== null
            ShaderEffect {
                // only the window's lower part, ending with its focus ring: the gap
                // to the frame and whatever sits in it stay where they are
                visible: cp.win !== null
                readonly property real m: stage.ringMargin
                x: cp.win ? cp.win.x - m : 0
                width: cp.win ? cp.win.w + 2 * m : 1
                height: cp.bottomLocal + m
                mesh: GridMesh { resolution: Qt.size(Math.max(16, Math.round((cp.win ? cp.win.w : 320) / 20)), 24) }
                property variant src: ShaderEffectSource {
                    sourceItem: scv
                    sourceRect: cp.win ? Qt.rect(cp.win.x - stage.ringMargin, world.areaH - stage.height, cp.win.w + 2 * stage.ringMargin, cp.bottomLocal + stage.ringMargin) : Qt.rect(0, 0, 1, 1)
                    hideSource: true
                }
                property real lift: world.clothLift
                property real cx: world.clothX - (cp.win ? cp.win.x - m : 0)
                property real spread: 95
                property real edge: cp.bottomLocal + m
                property real push: cp.hand * world.clothPush
                vertexShader: "shaders/cloth.vert.qsb"
                fragmentShader: "shaders/cloth.frag.qsb"
            }
            // the hand at the cloth's edge, drawn over it so it reads clearly
            // against the dark gap
            Rectangle {
                id: hand
                readonly property var who: world.clothFor
                readonly property bool glassy: who !== null && who.glass
                readonly property bool curtain: world.clothMode === "curtain"
                visible: world.pusher && who !== null && (world.clothLift > 6 || world.clothPush > 6)
                width: who ? who.size * 0.27 : 16
                height: width; radius: width / 2
                // lifting: under the raised edge; curtain: at the edge it pushes aside
                x: curtain ? world.clothX + cp.hand * world.clothPush * 0.92 - width / 2
                           : world.clothX + cp.hand * (who ? who.size * 0.3 : 20) - width / 2
                y: curtain ? cp.bottomLocal - (who ? who.size * 0.55 : 30)
                           : cp.bottomLocal - world.clothLift * 0.93 - height * 0.62
                color: glassy ? who.glassFill : (who ? who.handColor : "white")
                border.width: world.ring ? 1.4 : glassy ? 0 : 1
                border.color: world.ring ? world.alpha(world.primary, 0.9) : Qt.rgba(0, 0, 0, 0.3)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 0.5
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, hand.glassy ? 0.08 : 0.18) }
                        GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, hand.glassy ? 0.28 : 0.12) }
                    }
                }
                Rectangle {
                    x: parent.width * 0.22; y: parent.height * 0.18
                    width: parent.width * 0.32; height: width * 0.6; radius: height / 2
                    rotation: -25
                    color: "white"
                    opacity: hand.glassy ? 0.5 : 0.7
                }
            }
        }
        component StageHit: Item {
            id: sh
            required property var c
            required property int idx
            readonly property bool on: c.active && c.place === "stage" && !c.moving || c.held
            readonly property bool hovered: hov.hovered
            width: on ? c.size * 1.1 : 0
            height: on ? c.size * 0.95 : 0
            x: c.restX - width / 2
            y: stage.floor - height
            HoverHandler { id: hov; onHoveredChanged: if (sh.idx === 0) b0.stageHeld = hovered || bubbleHover.hovered }
            FigMouse { idx: sh.idx; winTop: world.areaH - stage.implicitHeight }
        }
        BallHit { id: ballHitStage; floor: stage.floor; where: "stage" }
        StageHit { id: shit0; c: c0; idx: 0 }
        StageHit { id: shit1; c: c1; idx: 1 }
        StageHit { id: shit2; c: c2; idx: 2 }
        StageHit { id: shit3; c: c3; idx: 3 }
        StageHit { id: shit4; c: c4; idx: 4 }

        Bubble {
            id: bubble
            st: c0
            title: b0.bubbleTitle
            text: b0.bubbleText
            chat: b0.bubbleChat
            shown: b0.bubbleShown && c0.place === "stage" ? 1 : 0
            x: Math.max(world.insets.left + 8, Math.min(parent.width - world.insets.right - width - 8, c0.x0 - width / 2))
            y: stage.floor - c0.size - 30 - height
            tailX: c0.x0 - x
            HoverHandler { id: bubbleHover; onHoveredChanged: b0.stageHeld = hovered || shit0.hovered }
            onSend: text => {
                b0.bubbleText = text
                b0.bubbleTitle = world.tr("Du", "You", "あなた")
                b0.holdStage(90000)
                shell.tell({ t: "chat", text: text })
            }
            onDismiss: b0.leaveStage()
        }
        Connections {
            target: b0
            function onWantFocus() { focusLater.start() }
        }
        Timer { id: focusLater; interval: 120; onTriggered: bubble.focusInput() }
    }

    // ── the chat window ───────────────────────────────────────────
    ChatWindow {
        id: chatWin
        screen: shell.screen
        world: world
        st: c0
        brain: b0
        onSend: text => shell.tell({ t: "chat", text: text })
        onForget: shell.tell({ t: "forget" })
        onPickModel: name => shell.tell({ t: "model", name: name })
        onRunAction: (aid, cmd) => shell.tell({ t: "run", id: aid, cmd: cmd })
        onDeclineAction: aid => shell.tell({ t: "decline", id: aid })
        commands: commands
        onRunShell: (id, cmd) => shell.tell({ t: "shell", id: id, cmd: cmd })
        onKillShell: shell.tell({ t: "shellKill" })
    }
    Commands { id: commands; shell: shell; world: world }
    Connections {
        target: b0
        function onWantFocus() { chatFocus.start() }
    }
    Timer { id: chatFocus; interval: 60; onTriggered: if (world.chatOpen) chatWin.focusInput() }

    // ── IPC, also how to test without a mouse ─────────────────────
    // aibou <function>   (or: qs -p <this dir> ipc call aibou <function>)
    IpcHandler {
        target: "aibou"
        function hello(): void { b0.hello() }
        function visit(): void { b0.visit() }
        function front(): void { b0.wake(true); b0.setFront(!b0.pinned) }
        // toggles; with the window open and him out of it, brings him back in
        function chat(): void { b0.wake(true); if (world.chatOpen && (b0.st.place === "chat" || !world.chatAway)) b0.closeChat(); else b0.openChat() }
        function close(): void { b0.closeChat() }
        function debug(): string { return chatWin.debug() }
        function ask(text: string): void {
            b0.wake(true); b0.openChat()
            if (world.chatBusy) return
            world.logAdd("me", text)
            shell.tell({ t: "chat", text: text })
        }
        function model(name: string): void { world.chatModel = name; shell.tell({ t: "model", name: name }) }
        function forget(): void { world.chatLog.clear(); shell.tell({ t: "forget" }) }
        function dock(): void { for (const b of shell.brains) if (b.st.active && b.doing === "idle" && b.st.place === "home") b.goDock() }
        function undock(): void { for (const b of shell.brains) if (b.st.place === "dock") { b.wake(true); b.leaveDock() } }
        function dockAt(side: string): void {
            for (const b of shell.brains) if (b.st.active && b.doing === "idle" && b.st.place === "home") { b.forceSide = side; b.goDock() }
        }
        function dockToggle(): void { if (c0.place === "dock") undock(); else { b0.wake(true); dock() } }
        function say(text: string): void { b0.toStage("", text, "happy", 5000, false) }
        function play(): void { b0.wake(true); b0.whenFree(() => b0.startPlay()) }
        function stop(): void { for (const b of shell.brains) b.stopPlay(); b0.leaveStage() }
        function sleep(): void { for (const b of shell.brains) if (b.st.active) b.goSleep(true) }
        function wake(): void { for (const b of shell.brains) b.wake(false) }
        function sleepToggle(): void { if (c0.sleeping) wake(); else sleep() }
        function walk(): void { b0.whenFree(() => { if (b0.doing === "idle") b0.startWalk(false) }) }
        function roll(): void { b0.whenFree(() => { if (b0.doing === "idle") b0.startWalk(true) }) }
        function meet(): void { b0.whenFree(() => { if (b0.doing === "idle") b0.meet() }) }
        function mood(name: string): void { c0.mood = name }
        // for tests: other figures until the settings file changes next
        function trySkins(a: string, b: string, c: string): void {
            const v = Object.assign({}, world.settings)
            v.skin1 = a; v.skin2 = b; v.skin3 = c
            world.settings = v
        }
        function clothTest(mode: string): void { shell.clothForce = mode }
        // for tests: settings until the next change of the real ones
        // (aibou trySet tint accent), a strain 0 … 1, a crash
        function trySet(key: string, value: string): void {
            const v = Object.assign({}, world.settings)
            v[key] = value === "true" ? true : value === "false" ? false : value
            world.settings = v
        }
        function strain(v: real): void { world.strain = v }
        function troubleKind(kind: string, name: string): void { world.trouble(kind, name) }
        function trouble(name: string): void { world.trouble("crash", name) }
        function beat(s: real): void { world.music = true; world.beat(s) }
        // for tests: a beat at a tempo (aibou beatAt 0.8 128)
        function beatAt(s: real, bpm: real): void { world.music = true; world.bpm = bpm; world.beat(s) }
        // from DMS (dms-leiste-patch 13): a popout docked to a bar, "side x y w h
        // screen", or "zu" when it closed
        function popout(state: string): void { shell.setPopout(state) }
        function frontAll(on: bool): void { for (const b of shell.brains) if (b.st.active) b.setFront(on) }
        function placeAll(x: real): void {
            for (let i = 0; i < 3; i++) { const c = world.cast[i]; if (c.active && c.place === "home" && !c.moving) { c.x0 = x + i * 110; c.restX = c.x0 } }
        }
        // for tests: put him somewhere at home without walking
        function moveTo(x: real): void { if (c0.place === "home" && !c0.moving) { c0.x0 = Math.max(c0.minX, Math.min(c0.maxX, x)); c0.restX = c0.x0 } }
        // for tests: figure i is picked up, carried to (x, y) and thrown with (vx, vy) px/s
        function throwTest(i: int, x: real, y: real, vx: real, vy: real): void {
            const b = shell.brains[i]
            const gx = b.st.x0, gy = (b.st.place === "sky" ? b.st.y0 : world.floorY) - b.st.size * 0.6
            b.wake(true)
            b.grab(gx, gy)
            const steps = 20
            let k = 0
            const t = Qt.createQmlObject('import QtQuick; Timer { interval: 30; repeat: true }', shell)
            t.triggered.connect(() => {
                k++
                if (k <= steps) { b.drag(gx + (x - gx) * k / steps, gy + (y - gy) * k / steps); return }
                // the last moves at the throw's speed
                b.drag(x + vx * 0.03, y + vy * 0.03)
                b.drag(x + vx * 0.06, y + vy * 0.06)
                b.trail = [{ t: Date.now() - 60, x: x, y: y }, { t: Date.now(), x: x + vx * 0.06, y: y + vy * 0.06 }]
                b.release()
                t.stop(); t.destroy()
            })
            t.start()
        }
        // for tests: figure i is picked up where it is and carried along "x,y;x,y;…"
        // (screen px, 40 ms per point), then let go
        function dragPath(i: int, path: string): void {
            const b = shell.brains[i]
            const pts = path.split(";").map(q => q.split(",").map(Number))
            const at = b.st.place === "dock" ? stage.dockPos(b.st) : null
            const leftSide = (world.barEdge === "left") === (b.st.dockSide === "bar")
            const upright = b.st.dockSide === "bar" || b.st.dockSide === "far"
            const gx = at ? (upright ? (leftSide ? world.insets.left + 6 : world.areaW - world.insets.right - 6) : b.st.x0) : b.st.x0
            const gy = at ? (upright ? b.st.barDockY : b.st.dockSide === "top" ? world.insets.top + 6 : world.floorY - 6)
                          : (b.st.place === "sky" ? b.st.y0 : world.floorY) - b.st.size * 0.6
            b.wake(true)
            b.grab(gx, gy)
            let k = 0
            const t = Qt.createQmlObject('import QtQuick; Timer { interval: 40; repeat: true }', shell)
            t.triggered.connect(() => {
                if (k < pts.length) { b.drag(pts[k][0], pts[k][1]); k++; return }
                b.trail = []
                b.release()
                t.stop(); t.destroy()
            })
            t.start()
        }
        function tickle(i: int): void { shell.clicked(i, Qt.LeftButton) }
        // for tests: the user grabs the ball, carries it to (x, h) and throws it with (vx, vy)
        function handThrowTest(x: real, h: real, vx: real, vy: real): void {
            world.handGrab(world.ballX, world.ballH)
            world.handMove(x, h)
            world.ballTrail = [{ t: Date.now() - 60, x: x - vx * 0.06, h: h - vy * 0.06 }, { t: Date.now(), x: x, h: h }]
            world.handThrow()
        }
        // one figure more or less (kept in the DMS plugin settings)
        function more(): void { shell.tell({ t: "buddies", delta: 1 }) }
        function fewer(): void { shell.tell({ t: "buddies", delta: -1 }) }
        // the last popout DMS reported (dms-leiste-patch 13), for checking
        function popoutState(): string { return JSON.stringify(world.popout) }
        // what DMS is told to draw
        function bodies(): string { return shell.frameBodies }
        // for checking: a few shared values
        function probe(): string {
            return JSON.stringify({ barSpot: world.barSpot, barFlat: world.barFlat, barEdge: world.barEdge,
                                    frameHost: world.frameHost, music: world.music, strain: world.strain,
                                    ball: world.ballOut ? { x: Math.round(world.ballX), h: Math.round(world.ballH), vx: Math.round(world.ballVX),
                                                            holder: world.ballHolder ? world.ballHolder.name : "" } : null,
                                    dockAt: [c0, c1, c2, c3, c4].map(c => c.place === "dock" ? stage.dockPos(c) : null) })
        }
        // for tests: figure i teases, or starts a quarrel with figure j
        // teasing and quarrels by hand happen in front of the windows
        function tease(i: int): void {
            const b = shell.brains[i]
            if (b.st.place === "dock" && b.st.dockSide === "frame" && b.outing()) return
            // the nearest other one comes to the front as well
            const o = world.cast.filter(c => c.active && c !== b.st).sort((p, q) => Math.abs(p.x0 - b.st.x0) - Math.abs(q.x0 - b.st.x0))[0]
            if (!o) return
            o.brain.whenFree(() => {}, true)
            b.whenFree(() => b.tease(o), true)
        }
        function climb(i: int): void { const b = shell.brains[i]; b.whenFree(() => b.climb()) }
        function outing(i: int): void { shell.brains[i].outing() }
        // for tests: figure i walks (or rolls) to x, out of the frame first
        function walkTo(i: int, x: real, roll: bool): void {
            const b = shell.brains[i]
            b.whenFree(() => { b.doing = "walk"; b.walkTarget = x; if (roll && !b.blockedOnWay(x) && b.st.roll(x)) b.doing = "roll"; else b.nextHop() })
        }
        function chatter(i: int): void { shell.brains[i].dockChatter() }
        // for tests: news from the machine as aiboud would send it (kind: recording, download,
        // battery, updates, job; data as JSON)
        function news(kind: string, data: string): void { world.news(kind, JSON.parse(data)) }
        // for tests: as if a window were fullscreen (until niri next reports the windows)
        function fakeFullscreen(on: bool): void { world.fullscreen = on }
        // for tests: the activity menu in the chat window, and picking from it
        function actMenu(open: bool): void { chatWin.actOpen = open }
        function pickActivity(level: string): void { world.activityTest = ""; world.setOption("activity", level) }
        // for tests: measure the bar once without the faces, as when it changed
        function barBareTest(): string { world.barHide = true; barBare.start(); return JSON.stringify(world.barSlots) }
        function barSlots(): string { return JSON.stringify({ slots: world.barSlots.map(Math.round), faces: world.barFaces, hide: world.barHide, gaps: shell.lastGaps.map(g => g.map(Math.round)), size: c0.size }) }
        // for tests: a message for the first figure, as from the notification daemon
        function fakeNotify(text: string): string {
            const behind = !!world.windowOver(c0.x0, c0.size * 0.5)
            b0.notify({ app: "Test", summary: text, body: "", urgency: 1 })
            return "place " + c0.place + ", window over him: " + behind
        }
        // for tests: the first figure grapples, sways and drops
        function grappleDrop(): void { b0.wake(true); b0.grapple(["sway", "drop"]) }
        // for tests: the rope of figure i
        function ropeInfo(i: int): string {
            const c = shell.brains[i].st, b = shell.brains[i]
            return JSON.stringify({ rope: c.rope, hanging: c.hanging, ropeLen: Math.round(c.ropeLen), pivot: [Math.round(c.pivotX), Math.round(c.pivotY)],
                                    hook: [Math.round(c.hookX), Math.round(c.hookY)], hangLen: Math.round(c.hangLen), at: [Math.round(c.x0), Math.round(c.y0)], place: c.place,
                                    doing: b.doing, grStage: b.grStage, shot: c.ropeShot })
        }
        // for tests: why the first figure would not jump for the pointer
        function lungeWhy(): string {
            const b = b0
            return JSON.stringify({ act: b.act, dnd: world.dnd, full: world.fullscreen, saving: world.saving, holder: world.pointerHolder !== null,
                                    sleeping: b.st.sleeping, doing: b.doing, place: b.st.place, moving: b.st.moving, held: b.st.held, flying: b.st.flying,
                                    cool: b.pointerCool > Date.now(), may: b.mayLunge(), x0: b.st.x0, grip: b.gripY(0) })
        }
        // for tests: the first figure idle in front of the windows, at once
        function toFront(): void { b0.st.stopAll(); b0.st.place = "stage"; b0.st.y0 = world.floorY; b0.st.sink = 0; b0.doing = "idle"; b0.stageIdle = 0 }
        // for tests: a pointer position (on this screen), as the pointer stream would bring it
        // for tests: a call from figure i where he is now (aibou shoutTest 0 Hi!)
        function shoutTest(i: int, text: string): void { shell.brains[i].st.call(text) }
        function fakePointer(x: real, y: real): string {
            for (const b of brains) if (b.st.active) b.pointerMoved(x, y)
            return brains.filter(b => b.st.active).map(b => b.st.name + " " + b.doing + " " + Math.round(b.gripY(0))).join(" | ")
        }
        // for tests: do not disturb as DMS would report it
        function fakeDnd(on: bool): void { world.dnd = on }
        // for tests: the activity without touching the settings ("" = back to the setting)
        function activity(level: string): string { world.activityTest = level; return world.activity }
        // for tests: he calls a friend now (alone or not); guestLeave ends the visit
        function callFriend(): bool { return b0.lonely(0, true) }
        // for tests: who dances with whom (Nr. 27)
        function duetInfo(): string {
            return JSON.stringify(shell.brains.filter(b => b.st.active).map(b => ({ name: b.st.name, doing: b.doing, lead: b.duetLead,
                partner: b.partner ? b.partner.name : null, pActive: b.partner ? b.partner.active : null,
                pDoing: b.partner && b.partner.brain ? b.partner.brain.doing : null,
                pPartner: b.partner && b.partner.brain && b.partner.brain.partner ? b.partner.brain.partner.name : null })))
        }
        function guestLeave(): void { b0.endVisit() }
        // for tests: open or close the legend in the chat window
        function legend(on: bool): void { chatWin.legendOpen = on }
        function legendState(): string { return chatWin.legendState() }
        // for tests: the last n lines of the chat window
        function logTail(n: int): string {
            const out = []
            for (let i = Math.max(0, world.chatLog.count - n); i < world.chatLog.count; i++) {
                const e = world.chatLog.get(i)
                out.push(e.who + " | " + e.phase + " | " + e.text + " | " + e.out.replace(/\n/g, "¶"))
            }
            return out.join("\n")
        }
        // for tests: a line typed into the chat window (a command, !shell or for the AI)
        function term(text: string): string {
            if (!chatWin.runLine(text)) return "ai"
            const e = world.chatLog.get(world.chatLog.count - 1)
            return e ? e.who + " | " + e.phase + " | " + e.out : "silent"
        }
        // for tests: figure i asks figure j to dance (music must be playing, or beats via beatAt)
        function duet(i: int, j: int): void {
            const b = shell.brains[i], o = shell.brains[j].st
            b.whenFree(() => { if (b.doing === "idle" && o.brain.doing === "idle") b.startDuet(o) })
        }
        // for tests: figure i walks over to figure j and greets: wave kiss hug five
        function together(i: int, j: int, kind: string): void {
            const b = shell.brains[i], o = shell.brains[j].st
            b.whenFree(() => { if (b.doing === "idle") b.meet(o, kind) })
        }
        // for tests: figure i feels a mood at a level (1 … 3); the brain's timers calm him again
        function feel(i: int, name: string, level: int): void {
            const st = shell.brains[i].st
            st.feeling = true; st.mood = name; st.level = level; st.feeling = false
            st.react()
        }
        // like a click on figure i in the frame
        function fetch(i: int): void { shell.brains[i].wake(true); shell.brains[i].fetchOut() }
        function quarrel(i: int, j: int): void {
            const a = shell.brains[i], b = shell.brains[j]
            b.whenFree(() => {}, true)
            a.whenFree(() => a.quarrelWith(world.cast[j]), true)
        }
        function status(): string {
            return JSON.stringify(shell.brains.filter(b => b.st.active).map(b => ({
                name: b.st.name, doing: b.doing, place: b.st.place, x: Math.round(b.st.x0), y: Math.round(b.st.place === "sky" ? b.st.y0 : world.floorY), mood: b.st.mood, shout: b.st.shout, bubble: b.bubbleShown ? b.bubbleText : "", chat: world.chatOpen,
                sleeping: b.st.sleeping, front: b.pinned, energy: +b.energy.toFixed(2) })))
        }
    }
}

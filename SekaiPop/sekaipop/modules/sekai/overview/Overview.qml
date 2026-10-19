import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The Overview: one card per workspace, each a to-scale mock of the screen with a
// *live picture* of every window on it (ScreencopyView, laid out from real window
// geometry, see services/HyprlandData.qml).
//
// (This used to be the Overview and the App Launcher as one surface, with a search pill
// over the cards. The launcher is gone from here: the Apps screen of the phone does it
// now, with everything the pill could do, see LauncherFace.qml and LauncherExtras.qml.
// `ipc call applauncher ...` and a bare Super tap open that screen, QuickPanel.qml.)
//
// You can drag a window's thumbnail:
//   - onto another workspace card to move that window there
//   - around its own card, if it's floating, to move it on screen
//   - anywhere else and it springs back
// Left-click a thumbnail to focus that window, middle-click to close
// it, click a card's empty space to switch to that workspace. Details
// of the gestures live in OverviewWindowTile.qml.
//
// The Overview is drawn as a strip of video film (FilmStrip.qml): each
// workspace's card is one frame of it, with a column of sprocket holes
// down both sides, and the strip winds past as it scrolls. The strip is a
// tall column of frames that sits on the left, in the middle or on the right
// of the screen (`overview.position`,
// Settings -> Hyprland -> Overview), with 1 to 10 cards (`overview.workspaces`).
// When the cards cannot all be shown at a readable size the column scrolls
// (mouse wheel / touchpad, Up / Down, Page Up / Page Down).
//
// Files:
//   Overview.qml              this one — window, layout maths, dispatches
//   FilmStrip.qml             the film base + sprocket holes behind the cards
//   OverviewWorkspaceCard.qml a card's film frame + drop target
//   OverviewWindowTile.qml    one live thumbnail + the drag
//   services/HyprlandData.qml hyprctl clients / monitors, polled only while open
//
// Way to open it:
//   qs -c sekaipop ipc call overview toggle       (also show / hide)
// Ways to close it: click outside the cards, Escape, focus a window / switch
// workspace from a card, or the keybind again.
//
// It opens on whichever monitor was focused when it fired.
//
// This board is one of two overviews. The option `overview.style`
// (Settings -> Hyprland -> Overview, SettingsService) can swap it for the
// ScrollOverview Hyprland plugin, a niri-style overview the compositor draws
// itself (services/ScrollOverviewService.qml). Every way in below
// (`ipc call overview ...`, the dock's Search key fallback) goes through
// openOn / toggleOn / hide, which pick: with `scroll` they drive the plugin,
// and if the plugin is not loaded they open this board instead.
Scope {
    id: root

    property bool open: false
    property bool closing: false
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // ===== overview sizing =====
    // How many workspace cards (1-10, the `overview.workspaces` option).
    readonly property int workspaceCount: Math.max(1, Math.min(10, Math.round(Number(SettingsService.get("overview.workspaces")) || 5)))
    // Which side of the screen the board sits on: left | center | right.
    readonly property string position: {
        const v = SettingsService.get("overview.position")
        return (v === "left" || v === "right") ? v : "center"
    }
    readonly property real cardSpacing: 16
    readonly property real cellPad: 10          // card edge -> mock screen
    readonly property real headerH: 28          // "Workspace N" strip
    readonly property real edgeGap: 24          // the board's edge -> the screen's (or the bar's) edge
    readonly property real minAreaH: 88         // the smallest a mock screen gets before the column scrolls
    readonly property real fitSlack: 20         // a column this much too tall is let through instead of scrolling a few pixels
    readonly property real maxWidthFraction: 0.34 // of the usable width, film strip included

    // The film strip the cards are frames of (FilmStrip.qml): how far
    // it extends past the row of cards on each side (the sprocket holes
    // sit in the side margins).
    readonly property real boardPadX: 38
    readonly property real boardPadTop: 36
    readonly property real boardPadBottom: 30

    // Same Lua/non-Lua fork Bar.qml and Dock.qml use for their dispatches.
    readonly property bool usingLua: Hyprland.usingLua !== false

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    // True when the ScrollOverview plugin is the one picked (Settings ->
    // Hyprland -> Overview). The board below is then only the fallback.
    readonly property bool scrollStyle: SettingsService.get("overview.style") === "scroll"

    // Opens this shell's own board.
    function openBoard(screen) {
        // Edit Desktop keeps the monitor on one empty workspace: no workspace
        // cards to look at or move windows between while it is on.
        if (EditMode.active)
            return
        if (screen)
            targetScreen = screen
        dragTarget = -1
        dragFrom = -1
        open = true
    }

    function openOn(screen) {
        if (EditMode.active)
            return
        if (root.scrollStyle)
            ScrollOverviewService.run("on", () => root.openBoard(screen))
        else
            root.openBoard(screen)
    }

    // Closes the board (and is what every card / tile calls). It never
    // touches the plugin: the plugin closes itself on a click or Escape.
    function close() {
        open = false
    }

    // Closes whichever overview is up (the `hide` of `ipc call overview`).
    function hide() {
        root.close()
        if (root.scrollStyle && ScrollOverviewService.available)
            ScrollOverviewService.dispatch("off")
    }

    // (Edit Desktop starting closes an open overview: shell.qml's entry point does that,
    // because this board may not be built at the time.)

    function toggleOn(screen) {
        if (open && (!screen || screen === targetScreen)) {
            close()
            return
        }
        if (EditMode.active)
            return
        if (root.scrollStyle)
            ScrollOverviewService.run("toggle", () => root.openBoard(screen))
        else
            root.openBoard(screen)
    }

    // (`ipc call overview toggle | show | hide | style` is answered in shell.qml, by the
    // entry point that builds this board on demand.)

    // ===== open/close animation =====
    property real openT: 0
    property real closeT: 0

    NumberAnimation {
        id: enterAnim
        target: root
        property: "openT"
        to: 1
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 1.5
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "closeT"
        from: 0
        to: 1
        duration: 150
        easing.type: Easing.OutQuad
        onStopped: {
            root.closing = false
            // Back to the starting state for the next open (the window
            // is hidden by now, or about to be reopened from scratch).
            root.closeT = 0
            root.openT = 0
        }
    }

    onOpenChanged: {
        // Window data is only refreshed while we're open.
        HyprlandData.active = open
        if (open) {
            exitAnim.stop()
            root.closing = false
            root.userScrolled = false
            root.scrollToActive()
            enterAnim.restart()
        } else {
            enterAnim.stop()
            root.closing = true
            exitAnim.restart()
        }
    }

    // ===== Overview: window data, geometry, dispatches =====

    function addrKey(t) {
        const a = t ? (t.address ?? "") : ""
        return a.startsWith("0x") ? a : "0x" + a
    }

    // Fresh hyprctl data, else Quickshell's own cached copy (only good
    // for the instant before the first refresh lands).
    function dataFor(t) {
        const d = HyprlandData.windowByAddress[root.addrKey(t)]
        if (d)
            return d
        const l = t ? t.lastIpcObject : null
        return (l && l.at) ? l : null
    }

    // Is this window one the Overview draws?
    function shown(t) {
        const d = root.dataFor(t)
        if (!d || d.mapped === false || d.hidden === true)
            return false
        const ws = d.workspace ? d.workspace.id : -1
        return ws >= 1 && ws <= root.workspaceCount
    }

    function countFor(ws) {
        let n = 0
        for (const t of Hyprland.toplevels.values) {
            if (!root.shown(t))
                continue
            const d = root.dataFor(t)
            if (d.workspace.id === ws)
                n++
        }
        return n
    }

    // A monitor's size in logical pixels and the part of it not eaten by
    // exclusive-zone layers (this shell's own bar), from `hyprctl
    // monitors -j`. `reserved` is [left, top, right, bottom].
    function monGeom(m) {
        if (!m)
            return null
        const swap = (m.transform ?? 0) % 2 === 1
        const sc = m.scale || 1
        const lw = (swap ? m.height : m.width) / sc
        const lh = (swap ? m.width : m.height) / sc
        const r = m.reserved ?? [0, 0, 0, 0]
        return {
            x: m.x ?? 0,
            y: m.y ?? 0,
            l: r[0],
            t: r[1],
            r: r[2],
            b: r[3],
            uw: Math.max(1, lw - r[0] - r[2]),
            uh: Math.max(1, lh - r[1] - r[3])
        }
    }

    // The monitor this Overview is showing on.
    readonly property var overviewMonitor: {
        const name = root.targetScreen ? root.targetScreen.name : ""
        return HyprlandData.monitors.find(m => m.name === name) ?? null
    }
    readonly property int overviewMonitorId: root.overviewMonitor ? root.overviewMonitor.id : -1
    readonly property var overviewGeom: {
        const g = root.monGeom(root.overviewMonitor)
        if (g)
            return g
        // No hyprctl data yet: fall back to the screen's own size.
        const w = root.targetScreen ? root.targetScreen.width : 1920
        const h = root.targetScreen ? root.targetScreen.height : 1080
        return { x: 0, y: 0, l: 0, t: 0, r: 0, b: 0, uw: Math.max(1, w), uh: Math.max(1, h) }
    }

    // The workspace showing on this monitor right now.
    readonly property int activeWs: {
        const m = root.targetScreen ? Hyprland.monitorFor(root.targetScreen) : null
        return (m && m.activeWorkspace) ? m.activeWorkspace.id : 1
    }

    // ===== card geometry: one column of cards =====
    // The part of the screen the board may use: the screen minus whatever the bar
    // (or anything else with an exclusive zone) keeps, in this overlay's design
    // pixels (the overlay is screen size / the monitor's scale, see ScaleHost below).
    readonly property real scaleFactor: ShellScale.forScreen(root.targetScreen) || 1
    readonly property real insetL: root.overviewGeom.l / root.scaleFactor
    readonly property real insetT: root.overviewGeom.t / root.scaleFactor
    readonly property real insetR: root.overviewGeom.r / root.scaleFactor
    readonly property real insetB: root.overviewGeom.b / root.scaleFactor
    readonly property real usableW: Math.max(200, overlayRoot.width - root.insetL - root.insetR)
    readonly property real usableH: Math.max(200, overlayRoot.height - root.insetT - root.insetB)

    // The tallest the column of cards may be on screen, and the widest a card's
    // mock screen may be (so one or two workspaces do not make giant cards).
    readonly property real maxColH: Math.max(120, root.usableH - root.edgeGap * 2 - root.boardPadTop - root.boardPadBottom)
    readonly property real maxAreaW: Math.max(80, Math.min(root.usableW * root.maxWidthFraction - root.boardPadX * 2 - root.cellPad * 2, 560))
    readonly property real aspect: root.overviewGeom.uw / root.overviewGeom.uh

    // Every card gets an equal share of the height, but never a mock screen
    // shorter than `minAreaH`: past that the column scrolls instead.
    readonly property real areaH0: Math.max(root.minAreaH, Math.min(
        (root.maxColH - (root.workspaceCount - 1) * root.cardSpacing) / root.workspaceCount - root.headerH - root.cellPad,
        root.maxAreaW / root.aspect))
    readonly property real areaH: Math.floor(root.areaH0)
    readonly property real areaW: Math.floor(root.areaH0 * root.aspect)
    readonly property real cardW: root.areaW + root.cellPad * 2
    readonly property real cardH: root.headerH + root.areaH + root.cellPad
    readonly property real cardStep: root.cardH + root.cardSpacing

    // The whole column, and how much of it shows at once.
    readonly property real colH: root.workspaceCount * root.cardH + (root.workspaceCount - 1) * root.cardSpacing
    readonly property real viewH: Math.min(root.colH, root.maxColH + root.fitSlack)
    readonly property bool scrollable: root.colH > root.viewH + 0.5
    readonly property real maxScroll: Math.max(0, root.colH - root.viewH)

    // Where the strip goes (its outer edge, in overlay pixels).
    readonly property real boardW: root.cardW + root.boardPadX * 2
    readonly property real boardH: root.viewH + root.boardPadTop + root.boardPadBottom
    readonly property real boardX: Math.round(root.position === "left"
        ? root.insetL + root.edgeGap
        : (root.position === "right"
            ? overlayRoot.width - root.insetR - root.edgeGap - root.boardW
            : root.insetL + (root.usableW - root.boardW) / 2))
    readonly property real boardY: Math.round(root.insetT + (root.usableH - root.boardH) / 2)

    // ===== scrolling the column =====
    property real scrollY: 0          // what is drawn (eases toward scrollTarget)
    property real scrollTarget: 0     // where the wheel has sent it
    property bool userScrolled: false // the user moved it since it opened
    readonly property real scrollEff: Math.max(0, Math.min(root.scrollY, root.maxScroll))

    NumberAnimation {
        id: scrollAnim
        target: root
        property: "scrollY"
        duration: 140
        easing.type: Easing.OutCubic
    }

    function scrollBy(px) {
        root.userScrolled = true
        root.scrollTarget = Math.max(0, Math.min(root.maxScroll, root.scrollTarget + px))
        scrollAnim.stop()
        scrollAnim.to = root.scrollTarget
        scrollAnim.start()
    }

    // Puts the card of the workspace you are on in the middle of the view, at once.
    function scrollToActive() {
        scrollAnim.stop()
        const v = Math.max(0, Math.min(root.maxScroll,
            (root.activeWs - 1) * root.cardStep + root.cardH / 2 - root.viewH / 2))
        root.scrollTarget = v
        root.scrollY = v
    }

    // The monitor's real size can land after the board opens (hyprctl is only
    // asked while it is open): keep the active card in view until the user scrolls.
    onCardHChanged: {
        if (root.open && !root.userScrolled)
            root.scrollToActive()
    }

    // Thumbnails are only captured while they can be seen: not once closed.
    readonly property bool captureActive: win.visible

    // Where a window goes on the card row, in the coordinates of the
    // shared `windowSpace` layer. Positions are worked out as fractions
    // of the window's *own* monitor's usable area, then multiplied by
    // this card's mock screen, so a window on a second monitor lands in
    // the right proportional spot too. Anything hanging off the edge is
    // clipped to the card.
    function rectFor(d) {
        if (!d || !d.at || !d.size)
            return null
        const ws = d.workspace ? d.workspace.id : -1
        if (ws < 1 || ws > root.workspaceCount)
            return null
        const g = root.monGeom(HyprlandData.monitors.find(m => m.id == d.monitor))
        if (!g)
            return null

        let fx0 = (d.at[0] - g.x - g.l) / g.uw
        let fy0 = (d.at[1] - g.y - g.t) / g.uh
        let fx1 = fx0 + d.size[0] / g.uw
        let fy1 = fy0 + d.size[1] / g.uh
        fx0 = Math.max(0, fx0)
        fy0 = Math.max(0, fy0)
        fx1 = Math.min(1, fx1)
        fy1 = Math.min(1, fy1)
        if (fx1 - fx0 < 0.005 || fy1 - fy0 < 0.005)
            return null

        const ox = root.cellPad
        const oy = (ws - 1) * root.cardStep + root.headerH
        return {
            x: ox + fx0 * root.areaW,
            y: oy + fy0 * root.areaH,
            w: (fx1 - fx0) * root.areaW,
            h: (fy1 - fy0) * root.areaH,
            monitorId: d.monitor,
            floating: d.floating === true,
            fullscreen: d.fullscreen ?? 0
        }
    }

    // ===== dispatches =====
    function focusWindow(d) {
        if (!d)
            return
        root.close()
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.focus({ window = \"address:" + d.address + "\" })"
            : "focuswindow address:" + d.address)
    }

    function closeWindow(d) {
        if (!d)
            return
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.window.close({ window = \"address:" + d.address + "\" })"
            : "closewindow address:" + d.address)
    }

    function switchToWorkspace(id) {
        root.close()
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.focus({ workspace = " + id + " })"
            : "workspace " + id)
    }

    function moveWindowToWorkspace(address, workspaceId) {
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.window.move({ workspace = " + workspaceId + ", follow = false, window = \"address:" + address + "\" })"
            : "movetoworkspacesilent " + workspaceId + ",address:" + address)
    }

    // x / y are absolute, in the same layout coordinates hyprctl's own
    // `at` uses.
    function moveFloatingWindow(address, x, y) {
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.window.move({ x = \"" + x + "\", y = \"" + y + "\", window = \"address:" + address + "\" })"
            : "movewindowpixel exact " + x + " " + y + ",address:" + address)
    }

    // ===== drag state =====
    property int dragFrom: -1
    property int dragTarget: -1

    function finishDrop(d, dx, dy) {
        const target = root.dragTarget
        root.dragTarget = -1
        root.dragFrom = -1
        if (!d || target === -1)
            return

        const ws = d.workspace ? d.workspace.id : -1
        if (target !== ws) {
            root.moveWindowToWorkspace(d.address, target)
            return
        }

        // Dropped back on its own card: only a floating window has a
        // position to change; a tiled one just springs back.
        if (d.floating !== true || !d.at)
            return
        if (Math.abs(dx) + Math.abs(dy) < 4)
            return
        const g = root.monGeom(HyprlandData.monitors.find(m => m.id == d.monitor))
        if (!g)
            return
        // Move it by how far it was dragged, converted from the mock
        // screen's pixels back to real ones.
        root.moveFloatingWindow(d.address,
            Math.round(d.at[0] + dx * g.uw / root.areaW),
            Math.round(d.at[1] + dy * g.uh / root.areaH))
    }

    // ===== The window =====
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.open || root.closing
        color: "transparent"

        // A full-screen overlay rather than a small popup: input
        // outside the pill/cards needs to reach *us* (to close on
        // click), not fall through to whatever's underneath, and a
        // fixed-size fullscreen surface means the animation only ever
        // resizes QML items inside it, never the actual Wayland
        // surface — QuickPanel.qml's railStaticBounds comment covers
        // why that matters.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore

        // WlrKeyboardFocus.Exclusive is the only one of the three
        // levels that reliably delivers key events to a layer-shell
        // surface the moment it maps rather than only after a click —
        // see WlrKeyboardFocus's own docs on OnDemand being unreliable
        // for exactly this. It also routes pointer input to this
        // surface regardless of output, which is a feature here: every
        // monitor's clicks land on it and count as "outside", not a leak.
        WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekaipop-overview"

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => keyCatcher.forceActiveFocus())
        }

        // The whole overlay is drawn inside a ScaleHost: overlayRoot below
        // is (screen size / this monitor's scale) big — so its own maths
        // (the card row's share of the width, the pill's 12% drop) all
        // still work in design pixels — and comes out scaled up or down
        // to fill the real screen. See scale.json / ShellScale.qml.
        ScaleHost {
            anchors.fill: parent
            factor: ShellScale.forScreen(root.targetScreen)

            Item {
                id: overlayRoot
                anchors.fill: parent

                // Click anywhere outside the pill / cards / results closes
                // it. Declared first (bottom of the stack) so everything
                // with its own MouseArea takes the click instead.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // No dark tint behind the launcher / overview any more: the
                // desktop stays as it is. This stays as an all-but-invisible
                // layer (opacity 0.001, was up to 0.4 dark) so the surface
                // is still drawn and catches clicks exactly as before.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colDeep
                    opacity: 0.001
                }

                // ===== the Overview =====
                Item {
                    id: overviewLayer

                    readonly property real showT: Math.max(0, Math.min(1, (root.openT - 0.35) / 0.65))

                    // The cards' column. The film strip reaches boardPadX / boardPadTop /
                    // boardPadBottom past it. A strip on the left or right edge slides in
                    // from that edge a little as it fades in.
                    x: Math.round(root.boardX + root.boardPadX
                        + (root.position === "left" ? -1 : (root.position === "right" ? 1 : 0)) * (1 - showT) * 70)
                    y: Math.round(root.boardY + root.boardPadTop)
                    width: root.cardW
                    height: root.viewH

                    // Fades in as the window opens.
                    opacity: showT * (1 - root.closeT)
                    visible: opacity > 0.001
                    scale: (0.95 + 0.05 * showT) * (1 - 0.02 * root.closeT)
                    transformOrigin: root.position === "left" ? Item.Left
                        : (root.position === "right" ? Item.Right : Item.Center)

                    // The film strip, behind everything. It eats clicks on its
                    // own surface so a slightly-off click between two cards
                    // doesn't close the Overview; clicking outside it does.
                    FilmStrip {
                        x: -root.boardPadX
                        y: -root.boardPadTop
                        width: root.boardW
                        height: root.boardH

                        frames: root.workspaceCount
                        frameStep: root.cardStep
                        frameHeight: root.cardH
                        topOffset: root.boardPadTop
                        scrollOffset: root.scrollEff
                        sideWidth: root.boardPadX

                        MouseArea {
                            anchors.fill: parent
                        }
                    }

                    // The cards and the thumbnails over them live in `content`, which
                    // slides up and down inside `viewport` when the column is taller
                    // than the screen. The viewport only clips while it has to, and
                    // keeps clear of the strip's edge.
                    Item {
                        id: viewport

                        readonly property real insetX: 14
                        readonly property real insetY: 10

                        x: -root.boardPadX + viewport.insetX
                        y: -root.boardPadTop + viewport.insetY
                        width: root.boardW - viewport.insetX * 2
                        height: root.boardH - viewport.insetY * 2
                        clip: root.scrollable

                        // One wheel feel for the whole shell (WheelScroll.qml): a mouse
                        // notch is Theme.wheelStep px, a touchpad follows the fingers.
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                if (!root.scrollable)
                                    return
                                root.scrollBy(-Theme.wheelPx(event))
                            }
                        }

                        Item {
                            id: content
                            x: root.boardPadX - viewport.insetX
                            y: root.boardPadTop - viewport.insetY - root.scrollEff
                            width: root.cardW
                            height: root.colH

                            Repeater {
                                model: root.workspaceCount
                                delegate: OverviewWorkspaceCard {
                                    required property int index

                                    workspaceId: index + 1
                                    x: 0
                                    y: index * root.cardStep
                                    width: root.cardW
                                    height: root.cardH
                                    areaWidth: root.areaW
                                    areaHeight: root.areaH
                                    cellPad: root.cellPad
                                    headerHeight: root.headerH
                                    windowCount: root.countFor(index + 1)

                                    onClicked: root.switchToWorkspace(workspaceId)
                                    onDragEntered: root.dragTarget = workspaceId
                                    onDragExited: {
                                        if (root.dragTarget === workspaceId)
                                            root.dragTarget = -1
                                    }
                                }
                            }

                            // Every window thumbnail, in one layer above all the
                            // cards (see OverviewWindowTile.qml for why).
                            Item {
                                id: windowSpace
                                anchors.fill: parent

                                Repeater {
                                    // The toplevel objects themselves are the model
                                    // values, so ScriptModel keeps a tile alive (and
                                    // its capture running) as windows come and go
                                    // instead of rebuilding every tile each time.
                                    model: ScriptModel {
                                        values: Hyprland.toplevels.values.filter(t => root.shown(t))
                                    }
                                    delegate: OverviewWindowTile {
                                        required property var modelData

                                        toplevel: modelData
                                        grid: root

                                        onActivated: data => root.focusWindow(data)
                                        onCloseRequested: data => root.closeWindow(data)
                                        onDragBegan: data => root.dragFrom = data && data.workspace ? data.workspace.id : -1
                                        onDragEnded: (data, dx, dy) => root.finishDrop(data, dx, dy)
                                    }
                                }

                                // The workspace you're on: a blue ring on its mock
                                // screen, above the tiles so a maximised window
                                // doesn't hide it, sliding between cards.
                                Rectangle {
                                    z: 50000
                                    x: root.cellPad
                                    y: (root.activeWs - 1) * root.cardStep + root.headerH
                                    width: root.areaW
                                    height: root.areaH
                                    radius: 6
                                    color: "transparent"
                                    border.width: 3
                                    border.color: ScrapbookTheme.accentCurrent
                                    visible: root.activeWs >= 1 && root.activeWs <= root.workspaceCount
                                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }

                                // While a tile is carried over a *different* card:
                                // a green ring on the one it would land on.
                                Rectangle {
                                    z: 50001
                                    x: root.cellPad
                                    y: (root.dragTarget - 1) * root.cardStep + root.headerH
                                    width: root.areaW
                                    height: root.areaH
                                    radius: 6
                                    color: "transparent"
                                    border.width: 3
                                    border.color: Qt.darker(ScrapbookTheme.tapeMint, 1.3)
                                    visible: root.dragFrom !== -1 && root.dragTarget !== -1 && root.dragTarget !== root.dragFrom
                                }
                            }
                        }
                    }

                    // A thin scroll marker on the strip's right rail, past the sprocket
                    // holes, only while the column is taller than the screen.
                    Rectangle {
                        visible: root.scrollable
                        x: root.cardW + root.boardPadX - 8
                        width: 4
                        radius: 2
                        color: ScrapbookTheme.filmHole
                        opacity: 0.6
                        height: Math.max(28, root.viewH * root.viewH / root.colH)
                        y: (root.viewH - height) * (root.maxScroll > 0 ? root.scrollEff / root.maxScroll : 0)
                    }
                }

                // Takes the keyboard so Escape closes it (there is no search box any more); Up / Down
                // and Page Up / Page Down scroll a column that is taller than the screen.
                Item {
                    id: keyCatcher
                    focus: true
                    Keys.onEscapePressed: root.close()
                    Keys.onUpPressed: root.scrollBy(-root.cardStep)
                    Keys.onDownPressed: root.scrollBy(root.cardStep)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageUp) {
                            root.scrollBy(-root.cardStep * 3)
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageDown) {
                            root.scrollBy(root.cardStep * 3)
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}

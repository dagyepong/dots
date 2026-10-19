pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common

// Edit Desktop's state — one singleton, so every window that has to take
// part (the wallpaper, the clock and to-do widgets, the shelf, the
// right-click menu) reads the same few numbers instead of talking to each
// other.
//
// What the mode does, in one picture: the desktop (wallpaper + widgets + the
// bar and the dock) shrinks into a framed sticker card in the middle of the screen, the rest
// of the screen becomes a dark diamond-pattern stage, and a shelf (EditTray.qml)
// slides up from the bottom edge. The shelf shows every desktop widget as it
// really looks (a live snapshot of the widget's own card, see EditPreview.qml).
//
//   - left click a widget on the shelf   add it to the desktop (or, if it is
//                                        already there, select it for editing)
//   - left click a widget on the card    select it to EDIT it: it works like it
//                                        does on the normal desktop (the clock's
//                                        double-click and style button, the
//                                        To-Do's tasks, the avatar), and it can
//                                        still be dragged
//   - left drag a widget on the card     move it
//   - right click a widget (card or shelf)   remove it
//   - click the bare card, or Esc        stop editing the selected widget
//   - Done (or Esc again)                leave
//
// How the shrinking is shared: each window draws its own piece of the
// desktop, so each one applies the SAME transform, worked out here from the
// same `progress`. `progress` is the one animated number (0 = the normal
// desktop, 1 = the card); the rest of this file is arithmetic on it.
//
//   EditMode.open("DP-1")      start editing that monitor
//   EditMode.close()
//   EditMode.openMenu(screen, x, y)   the right-click menu (DesktopMenu.qml)
//
//   qs -c sekaipop ipc call desktopedit toggle   (also: open / close)
//
// "Lock all" (see below): a saved switch, changed from the shelf's tile. It
// decides whether widgets can be dragged on the normal desktop; while editing
// it is ignored.
//
// The windows it is read from: WallpaperLayer.qml (backdrop + frame),
// EditStage.qml (wraps the widget, bar and dock windows' content),
// EditChrome.qml (the outline / drag shield / right-click remove),
// EditPreview.qml (each widget's snapshot for the shelf), EditTray.qml +
// EditTraySlot.qml (the shelf), DesktopMenu.qml.
//
// The bar and the dock draw through an EditStage too. Their windows are as
// big as the screen across their strip and never change size (resizing a
// layer-shell window that is anchored to the bottom or right edge shows its
// old picture in the wrong place for a frame or two, which is what made them
// jump when the mode started and ended); only their input region is the strip,
// and it is emptied while editing: in the card they are pictures.
Singleton {
    id: root

    // ===== state =====
    property bool active: false
    // The monitor being edited. Stays set while the card grows back to a
    // full desktop, so the windows can finish their exit animation.
    property string screenName: ""
    // 0 = normal desktop .. 1 = the card (overshoots a little on the way in).
    property real progress: 0

    // ===== the right-click menu =====
    property bool menuOpen: false
    property string menuScreen: ""
    property real menuX: 0           // window pixels, from the screen's top-left
    property real menuY: 0

    // ===== layout =====
    readonly property real trayHeight: 220       // the strip the shelf takes, gap included
    readonly property real frameWidth: 14        // navy outline + white ring around the card
    readonly property real cardRadius: 22        // the card's own corner
    readonly property real gap: 22               // space between the frame and whatever is next to it

    function editing(name) {
        return root.screenName !== "" && root.screenName === name
    }

    // ===== the shelf's tab =====
    property string requestedTab: "widgets"
    property int tabSerial: 0
    property string currentTab: "widgets"

    function showTab(tab) {
        root.requestedTab = tab
        root.tabSerial = root.tabSerial + 1
    }

    // ===== the selected widget =====
    property string editTarget: ""

    function select(id) {
        root.editTarget = (root.active && typeof id === "string") ? id : ""
    }

    // A one-shot "look here": the widget with this id flashes its outline
    // (EditChrome.qml listens to pingSerial).
    property string pingId: ""
    property int pingSerial: 0

    function ping(id) {
        root.pingId = id
        root.pingSerial = root.pingSerial + 1
    }

    // ===== what each widget looks like =====
    property var previewUrls: ({})
    property var previewSizes: ({})

    function setPreview(id, url, w, h) {
        const u = Object.assign({}, root.previewUrls)
        const z = Object.assign({}, root.previewSizes)
        if (url === "") {
            delete u[id]
            delete z[id]
        } else {
            u[id] = url
            z[id] = { w: w, h: h }
        }
        root.previewUrls = u
        root.previewSizes = z
    }

    // ===== the widgets =====
    readonly property var widgetList: [
        { id: "clock", title: "Clock", icon: "schedule" },
        { id: "usercard", title: "User card", icon: "badge" },
        { id: "weathercard", title: "Weather", icon: "partly_cloudy_day" },
        { id: "calendarcard", title: "Calendar", icon: "calendar_month" },
        { id: "todo", title: "To-Do", icon: "checklist" },
        { id: "notes", title: "Sticky Notes", icon: "sticky_note_2" },
        { id: "visualizer", title: "Visualizer", icon: "graphic_eq" },
        // Not one widget but a way to make them: it is never "on the desktop", so a click
        // always adds another frame, an EMPTY one that is on the desktop at once (nothing
        // is asked first; files are dropped on it, see ImageWidget.qml). Each picture on
        // the desktop is then its own id, "image:<id>", edited and removed like the
        // others, though it has no tile of its own.
        { id: "image", title: "Image", icon: "add_photo_alternate" },
        { id: "palettecard", title: "Palette", icon: "palette" },
        { id: "lyrics", title: "Lyrics", icon: "lyrics" }
    ]

    // The monitor a widget really lives on: the one it was last dropped on, or
    // the first one if that is not plugged in (or it never was dropped).
    function homeScreen(saved) {
        for (const s of Quickshell.screens) {
            if (s.name === saved)
                return saved
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function widgetShown(id) {
        if (id === "clock")
            return ClockService.shown
        if (id === "usercard")
            return UserCardService.shown
        if (id === "weathercard")
            return WeatherCardService.shown
        if (id === "calendarcard")
            return CalendarCardService.shown
        if (id === "palettecard")
            return PaletteService.shown
        if (id === "lyrics")
            return LyricsService.shown
        if (id === "todo")
            return TodoService.shown
        if (id === "notes")
            return NotesService.active
        if (id === "visualizer")
            return VisualizerService.shown
        if (id === "image")
            return ImageService.shown
        if (id.indexOf("image:") === 0)
            return ImageService.shown && ImageService.rec(id.slice(6)) !== null
        return false
    }

    // On the card being edited right now: switched on AND on this monitor.
    function widgetOn(id) {
        if (!root.widgetShown(id) || root.screenName === "")
            return false
        if (id === "clock")
            return root.homeScreen(ClockService.screenName) === root.screenName
        if (id === "usercard")
            return root.homeScreen(UserCardService.screenName) === root.screenName
        if (id === "weathercard")
            return root.homeScreen(WeatherCardService.screenName) === root.screenName
        if (id === "calendarcard")
            return root.homeScreen(CalendarCardService.screenName) === root.screenName
        if (id === "palettecard")
            return root.homeScreen(PaletteService.screenName) === root.screenName
        if (id === "lyrics")
            return root.homeScreen(LyricsService.screenName) === root.screenName
        if (id === "visualizer")
            return root.homeScreen(VisualizerService.screenName) === root.screenName
        // The shelf's Image tile is a button, not a widget: it is never "placed".
        if (id === "image")
            return false
        if (id.indexOf("image:") === 0) {
            const r = ImageService.rec(id.slice(6))
            return r !== null && root.homeScreen(r.screen) === root.screenName
        }
        // The To-Do card and the Sticky Notes are always on the first monitor.
        return root.homeScreen("") === root.screenName
    }

    // Brings a widget onto the card. One that lives on another monitor is moved
    // here (and goes back to its first spot, which is on screen here: the
    // clock's is the right edge, vertically centred).
    function addWidget(id) {
        const here = root.screenName
        if (id === "clock") {
            if (here !== "" && root.homeScreen(ClockService.screenName) !== here) {
                ClockService.posX = -1
                ClockService.posY = -1
                ClockService.screenName = here
            }
            ClockService.setShown(true)
        } else if (id === "usercard") {
            if (here !== "" && root.homeScreen(UserCardService.screenName) !== here) {
                UserCardService.posX = -1
                UserCardService.posY = -1
                UserCardService.screenName = here
            }
            UserCardService.setShown(true)
        } else if (id === "weathercard") {
            if (here !== "" && root.homeScreen(WeatherCardService.screenName) !== here) {
                WeatherCardService.posX = -1
                WeatherCardService.posY = -1
                WeatherCardService.screenName = here
            }
            WeatherCardService.setShown(true)
        } else if (id === "calendarcard") {
            if (here !== "" && root.homeScreen(CalendarCardService.screenName) !== here) {
                CalendarCardService.posX = -1
                CalendarCardService.posY = -1
                CalendarCardService.screenName = here
            }
            CalendarCardService.setShown(true)
        } else if (id === "palettecard") {
            if (here !== "" && root.homeScreen(PaletteService.screenName) !== here) {
                PaletteService.posX = -1
                PaletteService.posY = -1
                PaletteService.screenName = here
            }
            PaletteService.setShown(true)
        } else if (id === "lyrics") {
            if (here !== "" && root.homeScreen(LyricsService.screenName) !== here) {
                LyricsService.posX = -1
                LyricsService.posY = -1
                LyricsService.screenName = here
            }
            LyricsService.setShown(true)
        } else if (id === "visualizer") {
            if (here !== "" && root.homeScreen(VisualizerService.screenName) !== here) {
                VisualizerService.posX = -1
                VisualizerService.posY = -1
                VisualizerService.bandY = -1
                VisualizerService.bandX = -1
                VisualizerService.screenName = here
            }
            VisualizerService.setShown(true)
        } else if (id === "todo") {
            TodoService.setShown(true)
        } else if (id === "image") {
            // An empty frame lands on this monitor, at once, and is selected.
            ImageService.setShown(true)
            ImageService.addEmpty(here)
        } else if (id === "notes") {
            // Makes a first note when there is none yet.
            NotesService.setShown(true)
        }
    }

    function removeWidget(id) {
        if (root.editTarget === id)
            root.editTarget = ""
        if (id === "clock")
            ClockService.setShown(false)
        else if (id === "usercard")
            UserCardService.setShown(false)
        else if (id === "weathercard")
            WeatherCardService.setShown(false)
        else if (id === "calendarcard")
            CalendarCardService.setShown(false)
        else if (id === "palettecard")
            PaletteService.setShown(false)
        else if (id === "lyrics")
            LyricsService.setShown(false)
        else if (id === "todo")
            TodoService.setShown(false)
        else if (id === "notes")
            NotesService.setShown(false)
        else if (id === "visualizer")
            VisualizerService.setShown(false)
        else if (id.indexOf("image:") === 0)
            ImageService.remove(id.slice(6))
    }

    // ===== Lock all =====
    property bool widgetsLocked: true
    property bool lockLoaded: false
    readonly property bool desktopDragAllowed: !root.widgetsLocked && root.screenName === ""

    function setWidgetsLocked(value) {
        root.widgetsLocked = value
        if (root.lockLoaded)
            lockSaver.save(JSON.stringify({ widgetsLocked: root.widgetsLocked }))
    }

    function toggleWidgetsLocked() {
        root.setWidgetsLocked(!root.widgetsLocked)
    }

    readonly property string lockScript: Directories.script("state/edit-state.sh")

    function restoreLock(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.widgetsLocked === "boolean")
                root.widgetsLocked = s.widgetsLocked
        } catch (e) {
            // No file yet (first run) or an unreadable one: stay locked.
        }
        root.lockLoaded = true
    }

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.lockScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restoreLock(text)
        }
    }

    // Fire-and-forget save that never drops the last state (same as the
    // widgets' services).
    Process {
        id: lockSaver

        property var pending: null

        function save(json) {
            if (lockSaver.running) {
                lockSaver.pending = json
                return
            }
            lockSaver.pending = null
            lockSaver.exec(["sh", root.lockScript, "save", json])
        }

        onExited: {
            if (lockSaver.pending !== null) {
                const json = lockSaver.pending
                lockSaver.pending = null
                lockSaver.exec(["sh", root.lockScript, "save", json])
            }
        }
    }

    // This window's share of the animation: nothing on the other monitors.
    function progressFor(name) {
        return root.editing(name) ? root.progress : 0
    }

    // Where the card ends up (progress = 1) for a screen of w x h real pixels
    // on a monitor scaled by `ui`: the biggest copy of the screen that fits
    // between the shelf and the margins, centred in what is left. The card
    // is the WHOLE screen, bar and dock included (they shrink with the
    // wallpaper: Bar.qml and Dock.qml draw through an EditStage), so nothing
    // is reserved for them.
    function cardRect(w, h, ui) {
        const pad = (root.gap + root.frameWidth) * ui
        let l = pad
        let t = pad
        let r = w - pad
        let b = h - pad
        b -= root.trayHeight * ui
        const vw = Math.max(1, r - l)
        const vh = Math.max(1, b - t)
        const s = Math.max(0.05, Math.min(vw / Math.max(1, w), vh / Math.max(1, h)))
        return { x: l + (vw - w * s) / 2, y: t + (vh - h * s) / 2, s: s }
    }

    // The transform a window applies to its whole content (origin: top-left)
    // right now.
    function scaleFor(name, w, h, ui) {
        const p = root.progressFor(name)
        return 1 + (root.cardRect(w, h, ui).s - 1) * p
    }

    function xFor(name, w, h, ui) {
        return root.cardRect(w, h, ui).x * root.progressFor(name)
    }

    function yFor(name, w, h, ui) {
        return root.cardRect(w, h, ui).y * root.progressFor(name)
    }

    // ===== opening and closing =====
    readonly property bool usingLua: Hyprland.usingLua !== false

    function focusedScreenName() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return name
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function openMenu(screen, x, y) {
        // Game Mode takes the widgets away, so there is nothing to edit.
        if (root.active || LockState.locked || GameModeService.enabled)
            return
        root.menuScreen = screen
        root.menuX = x
        root.menuY = y
        root.menuOpen = true
    }

    function closeMenu() {
        root.menuOpen = false
    }

    function open(screen, tab) {
        if (root.active || LockState.locked || GameModeService.enabled)
            return
        root.requestedTab = (typeof tab === "string" && tab !== "") ? tab : "widgets"
        const name = (typeof screen === "string" && screen !== "") ? screen : root.focusedScreenName()
        if (name === "")
            return
        root.menuOpen = false
        root.editTarget = ""
        root.screenName = name
        root.active = true
        root.park(name)
        exitAnim.stop()
        enterAnim.restart()
    }

    function close() {
        if (!root.active)
            return
        root.active = false
        root.editTarget = ""
        root.unpark()
        enterAnim.stop()
        exitAnim.restart()
    }

    function toggle() {
        if (root.active)
            root.close()
        else
            root.open("")
    }

    // The way in is a pop (it overshoots the card a touch and settles, like
    // the Quick Panel coming out of a pocket); the way out is a plain ease.
    NumberAnimation {
        id: enterAnim
        target: root
        property: "progress"
        to: 1
        duration: 560
        easing.type: Easing.OutBack
        easing.overshoot: 1.25
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "progress"
        to: 0
        duration: 360
        easing.type: Easing.InOutCubic
        onFinished: {
            if (!root.active)
                root.screenName = ""
        }
    }

    // ===== getting the windows out of the way =====
    property int savedWorkspace: 0
    property string savedMonitor: ""
    property string toggledSpecial: ""

    function dispatch(lua, classic) {
        Hyprland.dispatch(root.usingLua ? lua : classic)
    }

    function park(name) {
        root.savedWorkspace = 0
        root.savedMonitor = ""
        root.toggledSpecial = ""
        root.holdWorkspace = 0
        settle.stop()
        probe.running = true
    }

    // `hyprctl -j clients` and `-j monitors` in one JSON document.
    Process {
        id: probe
        command: ["sh", "-c", "printf '{\"c\":'; hyprctl -j clients; printf ',\"m\":'; hyprctl -j monitors; printf '}'"]
        stdout: StdioCollector {
            onStreamFinished: root.parkFrom(text)
        }
    }

    function parkFrom(text) {
        // Closed again before the answer came back.
        if (!root.active || root.screenName === "")
            return
        try {
            const d = JSON.parse(text)
            const name = root.screenName
            const m = (d.m || []).find(x => x.name === name)
            if (!m)
                return
            const ws = m.activeWorkspace ? m.activeWorkspace.id : 0

            // A special workspace (a scratchpad) shown over the desktop is
            // closed first, the same way the lock does it.
            const sp = m.specialWorkspace
            if (sp && sp.id !== 0 && typeof sp.name === "string" && sp.name !== "") {
                const clean = sp.name.startsWith("special:") ? sp.name.substring(8) : sp.name
                root.toggledSpecial = clean
                root.dispatch("hl.dsp.focus({ monitor = \"" + name + "\" })", "focusmonitor " + name)
                root.dispatch("hl.dsp.workspace.toggle_special('" + clean + "')", "togglespecialworkspace " + clean)
            }

            if (!ws || ws < 0)
                return
            const busy = (d.c || []).some(w => w.workspace && w.workspace.id === ws && !w.pinned && w.mapped !== false)
            if (!busy) {
                root.holdWorkspace = ws
                return
            }
            settle.restart()
            root.savedWorkspace = ws
            root.savedMonitor = name
            root.dispatch("hl.dsp.focus({ monitor = \"" + name + "\" })", "focusmonitor " + name)
            root.dispatch("hl.dsp.focus({ workspace = 'empty' })", "workspace empty")
        } catch (e) {
            console.log("EditMode: could not read hyprctl output: " + e)
        }
    }

    function unpark() {
        settle.stop()
        root.holdWorkspace = 0
        const ws = root.savedWorkspace
        const name = root.savedMonitor
        const sp = root.toggledSpecial
        root.savedWorkspace = 0
        root.savedMonitor = ""
        root.toggledSpecial = ""
        if (ws > 0 && name !== "") {
            root.dispatch("hl.dsp.focus({ monitor = \"" + name + "\" })", "focusmonitor " + name)
            root.dispatch("hl.dsp.focus({ workspace = " + ws + " })", "workspace " + ws)
        }
        if (sp !== "")
            root.dispatch("hl.dsp.workspace.toggle_special('" + sp + "')", "togglespecialworkspace " + sp)
    }

    // ===== keeping the workspace where it is =====
    property int holdWorkspace: 0

    function holdNow() {
        if (!root.active || root.screenName === "")
            return
        const m = Hyprland.monitors.values.find(x => x.name === root.screenName)
        const id = m && m.activeWorkspace ? m.activeWorkspace.id : 0
        root.holdWorkspace = id > 0 ? id : 0
    }

    // The 'empty workspace' jump (see park) lands a moment after it is sent;
    // read where we ended up once it has settled.
    Timer {
        id: settle
        interval: 350
        onTriggered: root.holdNow()
    }

    function onHyprlandEvent(event) {
        if (!root.active || root.holdWorkspace <= 0)
            return
        const mon = Hyprland.focusedMonitor
        if (event.name === "workspacev2") {
            // data: "<id>,<name>". Only the monitor being edited matters.
            if (!mon || mon.name !== root.screenName)
                return
            const id = parseInt(event.data.split(",")[0])
            if (isNaN(id) || id === root.holdWorkspace)
                return
            root.dispatch("hl.dsp.focus({ workspace = " + root.holdWorkspace + " })",
                          "workspace " + root.holdWorkspace)
        } else if (event.name === "activespecialv2") {
            // data: "<id>,<name>,<monitor>". An empty name means it was closed.
            const parts = event.data.split(",")
            if (parts.length < 3 || parts[2] !== root.screenName)
                return
            const full = parts[1]
            if (full === "")
                return
            const clean = full.startsWith("special:") ? full.substring(8) : full
            root.dispatch("hl.dsp.workspace.toggle_special('" + clean + "')",
                          "togglespecialworkspace " + clean)
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.onHyprlandEvent(event)
        }
    }

    // Whether the desktop widgets (clock, To-Do, user card, weather card, visualizer; not the notes, which are always full-screen) may shrink their
    // window to a box around the card while nothing is being edited. Off by default: the
    // switch between that small window and the full-screen one Edit Desktop needs made
    // every widget jump a little when Done was pressed (confirmed: the jump is gone
    // with full-screen windows). On saves the compositor blending a full-screen layer
    // for every frame a widget draws, but brings the jump back.
    //   qs -c sekaipop ipc call desktopedit compactwindows true   (until the next reload)
    // Low-end mode (Settings -> Desktop -> Low-end mode, `perf.lowEnd`) turns it on and stays on
    // until the switch is turned off; the ipc call overrides both until the next reload.
    property var compactOverride: undefined
    readonly property bool compactWindows: root.compactOverride !== undefined
        ? !!root.compactOverride : SettingsService.flag("perf.lowEnd")

    // ===== ipc =====
    IpcHandler {
        target: "desktopedit"

        function compactwindows(on: bool): void {
            root.compactOverride = on;
        }

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open("");
        }

        // Edit Desktop on its THEME tab (what `theme toggle` does too).
        function theme(): void {
            ThemeService.togglePicker();
        }

        function close(): void {
            root.close();
        }

    }
}

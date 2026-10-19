pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The icon theme and the cursor theme, changed while everything is running.
// The work is scripts/theming/icon-cursor.sh (its header lists exactly what is written
// where, and how each kind of app hears about it); this file keeps the list of installed
// themes, remembers what was chosen, and makes the shell's own icons follow.
//
//   - Pick a theme in Settings -> Desktop -> Icons & cursor: it applies now (GTK, Qt, KDE,
//     Hyprland and XWayland), and open GTK apps change at once.
//   - The choice is saved (appearance.*), and the cursor is put back at every start,
//     because Hyprland forgets its cursor when it restarts.
//   - The shell's own icons (dock, launcher, overview, ...) ask `path()` below instead of
//     Quickshell.iconPath(). A running Qt program reads its icon theme once and cannot be
//     told to read it again, so after a change `path()` gets the files from the script
//     (`resolve`, which follows the icon theme spec itself) and the icons change live.
//     At start it uses the saved theme (or the system's) the same way, so the icons do not
//     depend on what Qt happened to read; until the first answer comes it asks Quickshell.
//
//   qs -c sekaipop ipc call appearance icons Papirus-Dark
//   qs -c sekaipop ipc call appearance cursor Bibata-Modern-Ice 28
//   qs -c sekaipop ipc call appearance status
//
// Windows cursors (.cur / .ani, any pack from a cursor site) are turned into a normal cursor
// theme by scripts/theming/win-cursor.py (through `icon-cursor.sh import`): it lands in
// ~/.local/share/icons, so it is listed next to the others and works in every app.
//
//   Settings -> Desktop -> Icons & cursor -> Import Windows cursors   (file chooser)
//   qs -c sekaipop ipc call appearance importcursor ~/Downloads/Pack.zip true
Singleton {
    id: root

    readonly property string script: Directories.script("theming/icon-cursor.sh")

    // Installed themes, by name.
    property var iconThemes: []
    property var cursorThemes: []

    // What the system has right now (from GNOME's settings), and what was chosen here.
    property string currentIcon: ""
    property string currentCursor: ""
    property int currentSize: 24

    readonly property string savedIcon: SettingsService.get("appearance.iconTheme")
    readonly property string savedCursor: SettingsService.get("appearance.cursorTheme")
    readonly property int savedSize: SettingsService.get("appearance.cursorSize")

    // What the Settings page shows as selected: our choice, else what the system has.
    readonly property string shownIcon: root.savedIcon !== "" ? root.savedIcon : root.currentIcon
    readonly property string shownCursor: root.savedCursor !== "" ? root.savedCursor : root.currentCursor
    readonly property int shownSize: root.savedCursor !== "" ? root.savedSize : root.currentSize

    // True while a change is being written.
    readonly property bool busy: runner.running || root.queue.length > 0

    // Goes up after an icon theme change, so everything that asked path() asks again.
    property int revision: 0

    // Set to the theme's name by the first icon change of this session. Until then (and after
    // a restart, when Qt itself reads the saved theme) path() just asks Quickshell.
    property string activeIcon: ""

    // name -> file ("" = not in that theme), for activeIcon. Replaced whole when new answers
    // arrive, which is what makes the bindings that read it run again.
    property var resolved: ({})

    // A file path as a URL: Image takes a bare path, but IconImage (the launcher's icons) does
    // not reliably, and a URL is right for both. Each part is percent-encoded, so a theme
    // folder with a space or a # in its name still loads.
    function fileUrl(p) {
        if (p.startsWith("file://") || p.startsWith("image://"))
            return p
        return "file://" + p.split("/").map(encodeURIComponent).join("/")
    }

    // The icon's file for an icon name. `fallbackOrCheck` is what Quickshell.iconPath takes
    // (a fallback icon name, or true to get "" when there is no such icon).
    //
    // After an icon theme change the answer comes from the script (see `resolve`); until it has
    // answered, and for a name the new theme (and hicolor) does not have, Quickshell's own
    // answer is used. A fallback icon name is looked up in the new theme as well, so a missing
    // icon shows the new theme's generic one rather than the old theme's.
    function path(name, fallbackOrCheck) {
        root.revision
        if (root.activeIcon !== "" && name) {
            const fb = typeof fallbackOrCheck === "string" ? fallbackOrCheck : ""
            const r = root.resolved[name]
            if (r === undefined) {
                root.want(name)
                if (fb !== "")
                    root.want(fb)
            } else if (r !== "") {
                return root.fileUrl(r)
            } else if (fb !== "") {
                const f = root.resolved[fb]
                if (f === undefined)
                    root.want(fb)
                else if (f !== "")
                    return root.fileUrl(f)
            }
        }
        // Not asked for yet, or the theme has no such icon: Quickshell's answer for now.
        return fallbackOrCheck === undefined
            ? Quickshell.iconPath(name)
            : Quickshell.iconPath(name, fallbackOrCheck)
    }

    // One line for the Settings page: how the shell's own icons did after the last change.
    property string resolveNote: ""

    // ===== asking the script for icon files =====
    // Names that bindings asked for while their answer was missing; asked in one go.
    property var wanted: ({})

    function want(name) {
        if (root.wanted[name] === undefined) {
            root.wanted[name] = true
            wantTimer.restart()
        }
    }

    Timer {
        id: wantTimer
        interval: 40
        onTriggered: root.resolveWanted()
    }

    function resolveWanted() {
        if (resolver.running) {
            wantTimer.restart()
            return
        }
        const names = Object.keys(root.wanted)
        if (names.length === 0 || root.activeIcon === "")
            return
        root.wanted = ({})
        resolver.theme = root.activeIcon
        resolver.names = names
        console.log("[IconCursorService] resolving", names.length, "icons in", root.activeIcon)
        resolver.exec(["sh", root.script, "resolve", root.activeIcon, "64"].concat(names))
    }

    Process {
        id: resolver

        property string theme: ""
        property var names: []

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[IconCursorService] resolve:", text.trim())
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                // The theme was changed again while this ran: these answers are for the old one.
                if (resolver.theme !== root.activeIcon)
                    return
                const next = Object.assign({}, root.resolved)
                for (const n of resolver.names)
                    next[n] = ""
                let found = 0
                for (const line of text.split("\n")) {
                    const i = line.indexOf("\t")
                    if (i > 0) {
                        next[line.slice(0, i)] = line.slice(i + 1).trim()
                        found++
                    }
                }
                console.log("[IconCursorService] resolved", found, "of", resolver.names.length,
                            "icons in", resolver.theme)
                root.resolved = next
                const total = Object.keys(next).length
                const have = Object.keys(next).filter(k => next[k] !== "").length
                root.resolveNote = "Shell icons: " + have + " of " + total + " found in " + resolver.theme
            }
        }

        onExited: (code, status) => {
            if (code !== 0)
                console.log("[IconCursorService] resolve exited with", code)
            // Whatever was asked for while this ran.
            if (Object.keys(root.wanted).length > 0)
                wantTimer.restart()
        }
    }

    // ===== choosing =====
    function setIcons(name) {
        if (!name)
            return
        SettingsService.set("appearance.iconTheme", name)
        root.currentIcon = name
        // The shell's own icons follow at once, without waiting for GTK / Qt.
        root.wanted = ({})
        root.resolved = ({})
        root.resolveNote = ""
        root.activeIcon = name
        root.revision++
        root.enqueue({ kind: "icons", argv: ["icons", name] })
    }

    // The size changes as a stepper is held down: wait for it to settle.
    function setCursor(name, size) {
        if (!name)
            return
        const s = Math.max(8, Math.min(256, Math.round(size || root.shownSize || 24)))
        SettingsService.set("appearance.cursorTheme", name)
        SettingsService.set("appearance.cursorSize", s)
        root.currentCursor = name
        root.currentSize = s
        cursorDebounce.restart()
    }

    function setCursorSize(size) {
        root.setCursor(root.shownCursor, size)
    }

    // Back to whatever the system had: forgets our choice (the files and settings the script
    // wrote stay as they are; pick a theme again to change them).
    function forgetChoice() {
        SettingsService.set("appearance.iconTheme", "")
        SettingsService.set("appearance.cursorTheme", "")
        root.refresh()
    }

    // ===== Windows cursors =====
    // True while the file chooser is open / while a pack is being converted.
    property bool picking: false
    property bool importing: false

    // One line for the Settings page: what the last import did.
    property string importNote: ""

    // Use the new theme as soon as it is made (the Settings button does; `importcursor false` only adds it).
    property bool importApply: false
    property string pickReopen: ""

    readonly property string pickPackScript: Directories.script("theming/pick-cursor-pack.sh")

    // path: a .zip, a folder, an install.inf or one .cur / .ani.
    function importPack(path, apply) {
        const p = (path || "").trim()
        if (p === "" || root.importing)
            return
        root.importing = true
        root.importApply = !!apply
        root.importNote = "Converting..."
        importer.theme = ""
        importer.report = ""
        importer.outDone = false
        importer.errDone = false
        importer.ended = false
        importer.rc = 0
        importer.exec(["sh", root.script, "import", p])
    }

    // The chooser is a window of its own: the Settings step aside while it is open (QuickPanel
    // listens to `picking`), so the dialog is not under them and gets the keyboard.
    // `reopen` = "settings" brings the Settings back afterwards.
    function pickPack(reopen) {
        if (root.picking || root.importing)
            return
        root.pickReopen = reopen || ""
        root.picking = true
        const chooser = SettingsService.get("files.chooser")
        const env = (chooser === "kdialog" || chooser === "zenity" || chooser === "yad")
            ? ["env", "SEKAIPOP_CHOOSER=" + chooser] : []
        packPicker.exec(env.concat(["sh", root.pickPackScript, "pick"]))
    }

    Process {
        id: packPicker
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                root.picking = false
                if (path !== "")
                    root.importPack(path, true)
                if (root.pickReopen !== "")
                    packReopen.restart()
            }
        }
    }

    // A beat after the dialog is gone, so a quick cancel does not land on the phone's own closing animation.
    Timer {
        id: packReopen
        interval: 450
        onTriggered: {
            const side = root.pickReopen
            root.pickReopen = ""
            if (side === "settings")
                Quickshell.execDetached(["qs", "-c", "sekaipop", "ipc", "call", "settings", "page", "desktop"])
        }
    }

    Process {
        id: importer

        property string theme: ""
        property string report: ""
        property bool outDone: false
        property bool errDone: false
        property bool ended: false
        property int rc: 0

        // Finish when the output, the messages and the exit have all arrived (they come in any order).
        function settle() {
            if (!importer.outDone || !importer.errDone || !importer.ended)
                return
            root.importing = false
            const lines = importer.report.split("\n").map(l => l.trim()).filter(l => l.length > 0)
            if (lines.length > 0)
                console.log("[IconCursorService] import:", lines.join(" | "))
            if (importer.rc === 0 && importer.theme !== "") {
                root.importNote = "Added " + importer.theme
                root.refresh()
                if (root.importApply)
                    root.setCursor(importer.theme, root.shownSize)
            } else {
                const last = lines.length > 0 ? lines[lines.length - 1] : ""
                root.importNote = last !== "" ? last.replace(/^win-cursor: /, "") : "Could not convert that"
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(x => x.trim()).filter(x => x.length > 0)
                importer.theme = l.length > 0 ? l[l.length - 1] : ""
                importer.outDone = true
                importer.settle()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                importer.report = text
                importer.errDone = true
                importer.settle()
            }
        }

        onExited: (code, status) => {
            importer.rc = code
            importer.ended = true
            importer.settle()
        }
    }

    Timer {
        id: cursorDebounce
        interval: 350
        onTriggered: root.enqueue({ kind: "cursor", argv: ["cursor", root.savedCursor, String(root.savedSize)] })
    }

    // ===== one run at a time =====
    // [{ kind, argv }]. A newer job of the same kind replaces one still waiting.
    property var queue: []

    function enqueue(job) {
        const q = root.queue.filter(j => j.kind !== job.kind)
        q.push(job)
        root.queue = q
        root.pump()
    }

    function pump() {
        if (runner.running || root.queue.length === 0)
            return
        const q = root.queue.slice()
        const job = q.shift()
        root.queue = q
        runner.job = job
        runner.exec(["sh", root.script].concat(job.argv))
    }

    Process {
        id: runner

        property var job: null

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[IconCursorService]", text.trim())
            }
        }

        onExited: (code, status) => {
            if (code !== 0)
                console.log("[IconCursorService]", runner.job ? runner.job.kind : "", "exited with", code)
            runner.job = null
            root.pump()
        }
    }

    // ===== what is installed / set =====
    function refresh() {
        if (!iconList.running) iconList.exec(["sh", root.script, "list", "icons"])
        if (!cursorList.running) cursorList.exec(["sh", root.script, "list", "cursors"])
        if (!getter.running) getter.exec(["sh", root.script, "get"])
    }

    function lines(text) {
        return text.split("\n").map(l => l.trim()).filter(l => l.length > 0)
    }

    Process {
        id: iconList
        stdout: StdioCollector { onStreamFinished: root.iconThemes = root.lines(text) }
    }

    Process {
        id: cursorList
        stdout: StdioCollector { onStreamFinished: root.cursorThemes = root.lines(text) }
    }

    Process {
        id: getter
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of root.lines(text)) {
                    const i = line.indexOf("=")
                    if (i <= 0)
                        continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "icons") root.currentIcon = v
                    else if (k === "cursor") root.currentCursor = v
                    else if (k === "size" && Number(v) > 0) root.currentSize = Number(v)
                }
                // No theme was ever chosen here: the system's one (just read) is the one to use.
                root.adoptTheme()
            }
        }
    }

    // ===== at start =====
    // Once the saved settings are read: put our cursor back (Hyprland starts with its own),
    // read what is installed, and make the shell's own icons use the saved icon theme.
    //
    // That last part matters: until now, after a restart `path()` asked Quickshell, which asks
    // Qt, and Qt only knows the icon theme if it was started with the right environment
    // (QT_QPA_PLATFORMTHEME, qt6ct, dconf being up yet...). Started from a keybind or a
    // terminal, or a bit too early at login, Qt did not know it and the dock / launcher icons
    // were just gone, until a theme was picked again in Settings (which is the one thing that
    // switched `path()` to the script's own lookup). So the same lookup is used from the
    // start, with the saved theme (or, if none was ever chosen here, the one the system has).
    property bool restored: false

    function adoptTheme() {
        // A theme picked in this session is already in use.
        if (root.activeIcon !== "")
            return
        const t = root.shownIcon
        if (t === "")
            return
        root.wanted = ({})
        root.resolved = ({})
        root.resolveNote = ""
        root.activeIcon = t
        root.revision++
    }

    function restoreAtStart() {
        if (root.restored || !SettingsService.loaded)
            return
        root.restored = true
        root.adoptTheme()
        if (root.savedCursor !== "")
            root.enqueue({ kind: "restore", argv: ["restore", root.savedCursor, String(root.savedSize)] })
        root.refresh()
    }

    Connections {
        target: SettingsService
        function onLoadedChanged() { root.restoreAtStart() }
    }

    Component.onCompleted: root.restoreAtStart()

    IpcHandler {
        target: "appearance"

        function icons(name: string): void { root.setIcons(name) }

        function cursor(name: string, size: int): void { root.setCursor(name, size) }

        // A Windows cursor pack (.zip, folder, install.inf, .cur / .ani) -> a cursor theme.
        // `apply` true also switches to it.  pickcursor opens the file chooser.
        function importcursor(path: string, apply: bool): void { root.importPack(path, apply) }

        function pickcursor(): void { root.pickPack("") }

        // The file the shell uses for an icon name right now (for finding out why one is wrong).
        function lookup(name: string): string {
            return root.path(name, true) + "  [theme " + (root.activeIcon || "(Qt's own)") + "]"
        }

        function status(): string {
            return JSON.stringify({
                icons: root.shownIcon, cursor: root.shownCursor, size: root.shownSize,
                activeIcon: root.activeIcon, note: root.resolveNote,
                iconThemes: root.iconThemes, cursorThemes: root.cursorThemes
            })
        }
    }
}

// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L I P B O A R D   S E R V I C E                                      │
// │   clipboard history · watcher, list and restore                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history. `clipboard.py` watches, stores and restores; this reads
// the file it writes.
//
// `Quickshell.clipboardText` is Qt's clipboard, which on Wayland only updates
// for a surface with keyboard focus, so a bar cannot observe it. `wl-paste
// --watch` uses the data-control protocol, which can.
//
// The history is shown only as a launcher mode.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/clipboard.py")

    // ── ENTRIES ─────────────────────────────────────────────────────────────
    //
    //   key      digest of the content
    //   kind     "text" or "image"
    //   mime     type handed back to wl-copy
    //   file     path of the payload; payloads stay out of the index, which
    //            is re-read on every copy
    //   preview  first line, whitespace collapsed; displayed and searched
    //   bytes    size
    //   copied   last time it reached the clipboard, ms since epoch
    property var entries: []

    readonly property int count: root.entries.length

    function normalise(list: var): var {
        const rows = []
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            const kept = list[index]
            if (!kept || !kept.key || !kept.file)
                continue
            rows.push({
                key: kept.key,
                kind: kept.kind === "image" ? "image" : "text",
                mime: kept.mime ?? "text/plain",
                file: kept.file,
                preview: kept.preview ?? "",
                bytes: kept.bytes ?? 0,
                copied: kept.copied ?? 0
            })
        }
        return rows
    }

    // Read-only here: the script is the only writer, and its lock serialises
    // the processes that modify the file.
    readonly property FileView store: FileView {
        path: `${SettingsService.stateDirectory}/clipboard.json`
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.entries = root.normalise(JSON.parse(text()).entries)
            } catch (error) {
                console.warn("Cannot read the clipboard history:", error)
            }
        }
        // Nothing copied yet; the script creates the file on first copy.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.entries = []
        }
    }

    // ── WATCHER ─────────────────────────────────────────────────────────────
    //
    // wl-paste spawns a fresh process per change, so the limits travel as
    // arguments. Changing any of them restarts the watcher.
    readonly property var wanted: SettingsService.clipboardHistory
        ? [root.script, "watch",
           "--keep", `${SettingsService.clipboardKeep}`,
           SettingsService.clipboardImages ? "--images" : "--no-images"]
        : []

    onWantedChanged: root.tend()

    // Managed by `tend()` rather than a binding:
    // - `running: <setting>` works once; Quickshell writes false when the
    //   process exits, which breaks the binding.
    // - Changing `command` does not affect a running process.
    // Restarting is safe: the script takes a pidfile and displaces the
    // previous holder, so a race still ends with one watcher. stdout is not
    // collected; a collector on a long-lived pipe only grows.
    readonly property Process watcher: Process {
        onExited: root.tend()
    }

    // Start time of the last watcher, for the respawn guard below.
    property real started: 0

    function tend(): void {
        if (root.watcher.running) {
            if (JSON.stringify(root.watcher.command) === JSON.stringify(root.wanted))
                return
            root.watcher.running = false
        }
        if (root.wanted.length === 0)
            return
        // A watcher that dies within 5 s is a broken command (e.g. wl-paste
        // missing), not a crash; don't respawn it in a tight loop.
        if (root.started > 0 && Date.now() - root.started < 5000) {
            console.warn("The clipboard watcher will not stay up; leaving it off.")
            return
        }
        root.started = Date.now()
        root.watcher.command = root.wanted
        root.watcher.running = true
    }

    Component.onCompleted: root.tend()

    // All mutations go through the script. The list updates through the file
    // watch, so only stderr is read.
    readonly property Process action: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("clipboard:", text.trim())
            }
        }
    }

    function run(arguments: var): void {
        if (!SettingsService.clipboardHistory)
            return
        root.action.running = false
        root.action.command = [root.script].concat(arguments)
        root.action.running = true
    }

    // The entry also moves to the top, since the watcher sees wl-copy's change
    // like any other.
    function copy(key: string): void {
        root.run(["restore", key])
    }

    function forget(key: string): void {
        root.run(["forget", key])
    }

    // Clears both the history and the current selection.
    function wipe(): void {
        root.run(["wipe"])
    }

    // ── SEARCH ──────────────────────────────────────────────────────────────
    //
    // Newest first, no ranking. Only the preview is matched; reading every
    // payload file per keystroke isn't worth it.
    function search(term: string, limit: int): var {
        const found = []
        const wanted = (term ?? "").toLowerCase()
        for (const entry of root.entries) {
            if (found.length >= limit)
                break
            if (wanted !== "" && !entry.preview.toLowerCase().includes(wanted))
                continue
            found.push(entry)
        }
        return found
    }

    // ── FORMATTING ──────────────────────────────────────────────────────────

    function weigh(bytes: int): string {
        if (bytes < 1024)
            return `${bytes} B`
        if (bytes < 1024 * 1024)
            return `${Math.round(bytes / 1024)} kB`
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    }

    // Relative time: "3 min ago" orders entries at a glance.
    function since(copied: real): string {
        const seconds = Math.max(0, Math.round((Date.now() - copied) / 1000))
        if (seconds < 60)
            return "just now"
        const minutes = Math.floor(seconds / 60)
        if (minutes < 60)
            return `${minutes} min ago`
        const hours = Math.floor(minutes / 60)
        if (hours < 24)
            return `${hours} h ago`
        return `${Math.floor(hours / 24)} d ago`
    }

    function describe(entry: var): string {
        const kind = entry.kind === "image" ? "Image" : "Text"
        return `${kind}  ·  ${root.weigh(entry.bytes)}  ·  ${root.since(entry.copied)}`
    }

    // Images have no text preview; the row's thumbnail identifies them.
    function title(entry: var): string {
        if (entry.kind === "image")
            return "Image"
        return entry.preview !== "" ? entry.preview : "Not text"
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

// The dock's Shelf (Dock.qml, DockShelfCard.qml): a place to put things down for a
// moment — files dropped on its key, or text — and pick them up again later. Kept
// across restarts (a JSON file next to the dock layout, written by
// pinned-apps-state.sh).
//
// An item is { id, kind: "file" | "text", value, name, added, dir }:
//   file   `value` is the path; `dir` is true for a folder (asked once, soon after it is put
//          down, and kept: it is what makes the shelf draw a folder, see ShelfMath.js)
//   text   `value` is the text itself
Singleton {
    id: root

    property var items: []
    readonly property int count: root.items.length

    readonly property string script: Directories.script("state/pinned-apps-state.sh")

    function newId() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36)
    }

    function baseName(path) {
        const parts = String(path).split("/").filter(p => p !== "")
        return parts.length > 0 ? decodeURIComponent(parts[parts.length - 1]) : String(path)
    }

    function pathOfUrl(url) {
        let u = String(url).trim()
        if (u.startsWith("file://"))
            u = decodeURIComponent(u.substring(7))
        return u
    }

    function add(list) {
        if (list.length === 0)
            return
        root.items = list.concat(root.items).slice(0, 60)
        root.persist()
        root.checkDirs()
    }

    function addFile(pathOrUrl) {
        const path = root.pathOfUrl(pathOrUrl)
        if (path === "" || root.items.some(i => i.kind === "file" && i.value === path))
            return
        root.add([{ id: root.newId(), kind: "file", value: path, name: root.baseName(path), added: Date.now() }])
    }

    function addText(text) {
        const t = String(text)
        if (t.trim() === "")
            return
        const firstLine = t.trim().split("\n")[0]
        root.add([{ id: root.newId(), kind: "text", value: t,
                    name: firstLine.length > 60 ? firstLine.substring(0, 60) + "…" : firstLine,
                    added: Date.now() }])
    }

    // Whatever a drop carries: files (a list of urls) or text.
    function addDrop(drop) {
        if (drop.hasUrls && drop.urls.length > 0) {
            // Files are kept by path; a web link (dragged out of a browser) is kept as text.
            for (const u of drop.urls) {
                if (/^[a-z][a-z0-9+.-]*:\/\//i.test(String(u)) && !String(u).startsWith("file://"))
                    root.addText(String(u))
                else
                    root.addFile(u)
            }
        } else if (drop.hasText) {
            const t = drop.text
            if (t.startsWith("file://"))
                t.split("\n").forEach(l => root.addFile(l))
            else
                root.addText(t)
        }
    }

    function remove(id) {
        root.items = root.items.filter(i => i.id !== id)
        root.persist()
    }

    function clear() {
        root.items = []
        root.persist()
    }

    // ===== doing things with an item =====
    function open(item) {
        if (item.kind === "file")
            Quickshell.execDetached(["xdg-open", item.value])
    }

    // A file goes on the clipboard as a file (paste it in a file manager); text as text.
    function copy(item) {
        if (item.kind === "file")
            Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "sh", item.value])
        else
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", item.value])
    }

    // Everything on the shelf onto the clipboard in one go: the files as files (paste them in a
    // file manager); with no files on the shelf, the texts one after another. The clipboard holds
    // one kind at a time, so with both on the shelf it is the files.
    function copyAll() {
        const files = root.items.filter(i => i.kind === "file")
        if (files.length > 0)
            Quickshell.execDetached(["sh", "-c", "for p in \"$@\"; do printf 'file://%s\\r\\n' \"$p\"; done | wl-copy --type text/uri-list", "sh"].concat(files.map(i => i.value)))
        else if (root.items.length > 0)
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", root.items.map(i => i.value).join("\n\n")])
    }

    function revealInFolder(item) {
        if (item.kind === "file")
            Quickshell.execDetached(["sh", "-c", "xdg-open \"$(dirname \"$1\")\"", "sh", item.value])
    }

    // Puts the clipboard's content on the shelf.
    function addFromClipboard() {
        paste.running = false
        paste.running = true
    }

    Process {
        id: paste
        command: ["sh", "-c",
            "t=$(wl-paste -t text/uri-list 2>/dev/null); if [ -n \"$t\" ]; then printf '%s' \"$t\"; else wl-paste -n 2>/dev/null; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text
                if (t.trim() === "")
                    return
                if (t.trim().startsWith("file://"))
                    t.split("\n").map(l => l.trim()).filter(l => l.startsWith("file://")).forEach(l => root.addFile(l))
                else
                    root.addText(t)
            }
        }
    }

    // ===== which files are folders =====
    // Asked once for every file that has no `dir` yet (new ones, and ones kept by an older
    // version): one `sh` goes through the paths and says D (a directory) or F for each.
    property bool dirAgain: false

    function checkDirs() {
        if (dirCheck.running) {
            root.dirAgain = true
            return
        }
        const paths = root.items.filter(i => i.kind === "file" && i.dir === undefined).map(i => i.value)
        if (paths.length === 0)
            return
        dirCheck.exec(["sh", "-c",
            "for p in \"$@\"; do if [ -d \"$p\" ]; then printf 'D %s\\n' \"$p\"; else printf 'F %s\\n' \"$p\"; fi; done",
            "sh"].concat(paths))
    }

    Process {
        id: dirCheck

        stdout: StdioCollector {
            onStreamFinished: {
                const dirs = new Set()
                const files = new Set()
                for (const l of text.split("\n")) {
                    if (l.startsWith("D "))
                        dirs.add(l.substring(2))
                    else if (l.startsWith("F "))
                        files.add(l.substring(2))
                }
                let changed = false
                root.items = root.items.map(i => {
                    if (i.kind === "file" && i.dir === undefined && (dirs.has(i.value) || files.has(i.value))) {
                        changed = true
                        return Object.assign({}, i, { dir: dirs.has(i.value) })
                    }
                    return i
                })
                if (changed)
                    root.persist()
            }
        }

        onExited: {
            if (root.dirAgain) {
                root.dirAgain = false
                root.checkDirs()
            }
        }
    }

    // ===== keeping it =====
    function persist() {
        saver.save(JSON.stringify(root.items))
    }

    Process {
        running: true
        command: ["sh", root.script, "shelf-load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (text.trim() !== "") {
                        const j = JSON.parse(text)
                        if (Array.isArray(j)) {
                            root.items = j
                            root.checkDirs()
                        }
                    }
                } catch (e) {
                    console.warn("ShelfService: couldn't read the shelf:", e)
                }
            }
        }
    }

    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "shelf-save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "shelf-save", json])
            }
        }
    }
}

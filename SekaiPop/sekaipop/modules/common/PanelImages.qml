pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// The avatar and banner pictures — picked by clicking them on the Quick
// Panel (QuickPanelFace.qml -> QuickPanel.qml -> pick()). A file chooser opens, the chosen
// picture is copied into ~/.local/share/sekaipop/ and shown; it's found
// again there the next time the shell starts. The chooser itself and the
// copying are pick-image.sh's job.
//
// A singleton (like Theme.qml, WallpaperService.qml) rather than a
// per-window instance, so any window that shows the picture reads the
// same one with no wiring.
//
//   avatar / banner   a file:// URL, or "" for "nothing picked" (the panel
//                     then falls back to QuickPanel's own avatarSource /
//                     bannerSource, and after that the grey template)
//   avatarPath /      the same pictures as plain file paths (what the
//   bannerPath        desktop presets save), "" for nothing picked
//   loaded            true once the pictures from an earlier session have
//                     been looked for (a preset saved before then would
//                     wrongly hold "no avatar, no banner")
//   busy              true while a chooser is open — QuickPanel drops its
//                     click-away grab meanwhile, or the chooser window
//                     taking focus would close the panel
//   pick(kind)        open the chooser for "avatar" or "banner"
//   clear(kind)       forget the picked picture (right-click on it)
Singleton {
    id: root

    property string avatar: ""
    property string banner: ""
    property bool loaded: false

    // The file path behind a file:// URL made by urlFor() ("" for none).
    function pathFor(url) {
        if (url.indexOf("file://") !== 0)
            return ""
        try {
            return decodeURIComponent(url.slice(7))
        } catch (e) {
            return ""
        }
    }

    readonly property string avatarPath: pathFor(avatar)
    readonly property string bannerPath: pathFor(banner)

    readonly property bool busy: picker.running

    readonly property string script: Directories.script("images/pick-image.sh")

    // Settings > General > Quick Panel > Avatar & banner picker. "auto" (or anything
    // unknown) leaves the choice to pick-image.sh; a name is tried first there.
    readonly property string chooser: {
        const c = SettingsService.get("files.chooser")
        return (c === "kdialog" || c === "zenity" || c === "yad") ? c : ""
    }

    function urlFor(path) {
        if (path === "")
            return ""
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }

    function assign(kind, path) {
        if (kind === "avatar")
            avatar = urlFor(path)
        else if (kind === "banner")
            banner = urlFor(path)
    }

    function pick(kind) {
        if (picker.running)
            return
        picker.kind = kind
        picker.running = true
    }

    // Kinds waiting for the script to forget them. A queue, not a single
    // slot: wearing a desktop preset with no avatar and no banner clears both
    // one straight after the other, and the second must not be dropped (the
    // file would come back at the next start).
    property var clearQueue: []

    function clear(kind) {
        assign(kind, "")
        root.clearQueue = root.clearQueue.concat([kind])
        root.pumpClear()
    }

    function pumpClear() {
        if (clearer.running || root.clearQueue.length === 0)
            return
        clearer.kind = root.clearQueue[0]
        root.clearQueue = root.clearQueue.slice(1)
        clearer.running = true
    }

    Process {
        id: picker

        property string kind: ""

        command: root.chooser === ""
            ? ["sh", root.script, "pick", kind]
            : ["env", "SEKAIPOP_CHOOSER=" + root.chooser, "sh", root.script, "pick", kind]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path !== "")
                    root.assign(picker.kind, path)
            }
        }
    }

    Process {
        id: clearer

        property string kind: ""

        command: ["sh", root.script, "clear", kind]
        onExited: root.pumpClear()
    }

    // What was picked in an earlier session.
    Process {
        command: ["sh", root.script, "load"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const sp = lines[i].indexOf(" ")
                    if (sp > 0)
                        root.assign(lines[i].slice(0, sp), lines[i].slice(sp + 1))
                }
                // After the pictures are set, not when the script exits.
                root.loaded = true
            }
        }
    }
}

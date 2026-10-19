pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// What version this shell is, whether a newer one exists, and what changed.
// The work is scripts/system/update-check.sh (a git checkout, an installed copy
// or an optional URL to a VERSION file; see its header). The changelog is
// CHANGELOG.md next to shell.qml.
//
// It also looks by itself (while "updates.shellNotify" is on, the default): once
// shortly after the shell starts and then every "updates.shellHours" hours. When
// such a look finds a newer version it sends ONE notification for it (the shell
// is the notification daemon, so it shows on the phone like any other) and
// remembers which version that was (`seen`, kept in ~/.cache/sekaipop/update-seen
// by the script), so it never repeats for the same one, also after a restart. A
// look you asked for yourself (the page, the button) counts as seen and sends
// nothing. Nothing is sent for an installed copy with no version mark yet
// (`unknown`: it can't tell if it is behind), and not while Game Mode is on
// (it waits for the next look). With the setting off nothing here touches the
// network until you press Check for updates.
//
//   status   "idle"      never asked yet
//            "checking"  asking
//            "current"   up to date
//            "behind"    a newer version exists (`behind` commits, or `latest`)
//            "nosource"  nothing to compare with (no git, no URL)
//            "error"     couldn't ask (`reason` says why)
Singleton {
    id: root

    property string version: ""
    // A git checkout (the shell folder is a clone, or the sekaipop/ folder of one).
    property bool isGit: false
    // An installed copy (what install.sh makes): updated by downloading the
    // newest commit from GitHub and swapping the folder. See update-check.sh.
    property bool managed: false
    // Installed copy with no commit mark yet: can't tell if it is current.
    property bool unknown: false
    readonly property bool canApply: isGit || managed
    property string branch: ""
    property string commit: ""
    property string remote: ""

    property string status: "idle"
    property int behind: 0
    property string latest: ""
    // Short id of the newest version out there (a commit, or the VERSION text).
    property string rev: ""
    // The id the user was last told about (or looked at themselves).
    property string seen: ""
    // True while the look in progress was asked for by the user.
    property bool byUser: false
    readonly property bool watching: SettingsService.flag("updates.shellNotify")
    property string reason: ""
    property double checkedAt: 0
    // Commits an update would bring: [{ hash, subject, age }]
    property var pending: []
    // CHANGELOG.md as [{ title, items: [text] }], newest first.
    property var changelog: []

    property bool updating: false
    property string updateMessage: ""

    readonly property string script: Directories.script("system/update-check.sh")

    function parseKv(text) {
        const out = {}
        for (const line of text.split("\n")) {
            const i = line.indexOf("=")
            if (i > 0)
                out[line.slice(0, i)] = line.slice(i + 1).trim()
        }
        return out
    }

    // `byUser` is true for a look somebody asked for (the page, the button).
    function check(byUser) {
        if (checker.running) {
            if (byUser === true)
                root.byUser = true
            return
        }
        root.byUser = byUser === true
        // A look the timers start leaves a known answer on screen (so the About tab's
        // badge does not blink every few hours); only the first one shows "checking".
        if (byUser === true || root.status === "idle" || root.status === "error")
            root.status = "checking"
        root.reason = ""
        checker.running = true
    }

    // One notification per newer version, and only for a look nobody asked for.
    function announce() {
        if (root.status !== "behind" || root.unknown || root.rev === "" || root.rev === root.seen)
            return
        if (!root.byUser && root.watching && GameModeService.enabled)
            return
        const byUser = root.byUser
        root.seen = root.rev
        seenWriter.exec(["sh", root.script, "seen", root.rev])
        if (byUser || !root.watching)
            return
        const what = root.isGit && root.behind > 0
            ? root.behind + (root.behind === 1 ? " new commit is" : " new commits are") + " waiting upstream."
            : (!root.isGit && !root.managed && root.latest !== "" ? "Version " + root.latest + " is out." : "A newer version is on GitHub.")
        Quickshell.execDetached(["notify-send", "-a", "sekaipop", "-i", "material:system_update",
            "SekaiPop update available", what + " Open Settings \u2192 About / Update to install it."])
    }

    function update() {
        if (updater.running)
            return
        root.updating = true
        root.updateMessage = ""
        updater.running = true
    }

    // Cheap and local; runs once at startup.
    Process {
        running: true
        command: ["sh", root.script, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = root.parseKv(text)
                root.version = kv.version || ""
                root.isGit = kv.git === "yes"
                root.managed = kv.managed === "yes"
                root.branch = kv.branch || ""
                root.commit = kv.commit || ""
                root.remote = kv.remote || ""
            }
        }
    }

    // Talks to the network (git fetch / curl), only when asked.
    Process {
        id: checker
        command: ["sh", root.script, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = root.parseKv(text)
                root.behind = Number(kv.behind || 0)
                root.latest = kv.latest || ""
                root.rev = kv.rev || ""
                root.unknown = kv.unknown === "yes"
                root.reason = kv.reason || ""
                root.status = kv.status || "error"
                root.checkedAt = Date.now()
                if (root.status === "behind" && root.isGit)
                    logger.running = true
                else
                    root.pending = []
                root.announce()
            }
        }
        onExited: code => {
            if (code !== 0 && root.status === "checking") {
                root.status = "error"
                root.reason = "the update check failed"
            }
        }
    }

    // What the user was last told about: read once at startup, written when it changes.
    Process {
        running: true
        command: ["sh", root.script, "seen"]
        stdout: StdioCollector {
            onStreamFinished: root.seen = text.trim()
        }
    }

    Process {
        id: seenWriter
    }

    // A first look a little after the start (the network is often not up yet in the
    // very first seconds), then regularly. Both only run while the setting is on.
    Timer {
        interval: 40 * 1000
        running: root.watching
        onTriggered: root.check()
    }

    Timer {
        interval: Math.max(1, SettingsService.get("updates.shellHours")) * 3600 * 1000
        running: root.watching
        repeat: true
        onTriggered: root.check()
    }

    Process {
        id: logger
        command: ["sh", root.script, "log"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length >= 3)
                        list.push({ hash: p[0], subject: p.slice(1, -1).join("|"), age: p[p.length - 1] })
                }
                root.pending = list
            }
        }
    }

    Process {
        id: updater
        command: ["sh", root.script, "apply"]
        stdout: StdioCollector {
            onStreamFinished: root.updateMessage = text.trim().split("\n").slice(-1)[0] || ""
        }
        onExited: code => {
            root.updating = false
            if (code === 0)
                // The new files are on disk: rebuild the shell from them.
                Quickshell.reload(true)
            else
                root.updateMessage = root.updateMessage || "the update didn't apply"
        }
    }

    // ===== changelog =====
    function parseChangelog(text) {
        const out = []
        let cur = null
        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (line.startsWith("## ")) {
                cur = { title: line.slice(3), items: [] }
                out.push(cur)
            } else if (cur && line.startsWith("- ")) {
                cur.items.push(line.slice(2).replace(/`/g, ""))
            }
        }
        return out
    }

    FileView {
        path: Quickshell.shellDir + "/CHANGELOG.md"
        onLoaded: root.changelog = root.parseChangelog(text())
        onLoadFailed: root.changelog = []
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Pending package updates (Arch): a count for the bar's badge
// (UpdatesBadge.qml), looked up by scripts/system/pkg-updates.sh with `checkupdates`
// (pacman-contrib; needs no root) and, when you ask for it, the AUR through
// paru or yay.
//
//   repoCount, aurCount, total   what is waiting
//   packages                     ["name 1.0 -> 1.1", ...] (the first few, repo then AUR)
//   status                       "idle" | "checking" | "ok" | "nocmd" | "error"
//   nudging                      total >= the "updates.nudgeAt" setting
//
// It looks once shortly after the shell starts and then every
// `updates.intervalMin` minutes (Settings -> Bar). When the count first reaches
// the nudge level in a session it also sends one notification (the shell is the
// notification daemon, so it shows on the phone like any other).
//
//   qs -c sekaipop ipc call updates refresh
//   qs -c sekaipop ipc call updates get
//   qs -c sekaipop ipc call updates run        (open the update in a terminal)
Singleton {
    id: root

    property int repoCount: 0
    property int aurCount: 0
    readonly property int total: root.repoCount + root.aurCount
    property var packages: []
    property string status: "idle"
    property double checkedAt: 0

    // Only looks (and nudges) while the bar's updates module is switched on
    // (Settings -> Bar -> Modules, off by default). `ipc call updates refresh`
    // still looks when asked.
    readonly property bool enabled: SettingsService.flag("bar.updates")

    readonly property int nudgeAt: SettingsService.get("updates.nudgeAt")
    readonly property bool nudging: root.nudgeAt > 0 && root.total >= root.nudgeAt

    readonly property string script: Directories.script("system/pkg-updates.sh")

    // True when the current look was asked for (right-click, `ipc call updates
    // refresh`) rather than started by the timers.
    property bool manual: false

    // The bar's badge is shown for as long as this is true, even with nothing
    // to update: from the start until the first look has finished, during a
    // look somebody asked for, and while the update runs in its terminal. (A
    // timed look that finds nothing new does not make the badge flash up.)
    readonly property bool loadingBadge: root.upgrading
        || (root.status === "idle" && root.checkedAt === 0)
        || (root.status === "checking" && (root.checkedAt === 0 || root.manual))

    // `byUser` is true for a look somebody asked for.
    function refresh(byUser) {
        if (checker.running) {
            if (byUser === true)
                root.manual = true
            return
        }
        root.manual = byUser === true
        root.status = "checking"
        checker.exec(["sh", root.script, "check", SettingsService.flag("updates.aur") ? "1" : "0"])
    }

    // "3 repo · 1 AUR" for the tag and the Settings page.
    readonly property string breakdown: {
        if (root.status === "nocmd")
            return "checkupdates not found (install pacman-contrib)"
        if (root.status === "error")
            return "couldn't check for updates"
        if (root.status === "idle" || (root.status === "checking" && root.checkedAt === 0))
            return "checking…"
        if (root.total === 0)
            return "up to date"
        const parts = [root.repoCount + " repo"]
        if (root.aurCount > 0)
            parts.push(root.aurCount + " AUR")
        return parts.join(" · ")
    }

    // ===== the check =====
    property bool nudged: false

    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                let repo = 0, aur = 0, status = "error"
                const pk = [], ak = []
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i < 0)
                        continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "status") status = v
                    else if (k === "repo") repo = Number(v) || 0
                    else if (k === "aur") aur = Number(v) || 0
                    else if (k === "pkg") pk.push(v)
                    else if (k === "aurpkg") ak.push(v)
                }
                root.status = status
                if (status === "ok") {
                    root.repoCount = repo
                    root.aurCount = aur
                    root.packages = pk.concat(ak)
                    root.checkedAt = Date.now()
                    root.maybeNudge()
                } else if (status === "nocmd") {
                    root.repoCount = 0
                    root.aurCount = 0
                    root.packages = []
                }
            }
        }
        onExited: code => {
            if (code !== 0 && root.status === "checking")
                root.status = "error"
        }
    }

    function maybeNudge() {
        if (!root.enabled)
            return
        if (!root.nudging) {
            if (root.total < root.nudgeAt)
                root.nudged = false
            return
        }
        if (root.nudged)
            return
        root.nudged = true
        Quickshell.execDetached(["notify-send", "-a", "sekaipop", "-i", "material:system_update",
            root.total + " updates are waiting",
            "Click the update badge in the bar to run them in a terminal."])
    }

    // A first look a little after startup (the network is often not up yet at
    // the very first second), then regularly.
    Timer {
        interval: 25 * 1000
        running: root.enabled
        onTriggered: root.refresh()
    }

    Timer {
        interval: Math.max(5, SettingsService.get("updates.intervalMin")) * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    // ===== running the update =====
    readonly property string updateScript:
        "checkupdates 2>/dev/null; echo; "
        + "if command -v paru >/dev/null 2>&1; then paru; "
        + "elif command -v yay >/dev/null 2>&1; then yay; "
        + "else sudo pacman -Syu; fi; "
        + "echo; printf 'Press Enter to close '; read _"

    function terminalCommand() {
        const t = SettingsService.get("updates.terminal")
        if (t === "foot")
            return ["foot", "sh", "-c", root.updateScript]
        if (t === "alacritty")
            return ["alacritty", "-e", "sh", "-c", root.updateScript]
        return ["kitty", "sh", "-c", root.updateScript]
    }

    readonly property bool upgrading: upgrader.running

    function runUpdate() {
        if (upgrader.running)
            return
        upgrader.exec(root.terminalCommand())
    }

    Process {
        id: upgrader
        onExited: root.refresh()
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh(true)
        }

        function run(): void {
            root.runUpdate()
        }

        function get(): string {
            return root.status + " total=" + root.total + " (" + root.breakdown + ")"
        }
    }
}

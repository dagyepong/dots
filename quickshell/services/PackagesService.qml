// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A C K A G E S   S E R V I C E                                        │
// │   installed, pending, and found · pacman and the AUR, read here          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backs the packages panel. Everything here is read-only (`packages.py` for
// installed packages and search, `UpdatesService` for pending updates).
// Install, Remove and Update run in a terminal so pacman's prompts, the
// password and the output stay visible; all lists refresh when it closes.
//
// No per-package upgrade: Arch does not support partial upgrades, so Update
// is always `-Syu`.
Singleton {
    id: root

    // ── PANEL ───────────────────────────────────────────────────────────────
    //
    // Declared sizes: the field, the rows and the footer.
    readonly property int panelWidth: 820
    readonly property int panelHeight: 560
    readonly property int fieldHeight: 36
    readonly property int rowHeight: 46
    readonly property int footerHeight: 30

    // The view persists between openings; the query does not, so a stale
    // filter never hides rows.
    property string view: "find"
    property string query: ""

    // "mine" (explicitly installed, `pacman -Qe`), "all" or "aur".
    property string installedFilter: "mine"

    readonly property var views: [
        { id: "updates",   label: "Updates" },
        { id: "installed", label: "Installed" },
        { id: "find",      label: "Find" }
    ]

    function step(delta: int): void {
        const ids = root.views.map(entry => entry.id)
        root.view = ids[(ids.indexOf(root.view) + delta + ids.length) % ids.length]
    }

    // ── INSTALLED ───────────────────────────────────────────────────────────

    property bool loaded: false
    property bool loading: false
    property var installed: []
    property string helper: ""

    readonly property int mineCount: root.installed.filter(row => row.explicit).length
    readonly property int aurCount: root.installed.filter(row => row.aur).length

    function load(): void {
        if (root.loading)
            return
        root.loading = true
        root.installedProcess.running = true
    }

    readonly property Process installedProcess: Process {
        command: [Quickshell.shellPath("scripts/packages.py"), "installed"]
        onExited: root.loading = false
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the installed packages:", error)
                    return
                }
                if (report.available !== true)
                    return
                root.installed = report.packages ?? []
                root.helper = report.helper ?? ""
                root.loaded = true
            }
        }
    }

    // ── SEARCH ──────────────────────────────────────────────────────────────
    //
    // Debounced 250 ms: each search is a pacman query plus an AUR request.

    property var found: []
    property string foundTerm: ""
    property int foundRepos: 0
    property int foundAur: 0
    // "ok", "prefix" (the AUR matched too much and answered the names that
    // start with it), "offline", or "short" (under two letters).
    property string foundNote: ""
    property bool searching: false

    readonly property string term: root.query.trim().toLowerCase()

    onQueryChanged: {
        if (root.view === "find")
            root.debounce.restart()
    }

    onViewChanged: {
        if (root.view === "find" && root.term !== root.foundTerm)
            root.debounce.restart()
    }

    readonly property Timer debounce: Timer {
        interval: 250
        onTriggered: root.search()
    }

    function search(): void {
        if (root.term.length < 2) {
            root.found = []
            root.foundTerm = root.term
            root.foundNote = root.term === "" ? "" : "short"
            return
        }
        // Replaces any search in flight; late answers for an old term are
        // dropped in the collector.
        root.searching = true
        root.searchProcess.running = false
        root.searchProcess.command = [Quickshell.shellPath("scripts/packages.py"),
                                      "search", root.term]
        root.searchProcess.running = true
    }

    readonly property Process searchProcess: Process {
        onExited: root.searching = false
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the package search:", error)
                    return
                }
                if (report.term !== root.term)
                    return
                root.found = report.results ?? []
                root.foundTerm = report.term
                root.foundRepos = report.repos ?? 0
                root.foundAur = report.aurCount ?? 0
                root.foundNote = report.aur ?? ""
            }
        }
    }

    // ── ROWS ────────────────────────────────────────────────────────────────
    //
    // One shape for all three lists, so the panel draws one row:
    //   { name, version, description, source, installed, from, to, size,
    //     votes, outOfDate }
    // with only the fields that list has.

    function matches(row: var): bool {
        return root.term === "" || row.name.toLowerCase().includes(root.term)
    }

    // Descriptions for the updates list; checkupdates only reports names and
    // versions.
    readonly property var descriptions: {
        const map = ({})
        for (const row of root.installed)
            map[row.name] = row.description
        return map
    }

    readonly property var rows: {
        if (root.view === "updates")
            return UpdatesService.updates.filter(row => root.matches(row)).map(row =>
                Object.assign({ description: root.descriptions[row.name] ?? "",
                                installed: true }, row))
        if (root.view === "installed") {
            // A query searches every installed package, ignoring the filter.
            const pool = root.term !== "" ? root.installed
                : root.installed.filter(row => root.installedFilter === "all"
                    || (root.installedFilter === "aur" ? row.aur : row.explicit))
            return pool.filter(row => root.matches(row)).map(row => Object.assign(
                { source: row.aur ? "aur" : "", installed: true }, row))
        }
        return root.term === root.foundTerm ? root.found : []
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    // A terminal is open on something this service asked for.
    readonly property bool busy: root.terminal.running

    function install(row: var): void {
        if (!row)
            return
        if (root.helper !== "")
            root.open([root.helper, "-S", row.name])
        else if (row.source !== "aur")
            root.open(["sudo", "pacman", "-S", row.name])
    }

    // -Rns: also removes orphaned dependencies and the configuration pacman
    // would otherwise keep as .pacsave. pacman refuses, with its reason, if
    // something still depends on the package.
    function remove(row: var): void {
        if (row)
            root.open(["sudo", "pacman", "-Rns", row.name])
    }

    function upgrade(): void {
        root.open(root.helper !== ""
            ? [root.helper, "-Syu"]
            : ["sudo", "pacman", "-Syu"])
    }

    // AUR packages need a helper.
    function installable(row: var): bool {
        return !!row && !row.installed && (row.source !== "aur" || root.helper !== "")
    }

    // The command is passed as arguments, never interpolated into the
    // script. The --class matches a floating window rule, and the script
    // keeps the window open with the exit status until Enter.
    readonly property string holdScript: "\"$@\"; status=$?; printf '\\n'; "
        + "if [ $status -eq 0 ]; then printf '  Done. '; "
        + "else printf '  Stopped, with status %s. ' \"$status\"; fi; "
        + "printf 'Enter closes this window.'; read -r _"

    function open(command: var): void {
        if (root.terminal.running)
            return
        root.terminal.command = ["kitty", "--class", "impasto-packages",
                                 "--title", command.join(" "),
                                 "sh", "-c", root.holdScript, "sh"].concat(command)
        root.terminal.running = true
    }

    readonly property Process terminal: Process {
        onExited: {
            root.load()
            UpdatesService.refresh()
            if (root.foundTerm !== "")
                root.search()
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var sectors: ["All", "Favorites", "Recent", "Internet", "Development", "Gaming",
                                    "Media", "Graphics", "Office", "System", "Utilities", "Other"]

    // ---- Favorites and recents (saved in ~/.local/state/quickshell/launcher.json) ----
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property int recentMax: 12

    property var favorites: []      // app ids
    property var recent: []         // app ids, most recent first

    FileView {
        id: store
        path: root.stateDir + "/launcher.json"
        blockLoading: true
        printErrors: false
    }

    function save() {
        try {
            store.setText(JSON.stringify({ favorites: favorites, recent: recent }))
        } catch (e) {
            console.log("launcher: save:", e)
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        try {
            const d = JSON.parse(store.text())
            if (Array.isArray(d.favorites)) favorites = d.favorites
            if (Array.isArray(d.recent)) recent = d.recent.slice(0, recentMax)
        } catch (e) {}
    }

    function isFavorite(id) {
        return favorites.indexOf(id) >= 0
    }

    function toggleFavorite(id) {
        const f = favorites.slice()
        const i = f.indexOf(id)
        if (i >= 0) f.splice(i, 1)
        else f.push(id)
        favorites = f
        save()
    }

    function recordRecent(id) {
        const r = recent.filter(x => x !== id)
        r.unshift(id)
        recent = r.slice(0, recentMax)
        save()
    }

    // ---- App list ----
    function has(cats, name) {
        for (let i = 0; i < cats.length; i++) if (cats[i] === name) return true
        return false
    }

    function sectorOf(e) {
        const c = e.categories
        if (has(c, "Game")) return "Gaming"
        if (has(c, "Development")) return "Development"
        if (has(c, "WebBrowser") || has(c, "Network")) return "Internet"
        if (has(c, "AudioVideo") || has(c, "Audio") || has(c, "Video")) return "Media"
        if (has(c, "Graphics")) return "Graphics"
        if (has(c, "Office")) return "Office"
        if (has(c, "System") || has(c, "Settings")) return "System"
        if (has(c, "Utility")) return "Utilities"
        return "Other"
    }

    // All visible apps, in alphabetical order
    readonly property var all: {
        const v = DesktopEntries.applications.values
        const out = []
        for (let i = 0; i < v.length; i++) {
            const e = v[i]
            if (e.noDisplay) continue
            let kw = ""
            for (let k = 0; k < e.keywords.length; k++) kw += " " + e.keywords[k]
            out.push({
                id: e.id,
                entry: e,
                name: e.name,
                sub: e.comment || e.genericName || "",
                icon: e.icon,
                sector: sectorOf(e),
                hay: (e.name + " " + e.genericName + " " + e.comment + kw).toLowerCase()
            })
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }

    readonly property var byId: {
        const m = {}
        for (let i = 0; i < all.length; i++) m[all[i].id] = all[i]
        return m
    }

    // Apps of a sector (Favorites: alphabetical order, Recent: most recent first)
    function inSector(sector) {
        const out = []
        if (sector === "All") return all
        if (sector === "Favorites") {
            for (let i = 0; i < all.length; i++)
                if (favorites.indexOf(all[i].id) >= 0) out.push(all[i])
            return out
        }
        if (sector === "Recent") {
            for (let i = 0; i < recent.length; i++) {
                const a = byId[recent[i]]
                if (a) out.push(a)
            }
            return out
        }
        for (let i = 0; i < all.length; i++) if (all[i].sector === sector) out.push(all[i])
        return out
    }

    function count(sector) {
        return inSector(sector).length
    }

    // Show only the sectors that have at least one app
    readonly property var visibleSectors: sectors.filter(
        s => s === "All" || s === "Favorites" || s === "Recent" || count(s) > 0)

    function filter(query, sector) {
        const q = query.trim().toLowerCase()

        if (q === "") return inSector(sector)

        // With a search I look in all sectors: first those starting with the text, then the rest
        const scored = []
        for (let i = 0; i < all.length; i++) {
            const a = all[i]
            const n = a.name.toLowerCase()
            let score = -1
            if (n.startsWith(q)) score = 0
            else if (n.indexOf(q) >= 0) score = 1
            else if (a.hay.indexOf(q) >= 0) score = 2
            if (score >= 0) scored.push([score, a])
        }
        scored.sort((x, y) => (x[0] - y[0]) || x[1].name.localeCompare(y[1].name))
        return scored.map(s => s[1])
    }

    function launch(entry) {
        if (entry.runInTerminal) {
            const cmd = ["kitty", "-e"]
            for (let i = 0; i < entry.command.length; i++) cmd.push(entry.command[i])
            Quickshell.execDetached(cmd)
        } else {
            entry.execute()
        }

        try { recordRecent(entry.id) } catch (e) { console.log("launcher: recents:", e) }
    }
}

.pragma library

// Which Hyprland window a media player lives in. Used by MediaPopup.qml (the tab's
// label, the cover's "go to the window" click, and one entry per app).
//
// Firefox forks (Zen, LibreWolf, Floorp...) publish their MPRIS player under
// Firefox's own name, so a "Mozilla Firefox" player can really be Zen. When no
// window matches by name and the player is Firefox-family, fall back to
// whichever Firefox-family window is open and say so (`viaFallback`).

var firefoxFamily = /firefox|zen|librewolf|floorp|waterfox|mullvad|tor-browser/

function classOf(t) {
    return String(t.wayland?.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "").toLowerCase()
}

// -> { matches: [toplevel...], viaFallback: bool }
function resolve(p, toplevels) {
    const names = []
    const add = v => {
        const t = String(v ?? "").toLowerCase().trim()
        if (t !== "" && names.indexOf(t) === -1)
            names.push(t)
    }
    add(p.desktopEntry)
    add(p.identity)
    add(String(p.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "").replace(/\.instance.*$/, ""))
    // "Mozilla Firefox" -> "firefox", "Mozilla zen-twilight" -> "zen-twilight"
    for (const part of String(p.identity ?? "").toLowerCase().split(/\s+/))
        if (part !== "mozilla" && part.length > 2)
            add(part)

    const all = (toplevels ?? []).filter(t => classOf(t) !== "")
    const byName = all.filter(t => {
        const cls = classOf(t)
        return names.some(n => cls === n || cls.indexOf(n) !== -1 || n.indexOf(cls) !== -1)
    })
    if (byName.length > 0)
        return { matches: byName, viaFallback: false }

    if (names.some(n => firefoxFamily.test(n))) {
        const forks = all.filter(t => firefoxFamily.test(classOf(t)))
        if (forks.length > 0)
            return { matches: forks, viaFallback: true }
    }
    return { matches: [], viaFallback: false }
}

// One app = one card. Players that live in the same app are merged into one,
// keeping the featured one, else a playing one, else the first: Zen and
// Chromium report several players (one per tab / window / instance), mpv one
// per running instance. Apps are told apart by their window's class; a player
// with no window (Spotify closed to the tray, say) is grouped by its own name.
function onePerApp(players, toplevels, featured, playingState) {
    const groups = {}
    const out = []
    const score = q => (q === featured ? 2 : 0) + (q.playbackState === playingState ? 1 : 0)
    for (const p of players) {
        const info = resolve(p, toplevels)
        const key = info.matches.length > 0
            ? "win:" + classOf(info.matches[0])
            : "id:" + String(p.desktopEntry || p.identity || p.dbusName || "").toLowerCase()
        const best = groups[key]
        if (best === undefined) {
            groups[key] = { player: p, index: out.length }
            out.push(p)
        } else if (score(p) > score(best.player)) {
            out[best.index] = p
            best.player = p
        }
    }
    return out
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

// The 10-band equalizer's state and brain, carried over from the end-4's pC fork
// version (EqualizerView.qml + EqualizerAutoService.qml) into one singleton, so
// the card (EqualizerPopup.qml) is only drawing:
//
//   - the ten bands, the preamp, the preset in use, and whether there are
//     unsaved changes (`pending`);
//   - every call to scripts/eq/equalizer.sh (it writes the 32-band EasyEffects
//     preset and loads it live). The calls go through ONE queue, one at a time,
//     because the script reads, changes and rewrites a small state file: two of
//     them at once could lose a change;
//   - Auto: follows the song's genre (Last.fm tags -> a preset) in the
//     background, whether or not the card is open.
//
// Needs `easyeffects`, `jq`, `python3` and `curl` (Auto only). The state lives in
// ${XDG_STATE_HOME:-~/.local/state}/sekaipop/eq.
//
//   qs -c sekaipop ipc call eq open | preset <name> | auto <on|off> | get
//                            lastfmKey <key> | saveAs <name>
//                            chain <name> | newChain <name>
Singleton {
    id: root

    // ===== where things are =====
    readonly property string script: Directories.script("eq/equalizer.sh")
    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/sekaipop/eq"

    // ===== the curve =====
    readonly property var bandLabels: ["32", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property real bandRange: 12          // -12 .. +12 dB
    readonly property real preampRange: 12

    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real preamp: 0
    property string presetName: "Flat"
    // Changed, audible (previewed), but not written into the preset yet.
    property bool pending: false
    // equalizer.sh refused to touch a preset EasyEffects never saved.
    property bool needsManualSave: false

    readonly property var presetNames: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    // Mirrors equalizer.sh's save_preset() calls, so a tap moves the pegs at once.
    readonly property var presetValues: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
        "Treble":  [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
        "Vocal":   [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
        "Pop":     [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
        "Rock":    [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
        "Jazz":    [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
        "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
    })

    // Your own saved curves: { name: [10 numbers] }.
    property var customPresets: ({})
    readonly property var customNames: Object.keys(root.customPresets).sort()

    // The EasyEffects preset the equalizer is merged into (the one holding the
    // rest of your chain), and the ones that exist on disk.
    property string activePreset: "output"
    property var availablePresets: []

    property string lastfmKey: ""

    signal openRequested()

    // ===== the command queue =====
    property var queue: []

    function run(args) {
        const q = root.queue.slice()
        const key = args[0]
        // A newer value for the same band / preamp replaces one still waiting,
        // and one waiting preview is enough.
        if (key === "set_band" || key === "set_preamp" || key === "preview") {
            for (let i = q.length - 1; i >= 0; i--) {
                const a = q[i]
                if (a[0] === key && (key !== "set_band" || a[1] === args[1])) {
                    q[i] = args
                    root.queue = q
                    root.pump()
                    return
                }
            }
        }
        q.push(args)
        root.queue = q
        root.pump()
    }

    function pump() {
        if (runner.running || root.queue.length === 0)
            return
        const q = root.queue.slice()
        const next = q.shift()
        root.queue = q
        runner.exec(["bash", root.script, root.stateDir].concat(next))
    }

    Process {
        id: runner
        onExited: root.pump()
    }

    // ===== reading it back =====
    function refresh() {
        getProc.running = false
        getProc.running = true
        customProc.running = false
        customProc.running = true
        activeProc.running = false
        activeProc.running = true
        listProc.running = false
        listProc.running = true
        keyProc.running = false
        keyProc.running = true
        root.refreshNeedsSave()
        autoGetProc.running = false
        autoGetProc.running = true
    }

    function refreshNeedsSave() {
        needsProc.running = false
        needsProc.running = true
    }

    // The script's calls are detached; give them a moment, then ask what they found.
    Timer {
        id: recheck
        interval: 600
        onTriggered: root.refreshNeedsSave()
    }

    // ===== changing it =====
    function setBand(index, value) {
        const v = Math.max(-root.bandRange, Math.min(root.bandRange, Math.round(value)))
        if (root.bands[index] === v)
            return
        const b = root.bands.slice()
        b[index] = v
        root.bands = b
        root.presetName = "Custom"
        root.currentPresetName = "Custom"
        root.pending = true
        root.run(["set_band", String(index + 1), String(v)])
        previewTimer.restart()
    }

    function resetBand(index) {
        root.setBand(index, 0)
    }

    // The preamp is a master gain on top of the curve; it does not rename the preset.
    function setPreamp(value) {
        const v = Math.max(-root.preampRange, Math.min(root.preampRange, Math.round(value)))
        if (root.preamp === v)
            return
        root.preamp = v
        root.pending = true
        root.run(["set_preamp", String(v)])
        previewTimer.restart()
    }

    // Hear it after the controls go quiet: the preview reloads the whole
    // EasyEffects chain, which pops if it is done many times a second.
    Timer {
        id: previewTimer
        interval: 120
        onTriggered: root.run(["preview"])
    }

    // The real commit: into the active preset's own file.
    function save() {
        previewTimer.stop()
        root.run(["save"])
        root.pending = false
        recheck.restart()
    }

    // Throw away what was only previewed, back to the saved preset.
    function revert() {
        previewTimer.stop()
        root.run(["revert_preview"])
        root.pending = false
        revertRead.restart()
    }

    Timer {
        id: revertRead
        interval: 700
        onTriggered: {
            getProc.running = false
            getProc.running = true
        }
    }

    // Called when the card is put away by a click elsewhere: what was never
    // saved does not stay on your ears.
    function discardIfPending() {
        if (root.pending)
            root.revert()
    }

    function applyPreset(name) {
        const vals = root.presetValues[name]
        if (!vals)
            return
        root.bands = vals.slice()
        root.presetName = name
        root.currentPresetName = name
        root.pending = false
        previewTimer.stop()
        root.run(["preset", name])
        recheck.restart()
    }

    function applyCustom(name) {
        const vals = root.customPresets[name]
        if (!vals)
            return
        root.bands = vals.slice()
        root.presetName = name
        root.currentPresetName = name
        root.pending = false
        previewTimer.stop()
        root.run(["preset", name])
        recheck.restart()
    }

    // Any preset name: a built-in, or one of your own.
    function applyAny(name) {
        if (root.presetValues[name] !== undefined)
            root.applyPreset(name)
        else if (root.customPresets[name] !== undefined)
            root.applyCustom(name)
    }

    function saveCustom(name) {
        const n = String(name).trim()
        if (n === "")
            return
        previewTimer.stop()
        root.run(["save_custom", n].concat(root.bands.map(v => String(Math.round(v)))))
        const updated = Object.assign({}, root.customPresets)
        updated[n] = root.bands.slice()
        root.customPresets = updated
        root.presetName = n
        root.currentPresetName = n
        root.pending = false
        recheck.restart()
    }

    function deleteCustom(name) {
        root.run(["delete_custom", name])
        const updated = Object.assign({}, root.customPresets)
        delete updated[name]
        root.customPresets = updated
        if (root.presetName === name) {
            root.presetName = "Custom"
            root.currentPresetName = "Custom"
        }
    }

    function setActivePreset(name) {
        const n = String(name).trim()
        if (n === "")
            return
        root.activePreset = n
        root.run(["set_active_preset", n])
        recheck.restart()
        listRefresh.restart()
    }

    // Makes a brand-new EasyEffects preset and switches to it. That reloads
    // EasyEffects, so whatever you had live and unsaved there is replaced.
    function createActivePreset(name) {
        const n = String(name).trim()
        if (n === "")
            return
        root.activePreset = n
        root.run(["create_preset", n])
        recheck.restart()
        listRefresh.restart()
    }

    Timer {
        id: listRefresh
        interval: 800
        onTriggered: {
            listProc.running = false
            listProc.running = true
        }
    }

    function setLastfmKey(key) {
        const k = String(key).trim()
        root.lastfmKey = k
        root.run(["set_lastfm_key", k])
        // A key just came (or went): look the current song up again.
        root.lastLookupKey = ""
        root.maybeLookupGenre()
    }

    // ===== Auto: follow the genre =====
    property bool autoEnabled: false

    // Which players Auto reacts to at all (substring of the player's name,
    // lower case). Empty = whatever is playing. Check yours with
    // `playerctl -l`.
    readonly property var allowedPlayerIdentities: ["spotify", "firefox"]
    // For these, the page the player is on has to be one of these hosts as well
    // (so a podcast in another tab does not count as "watching YouTube").
    readonly property var domainRestrictedIdentities: ({
        "firefox": ["youtube.com"]
    })

    // The player Auto listens to: the one playing, else one with a song.
    readonly property var player: {
        const list = Mpris.players.values
        let paused = null
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (!root.isEligiblePlayer(p))
                continue
            if (p.playbackState === MprisPlaybackState.Playing)
                return p
            if (paused === null && (p.trackTitle ?? "") !== "")
                paused = p
        }
        return paused
    }

    function isEligiblePlayer(p) {
        if (!p)
            return false
        const identity = (p.identity ?? "").toLowerCase()
        if (root.allowedPlayerIdentities.length > 0
                && !root.allowedPlayerIdentities.some(id => identity.includes(id)))
            return false
        for (const key in root.domainRestrictedIdentities) {
            if (!identity.includes(key))
                continue
            const hosts = root.domainRestrictedIdentities[key]
            const pageUrl = String(p.metadata?.["xesam:url"] ?? "").toLowerCase()
            return hosts.some(host => pageUrl.includes(host))
        }
        return true
    }

    // The preset Auto last applied (or you did), so a lookup that lands on the
    // same one is a no-op instead of another EasyEffects reload.
    property string currentPresetName: "Flat"
    property string lastLookupKey: ""
    property var lastArtistTags: []
    property var lastTrackTags: []

    readonly property var genreTagPresetMap: ({
        "metal": "Rock", "punk": "Rock", "grunge": "Rock",
        "emo": "Rock", "screamo": "Rock", "ska": "Rock", "rock": "Rock",
        "classical": "Classic", "orchestra": "Classic", "orchestral": "Classic",
        "opera": "Classic", "baroque": "Classic", "symphony": "Classic", "soundtrack": "Classic",
        "jazz": "Jazz", "blues": "Jazz", "swing": "Jazz", "bossa nova": "Jazz",
        "lounge": "Jazz", "trip hop": "Jazz", "ambient": "Jazz", "chillout": "Jazz",
        "downtempo": "Jazz", "lo-fi": "Jazz", "lofi": "Jazz",
        "hip hop": "Bass", "hip-hop": "Bass", "rap": "Bass", "trap": "Bass",
        "edm": "Bass", "electronic": "Bass", "house": "Bass", "techno": "Bass",
        "dubstep": "Bass", "dnb": "Bass", "d&b": "Bass", "reggae": "Bass", "dub": "Bass",
        "grime": "Bass", "funk": "Bass", "disco": "Bass", "afrobeat": "Bass",
        "synthwave": "Bass", "bass": "Bass",
        "acoustic": "Vocal", "folk": "Vocal", "singer-songwriter": "Vocal",
        "a cappella": "Vocal", "country": "Vocal", "gospel": "Vocal", "choir": "Vocal",
        "soul": "Vocal", "r&b": "Vocal", "rnb": "Vocal", "vocal": "Vocal",
        "pop": "Pop"
    })

    // Last.fm tags that contain a key by accident ("male vocalists" is not
    // "vocal", a "double bass" is not "bass").
    readonly property var falsePositiveSubstrings: ({
        "vocal": ["vocalist"],
        "bass": ["double bass", "upright bass", "bass guitar", "bassist", "bass player"]
    })

    function toggleAuto() {
        const next = !root.autoEnabled
        root.autoEnabled = next
        root.run(["set_auto", next ? "true" : "false"])
        if (next) {
            root.lastLookupKey = ""
            root.maybeLookupGenre()
        }
    }

    function setAuto(on) {
        if (root.autoEnabled !== on)
            root.toggleAuto()
    }

    // "Artist - Title (Lyrics) - YouTube" -> { artist, track }, a guess for
    // players (Firefox) that give no artist of their own.
    function deriveYouTubeArtistTrack(rawTitle) {
        let t = String(rawTitle ?? "")
        t = t.replace(/^\(\d+\)\s*/, "").replace(/\s*-\s*YouTube$/i, "").trim()
        if (!t)
            return null
        const parts = t.split(" - ")
        if (parts.length < 2)
            return null
        const artist = parts[0].trim()
        let track = parts.slice(1).join(" - ").trim()
        track = track.replace(/[\[(](official\s*)?(music\s*)?(video|audio|lyrics?|visualizer|hd|4k)[\])]/gi, "").trim()
        if (!artist || !track)
            return null
        return { artist: artist, track: track }
    }

    function maybeLookupGenre() {
        if (!root.autoEnabled)
            return
        if (!root.isEligiblePlayer(root.player))
            return
        let artist = root.player?.trackArtist ?? ""
        let title = root.player?.trackTitle ?? ""
        if (!artist && title) {
            const parsed = root.deriveYouTubeArtistTrack(title)
            if (!parsed)
                return
            artist = parsed.artist
            title = parsed.track
        }
        if (!artist)
            return
        const key = artist + "\u241F" + title
        if (key === root.lastLookupKey)
            return
        root.lastLookupKey = key
        root.lastArtistTags = []
        root.lastTrackTags = []
        genreProc.artist = artist
        genreProc.running = false
        genreProc.running = true
        if (title) {
            trackGenreProc.artist = artist
            trackGenreProc.title = title
            trackGenreProc.running = false
            trackGenreProc.running = true
        }
    }

    // One tag list's votes: the top tag counts most, then it decays.
    function scoreTagGroup(tags, multiplier, scores) {
        if (!Array.isArray(tags))
            return
        tags.forEach((tag, i) => {
            const lower = String(tag).toLowerCase()
            if (!lower)
                return
            const rankWeight = tags.length - i
            for (const key in root.genreTagPresetMap) {
                if (!lower.includes(key))
                    continue
                const exclusions = root.falsePositiveSubstrings[key]
                if (exclusions && exclusions.some(bad => lower.includes(bad)))
                    continue
                const preset = root.genreTagPresetMap[key]
                scores[preset] = (scores[preset] || 0) + rankWeight * multiplier
                break
            }
        })
    }

    // The song's own tags weigh three times the artist's. Nothing matched = null
    // (the preset stays as it is).
    function presetForTags(artistTags, trackTags) {
        const scores = {}
        root.scoreTagGroup(trackTags, 3, scores)
        root.scoreTagGroup(artistTags, 1, scores)
        let best = null
        let bestScore = 0
        for (const preset in scores) {
            if (scores[preset] > bestScore) {
                best = preset
                bestScore = scores[preset]
            }
        }
        return bestScore > 0 ? best : null
    }

    function recomputePreset() {
        if (!root.autoEnabled)
            return
        const preset = root.presetForTags(root.lastArtistTags, root.lastTrackTags)
        if (preset && preset !== root.currentPresetName)
            root.applyPreset(preset)
    }

    onPlayerChanged: root.maybeLookupGenre()

    Connections {
        target: root.player
        function onTrackArtistChanged() { root.maybeLookupGenre() }
        function onTrackTitleChanged() { root.maybeLookupGenre() }
    }

    Component.onCompleted: root.refresh()

    // ===== the readers =====
    Process {
        id: getProc
        command: ["bash", root.script, root.stateDir, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.bands = [d.b1, d.b2, d.b3, d.b4, d.b5, d.b6, d.b7, d.b8, d.b9, d.b10].map(Number)
                    root.presetName = d.preset ?? "Custom"
                    root.currentPresetName = root.presetName
                    root.pending = !!d.pending
                    root.preamp = Number(d.preamp) || 0
                } catch (e) {
                    // The state file is not there yet: keep what is showing.
                }
            }
        }
    }

    Process {
        id: customProc
        command: ["bash", root.script, root.stateDir, "get_custom"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const parsed = {}
                    for (const name in d) {
                        const b = d[name]
                        parsed[name] = [b.b1, b.b2, b.b3, b.b4, b.b5, b.b6, b.b7, b.b8, b.b9, b.b10].map(Number)
                    }
                    root.customPresets = parsed
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: activeProc
        command: ["bash", root.script, root.stateDir, "get_active_preset"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.activePreset = t.length > 0 ? t : "output"
            }
        }
    }

    Process {
        id: listProc
        command: ["bash", root.script, root.stateDir, "list_presets"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.availablePresets = JSON.parse(text)
                } catch (e) {
                    root.availablePresets = []
                }
            }
        }
    }

    Process {
        id: keyProc
        command: ["bash", root.script, root.stateDir, "get_lastfm_key"]
        stdout: StdioCollector {
            onStreamFinished: root.lastfmKey = text.trim()
        }
    }

    Process {
        id: needsProc
        command: ["bash", root.script, root.stateDir, "get_needs_save"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.needsManualSave = (t === "true" || t === "1")
            }
        }
    }

    Process {
        id: autoGetProc
        command: ["bash", root.script, root.stateDir, "get_auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.autoEnabled = (t === "true" || t === "1")
                if (root.autoEnabled)
                    root.maybeLookupGenre()
            }
        }
    }

    Process {
        id: genreProc
        property string artist: ""
        command: artist.length > 0
            ? ["bash", root.script, root.stateDir, "genre_tags", artist]
            : ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lastArtistTags = JSON.parse(text)
                } catch (e) {
                    root.lastArtistTags = []
                }
                root.recomputePreset()
            }
        }
    }

    Process {
        id: trackGenreProc
        property string artist: ""
        property string title: ""
        command: (artist.length > 0 && title.length > 0)
            ? ["bash", root.script, root.stateDir, "track_genre_tags", artist, title]
            : ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lastTrackTags = JSON.parse(text)
                } catch (e) {
                    root.lastTrackTags = []
                }
                root.recomputePreset()
            }
        }
    }

    // ===== ipc =====
    IpcHandler {
        target: "eq"

        // Open (or put away) the equalizer card on the focused monitor.
        function open(): void {
            root.openRequested()
        }

        function preset(name: string): void {
            root.applyAny(name)
        }

        function auto(on: bool): void {
            root.setAuto(on)
        }

        function get(): string {
            return JSON.stringify({
                bands: root.bands,
                preamp: root.preamp,
                preset: root.presetName,
                pending: root.pending,
                auto: root.autoEnabled,
                chain: root.activePreset
            })
        }

        // For when typing into the card does not work (the compositor did not give
        // it the keyboard): set the Last.fm key / save the curve from the terminal.
        function lastfmKey(key: string): void {
            root.setLastfmKey(key)
        }

        function saveAs(name: string): void {
            root.saveCustom(name)
        }

        // Same fallback for the setup page: pick an existing EasyEffects preset
        // for the equalizer to live in, or create a new one.
        function chain(name: string): void {
            root.setActivePreset(name)
        }

        function newChain(name: string): void {
            root.createActivePreset(name)
        }
    }
}

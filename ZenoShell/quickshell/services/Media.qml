pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // Prefers the player that is playing, otherwise the first available
    readonly property var player: {
        const list = Mpris.players.values
        let first = null
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
            if (first === null) first = list[i]
        }
        return first
    }

    readonly property bool active: player !== null
    readonly property string title:  player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album:  player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property string source: player ? (player.identity || "") : ""
    readonly property bool playing:  player ? player.isPlaying : false

    readonly property real position: player ? player.position : 0
    readonly property real length:   player ? player.length : 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    readonly property bool canSeek: player ? (player.canSeek && player.positionSupported && length > 0) : false
    readonly property bool canNext: player ? player.canGoNext : false
    readonly property bool canPrevious: player ? player.canGoPrevious : false
    readonly property bool canToggle: player ? player.canTogglePlaying : false

    // MPRIS does not announce the position while it advances: ask for it twice a second
    Timer {
        interval: 500
        repeat: true
        running: root.playing && root.player !== null && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }

    function toggle()   { if (canToggle) player.togglePlaying() }
    function next()     { if (canNext) player.next() }
    function previous() { if (canPrevious) player.previous() }
    function seekTo(ratio) { if (canSeek) player.position = ratio * length }

    function fmt(s) {
        const t = Math.max(0, Math.floor(s))
        const m = Math.floor(t / 60)
        const sec = t % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }
}

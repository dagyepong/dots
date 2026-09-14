// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   S E R V I C E                                              │
// │   the player worth showing · mpris over d-bus                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

import "."

// Picks one MPRIS player and exposes it flatly: the one that is playing,
// otherwise the first controllable one, so a paused track stays on the island.
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    readonly property MprisPlayer active: {
        const playing = root.players.find(player => player.isPlaying)
        if (playing)
            return playing
        return root.players.find(player => player.canControl) ?? null
    }

    readonly property bool available: root.active !== null
    readonly property bool playing: root.available && root.active.isPlaying

    readonly property string title: root.available ? (root.active.trackTitle ?? "") : ""
    readonly property string artist: root.available ? (root.active.trackArtist ?? "") : ""
    readonly property string album: root.available ? (root.active.trackAlbum ?? "") : ""
    readonly property string artUrl: root.available ? (root.active.trackArtUrl ?? "") : ""
    readonly property string identity: root.available ? (root.active.identity ?? "") : ""

    readonly property bool canNext: root.available && root.active.canGoNext
    readonly property bool canPrevious: root.available && root.active.canGoPrevious
    readonly property bool canToggle: root.available && root.active.canTogglePlaying
    readonly property bool canSeek: root.available && root.active.canSeek && root.length > 0

    // Seconds. Streams report no length, so `progress` stays at 0.
    readonly property real length: root.available ? (root.active.length ?? 0) : 0
    readonly property real position: root.available ? (root.active.position ?? 0) : 0
    readonly property bool seekable: root.length > 0
    readonly property real progress: root.seekable
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0

    // MPRIS does not push position, so it is polled only while something on
    // screen holds a subscribe().
    property int watchers: 0

    readonly property Timer positionTimer: Timer {
        interval: 1000
        repeat: true
        running: root.watchers > 0 && root.playing && root.seekable
        onTriggered: {
            if (root.available)
                root.active.positionChanged()
        }
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function toggle(): void {
        if (root.canToggle)
            root.active.togglePlaying()
    }

    function next(): void {
        if (root.canNext)
            root.active.next()
    }

    // `fraction` of the track's length.
    function seek(fraction: real): void {
        if (!root.canSeek)
            return
        root.active.position = Math.max(0, Math.min(1, fraction)) * root.length
    }

    function previous(): void {
        if (root.canPrevious)
            root.active.previous()
    }
}

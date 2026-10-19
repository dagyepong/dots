import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// The system side of the media pill (with Bar.qml, one of the only two
// files that talk to the system). Anything that publishes itself over
// MPRIS shows up here: Spotify, mpv, VLC, and browsers — Firefox and
// Chromium-based ones expose YouTube / Twitch / SoundCloud tabs as a
// player through the web Media Session API, so "watching a video on
// YT" works with no extra setup.
//
// Which player is shown when there are several:
//   1. whichever one most recently *started* playing, whether it's
//      still playing or you've since paused it — pausing Spotify
//      doesn't hand the widget over to a YouTube tab that merely
//      happens to still be going in the background; only actually
//      hitting play on that tab does. (This is also why pausing dims
//      the widget instead of blanking it: the same player stays
//      picked, just now paused.)
//   2. nothing has ever "started" yet this session (fresh shell
//      launch, something was already playing before it could see the
//      transition) -> any player that's currently playing
//   3. otherwise a paused player
//   4. otherwise nothing -> "Nothing Playing"
Scope {
    id: root

    property var lastStarted: null

    readonly property var player: pickPlayer()

    readonly property bool present: player !== null
    readonly property bool playing: player !== null
        && player.playbackState === MprisPlaybackState.Playing

    readonly property string title: {
        if (player === null)
            return ""
        // A few players report no title at all; name the app instead
        // of showing an empty pill.
        return player.trackTitle !== "" ? player.trackTitle : (player.identity ?? "")
    }
    readonly property string artist: player?.trackArtist ?? ""

    // Cover art from the player; when a browser doesn't hand one over
    // but the tab is a YouTube video, fall back to that video's own
    // thumbnail (mqdefault is 16:9 with no letterbox bars).
    readonly property string artUrl: {
        if (player === null)
            return ""
        const direct = player.trackArtUrl ?? ""
        return direct !== "" ? direct : youtubeThumbnail()
    }

    onArtUrlChanged: console.log("[media] " + title + " | art: " + (artUrl !== "" ? artUrl : "(none)"))

    function youtubeThumbnail() {
        const md = player.metadata
        const url = md ? md["xesam:url"] : undefined
        if (typeof url !== "string")
            return ""
        const m = url.match(/(?:[?&]v=|youtu\.be\/|\/shorts\/)([A-Za-z0-9_-]{11})/)
        return m ? "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg" : ""
    }

    function pickPlayer() {
        const list = Mpris.players.values

        // Rule 1: the last player that actually started playing keeps
        // the widget for as long as it's still around, playing or
        // paused. Checked as its own pass, ahead of "any playing
        // player" below, so a background player that never lost focus
        // can't steal the widget back just because the current one got
        // paused.
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (p === lastStarted
                    && (p.playbackState === MprisPlaybackState.Playing || p.trackTitle !== ""))
                return p
        }

        // Rule 1 found nothing usable (lastStarted is null, or that
        // player's gone/titleless) -> fall back to whatever's actually
        // playing, else whatever's paused with a title.
        let playing = null
        let paused = null
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (p.playbackState === MprisPlaybackState.Playing) {
                if (playing === null)
                    playing = p
            } else if (p.trackTitle !== "" && paused === null) {
                paused = p
            }
        }
        return playing !== null ? playing : paused
    }

    // Remember whichever player last switched to Playing.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function onPlaybackStateChanged() {
                if (modelData.playbackState === MprisPlaybackState.Playing)
                    root.lastStarted = modelData
            }
        }
    }

    // The wheel over the pill changes the player's own volume (MPRIS
    // Volume, 0..1), five points a notch. Players without volume support
    // (some browsers) ignore it.
    function changeVolume(direction) {
        if (player === null || !player.volumeSupported || !player.canControl)
            return
        const v = Math.max(0, Math.min(1, (player.volume ?? 0) + direction * 0.05))
        player.volume = v
    }

    readonly property bool volumeAvailable: player !== null && player.volumeSupported

    function togglePlaying() {
        if (player !== null && player.canTogglePlaying)
            player.togglePlaying()
    }

    function next() {
        if (player !== null && player.canGoNext)
            player.next()
    }

    function previous() {
        if (player !== null && player.canGoPrevious)
            player.previous()
    }
}

pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick 6.10

Singleton {
    id: root

    readonly property var list: Mpris.players.values

    property var active: null

    property real currentPosition: 0
    property real trackLength: 0
    property bool isPlaying: false

    function findActivePlayer() {
        var all = Mpris.players && Mpris.players.values ? Mpris.players.values : []
        if (!all || all.length === 0) return null
        for (var i = 0; i < all.length; i++) {
            if (all[i] && all[i].isPlaying) {
                return all[i]
            }
        }
        return all[0] || null
    }

    function updateActivePlayer() {
        var candidate = findActivePlayer()
        if (candidate !== active) {
            active = candidate
        }
    }

    Component.onCompleted: {
        updateActivePlayer()
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            updateActivePlayer()
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: updateActivePlayer()
    }

    Connections {
        target: active
        function onPositionChanged() {
            if (active) {
                currentPosition = active.position || 0
            }
        }
        function onPlaybackStateChanged() {
            if (active) {
                isPlaying = active.isPlaying
                trackLength = (active.length && active.length < 9e18) ? active.length : 0
                currentPosition = active.position || 0
            }
        }
    }

    onActiveChanged: {
        if (active) {
            currentPosition = active.position || 0
            trackLength = (active.length && active.length < 9e18) ? active.length : 0
            isPlaying = active.isPlaying
        } else {
            currentPosition = 0
            trackLength = 0
            isPlaying = false
        }
    }

    Timer {
        id: statePoller
        interval: 800
        repeat: true
        running: true
        onTriggered: {
            if (active) {
                currentPosition = active.position || 0
                trackLength = (active.length && active.length < 9e18) ? active.length : 0
                isPlaying = active.isPlaying
            } else {
                currentPosition = 0
                trackLength = 0
                isPlaying = false
            }
        }
    }

    function getIdentity(player: var): string {
        return player?.identity ?? "Unknown"
    }
}
// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   S E R V I C E                                          │
// │   weather · current conditions and forecast                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current conditions from wttr.in via `scripts/weather.py`. With no place
// set, wttr.in geolocates the request's address (no key, no account); the
// place it resolved is shown on the card.
//
// Polled every 15 minutes while something is subscribed. The last reading
// stays in between.
Singleton {
    id: root

    readonly property int pollInterval: 900000

    property int watchers: 0
    property bool available: false

    // Query on construction: the bar needs `available` before the module
    // exists to subscribe. Only reached while the module is enabled.
    Component.onCompleted: root.refresh()

    property string place: ""
    property string region: ""
    property int temperature: 0
    property int feelsLike: 0
    property string description: ""
    property string glyph: ""
    property int humidity: 0
    property int wind: 0
    property int low: 0
    property int high: 0
    property var hourly: []

    // So the card can show how old the reading is.
    property date readAt: new Date(0)

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2)
            return "just now"
        if (minutes < 60)
            return `${minutes} min ago`
        const hours = Math.round(minutes / 60)
        return `${hours} h ago`
    }

    // The next four three-hour blocks, running into tomorrow when today has
    // none left.
    readonly property var ahead: {
        const hour = root.clock.date.getHours()
        return (root.hourly ?? [])
            .filter(block => block.tomorrow || block.hour > hour)
            .slice(0, 4)
    }

    function subscribe(): void {
        root.watchers += 1
        // Only if never read or older than ten minutes.
        const minutes = (new Date().getTime() - root.readAt.getTime()) / 60000
        if (!root.available || minutes > 10)
            root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // A new place is a different reading; fetch it now.
    Connections {
        target: SettingsService

        function onWeatherPlaceChanged(): void {
            if (root.watchers > 0)
                root.refresh()
        }
    }

    property bool placeUnknown: false

    readonly property Process query: Process {
        command: {
            const line = [Quickshell.shellPath("scripts/weather.py")]
            const place = SettingsService.weatherPlace.trim()
            return place === "" ? line : line.concat([place])
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the weather report:", error)
                    return
                }
                // Flagged separately: the last good reading stays on the card,
                // so otherwise an unknown place would look like no change.
                root.placeUnknown = report.reason === "place"
                if (report.available !== true) {
                    // Keep the last good reading.
                    if (!root.available)
                        root.available = false
                    return
                }
                root.place = report.place
                root.region = report.region
                root.temperature = report.temperature
                root.feelsLike = report.feelsLike
                root.description = report.description
                root.glyph = report.glyph
                root.humidity = report.humidity
                root.wind = report.wind
                root.low = report.low
                root.high = report.high
                root.hourly = report.hourly ?? []
                root.readAt = new Date()
                root.available = true
            }
        }
    }
}

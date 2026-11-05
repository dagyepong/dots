import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.settings

// Step 4: clock format and first day of the week
WStep {
    title: "Time and calendar"
    subtitle: "How the clock looks in the bar, on the lock screen and in the calendar."

    Rectangle {
        y: 6
        width: 360
        height: 190
        radius: 24
        color: Theme.surfaceSoft

        Text {
            id: bigTime
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36
            text: Qt.formatDateTime(clock.date, Settings.timeFormat)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 58
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }

        SystemClock { id: clock; precision: SystemClock.Minutes }
    }

    Column {
        x: 420
        y: 6
        spacing: 26

        Column {
            spacing: 10
            Text { text: "Time format"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true }
            SChoice {
                base: Theme.surfaceSoft
                model: [{ id: "24", label: "24 hours" }, { id: "12", label: "12 hours  AM / PM" }]
                current: Settings.clock24 ? "24" : "12"
                onPicked: id => Settings.set("clock24", id === "24")
            }
        }

        Column {
            spacing: 10
            Text { text: "The week starts on"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true }
            SChoice {
                base: Theme.surfaceSoft
                model: [{ id: "1", label: "Monday" }, { id: "0", label: "Sunday" }]
                current: String(Settings.weekStart)
                onPicked: id => Settings.set("weekStart", parseInt(id))
            }
        }
    }
}

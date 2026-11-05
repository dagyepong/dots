import QtQuick
import qs.theme
import qs.services

SPage {
    title: "Bar & clock"
    subtitle: "The clock shown in the bar, the lock screen and the calendar."

    SSection {
        title: "Clock"

        SRow {
            title: "Time format"
            hint: "24-hour (14:30) or 12-hour with AM / PM."
            SChoice {
                model: [{ id: "24", label: "24 h" }, { id: "12", label: "12 h" }]
                current: Settings.clock24 ? "24" : "12"
                onPicked: id => Settings.set("clock24", id === "24")
            }
        }

        SRow {
            last: true
            title: "Week starts on"
            hint: "Used by the calendar."
            SChoice {
                model: [{ id: "1", label: "Monday" }, { id: "0", label: "Sunday" }]
                current: String(Settings.weekStart)
                onPicked: id => Settings.set("weekStart", parseInt(id))
            }
        }
    }
}

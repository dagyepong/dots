import QtQuick
import qs.theme
import qs.services
import qs.widgets

SPage {
    title: "Power & battery"
    subtitle: "Power profile, the two quick modes and the battery."

    Component.onCompleted: PowerSaver.refresh()

    SSection {
        title: "Modes"

        SRow {
            title: "Game Mode"
            hint: "Animations, blur, shadows, rounded corners and gaps off; Do Not Disturb on. Also with Alt+G."
            Toggle { checked: GameMode.on; onToggled: GameMode.toggle() }
        }

        SRow {
            last: true
            title: "Eco Mode"
            hint: "Power-saver profile, brightness down, Bluetooth off, fewer effects. Also with Alt+E."
            Toggle { checked: PowerSaver.on; onToggled: PowerSaver.toggle() }
        }
    }

    SSection {
        title: "Power profile"

        SRow {
            last: true
            title: "System profile"
            hint: PowerSaver.profile === "" ? "power-profiles-daemon is not answering: install it and start it to use this." : "Needs power-profiles-daemon."
            SChoice {
                model: [{ id: "power-saver", label: "Saver" }, { id: "balanced", label: "Balanced" }, { id: "performance", label: "Performance" }]
                current: PowerSaver.profile
                onPicked: id => { PowerSaver.setProfile(id); PowerSaver.profile = id }
            }
        }
    }

    SSection {
        title: "Battery"
        visible: Battery.present
        height: visible ? implicitHeight : 0

        SRow {
            title: Math.round(Battery.percent * 100) + "%"
            hint: Battery.statusText + (Battery.timeText !== "" ? " · " + Battery.timeText : "")
            last: true
            Rectangle {
                width: 160; height: 10; radius: 5
                color: Theme.island
                Rectangle {
                    width: Math.max(10, parent.width * Battery.percent); height: 10; radius: 5
                    color: Battery.tone
                }
            }
        }
    }
}

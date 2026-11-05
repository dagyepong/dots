import QtQuick
import Quickshell
import qs.theme
import qs.services

SPage {
    title: "Wallpaper, lock & idle"
    subtitle: "The wallpaper picker, the lock screen and what happens when you stop using the computer."

    SSection {
        title: "Wallpaper"

        SRow {
            last: true
            title: "Choose a wallpaper"
            hint: "Opens the picker with the images of your Wallpapers folder. The colors of the shell follow the one you pick. Also with Alt+W."
            SButton {
                label: "Open picker"
                accent: true
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wallpaper", "toggle"])
            }
        }
    }

    SSection {
        title: "Lock screen"

        SRow {
            last: true
            title: "Lock now"
            hint: "Also with Alt+L."
            SButton {
                label: "Lock"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"])
            }
        }
    }

    SSection {
        title: "When idle"

        SRow {
            title: "Lock the screen after"
            hint: "Counted from the last mouse or keyboard input. Needs a compositor that supports idle notifications (niri and Hyprland do)."
            SChoice {
                model: [{ id: "0", label: "Never" }, { id: "5", label: "5 min" }, { id: "10", label: "10 min" }, { id: "15", label: "15 min" }, { id: "30", label: "30 min" }]
                current: String(Settings.lockMin)
                onPicked: id => Settings.set("lockMin", parseInt(id))
            }
        }

        SRow {
            last: true
            title: "Turn the screen off after"
            hint: "The screen wakes up with the first movement. Videos and other things that keep the screen awake are respected."
            SChoice {
                model: [{ id: "0", label: "Never" }, { id: "5", label: "5 min" }, { id: "10", label: "10 min" }, { id: "15", label: "15 min" }, { id: "30", label: "30 min" }]
                current: String(Settings.screenOffMin)
                onPicked: id => Settings.set("screenOffMin", parseInt(id))
            }
        }
    }
}

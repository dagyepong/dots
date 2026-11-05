import QtQuick
import qs.theme
import qs.services
import qs.widgets

SPage {
    title: "Notifications & OSD"
    subtitle: "Do Not Disturb and the volume / brightness indicator."

    SSection {
        title: "Do Not Disturb"

        SRow {
            title: "Do Not Disturb"
            hint: NotifCenter.dnd ? NotifCenter.dndText : "Notifications stop popping up; they stay in the notification center. Also with Alt+D."
            last: !NotifCenter.dnd
            Toggle {
                checked: NotifCenter.dnd
                onToggled: NotifCenter.setDnd(!NotifCenter.dnd, 0)
            }
        }

        SRow {
            visible: NotifCenter.dnd
            height: visible ? implicitHeight : 0
            last: true
            title: "Turn off after"
            hint: "Do Not Disturb switches itself off when the time is up."
            SChoice {
                model: [{ id: "30", label: "30 min" }, { id: "60", label: "1 h" }, { id: "120", label: "2 h" }, { id: "0", label: "Never" }]
                current: String(NotifCenter.dndMinutes)
                onPicked: id => NotifCenter.setDnd(true, parseInt(id))
            }
        }
    }

    SSection {
        title: "Volume & brightness indicator"

        SRow {
            title: "Show the indicator"
            hint: "The small bar that appears when volume or brightness change. Its look follows the style."
            last: !Settings.osdEnabled
            Toggle {
                checked: Settings.osdEnabled
                onToggled: Settings.set("osdEnabled", !Settings.osdEnabled)
            }
        }

        SRow {
            visible: Settings.osdEnabled
            height: visible ? implicitHeight : 0
            title: "Stays on screen for"
            SChoice {
                model: [{ id: "1000", label: "1 s" }, { id: "1500", label: "1.5 s" }, { id: "2500", label: "2.5 s" }, { id: "4000", label: "4 s" }]
                current: String(Settings.osdMs)
                onPicked: id => Settings.set("osdMs", parseInt(id))
            }
        }

        SRow {
            visible: Settings.osdEnabled
            height: visible ? implicitHeight : 0
            last: true
            title: "Preview"
            SButton {
                label: "Show now"
                onClicked: OsdState.show("volume")
            }
        }
    }
}

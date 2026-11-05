import QtQuick
import qs.theme
import qs.services
import qs.pages
import qs.widgets

SPage {
    id: root
    title: "Monitors & display"
    subtitle: "Turn monitors on or off, move them, rotate them, choose resolution, refresh rate and scale. Changes apply at once."

    Item {
        width: parent.width
        height: 40

        SButton {
            label: "Identify monitors"
            onClicked: Displays.identify()
        }

        SButton {
            x: 150
            label: "Refresh list"
            onClicked: Displays.refresh()
        }
    }

    Rectangle {
        width: parent.width
        height: dash.height + 28
        radius: 18
        color: Theme.surfaceSoft

        Flickable {
            x: 0
            y: 14
            width: parent.width
            height: dash.height
            contentWidth: dash.width
            contentHeight: dash.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            MonitorsDash {
                id: dash
                x: Math.max(0, (parent.width - width) / 2)
            }
        }
    }

    SSection {
        title: "Brightness & night light"

        Item {
            width: parent.width
            height: disp.height + 8

            DisplayPage {
                id: disp
                embedded: true
                x: 6
                y: 4
                width: parent.width - 12
            }
        }
    }
}

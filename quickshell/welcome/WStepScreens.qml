import QtQuick
import qs.theme
import qs.services
import qs.widgets
import qs.settings

// Step 6: monitors
WStep {
    title: "Your monitors"
    subtitle: "Turn them on or off, place them, rotate them, choose resolution and scale. With one monitor there is nothing to do here."

    SButton {

        base: Theme.surfaceSoft
        y: 0
        x: parent.width - width
        label: "Identify monitors"
        onClicked: Displays.identify()
    }

    Rectangle {
        y: 44
        width: parent.width
        height: dash.height + 28
        radius: 22
        color: Theme.surfaceSoft

        Flickable {
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
}

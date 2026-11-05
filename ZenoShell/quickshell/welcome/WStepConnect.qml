import QtQuick
import qs.theme
import qs.services
import qs.pages

// Step 5: Wi-Fi and Bluetooth, the real pages one next to the other
WStep {
    title: "Wi-Fi and Bluetooth"
    subtitle: "Connect now, or skip this step. Everything is also in Settings."

    Row {
        spacing: 20
        height: parent.height

        Rectangle {
            width: (parent.parent.width - 20) / 2
            height: parent.height
            radius: 22
            color: Theme.surfaceSoft
            clip: true

            WifiPage {
                anchors.fill: parent
                anchors.margins: 8
                embedded: true
            }
        }

        Rectangle {
            width: (parent.parent.width - 20) / 2
            height: parent.height
            radius: 22
            color: Theme.surfaceSoft
            clip: true

            BluetoothPage {
                anchors.fill: parent
                anchors.margins: 8
                embedded: true
            }
        }
    }
}

// ~/.config/quickshell/components/BatteryPopup.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import "../" // Imports root folder context path line cleanly

Item {
    id: popup
    property string monitorId: ""

    anchors.fill: parent

    property var device: UPower.displayDevice
    property int capacity: device ? Math.round(device.percentage * 100) : 0
    property real health: device ? Math.min(100, Math.round((device.capacity) * 100)) : 100
    property bool isCharging: device ? (device.state === 1) : false

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "Calculating..."
        let hours = Math.floor(seconds / 3600)
        let mins = Math.floor((seconds % 3600) / 60)
        return hours + "h " + mins + "m"
    }

    // Positions panel inside the screen container matching status bar alignments
    Rectangle {
        width: 220
        height: 130
        
        // Aligns panel context box down to the bottom right corner (6px offset margin gap)
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 6
        
        color: Appearance.srcery.black
        border.color: Appearance.srcery.gray3
        border.width: 1
        radius: 4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "SYSTEM POWER"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; weight: Font.Bold }
                    color: Appearance.srcery.gray4
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: popup.isCharging ? "AC POWER" : "BATTERY"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; weight: Font.Bold }
                    color: popup.isCharging ? Appearance.srcery.cyan : Appearance.srcery.yellow
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.srcery.gray2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Text { text: "Charge Level:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Appearance.srcery.gray5 }
                    Item { Layout.fillWidth: true }
                    Text { text: popup.capacity + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; color: Appearance.srcery.white }
                }

                RowLayout {
                    Text { text: "Health State:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Appearance.srcery.gray5 }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: (popup.health > 0 ? popup.health : "100") + "%"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
                        color: popup.health > 80 ? Appearance.srcery.green : Appearance.srcery.red 
                    }
                }

                RowLayout {
                    Text { 
                        text: popup.isCharging ? "Time to Full:" : "Est. Uptime:"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Appearance.srcery.gray5 
                    }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: popup.isCharging ? popup.formatTime(popup.device.timeToFull) : popup.formatTime(popup.device.timeToEmpty)
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; color: Appearance.srcery.white 
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config

Item {
    id: root
    property string monitorId: ""

    property var batteryDevice: UPower.displayDevice
    property int percent: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
    property bool charging: batteryDevice ? (batteryDevice.state === 1) : false
    property bool hasBattery: batteryDevice && batteryDevice.percentage !== undefined

    visible: hasBattery
    implicitHeight: Appearance.bar.height
    implicitWidth: visible ? mainLayout.implicitWidth : 0

    // Low frequency clock to shift matrix elements safely
    property int matrixTick: 0
    Timer {
        interval: 600
        running: root.charging
        repeat: true
        onTriggered: root.matrixTick = (root.matrixTick + 1) % 4
    }

    RowLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: 4

        // Complete Text-Based Matrix Node
        Text {
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.DemiBold
            }
            color: root.charging ? Appearance.srcery.cyan : Appearance.srcery.gray4
            Layout.alignment: Qt.AlignVCenter

            // Custom procedural formatting logic
            text: {
                let opening = "["
                let closing = "] " + root.percent + "%"
                let b1 = "░", b2 = "░", b3 = "░"

                if (root.charging) {
                    // Animates a sequential data-stream across the cells
                    if (root.matrixTick === 1) b1 = "█"
                    if (root.matrixTick === 2) b2 = "█"
                    if (root.matrixTick === 3) b3 = "█"
                    return opening + b1 + b2 + b3 + closing
                } else {
                    // Static blocks representing exact charge ranges
                    if (root.percent >= 20) b1 = "█"
                    if (root.percent >= 55) b2 = "█"
                    if (root.percent >= 85) b3 = "█"
                    return opening + b1 + b2 + b3 + closing
                }
            }
        }
    }
}
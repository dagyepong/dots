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
    implicitWidth: visible ? (mainLayout.implicitWidth) : 0

    // High-visibility base colors from your Srcery palette
    readonly property color baseColor: {
        if (percent < 20) return Appearance.srcery.red
        if (percent < 50) return Appearance.srcery.yellow
        return Appearance.srcery.green
    }

    // This tracking property controls the block stepping during charging waves
    property int chargeStep: 0

    // Low-frequency timer (0.8s interval = virtually zero CPU overhead)
    Timer {
        interval: 800
        running: root.charging
        repeat: true
        onTriggered: root.chargeStep = (root.chargeStep + 1) % 4
        onRunningChanged: if (!running) root.chargeStep = 0
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    RowLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: Appearance.spacing.p1 + 2

        // --- RETRO STEP BATTERY FRAME ---
        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter

            // Outer Shell Case
            Rectangle {
                id: batteryBorder
                anchors.fill: parent
                anchors.rightMargin: 3
                color: "transparent"
                border.color: root.charging ? Appearance.srcery.cyan : root.baseColor
                border.width: 1.5
                radius: 3

                // Container for the 3 distinct battery level cells
                Row {
                    anchors.fill: parent
                    anchors.margins: 2.5
                    spacing: 1.5

                    // Segment 1 (Low)
                    Rectangle {
                        width: 6; height: parent.height
                        radius: 1
                        color: (root.charging ? (root.chargeStep >= 1) : (root.percent >= 15)) 
                               ? (root.charging ? Appearance.srcery.cyan : root.baseColor) : "transparent"
                    }

                    // Segment 2 (Medium)
                    Rectangle {
                        width: 6; height: parent.height
                        radius: 1
                        color: (root.charging ? (root.chargeStep >= 2) : (root.percent >= 50)) 
                               ? (root.charging ? Appearance.srcery.cyan : root.baseColor) : "transparent"
                    }

                    // Segment 3 (High)
                    Rectangle {
                        width: 6; height: parent.height
                        radius: 1
                        color: (root.charging ? (root.chargeStep >= 3) : (root.percent >= 85)) 
                               ? (root.charging ? Appearance.srcery.cyan : root.baseColor) : "transparent"
                    }
                }
            }

            // Positive Terminal Tip
            Rectangle {
                anchors.left: batteryBorder.right
                anchors.leftMargin: 0.5
                anchors.verticalCenter: batteryBorder.verticalCenter
                width: 2.5
                height: 6
                color: root.charging ? Appearance.srcery.cyan : root.baseColor
                radius: 1
            }
        }

        // --- PERCENTAGE TEXT ---
        Text {
            text: root.percent + "%"
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Bold
            }
            color: root.charging ? Appearance.srcery.cyan : Appearance.srcery.gray4
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
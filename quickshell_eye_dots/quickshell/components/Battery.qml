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

    // Dynamic state colors mapped cleanly from your theme
    readonly property color stateColor: {
        if (charging) return Appearance.srcery.cyan
        if (percent < 20) return Appearance.srcery.red
        if (percent < 50) return Appearance.srcery.yellow
        return Appearance.srcery.green
    }

    MouseArea { 
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {} 
    }

    RowLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: Appearance.spacing.p1 + 2

        // --- EYE CANDY BATTERY ICON CANVAS ---
        Item {
            id: batteryIconContainer
            Layout.preferredWidth: 28
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter

            // Battery Outer Shell
            Rectangle {
                id: batteryBorder
                anchors.fill: parent
                anchors.rightMargin: 3 // Leave space for the battery tip node
                color: "transparent"
                border.color: root.stateColor
                border.width: 1.5
                radius: 3

                // The smooth fluid internal fluid fill indicator
                Rectangle {
                    id: batteryFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2.5
                    
                    // Smooth structural interpolation when battery state moves
                    width: Math.max(0, (parent.width - 5) * (root.percent / 100))
                    color: root.stateColor
                    radius: 1.5

                    Behavior on width {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 250 }
                    }
                }
            }

            // Battery Positive Terminal Node (The Tip)
            Rectangle {
                anchors.left: batteryBorder.right
                anchors.leftMargin: 0.5
                anchors.verticalCenter: batteryBorder.verticalCenter
                width: 2.5
                height: 6
                color: root.stateColor
                radius: 1

                Behavior on color {
                    ColorAnimation { duration: 250 }
                }
            }

            // Flashy Charging Glow & Pulse Animation
            SequentialAnimation on opacity {
                running: root.charging
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }

            // Fallback reset if charging stops instantly
            onOpacityChanged: { if (!root.charging && opacity !== 1.0) opacity = 1.0 }
        }

        // --- PERCENTAGE TEXT DISPLAY ---
        Text {
            id: batteryLabel
            text: root.percent + "%"
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Bold
            }
            color: root.charging ? Appearance.srcery.cyan : Appearance.srcery.gray4
            Layout.alignment: Qt.AlignVCenter
            
            Behavior on color {
                ColorAnimation { duration: 250 }
            }
        }
    }
}

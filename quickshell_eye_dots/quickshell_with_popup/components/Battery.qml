// ~/.config/quickshell/components/Battery.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import "../" // FIX: Imports the root directory context to resolve GlobalState

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

    readonly property color statusColor: {
        if (charging) return Appearance.srcery.cyan
        if (percent < 20) return Appearance.srcery.red
        if (percent < 50) return Appearance.srcery.yellow
        return Appearance.srcery.green
    }

    RowLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: Appearance.spacing.p1 + 2

        Item {
            id: iconWrapper
            Layout.preferredWidth: 26
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: frameBody
                anchors.fill: parent
                anchors.rightMargin: 3
                color: "transparent"
                border.color: clickTrack.hovered ? Appearance.srcery.white : root.statusColor
                border.width: 1.5
                radius: 3

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.max(0, (parent.width - 4) * (root.percent / 100))
                    color: root.statusColor
                    radius: 1
                }
            }

            Rectangle {
                anchors.left: frameBody.right
                anchors.leftMargin: 0.5
                anchors.verticalCenter: frameBody.verticalCenter
                width: 2
                height: 5
                color: clickTrack.hovered ? Appearance.srcery.white : root.statusColor
                radius: 0.5
            }
        }

        Text {
            text: root.percent + "%"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; weight: Font.Bold }
            color: clickTrack.hovered ? Appearance.srcery.white : (root.charging ? Appearance.srcery.cyan : Appearance.srcery.gray4)
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: clickTrack
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            GlobalState.toggleBatteryPopup(root.monitorId);
        }
    }
}

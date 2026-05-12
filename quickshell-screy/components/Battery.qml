import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config

Item {
    property string monitorId: ""

    property var batteryDevice: UPower.displayDevice
    property int percent: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
    property bool charging: batteryDevice ? (batteryDevice.state === 1) : false
    property bool hasBattery: batteryDevice && batteryDevice.percentage !== undefined

    visible: hasBattery
    implicitHeight: Appearance.bar.height
    implicitWidth: visible ? (batteryLabel.width + batteryIcon.width + Appearance.spacing.p1) : 0

    MouseArea { anchors.fill: parent; onClicked: {} }

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.p1

        Text {
            id: batteryIcon
            text: {
                if (charging) return "⚡"
                if (percent >= 60) return "🔋"
                if (percent >= 20) return "🔋"
                return "🪫"
            }
            font.pixelSize: Appearance.spacing.p2 * 1.5
            color: {
                if (charging) return Appearance.srcery.cyan
                if (percent < 20) return Appearance.srcery.red
                if (percent < 50) return Appearance.srcery.yellow
                return Appearance.srcery.green
            }
            Layout.preferredHeight: font.pixelSize
            Layout.preferredWidth: implicitWidth
        }

        Text {
            id: batteryLabel
            text: percent + "%"
            font.pixelSize: 9
            color: Appearance.srcery.gray4
        }
    }
}
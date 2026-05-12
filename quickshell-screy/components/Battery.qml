import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config

Item {
    property string monitorId: ""

    readonly property var batteryDevice: UPower.displayDevice
    readonly property int  percentage: batteryDevice?.percentage ?? 0
    readonly property bool charging: batteryDevice?.state === UPowerDeviceState.Charging
    readonly property bool hasBattery: batteryDevice?.valid ?? false

    visible: hasBattery
    implicitHeight: Appearance.bar.height
    implicitWidth: batteryLabel.width + batteryIcon.width + Appearance.spacing.p1

    MouseArea { anchors.fill: parent; onClicked: {} }

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.p1

        Text {
            id: batteryIcon
            text: {
                if (!hasBattery) return "🔋"
                if (charging) return "⚡"
                if (percentage >= 60) return "🔋"
                if (percentage >= 20) return "🔋"
                return "🪫"
            }
            font.pixelSize: Appearance.spacing.p2 * 1.5
            color: {
                if (!hasBattery) return Appearance.srcery.gray4
                if (charging) return Appearance.srcery.cyan
                if (percentage < 20) return Appearance.srcery.red
                if (percentage < 50) return Appearance.srcery.yellow
                return Appearance.srcery.green
            }
            Layout.preferredHeight: font.pixelSize
            Layout.preferredWidth: implicitWidth
        }

        Text {
            id: batteryLabel
            text: hasBattery ? percentage + "%" : "—%"
            font.pixelSize: 9   // adjust this to match your bar's text size
            color: Appearance.srcery.gray4
        }
    }
}

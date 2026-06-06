import "../../core"
import "../../widgets"
import "../../services"
import "../../core/functions"
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property color color: Appearance.colors.colStatusBarText
    visible: Battery.available
    
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= (Config.options.battery?.low ?? 20) / 100
    readonly property bool chargingActive: isCharging || (isPluggedIn && percentage < 0.98)
    property real chargingPulse: 0
    property real chargingSweep: -0.35
    readonly property color chargingCyan: Qt.rgba(0.22, 0.94, 1.0, 1.0)

    onChargingActiveChanged: {
        chargingPulse = chargingActive ? 0.25 : 0;
        chargingSweep = chargingActive ? -0.35 : -0.35;
    }

    Timer {
        id: chargePulseTimer
        interval: 620
        running: root.chargingActive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.chargingPulse = root.chargingPulse >= 0.9 ? 0.28 : 1.0
        onRunningChanged: if (!running) root.chargingPulse = 0
    }

    Timer {
        id: chargeSweepTimer
        interval: 360
        running: root.chargingActive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.chargingSweep = root.chargingSweep >= 1.25 ? -0.35 : root.chargingSweep + 0.34
        onRunningChanged: if (!running) root.chargingSweep = -0.35
    }

    implicitWidth: 35 * Appearance.effectiveScale
    implicitHeight: 24 * Appearance.effectiveScale

    RowLayout {
        anchors.centerIn: parent
        spacing: 1 * Appearance.effectiveScale

        Item {
            id: batteryShell
            Layout.preferredWidth: 29 * Appearance.effectiveScale
            Layout.preferredHeight: 18 * Appearance.effectiveScale
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: batteryProgress
                anchors.margins: -2 * Appearance.effectiveScale
                radius: batteryProgress.radius + (2 * Appearance.effectiveScale)
                color: "transparent"
                border.width: root.chargingActive ? 1 * Appearance.effectiveScale : 0
                border.color: Qt.rgba(0.22, 0.94, 1.0, 0.38 + (root.chargingPulse * 0.38))
                opacity: root.chargingActive ? 1 : 0
            }

            ClippedProgressBar {
                id: batteryProgress
                anchors.centerIn: parent
                valueBarWidth: 26 * Appearance.effectiveScale
                valueBarHeight: 14 * Appearance.effectiveScale

                radius: 4.5 * Appearance.effectiveScale

                value: percentage
                highlightColor: {
                     if (chargingActive) return Qt.rgba(0.22, 0.94, 1.0, 0.72 + (root.chargingPulse * 0.28))
                     if (isLow) return Appearance.m3colors.m3error
                     return root.color
                }
                trackColor: {
                    if (chargingActive) return Qt.rgba(0.22, 0.94, 1.0, 0.14 + (root.chargingPulse * 0.20))
                    if (isLow) return Appearance.m3colors.m3errorContainer
                    return ColorUtils.applyAlpha(highlightColor, 0.2)
                }

                // Custom text mask to include the bolt icon.
                textMask: Item {
                    width: batteryProgress.valueBarWidth
                    height: batteryProgress.valueBarHeight

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        MaterialSymbol {
                            id: boltIcon
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: -2 * Appearance.effectiveScale
                            Layout.rightMargin: -2 * Appearance.effectiveScale
                            fill: 1
                            text: "electric_bolt"
                            iconSize: 9 * Appearance.effectiveScale
                            visible: chargingActive
                            opacity: chargingActive ? (0.28 + (root.chargingPulse * 0.72)) : 0
                            scale: chargingActive ? (0.88 + (root.chargingPulse * 0.22)) : 1
                            color: root.chargingCyan
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: 10 * Appearance.effectiveScale
                            font.weight: Font.DemiBold
                            text: batteryProgress.text
                            color: chargingActive ? Qt.rgba(0.22, 0.94, 1.0, 0.80 + (root.chargingPulse * 0.20)) : (isLow ? Appearance.m3colors.m3onError : root.color)
                        }
                    }
                }
            }

            Item {
                anchors.fill: batteryProgress
                clip: true
                visible: root.chargingActive
                opacity: 0.18 + (root.chargingPulse * 0.22)

                Rectangle {
                    width: 7 * Appearance.effectiveScale
                    height: parent.height * 1.7
                    x: ((parent.width + width) * root.chargingSweep) - width
                    y: (parent.height - height) / 2
                    rotation: 18
                    radius: width / 2
                    color: root.chargingCyan
                }
            }

            MaterialSymbol {
                anchors.centerIn: batteryProgress
                fill: 1
                text: "electric_bolt"
                iconSize: 8 * Appearance.effectiveScale
                color: Qt.rgba(0.08, 0.20, 0.24, 0.95)
                visible: root.chargingActive
                opacity: 0.34 + (root.chargingPulse * 0.38)
                scale: 0.88 + (root.chargingPulse * 0.14)
                    }
        }

        // Battery Tip
        Rectangle {
            Layout.preferredWidth: 2 * Appearance.effectiveScale
            Layout.preferredHeight: 6 * Appearance.effectiveScale
            Layout.alignment: Qt.AlignVCenter
            radius: 1 * Appearance.effectiveScale
            color: chargingActive ? batteryProgress.highlightColor : ((percentage >= 0.98) ? batteryProgress.highlightColor : batteryProgress.trackColor)
            opacity: chargingActive ? (0.45 + root.chargingPulse * 0.55) : 1
        }
    }
}

// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T A T S   M O D U L E                                                │
// │   system load · ring, sparklines when open                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// CPU load on the chip; the detail shows CPU and memory with recent history.
// Cores, disks and temperatures are in the stats panel. The ring steps through
// the indicator hues like the battery's.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property color loadTint: {
        if (StatsService.cpu >= 90)
            return Theme.indicatorBad
        if (StatsService.cpu >= 70)
            return Theme.indicatorWarn
        return Theme.indicator
    }

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: StatsService.cpu / 100
                    trackColor: Theme.indicatorDim
                    fillColor: root.loadTint

                    Behavior on fillColor {
                        ColorAnimation { duration: Theme.durationMedium }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰻠"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: Theme.indicator
                    }
                }
            }
        }
    }

    Component {
        id: detail

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            StatCard {
                Layout.fillWidth: true
                // No card: both readings sit on the island.
                bare: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                icon: "󰻠"
                title: "Processor"
                reading: `${StatsService.cpu.toFixed(0)}%`
                detail: `load ${StatsService.load[0].toFixed(2)}`
                series: StatsService.cpuHistory
                accent: Theme.accent
            }

            StatCard {
                Layout.fillWidth: true
                bare: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                icon: "󰍛"
                title: "Memory"
                reading: `${(StatsService.memoryFraction * 100).toFixed(0)}%`
                detail: `${StatsService.bytes(StatsService.memoryUsed)} of ${StatsService.bytes(StatsService.memoryTotal)}`
                series: StatsService.memoryHistory
                accent: Theme.blue
            }
        }
    }
}

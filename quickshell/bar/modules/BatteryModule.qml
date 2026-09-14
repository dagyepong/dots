// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A T T E R Y   M O D U L E                                            │
// │   battery · charge ring, time remaining when open                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"
import "../widgets"

// The ring shows the charge; the detail adds what UPower reports beyond it:
// time remaining, charge direction, power draw and cell health.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the percentage beside it.
    Component {
        id: chip

        Item {
            BatteryWidget {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
            }
        }
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                BatteryWidget {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    size: 44
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: `${BatteryService.percent}%`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        // The estimate is blank for a minute or two after the
                        // cable changes, so the state line stands on its own
                        // until it arrives.
                        text: BatteryService.estimate !== ""
                            ? `${BatteryService.stateWord}  ·  ${BatteryService.estimate}`
                            : BatteryService.stateWord
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "POWER"
                    value: BatteryService.watts > 0
                        ? `${BatteryService.watts.toFixed(1)} W`
                        : "—"
                    note: BatteryService.charging ? "going in" : "coming out"
                }

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: BatteryService.healthKnown ? "HEALTH" : "CHARGE"
                    // Cells that don't report health get what they do report,
                    // not a guess.
                    value: BatteryService.healthKnown
                        ? `${BatteryService.health}%`
                        : `${BatteryService.energy.toFixed(1)} Wh`
                    note: BatteryService.energyCapacity > 0
                        ? `of ${BatteryService.energyCapacity.toFixed(1)} Wh full`
                        : ""
                }
            }
        }
    }
}

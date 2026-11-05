// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   M O D U L E                                        │
// │   bluetooth · connected devices, radio switch when open                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The chip names the connected device, so audio that fell back to the
// speakers is visible at a glance. Pairing is not supported (no PIN agent);
// the device list is in the control centre.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            title: BluetoothService.summary
            subtitle: {
                if (!BluetoothService.enabled)
                    return "Adapter off"
                const count = BluetoothService.connectedDevices.length
                if (count === 0)
                    return "On · nothing connected"
                return count === 1
                    ? "On · 1 device connected"
                    : `On · ${count} devices connected`
            }

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: BluetoothService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: BluetoothService.enabled ? Theme.indicator : Theme.textMuted
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                ToggleSwitch {
                    checked: BluetoothService.enabled
                    onToggled: BluetoothService.toggle()
                }
            }

            CardFact {
                name: "Devices"
                value: `${BluetoothService.connectedDevices.length} connected`
            }

            CardFact {
                name: "Pairing"
                value: "in the control centre"
            }
        }
    }
}

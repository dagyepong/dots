import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.VectorImage
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl

import Quickshell.Bluetooth

PanelWindow {
    anchors.top: true
    anchors.right: true
    implicitHeight: 1080
    implicitWidth: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dynamic-island"

    Behavior on implicitWidth{
        NumberAnimation{duration:250;easing.type: Easing.OutCubic}
    }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    exclusiveZone: 0

    property bool hovered: false

    mask: Region {
        item: content
    }

    Item {
        id: content
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#000000"

            HoverHandler {
                id: bluetooth_panel_hover
                onHoveredChanged: {
                    bluetooth_panel.WlrLayershell.keyboardFocus = bluetooth_panel_hover.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                }
            }

            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 16

                RowLayout {

                    Rectangle{
                        height: 50
                        width: 50
                        radius: 15
                        color: "#000000"
                        HoverHandler {
                            onHoveredChanged: parent.color = hovered ? "#333333" : "#000000"
                        }
                        TapHandler{
                            onTapped: {
                                bluetooth_panel.implicitWidth = 0
                                BluetoothService.stopScan()
                            }
                        }
                        VectorImage {
                            id: shutdown_icon
                            anchors.centerIn: parent
                            source: "shutdown.svg"
                            width: 25
                            height: 25
                            preferredRendererType: VectorImage.CurveRenderer
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: "Bluetooth settings"; font.bold: true; font.pixelSize: 17; font.family: "SF Mono"; font.weight: 600; color: "#ffffff"}
                    Item { Layout.fillWidth: true }

                    Switch {
                        id: control


                        checked: BluetoothService.bluetoothEnabled
                        onToggled: BluetoothService.setBluetoothEnabled(checked)

                        Connections {
                            target: BluetoothService
                            function onBluetoothEnabledChanged() {
                                control.checked = BluetoothService.bluetoothEnabled
                            }
                        }

                        property color trackColorOn: "#35D05B"
                        property color trackColorOff: "#333333"
                        property color handleColorOn: "#ffffff"
                        property color handleColorOff: "#ffffff"
                        property color borderColorOn: "transparent"
                        property color borderColorOff: "transparent"

                        property int trackWidth: 50
                        property int trackHeight: 20
                        property int trackRadius: 10

                        property int handleSize: 20
                        property int handleMargin: 0

                        property int animationDuration: 150

                        indicator: Rectangle {
                            implicitWidth: control.trackWidth
                            implicitHeight: control.trackHeight
                            x: control.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: control.trackRadius

                            color: control.checked ? control.trackColorOn : control.trackColorOff
                            border.color: control.checked ? control.borderColorOn : control.borderColorOff
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: control.animationDuration }
                            }

                            Rectangle {
                                id: handle
                                width: control.handleSize + 5
                                height: control.handleSize
                                radius: 10
                                y: (parent.height - height) / 2

                                x: control.checked
                                   ? parent.width - width - control.handleMargin
                                   : control.handleMargin

                                color: control.checked ? control.handleColorOn : control.handleColorOff
                                border.color: "#AAAAAA"

                                Behavior on x {
                                    NumberAnimation {
                                        duration: control.animationDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: control.animationDuration }
                                }
                            }
                        }

                        background: Item {}
                    }
                }

                Item{Layout.fillHeight: true}
                BusyIndicator{running: BluetoothService.scanning; visible: BluetoothService.scanning}
                Item{Layout.fillHeight: true}

                Repeater {
                    model: BluetoothService.devices
                    delegate: RowLayout {
                        required property BluetoothDevice modelData
                        Layout.fillWidth: true

                        IconImage {
                            source: Quickshell.iconPath(modelData.icon, "bluetooth")
                            width: 20
                            height: 20
                        }

                        Text {
                            text: modelData.name
                            Layout.fillWidth: true
                            font.family: "SF Mono"
                            elide: Text.ElideRight
                            font.weight: 600
                            color: modelData.connected ? "#35D05B" : "#888888"
                        }
                        Item{Layout.fillWidth: true}
                        Text {
                            text: modelData.pairing
                                  ? "Pairing…"
                                  : modelData.state === BluetoothDeviceState.Connecting
                                  ? "Connecting…"
                                  : modelData.state === BluetoothDeviceState.Disconnecting
                                  ? "Disconnecting…"
                                  : modelData.batteryAvailable
                                  ? Math.round(modelData.battery * 100) + "%"
                                  : ""
                            font.family: "SF Mono"
                            font.weight: 600
                            color: Qt.rgba(1, 1, 1, modelData.batteryAvailable ? modelData.battery : 0.6)
                        }
                        Item{Layout.fillWidth: true}
                        Rectangle {
                            width: 100
                            height: 25
                            radius: 22
                            color: "#000000"
                            border.color: "#333333"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
                                font.family: "SF Mono"
                                color: "#ffffff"
                            }

                            TapHandler {
                                onTapped: {
                                    if (modelData.connected) {
                                        modelData.disconnect()
                                    } else if (modelData.paired) {
                                        modelData.connect()
                                    } else {
                                        modelData.pair()
                                    }
                                }
                            }

                            HoverHandler {
                                onHoveredChanged: parent.color = hovered ? "#333333" : "#000000"
                            }

                            Behavior on color {
                                ColorAnimation{duration: 250; easing.type: Easing.OutCubic}
                            }
                        }
                    }
                }
            }
        }
    }
}

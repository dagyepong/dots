import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.VectorImage
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl

import Quickshell.Networking

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

    property bool hovered:  false

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
                id: wifi_panel_hover
                onHoveredChanged: {
                    wifi_panel.WlrLayershell.keyboardFocus = wifi_panel_hover.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                                wifi_panel.implicitWidth = 0
                                WifiService.stopScan()
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
                    Text { text: "Wi-Fi settings"; font.bold: true; font.pixelSize: 17; font.family: "SF Mono"; font.weight: 600; color: "#ffffff"}
                    Item { Layout.fillWidth: true }

                    Switch {
                        id: control

                        checked: WifiService.wifiEnabled
                        onToggled: WifiService.setWifiEnabled(checked)

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
                        // --------------------------

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

                Repeater {
                    id: network_list
                    model: WifiService.networks
                    delegate: RowLayout {
                        required property WifiNetwork modelData
                        Layout.fillWidth: true

                        Text { text: modelData.name; Layout.fillWidth: true; font.family: "SF Mono"; elide: Text.ElideRight; font.weight: 600; color: modelData.connected ? "#35D05B" : "#888888" }
                        Item{Layout.fillWidth: true}
                        Text { text: Math.round(modelData.signalStrength * 100) + "%"; font.family: "SF Mono"; font.weight: 600; color: Qt.rgba(1, 1, 1, modelData.signalStrength)}
                        Item{Layout.fillWidth: true}
                        Rectangle {
                            width: 100
                            height: 25
                            radius: 22
                            color: "#000000"
                            border.color: "#333333"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "Disconnect" : "Connect"
                                font.family: "SF Mono"
                                color: "#ffffff"
                            }

                            TapHandler {
                                onTapped: {
                                    if (modelData.connected) {
                                        modelData.disconnect()
                                    } else if (modelData.known || modelData.security === WifiSecurityType.Open) {
                                        modelData.connect()
                                    } else {
                                        passwordDialog.network = modelData
                                        passwordDialog.open()
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

                        Connections {
                            target: modelData
                            function onConnectionFailed(reason) {
                                if (reason === ConnectionFailReason.NoSecrets) {
                                    passwordDialog.network = modelData
                                    passwordDialog.open()
                                } else {
                                    console.log("Connection failed:", reason)
                                }
                            }
                        }
                    }
                }

                Item {
                    id: passwordDialog
                    property WifiNetwork network: null
                    property bool dialogOpen: false
                    visible: dialogOpen
                    anchors.fill: parent
                    z: 100

                    function open() {
                        dialogOpen = true
                        wifi_panel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
                        pwField.text = ""
                        pwField.forceActiveFocus()
                    }

                    function close() {
                        dialogOpen = false
                        wifi_panel.WlrLayershell.keyboardFocus = wifi_panel_hover.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    }

                    // dim background
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 0.6
                        TapHandler { onTapped: passwordDialog.close() }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 150
                        radius: 12
                        color: "#1a1a1a"
                        border.color: "#333333"

                        FocusScope {
                            id: dialogFocusScope
                            anchors.fill: parent
                            anchors.margins: 16
                            focus: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12

                                Text {
                                    text: "Connect to " + (passwordDialog.network ? passwordDialog.network.name : "")
                                    color: "#ffffff"
                                    font.family: "SF Mono"
                                    font.bold: true
                                }

                                TextField {
                                    id: pwField
                                    Layout.fillWidth: true
                                    placeholderText: "Network Password"
                                    echoMode: TextInput.Password
                                    focus: true
                                    Keys.onReturnPressed: {
                                        passwordDialog.network.connectWithPsk(pwField.text)
                                        passwordDialog.close()
                                    }
                                    Keys.onEscapePressed: passwordDialog.close()
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 8
                                    Rectangle {
                                        width: 70; height: 30; radius: 8
                                        color: "#333333"
                                        Text { anchors.centerIn: parent; text: "Cancel"; color: "#ffffff"; font.family: "SF Mono" }
                                        TapHandler { onTapped: passwordDialog.close() }
                                    }
                                    Rectangle {
                                        width: 70; height: 30; radius: 8
                                        color: "#35D05B"
                                        Text { anchors.centerIn: parent; text: "OK"; color: "#000000"; font.family: "SF Mono" }
                                        TapHandler {
                                            onTapped: {
                                                passwordDialog.network.connectWithPsk(pwField.text)
                                                passwordDialog.close()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

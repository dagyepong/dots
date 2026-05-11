import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: popupWindow

    ipcTarget: "network"
    initialScale: 0.94
    barPosition: Commons.Config.barPosition

    readonly property bool wifiEnabled: Services.Network.wifiEnabled
    readonly property bool ethernetConnected: Services.Network.ethernetConnected
    readonly property string activeType: Services.Network.activeType
    readonly property bool connected: Services.Network.connected
    readonly property string stateText: Services.Network.stateText
    readonly property var networks: Services.Network.accessPoints

    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Commons.Theme.border
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)

    implicitWidth: 320
    implicitHeight: contentColumn.implicitHeight + 32

    function signalIcon(strength, isOn) {
        if (activeType === "ethernet") return "󰈀"
        if (!isOn) return "󰤭"
        if (strength >= 75) return "󰤨"
        if (strength >= 50) return "󰤥"
        if (strength >= 25) return "󰤢"
        return "󰤟"
    }

    Rectangle {
        anchors.fill: parent
        color: cSurface
        radius: Commons.Theme.radiusPanel
        border.color: cBorder
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Commons.Theme.popupShadowOpacity)
            shadowBlur: Commons.Theme.popupShadowBlur
            shadowVerticalOffset: Commons.Theme.popupShadowOffset
        }

        Process {
            id: settingsProcess
            command: ["nm-connection-editor"]
            onStarted: popupWindow.shouldShow = false
        }

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Commons.Config.popupContentPadding
            spacing: Commons.Theme.spacingMd

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Widgets.HeaderWithIcon {
                    Layout.fillWidth: true
                    icon: activeType === "ethernet" ? "󰈀" : "󰤨"
                    title: "Network"
                    subtitle: stateText
                    iconColor: cPrimary
                    titleColor: cText
                    subtitleColor: cSubText
                }

                Item {
                    Layout.fillWidth: true
                }

                Widgets.ToggleSwitch {
                    width: 44
                    height: 24
                    checked: wifiEnabled
                    checkedColor: cPrimary
                    uncheckedColor: Qt.rgba(cText.r, cText.g, cText.b, 0.15)
                    thumbColor: "#ffffff"
                    animationDuration: 150
                    onToggled: Services.Network.setWifiEnabled(!wifiEnabled)
                }
            }

            Widgets.HoverButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Commons.Theme.radius
                icon: Services.Network.refreshing ? "󰑐" : "󰑐"
                text: Services.Network.refreshing ? "Refreshing..." : "Refresh networks"
                iconSize: 16
                textSize: 12
                iconColor: cText
                hoverIconColor: cPrimary
                textColor: cText
                hoverTextColor: cText
                baseColor: cSurfaceContainer
                hoverColor: cHover
                onClicked: Services.Network.refresh()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: networks.length === 0 ? 120 : Math.min(networkList.contentHeight + 8, 260)
                radius: Commons.Theme.radius
                color: cSurfaceContainer
                clip: true

                ListView {
                    id: networkList
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2
                    model: networks
                    clip: true

                    delegate: Widgets.ListItem {
                        width: networkList.width
                        height: 48
                        required property var modelData

                        icon: popupWindow.signalIcon(modelData.signal, wifiEnabled)
                        title: modelData.ssid
                        subtitle: modelData.inUse ? "Connected" : ((modelData.security && modelData.security.length > 0) ? modelData.security : "Open")
                        iconColor: modelData.inUse ? cPrimary : cText
                        titleColor: cText
                        subtitleColor: modelData.inUse ? cPrimary : cSubText
                        hoverColor: cHover
                        borderColor: "transparent"
                        showBorder: false

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.signal + "%"
                            font.family: Commons.Theme.fontMono
                            font.pixelSize: 10
                            color: cSubText
                        }
                    }
                }

                Widgets.EmptyState {
                    anchors.centerIn: parent
                    visible: networks.length === 0
                    icon: ethernetConnected ? "󰈀" : (wifiEnabled ? "󰤯" : "󰤭")
                    iconSize: 32
                    iconOpacity: 0.2
                    title: ethernetConnected ? "Ethernet connected" : (wifiEnabled ? "No networks found" : "Wi-Fi disabled")
                    subtitle: ""
                    textOpacity: 1.0
                }
            }

            Widgets.TextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                icon: "󰒓"
                text: "Open Network Settings"
                iconColor: cSubText
                textColor: cSubText
                hoverColor: cHover
                showBorder: false
                onClicked: settingsProcess.running = true
            }
        }
    }
}

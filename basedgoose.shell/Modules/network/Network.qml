import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../../Services" as Services
import "../../Commons" as Commons

Item {
    id: root

    property var barWindow
    property var networkPopup
    property bool isVertical: false
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool wifiEnabled: Services.Network.wifiEnabled
    readonly property bool ethernetAvailable: Services.Network.ethernetAvailable
    readonly property bool ethernetConnected: Services.Network.ethernetConnected
    readonly property string activeType: Services.Network.activeType
    readonly property bool connected: Services.Network.connected
    readonly property int signalStrength: Services.Network.signalStrength
    readonly property string statusText: {
        if (ethernetConnected) return Services.Network.connectionName.length > 0 ? Services.Network.connectionName : "Ethernet"
        if (!wifiEnabled && !ethernetAvailable) return "Off"
        if (!wifiEnabled && ethernetAvailable) return "No link"
        if (connected) return Services.Network.connectionName.length > 0 ? Services.Network.connectionName : "Connected"
        return "No link"
    }

    function signalIcon() {
        if (activeType === "ethernet") return "󰈀"
        if (!wifiEnabled) return "󰤭"
        if (!connected) return "󰤯"
        if (signalStrength >= 75) return "󰤨"
        if (signalStrength >= 50) return "󰤥"
        if (signalStrength >= 25) return "󰤢"
        return "󰤟"
    }

    implicitWidth: isVertical ? 28 : networkRow.implicitWidth
    implicitHeight: isVertical ? networkCol.implicitHeight : Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    RowLayout {
        id: networkRow
        anchors.centerIn: parent
        spacing: 3
        visible: !isVertical

        Text {
            text: root.signalIcon()
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 14
            color: {
                if (!wifiEnabled && !ethernetConnected) return Commons.Theme.foregroundMuted
                if (connected && isHovered) return Commons.Theme.secondary
                if (connected) return Commons.Theme.success
                return Commons.Theme.foreground
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }

        Text {
            text: statusText
            font.family: Commons.Theme.fontUI
            font.pixelSize: 10
            color: connected || wifiEnabled || ethernetAvailable ? Commons.Theme.foreground : Commons.Theme.foregroundMuted
            visible: text !== ""
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: 120
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Column {
        id: networkCol
        anchors.centerIn: parent
        spacing: 2
        visible: isVertical

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.signalIcon()
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 14
            color: {
                if (!wifiEnabled && !ethernetConnected) return Commons.Theme.foregroundMuted
                if (connected && isHovered) return Commons.Theme.secondary
                if (connected) return Commons.Theme.success
                return Commons.Theme.foreground
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: 4
            radius: Commons.Theme.radiusSm
            visible: wifiEnabled || ethernetAvailable
            color: connected ? Commons.Theme.success : Commons.Theme.foregroundMuted
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (networkPopup && barWindow) {
                if (!networkPopup.shouldShow) {
                    networkPopup.positionNear(root, barWindow)
                }
                networkPopup.shouldShow = !networkPopup.shouldShow
            }
        }
    }
}

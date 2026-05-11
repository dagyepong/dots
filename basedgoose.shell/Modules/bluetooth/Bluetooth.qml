import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../../Services" as Services
import "../../Commons" as Commons

Item {
    id: root
    
    property var barWindow
    property var bluetoothPopup
    property bool isVertical: false
    
    readonly property bool isEnabled: Services.Bluetooth.powered
    readonly property bool hasConnection: Services.Bluetooth.connected
    readonly property string deviceName: Services.Bluetooth.deviceName
    readonly property int deviceCount: Services.Bluetooth.deviceCount
    readonly property bool isHovered: mouseArea.containsMouse
    
    implicitWidth: isVertical ? 28 : bluetoothRow.implicitWidth
    implicitHeight: isVertical ? bluetoothCol.implicitHeight : Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    // Horizontal layout
    RowLayout {
        id: bluetoothRow
        anchors.centerIn: parent
        spacing: 3
        visible: !isVertical
        
        Text {
            text: {
                if (!isEnabled) return "󰂲"
                if (hasConnection) return "󰂱"
                return "󰂯"
            }
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 14
            color: {
                if (!isEnabled) return Commons.Theme.foreground
                if (isHovered) return Commons.Theme.secondary
                if (hasConnection) return Commons.Theme.success
                return Commons.Theme.foreground
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
        
        Text {
            text: {
                if (!isEnabled) return "Off"
                if (!hasConnection) return ""
                if (deviceCount > 1) return deviceName + " +" + (deviceCount - 1)
                return deviceName
            }
            font.family: Commons.Theme.fontUI
            font.pixelSize: 10
            font.weight: hasConnection ? Font.Medium : Font.Normal
            color: {
                if (!isEnabled || !hasConnection) return Commons.Theme.foreground
                if (isHovered) return Commons.Theme.primary
                return Commons.Theme.foreground
            }
            visible: text !== ""
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    
    // Vertical layout
    Column {
        id: bluetoothCol
        anchors.centerIn: parent
        spacing: 2
        visible: isVertical
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                if (!isEnabled) return "󰂲"
                if (hasConnection) return "󰂱"
                return "󰂯"
            }
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 14
            color: {
                if (!isEnabled) return Commons.Theme.foreground
                if (isHovered) return Commons.Theme.secondary
                if (hasConnection) return Commons.Theme.success
                return Commons.Theme.foreground
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
        
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: 4
            radius: Commons.Theme.radiusSm
            color: hasConnection ? Commons.Theme.success : (isEnabled ? Commons.Theme.foregroundMuted : "transparent")
            visible: isEnabled
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: {
            if (bluetoothPopup && barWindow) {
                if (!bluetoothPopup.shouldShow) {
                    bluetoothPopup.positionNear(root, barWindow)
                }
                bluetoothPopup.shouldShow = !bluetoothPopup.shouldShow
            }
        }
    }
}

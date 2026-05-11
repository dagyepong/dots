import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../Services" as Services
import "../../Commons" as Commons

Rectangle {
    id: workspaces
    
    property var barWindow
    property bool isVertical: false
    
    Layout.preferredWidth: isVertical ? Commons.Config.componentHeight : (workspaceRowH.implicitWidth + 16)
    Layout.preferredHeight: isVertical ? (workspaceColV.implicitHeight + 16) : Commons.Config.componentHeight
    implicitWidth: isVertical ? Commons.Config.componentHeight : (workspaceRowH.implicitWidth + 16)
    implicitHeight: isVertical ? (workspaceColV.implicitHeight + 16) : Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight
    color: Commons.Theme.surfaceBase
    radius: Commons.Theme.radiusPanel
    clip: true
    
    // Horizontal layout
    RowLayout {
        id: workspaceRowH
        anchors.centerIn: parent
        spacing: Commons.Config.workspaceSpacing
        visible: !isVertical
        
        Repeater {
            model: Commons.Config.workspaceCount
            
            delegate: Rectangle {
                required property int index
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === (index + 1) : false
                property bool hasWindows: ws !== undefined && ws !== null
                
                Layout.preferredWidth: isActive ? Commons.Config.workspaceIndicatorActiveWidth : Commons.Config.workspaceIndicatorWidth
                Layout.preferredHeight: isActive ? Commons.Config.workspaceIndicatorHeight : Commons.Config.workspaceIndicatorInactiveHeight
                Layout.alignment: Qt.AlignVCenter
                radius: Commons.Config.workspaceIndicatorRadius
                color: isActive ? Commons.Theme.primary : (hasWindows ? Commons.Theme.secondary : Commons.Theme.foregroundMuted)
                
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + (parent.index + 1))
                }
            }
        }
    }
    
    // Vertical layout
    ColumnLayout {
        id: workspaceColV
        anchors.centerIn: parent
        spacing: Commons.Config.workspaceSpacing
        visible: isVertical
        
        Repeater {
            model: Commons.Config.workspaceCount
            
            delegate: Rectangle {
                required property int index
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === (index + 1) : false
                property bool hasWindows: ws !== undefined && ws !== null
                
                Layout.preferredWidth: isActive ? Commons.Config.workspaceIndicatorHeight : Commons.Config.workspaceIndicatorInactiveHeight
                Layout.preferredHeight: isActive ? Commons.Config.workspaceIndicatorActiveWidth : Commons.Config.workspaceIndicatorWidth
                Layout.alignment: Qt.AlignHCenter
                radius: Commons.Config.workspaceIndicatorRadius
                color: isActive ? Commons.Theme.primary : (hasWindows ? Commons.Theme.secondary : Commons.Theme.foregroundMuted)
                
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + (parent.index + 1))
                }
            }
        }
    }
}

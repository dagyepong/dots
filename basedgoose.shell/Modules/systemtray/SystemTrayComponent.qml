import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Services" as Services
import "../../Commons" as Commons

Item {
    id: systemTrayComponent
    
    property var barWindow: null
    property bool isVertical: false
    
    implicitWidth: isVertical ? Commons.Config.trayIconSize : trayRowH.implicitWidth
    implicitHeight: isVertical ? trayColV.implicitHeight : Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    visible: SystemTray.items.values.length > 0
    
    // Horizontal layout
    RowLayout {
        id: trayRowH
        anchors.centerIn: parent
        spacing: Commons.Config.traySpacing
        visible: !isVertical
        
        Repeater {
            model: SystemTray.items
            
            Rectangle {
                width: Commons.Config.trayIconSize
                height: Commons.Config.trayIconSize
                color: trayMaH.containsMouse ? Commons.Theme.background : "transparent"
                radius: Commons.Config.trayIconRadius
                
                Image {
                    anchors.centerIn: parent
                    width: Commons.Config.trayIconImageSize
                    height: Commons.Config.trayIconImageSize
                    source: modelData.icon
                    smooth: true
                }
                
                MouseArea {
                    id: trayMaH
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu) {
                                var window = systemTrayComponent.barWindow;
                                if (window) {
                                    var pos = mapToItem(null, mouse.x, mouse.y);
                                    modelData.display(window, pos.x, pos.y);
                                }
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        }
                    }
                    
                    onWheel: (wheel) => {
                        modelData.scroll(wheel.angleDelta.y / 120, false);
                    }
                }
                
                ToolTip {
                    visible: trayMaH.containsMouse
                    text: modelData.tooltipTitle || modelData.title
                    delay: 500
                    contentWidth: 200
                }
            }
        }
    }
    
    // Vertical layout
    ColumnLayout {
        id: trayColV
        anchors.centerIn: parent
        spacing: Commons.Config.traySpacing
        visible: isVertical
        
        Repeater {
            model: SystemTray.items
            
            Rectangle {
                width: Commons.Config.trayIconSize
                height: Commons.Config.trayIconSize
                color: trayMaV.containsMouse ? Commons.Theme.background : "transparent"
                radius: Commons.Config.trayIconRadius
                
                Image {
                    anchors.centerIn: parent
                    width: Commons.Config.trayIconImageSize
                    height: Commons.Config.trayIconImageSize
                    source: modelData.icon
                    smooth: true
                }
                
                MouseArea {
                    id: trayMaV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu) {
                                var window = systemTrayComponent.barWindow;
                                if (window) {
                                    var pos = mapToItem(null, mouse.x, mouse.y);
                                    modelData.display(window, pos.x, pos.y);
                                }
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        }
                    }
                    
                    onWheel: (wheel) => {
                        modelData.scroll(wheel.angleDelta.y / 120, false);
                    }
                }
                
                ToolTip {
                    visible: trayMaV.containsMouse
                    text: modelData.tooltipTitle || modelData.title
                    delay: 500
                    contentWidth: 200
                }
            }
        }
    }
}

import QtQuick 6.10
import QtQuick.Controls 6.10
import "../Commons" as Commons

Slider {
    id: root
    
    property color trackColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.15)
    property color progressColor: Commons.Theme.primary
    property color handleColor: Commons.Theme.foreground
    property color handleBorderColor: Commons.Theme.primaryMuted
    property int trackHeight: 6
    property int trackRadius: Commons.Theme.radiusSm
    property int handleSize: 18
    property bool showHandle: true
    property int animationDuration: 100
    
    implicitHeight: 32
    
    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: root.trackHeight
        width: root.availableWidth
        height: implicitHeight
        radius: root.trackRadius
        color: root.trackColor
        
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            color: root.progressColor
            radius: root.trackRadius
            
            Behavior on width {
                NumberAnimation { 
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic 
                }
            }
        }
    }
    
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: root.handleSize
        implicitHeight: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        border.color: root.handleBorderColor
        border.width: 2
        visible: root.showHandle && (root.hovered || root.pressed)
        opacity: visible ? 1.0 : 0.0
        
        Behavior on x {
            NumberAnimation { 
                duration: root.animationDuration
                easing.type: Easing.OutCubic 
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}

import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../Services" as Services
import "../../Commons" as Commons

Item {
    id: root
    
    property var notificationCenter
    property var barWindow
    property bool isVertical: false
    
    readonly property var notifs: Services.Notifications
    readonly property int unreadCount: notifs.activeNotifications.length
    readonly property bool hasDnd: notifs.dnd
    readonly property bool isHovered: mouseArea.containsMouse
    
    implicitWidth: isVertical ? 28 : 20
    implicitHeight: Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    // Notification icon
    Text {
        id: notifIcon
        anchors.centerIn: parent
        text: root.hasDnd ? "󰂛" : (root.unreadCount > 0 ? "󰵅" : "󰂚")
        font.family: Commons.Theme.fontIcon
        font.pixelSize: 14
        color: {
            if (root.hasDnd) return Commons.Theme.error
            if (root.isHovered) return Commons.Theme.secondary
            return Commons.Theme.foreground
        }
        
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: root.isHovered ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
    }
    
    // dot indicator
    Rectangle {
        visible: root.unreadCount > 0 && !root.hasDnd
        width: 6
        height: 6
        radius: Commons.Theme.radiusSm
        color: Commons.Theme.secondary
        anchors.right: notifIcon.right
        anchors.top: notifIcon.top
        anchors.rightMargin: -2
        anchors.topMargin: -2
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            if (root.notificationCenter && root.barWindow) {
                if (!root.notificationCenter.shouldShow) {
                    root.notificationCenter.positionNear(root, root.barWindow)
                }
                root.notificationCenter.shouldShow = !root.notificationCenter.shouldShow
            }
        }
    }
    
    SequentialAnimation {
        id: pulseAnim
        running: root.unreadCount > 0 && !root.hasDnd
        loops: 1
        
        NumberAnimation {
            target: notifIcon
            property: "scale"
            from: 1.0
            to: 1.15
            duration: 150
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: notifIcon
            property: "scale"
            from: 1.15
            to: root.isHovered ? 1.05 : 1.0
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}

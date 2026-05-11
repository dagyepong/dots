import QtQuick
import "../../Commons" as Commons

Item {
    id: root
    
    signal clicked()
    
    property var barWindow
    property var powerMenuPopup
    property bool isVertical: false
    
    readonly property bool isHovered: mouseArea.containsMouse
    
    implicitWidth: isVertical ? 28 : 20
    implicitHeight: Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    Text {
        id: powerIcon
        anchors.centerIn: parent
        text: "\udb81\udc25"
        font.family: Commons.Theme.fontIcon
        font.pixelSize: 14
        color: root.isHovered ? Commons.Theme.secondary : Commons.Theme.foreground
        
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: root.isHovered ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            if (root.powerMenuPopup && root.barWindow) {
                if (!root.powerMenuPopup.shouldShow) {
                    root.powerMenuPopup.positionNear(root, root.barWindow)
                }
                root.powerMenuPopup.shouldShow = !root.powerMenuPopup.shouldShow
            }
            root.clicked()
        }
    }
}

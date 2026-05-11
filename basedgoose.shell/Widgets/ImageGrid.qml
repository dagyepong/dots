import QtQuick 6.10
import QtQuick.Controls 6.10
import "../Commons" as Commons

Item {
    id: root
    
    property alias model: gridView.model
    property alias delegate: gridView.delegate
    property int cellWidth: 180
    property int cellHeight: 180 * 9 / 16 + 8
    property color backgroundColor: Qt.lighter(Commons.Theme.background, 1.15)
    
    default property alias content: overlayContainer.children
    
    Rectangle {
        anchors.fill: parent
        radius: Commons.Theme.radius
        color: root.backgroundColor
        clip: true
        
        Item {
            anchors.fill: parent
            anchors.margins: 8
            
            GridView {
                id: gridView
                anchors.centerIn: parent
                width: Math.floor((parent.width / root.cellWidth)) * root.cellWidth
                height: Math.min(parent.height, Math.ceil(model ? model.count / Math.max(1, Math.floor(parent.width / root.cellWidth)) : 0) * root.cellHeight)
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                clip: true
                
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    active: true
                }
            }
            
            Item {
                id: overlayContainer
                anchors.fill: parent
            }
        }
    }
}
import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string text: ""
    property string placeholderText: "Select..."
    property color textColor: Commons.Theme.foreground
    property color placeholderColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)
    property color highlightColor: Commons.Theme.primary
    property color baseColor: Qt.lighter(Commons.Theme.background, 1.15)
    property color hoverColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.06)
    property color borderColor: Commons.Theme.border
    property color hoverBorderColor: highlightColor
    property bool isHighlighted: false
    property int animationDuration: 100
    
    signal clicked()
    
    implicitWidth: 200
    implicitHeight: 40
    radius: Commons.Theme.radius
    color: dropdownArea.containsMouse ? hoverColor : baseColor
    border.color: dropdownArea.containsMouse ? hoverBorderColor : borderColor
    border.width: 1
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    Behavior on border.color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        
        Text {
            Layout.fillWidth: true
            text: root.text || root.placeholderText
            font.family: Commons.Theme.fontUI
            font.pixelSize: 12
            color: root.isHighlighted ? root.highlightColor : (root.text ? root.textColor : root.placeholderColor)
            elide: Text.ElideRight
        }
        
        Text {
            text: dropdownArea.containsMouse ? "󰅀" : "󰅂"
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 12
            color: root.placeholderColor
            
            Behavior on text {
                PropertyAnimation { duration: root.animationDuration }
            }
        }
    }
    
    MouseArea {
        id: dropdownArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

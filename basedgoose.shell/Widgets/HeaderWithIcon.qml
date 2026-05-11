import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../Commons" as Commons

RowLayout {
    id: root
    
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color iconColor: Commons.Theme.secondary
    property color iconBackgroundColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.15)
    property color titleColor: Commons.Theme.foreground
    property color subtitleColor: Qt.rgba(titleColor.r, titleColor.g, titleColor.b, 0.6)
    property int iconSize: 18
    property int iconBoxSize: 36
    property int iconBoxRadius: Commons.Theme.radiusLg
    property int titleSize: Commons.Theme.fontSizeHeading
    property int subtitleSize: Commons.Theme.fontSizeCaption
    
    spacing: Commons.Theme.spacingMd
    
    Rectangle {
        width: root.iconBoxSize
        height: root.iconBoxSize
        radius: root.iconBoxRadius
        color: root.iconBackgroundColor
        
        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Commons.Theme.fontIcon
            font.pixelSize: root.iconSize
            color: root.iconColor
        }
    }
    
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        
        Text {
            text: root.title
            font.family: Commons.Theme.fontUI
            font.pixelSize: root.titleSize
            font.weight: Font.Bold
            color: root.titleColor
            visible: root.title.length > 0
        }
        
        Text {
            text: root.subtitle
            font.family: Commons.Theme.fontUI
            font.pixelSize: root.subtitleSize
            color: root.subtitleColor
            visible: root.subtitle.length > 0
        }
    }
}

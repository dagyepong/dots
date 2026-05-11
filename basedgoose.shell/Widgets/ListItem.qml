import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color iconColor: Commons.Theme.foreground
    property color titleColor: Commons.Theme.foreground
    property color subtitleColor: Qt.rgba(titleColor.r, titleColor.g, titleColor.b, 0.6)
    property color baseColor: "transparent"
    property color hoverColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.06)
    property color borderColor: Commons.Theme.border
    property int iconSize: 18
    property int titleSize: Commons.Theme.fontSize
    property int subtitleSize: Commons.Theme.fontSizeCaption
    property int animationDuration: 100
    property bool showBorder: false
    property alias contentItem: contentArea
    
    signal clicked()
    
    implicitWidth: 300
    implicitHeight: 56
    radius: Commons.Theme.radiusLg
    color: itemArea.containsMouse ? hoverColor : baseColor
    border.width: showBorder ? 1 : 0
    border.color: borderColor
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    RowLayout {
        id: contentArea
        anchors.fill: parent
        anchors.leftMargin: Commons.Theme.spacingLg
        anchors.rightMargin: Commons.Theme.spacingLg
        spacing: Commons.Theme.spacingMd
        
        Text {
            text: root.icon
            font.family: Commons.Theme.fontIcon
            font.pixelSize: root.iconSize
            color: root.iconColor
            visible: root.icon.length > 0
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            Text {
                text: root.title
                font.family: Commons.Theme.fontUI
                font.pixelSize: root.titleSize
                font.weight: Font.Medium
                color: root.titleColor
                elide: Text.ElideRight
                Layout.fillWidth: true
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
    
    MouseArea {
        id: itemArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        z: -1
    }
}

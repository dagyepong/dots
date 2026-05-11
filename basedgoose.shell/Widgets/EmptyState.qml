import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../Commons" as Commons

ColumnLayout {
    id: root
    
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property int iconSize: 64
    property real iconOpacity: 0.3
    property real textOpacity: 0.6
    
    spacing: 12
    
    Text {
        text: root.icon
        font.family: Commons.Theme.fontIcon
        font.pixelSize: root.iconSize
        color: Commons.Theme.surfaceTextVariant
        opacity: root.iconOpacity
        Layout.alignment: Qt.AlignHCenter
    }
    
    Text {
        text: root.title
        font.pixelSize: 16
        font.weight: Font.Medium
        font.family: Commons.Theme.fontUI
        color: Commons.Theme.surfaceTextVariant
        opacity: root.textOpacity
        Layout.alignment: Qt.AlignHCenter
        visible: root.title.length > 0
    }
    
    Text {
        text: root.subtitle
        font.pixelSize: 13
        font.family: Commons.Theme.fontUI
        color: Commons.Theme.surfaceTextVariant
        opacity: root.textOpacity * 0.67
        Layout.alignment: Qt.AlignHCenter
        visible: root.subtitle.length > 0
    }
}


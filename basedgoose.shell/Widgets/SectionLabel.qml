import QtQuick 6.10
import "../Commons" as Commons

Text {
    id: root
    
    property color labelColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.6)
    
    font.family: Commons.Theme.fontUI
    font.pixelSize: Commons.Theme.fontSizeCaption
    font.weight: Font.Medium
    font.letterSpacing: 0.5
    color: root.labelColor
}

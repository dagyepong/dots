import QtQuick
import qs.theme

// Base of a step: big title, a line under it and the area for the content
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: areaItem.data
    property alias area: areaItem

    Text {
        id: head
        x: 56
        y: 44
        width: parent.width - 112
        text: root.title
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 30
        font.bold: true
    }

    Text {
        id: sub
        x: 56
        anchors.top: head.bottom
        anchors.topMargin: 6
        width: parent.width - 112
        text: root.subtitle
        wrapMode: Text.WordWrap
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    Item {
        id: areaItem
        x: 56
        y: 44 + head.height + 6 + sub.height + 24
        width: parent.width - 112
        height: parent.height - y - 8
    }
}

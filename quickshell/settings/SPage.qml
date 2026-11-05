import QtQuick
import qs.theme

// A page of the Settings window: title and a scrolling column of cards
Flickable {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: col.data

    contentWidth: width
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        x: 28
        y: 24
        width: root.width - 56
        spacing: 14

        Item {
            width: parent.width
            height: head.implicitHeight + (sub.visible ? sub.implicitHeight + 2 : 0) + 6

            Text {
                id: head
                text: root.title
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                id: sub
                visible: root.subtitle !== ""
                anchors.top: head.bottom
                anchors.topMargin: 2
                width: parent.width
                text: root.subtitle
                wrapMode: Text.WordWrap
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }
}

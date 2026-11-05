import QtQuick
import qs.theme

// A card with a small title and rows inside
Item {
    id: root

    property string title: ""
    default property alias rows: rowsCol.data

    width: parent ? parent.width : 400
    implicitHeight: (titleText.visible ? titleText.height + 8 : 0) + card.height

    Text {
        id: titleText
        visible: root.title !== ""
        x: 6
        text: root.title.toUpperCase()
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1
    }

    Rectangle {
        id: card
        y: titleText.visible ? titleText.height + 8 : 0
        width: parent.width
        height: rowsCol.implicitHeight + 8
        radius: 18
        color: Theme.surfaceSoft

        Column {
            id: rowsCol
            x: 6
            y: 4
            width: parent.width - 12
        }
    }
}

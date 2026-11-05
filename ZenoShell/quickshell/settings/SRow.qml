import QtQuick
import qs.theme

// A row: title and hint on the left, the control on the right
Item {
    id: root

    property string title: ""
    property string hint: ""
    property bool last: false
    default property alias control: slot.data

    width: parent ? parent.width : 400
    implicitHeight: Math.max(52, texts.implicitHeight + 20)

    Column {
        id: texts
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: slot.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        Text {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            wrapMode: Text.WordWrap
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Rectangle {
        visible: !root.last
        anchors.bottom: parent.bottom
        x: 12
        width: parent.width - 24
        height: 1
        color: Theme.border
        opacity: 0.5
    }
}

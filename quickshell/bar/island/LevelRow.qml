// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L E V E L   R O W                                                      │
// │   one level on a control-centre page · its name, then its bar            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../components"

// Every level on the sound page is one of these: a column of fixed width with
// the mark and the name, then the bar, so every bar on the page starts at the
// same place and is the same size. The mark is a glyph or an application's
// icon; a click on it is `markClicked`, which mutes it.
Item {
    id: root

    property string glyph: ""
    property string picture: ""
    property string name: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property string unit: "%"
    property bool dimmed: false
    property bool available: true

    signal moved(int value)
    signal markClicked()

    width: parent ? parent.width : 0
    height: Theme.detailRow

    Item {
        id: mark

        width: 20
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.dimmed ? 0.45 : 1

        Image {
            id: picture

            anchors.fill: parent
            source: root.picture
            visible: root.picture !== "" && status === Image.Ready
            sourceSize.width: 40
            sourceSize.height: 40
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: !picture.visible
            text: root.glyph !== "" ? root.glyph : "󰝚"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.text
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.markClicked()
        }
    }

    Text {
        id: label

        anchors.left: mark.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.detailLabel - mark.width - 10
        elide: Text.ElideRight
        text: root.name
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeRegular - 1
        color: root.dimmed ? Theme.textMuted : Theme.text
    }

    SliderRow {
        x: Theme.detailLabel + 8
        width: parent.width - x
        height: Theme.detailRow - 4
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        from: root.from
        to: root.to
        unit: root.unit
        dimmed: root.dimmed
        available: root.available
        onMoved: value => root.moved(value)
    }
}

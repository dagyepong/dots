import QtQuick
import qs.theme

Rectangle {
    id: chip

    property string label: ""
    property string icon: ""             // if set, replaces the text
    property bool accent: false
    property bool selected: false
    signal clicked()

    implicitHeight: 28
    radius: height / 2
    color: selected ? Theme.accent
           : (chipMouse.containsMouse ? Theme.islandHover : (accent ? Theme.border : Theme.island))
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 100 } }

    Glyph {
        anchors.centerIn: parent
        visible: chip.icon !== ""
        kind: chip.icon !== "" ? chip.icon : "play"
        size: 14
        color: chip.selected ? Theme.island : Theme.foreground
    }

    Text {
        anchors.centerIn: parent
        visible: chip.icon === ""
        text: chip.label
        color: chip.selected ? Theme.island : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.bold: chip.selected || chip.accent
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A small sticker button for the dock's cards (Dock*Card.qml): an icon and/or a
// label on a raised Pill that presses down under the pointer. `accent` fills it
// cyan (the main action of a card).
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool accent: false
    property bool selected: false
    property real iconSize: 20
    property real fontSize: 14

    signal clicked()

    implicitHeight: 36
    implicitWidth: Math.max(40, row.implicitWidth + 24)
    width: implicitWidth
    height: implicitHeight

    Pill {
        anchors.fill: parent
        cornerRadius: 11
        ringWidth: 5
        fillColor: (root.accent || root.selected) ? Theme.accentCyan : Theme.surface
        pressed: area.pressed

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: root.iconSize
                fill: root.accent ? 1 : 0
                color: (root.accent || root.selected) ? Theme.colBorder : Theme.ink
            }

            Text {
                visible: root.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: (root.accent || root.selected) ? Theme.colBorder : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

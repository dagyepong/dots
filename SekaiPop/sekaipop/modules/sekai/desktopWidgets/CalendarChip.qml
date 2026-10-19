import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A small button on the calendar card (CalendarCardWidget.qml): an icon and a word.
// `primary` is the mint-cyan one, `danger` goes pink under the pointer, and
// `usable: false` greys it out and ignores the click.
//
//   CalendarChip { icon: "check"; label: "Done"; primary: true; onClicked: ... }
Item {
    id: chip

    property string icon: ""
    property string label: ""
    property bool primary: false
    property bool danger: false
    property bool usable: true
    signal clicked()

    implicitWidth: chipRow.implicitWidth + 22
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight
    opacity: chip.usable ? 1 : 0.45

    readonly property bool lit: chipArea.containsMouse && chip.usable

    Gradient {
        id: fill
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    Rectangle {
        anchors.fill: parent
        radius: 13
        border.width: 2
        border.color: Theme.pLine
        antialiasing: true
        color: chip.primary ? Theme.accentMint
            : (chip.lit ? (chip.danger ? Theme.irisColorPink : Theme.pSurfaceHover) : Theme.pSurface)
        gradient: chip.primary ? fill : null

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 4

        MaterialIcon {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: chip.icon
            size: 15
            weight: 700
            fill: 0
            color: chip.primary || (chip.danger && chip.lit) ? Theme.colBorder : Theme.pInk
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: chip.primary || (chip.danger && chip.lit) ? Theme.colBorder : Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: chip.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (chip.usable)
                chip.clicked()
        }
    }
}

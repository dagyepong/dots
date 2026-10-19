import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One utility button *inside* the long bar of UtilButtons.qml: just a
// Material Symbols glyph, no pill of its own (the bar is the pill).
// `active` lights it up (a rounded highlight filled with `activeFill`,
// dark glyph) for the ones that have a state: muted mic, performance
// profile, recording. Hover and press get a soft white wash, and the
// glyph dips slightly while pressed.
//
//   UtilKey { icon: "mic"; active: muted; onClicked: toggleMic() }
Item {
    id: root

    property string icon: ""
    property bool active: false
    property color activeFill: Theme.accentCyan

    // The key's name (the flyout's caption shows it while the pointer is over it)
    // and whether the pointer is over it right now.
    property string label: ""
    readonly property bool hovered: area.containsMouse

    // The bar's pill uses 30 x 24 and a 20 px glyph; the flyout's keypad bigger ones.
    property real keyWidth: 30
    property real keyHeight: 24
    property int iconSize: 20

    signal clicked()

    implicitWidth: root.keyWidth
    implicitHeight: root.keyHeight

    // Highlight behind the glyph: lit fill when active, otherwise a
    // faint white wash that only shows on hover / press.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 8
        antialiasing: true
        color: root.active ? root.activeFill : Theme.chipInk
        opacity: root.active ? 1
            : (area.pressed ? 0.24 : (area.containsMouse ? 0.12 : 0))

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MaterialIcon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.active ? Theme.colBorder : Theme.chipInk
        scale: area.pressed ? 0.84 : 1

        Behavior on scale {
            NumberAnimation {
                duration: area.pressed ? 70 : 220
                easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: 2.2
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

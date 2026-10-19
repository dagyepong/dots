import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One of the round keys on the Calendar lockscreen (Restart, Shut down): an icon on a
// round plate (LockPlate.qml) that sinks like a keycap when pressed. Pressed once it
// turns pink and shows an exclamation mark (`armed`, kept by LockContext for a few
// seconds); pressing it again is what does the thing. Pure UI: it only says pressed().
// `hovered` lets the caller name the key in the line under the keys.
//
// A file of its own, not an inline component of LockCalendar.qml, because inline
// components cannot see the ids of the file they are written in. Everything it needs
// comes from LockPalette, plus `u` (LockCalendar's size unit).
Item {
    id: key

    property string icon: ""
    property bool armed: false
    property real u: 1

    readonly property bool hovered: area.containsMouse

    signal pressed()

    function px(n) {
        return Math.round(n * key.u)
    }

    LockPlate {
        anchors.fill: parent
        pressed: area.pressed
        outline: key.px(3)
        ring: key.px(2)
        shadowDy: key.px(6)
        fillColor: key.armed ? LockPalette.calAccent : (area.containsMouse ? LockPalette.calMint : LockPalette.paper)

        Behavior on fillColor {
            ColorAnimation { duration: 110 }
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: key.armed ? "priority_high" : key.icon
            size: key.px(40)
            weight: 600
            color: LockPalette.cBorder
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.pressed()
    }
}

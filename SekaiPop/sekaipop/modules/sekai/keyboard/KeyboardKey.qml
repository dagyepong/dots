import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One key of the on-screen keyboard, built exactly like a workspace badge
// (WorkspaceBadges.qml): the shared Pill (navy outline, white ring, flat colour,
// hard shadow straight down), the number-style ExtraBold label in the outline
// navy, a real push-into-the-shadow on mouse-down with the same spring back, and
// a lit modifier that grows in place with the badges' soft OutBack bounce.
// Like the badges there is no hover magnification.
//
//   KeyboardKey { width: 46; label: "q"; onActivated: press() }
//
// `active` lights a modifier (the caller picks its colour through `fill`);
// `locked` adds the little dot under the label that a locked Shift / Caps wears.
// `repeats` makes a held key fire again, after a short wait, like a real one.
Item {
    id: root

    property string label: ""
    property string icon: ""
    property color fill: Theme.accentCyan
    property bool active: false
    property bool locked: false
    property bool repeats: false
    property real labelSize: 16
    property real keyHeight: 46

    // The workspace badge nudges its digits down a touch so they sit in the
    // middle of the face; the same nudge here.
    readonly property real numberNudge: 2

    readonly property bool down: area.pressed

    signal activated()

    // Same shape as a badge: the face is keyHeight tall, the shadow hangs below.
    height: root.keyHeight + Theme.shadowOffset

    Pill {
        id: cap
        anchors.fill: parent

        cornerRadius: Theme.radiusBadge
        ringWidth: 8
        fillColor: root.fill
        pressed: area.pressed

        // Grows in place like the active workspace badge; width and height
        // never change, so the row never reflows.
        scale: root.active ? 1.1 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.shadowOffset / 2 + root.numberNudge
            visible: root.icon === ""
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: root.labelSize
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            text: root.label
        }

        MaterialIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.shadowOffset / 2 + root.numberNudge
            visible: root.icon !== ""
            name: root.icon
            size: 22
            weight: 600
            color: Theme.colBorder
        }

        // A locked Shift / Caps: a small dot under the label.
        Rectangle {
            visible: root.locked
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 6
            height: 6
            radius: 3
            color: Theme.colBorder
        }
    }

    // A sibling of the Pill, not inside it: anything declared inside a Pill is
    // reparented onto its inset fill, where "anchors.fill: parent" would not
    // cover the key (see the same note in WorkspaceBadges.qml).
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // Presses count the moment they land, not on release: typing feels late
        // otherwise.
        onPressed: {
            root.activated()
            if (root.repeats) {
                hold.interval = 420
                hold.restart()
            }
        }
        onReleased: hold.stop()
        onCanceled: hold.stop()
    }

    Timer {
        id: hold
        repeat: true
        onTriggered: {
            hold.interval = 55
            root.activated()
        }
    }

    onVisibleChanged: if (!visible) hold.stop()
}

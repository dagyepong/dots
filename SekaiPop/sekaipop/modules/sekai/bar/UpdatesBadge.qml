import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Pending package updates, as a bar button: an "update" glyph with the count
// in a small badge. Pure UI: Bar.qml feeds it PackageUpdatesService's numbers.
//
//   count     how many updates are waiting
//   nudging   "a lot": the button turns amber and the glyph does a little hop
//             every few seconds
//   left click   run the update in a terminal   right click   look again
//
// The badge is on the bar from the start while the first look is under way
// (`loading`: the glyph spins), so it does not pop in when the answer arrives;
// it then either becomes the count or, with nothing to update, shrinks away.
// It grows in and shrinks away (`reveal`) rather than popping, and Status_Bar
// reads `reveal` to open and close its slot in the bar gradually.
// Nothing is shown while there is nothing to update (unless `showZero`).
Item {
    id: root

    property int count: 0
    property bool nudging: false
    property bool showZero: false
    property bool busy: false
    // A look is under way that should be seen even with nothing to update:
    // the first one after start, one asked for, or an update being run.
    property bool loading: false
    // False when the module is switched off in Settings.
    property bool allowed: true
    property string tipText: ""
    property string barPosition: "top"

    signal clicked()
    signal refreshRequested()

    readonly property bool shown: allowed && (count > 0 || showZero || loading)

    // 0 -> 1: grows in and shrinks away instead of popping.
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    opacity: Math.min(1, reveal * 1.5)
    scale: 0.55 + 0.45 * reveal

    // The count as last seen above zero, so the number does not turn into a
    // "0" while the badge is still shrinking away.
    property int shownCount: count
    onCountChanged: if (count > 0) shownCount = count

    implicitWidth: Theme.pillHeight
    implicitHeight: Theme.pillHeight + Theme.shadowOffset

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: 8
        capKeepsFill: root.nudging || root.count > 0   // Capsule bar: coloured only while there is news
        fillColor: root.nudging ? "#ffb74d" : (root.count > 0 ? Theme.accentMint : Theme.surface)
        pressed: area.pressed
        Behavior on fillColor {
            ColorAnimation { duration: 220 }
        }

        MaterialIcon {
            id: glyph
            anchors.centerIn: parent
            size: 18
            fill: root.nudging ? 1 : 0
            color: root.count > 0 ? Theme.colBorder : Theme.ink
            name: root.busy ? "sync" : "system_update_alt"
            transformOrigin: Item.Center

            RotationAnimator on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1000
                onRunningChanged: if (!running) glyph.rotation = 0
            }

            // The hop: only while nudging, every ~6 s.
            transform: Translate { id: hop }

            // A Timer starts each hop and the animation only runs for the ~0.4 s of the
            // hop itself. It used to be one endless SequentialAnimation with a 5.2 s
            // PauseAnimation in it: a running animation makes Qt render a frame on every
            // vsync, pause or not, so with the badge nudging the whole bar window
            // committed 144 frames a second to Hyprland while nothing moved (counted with
            // qt.scenegraph.time.renderloop: 144 fps with the bar, none without it).
            Timer {
                interval: 5620          // 5200 ms of rest + the 420 ms hop, as before
                repeat: true
                running: root.nudging && !root.busy
                onTriggered: hopAnim.restart()
            }
            SequentialAnimation {
                id: hopAnim
                NumberAnimation { target: hop; property: "y"; to: -5; duration: 160; easing.type: Easing.OutQuad }
                NumberAnimation { target: hop; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBounce }
            }
        }

        Rectangle {
            visible: opacity > 0.01
            opacity: root.count > 0 ? 1 : 0
            scale: root.count > 0 ? 1 : 0.5
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack }
            }
            anchors {
                top: parent.top
                right: parent.right
                topMargin: -2
                rightMargin: -2
            }
            radius: 8
            color: root.nudging ? "#e0575b" : Theme.colBorder
            border.width: 2
            border.color: Theme.ringWhite
            implicitWidth: Math.max(16, countLabel.implicitWidth + 8)
            implicitHeight: 16
            antialiasing: true

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: root.shownCount > 99 ? "99+" : root.shownCount
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.refreshRequested()
            else
                root.clicked()
        }
    }

    BarTip {
        shown: area.containsMouse
        text: root.tipText
        barPosition: root.barPosition
    }
}

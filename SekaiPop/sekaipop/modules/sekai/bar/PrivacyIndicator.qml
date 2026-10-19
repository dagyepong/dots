import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The privacy pill: appears on the bar while the microphone is live or the
// screen is being shared. Pure UI: Bar.qml feeds it PrivacyService's state.
//
//   [ mic ] [ screen ]
//
// Only the icons are on the bar, so nothing about what you are doing is
// readable at a glance by someone looking at your screen. The icons that apply
// light up in the warning pink; hover the pill to see the details (which app
// has the microphone, who is watching the screen) in a small tag.
// It grows in and shrinks away (`reveal`, 0 -> 1) rather than popping: the
// pill scales and fades while its slot in the bar opens or closes (Status_Bar
// reads `reveal` to do that), and the icons stay on it until it has gone.
// Nothing is drawn while nothing is in use: the module takes no room
// (`visible` is false once it has finished shrinking).
Item {
    id: root

    property bool vertical: false
    // Which edge the bar is on, so the tag opens towards the screen.
    property string barPosition: "top"
    property bool micLive: false
    property bool screenLive: false
    // What the hover tag says (one line per thing in use).
    property string detailText: ""

    readonly property bool live: micLive || screenLive

    // 0 -> 1. Also what the bar's layout uses to open and close this module's
    // slot gradually (see Status_Bar.qml).
    property real reveal: live ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    opacity: Math.min(1, reveal * 1.5)
    scale: 0.55 + 0.45 * reveal

    // Which icons are on the pill. They follow micLive / screenLive while
    // something is in use, and stay as they were while it fades out (the
    // live flags are already false by then, which would empty the pill).
    //
    // Both are set together, from micLive / screenLive themselves. (It used to
    // test `live` inside each change handler: `live` can still hold its old
    // value at that moment, so the icons were sometimes not updated and the
    // pill came up empty until the shell was reloaded. A leftover icon from the
    // last time could also show for the wrong thing.)
    property bool micShown: false
    property bool screenShown: false
    function refreshShown() {
        if (micLive || screenLive) {
            micShown = micLive
            screenShown = screenLive
        }
    }
    onMicLiveChanged: refreshShown()
    onScreenLiveChanged: refreshShown()
    Component.onCompleted: refreshShown()

    readonly property color warn: "#ff6f91"

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: vertical ? 6 : 8
        capKeepsFill: true   // Capsule bar: the warning colour is the point, keep it
        fillColor: root.warn

        implicitWidth: root.vertical ? pill.barVWidth
                                     : row.implicitWidth + 2 * ringWidth + 14
        implicitHeight: root.vertical ? col.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + Theme.shadowOffset
                                      : Theme.pillHeight + Theme.shadowOffset

        // A slow pulse so it is hard to miss without being annoying.
        SequentialAnimation on opacity {
            running: root.live
            loops: Animation.Infinite
            NumberAnimation { to: 0.82; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }

        Row {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                visible: root.micShown
                anchors.verticalCenter: parent.verticalCenter
                name: "mic"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
            MaterialIcon {
                visible: root.screenShown
                anchors.verticalCenter: parent.verticalCenter
                name: "screen_record"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
        }

        Column {
            id: col
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                visible: root.micShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: "mic"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
            MaterialIcon {
                visible: root.screenShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: "screen_record"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
        }
    }

    // Hover: what is in use and by whom, as a small tag towards the inside of
    // the screen.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
    }
    BarTip {
        shown: area.containsMouse
        text: root.detailText
        barPosition: root.barPosition
    }
}

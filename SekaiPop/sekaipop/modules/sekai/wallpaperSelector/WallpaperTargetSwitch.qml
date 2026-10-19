import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The "which wallpaper am I choosing?" switch in the wallpaper board's header:
// Desktop | Lockscreen. Only there while Settings -> Desktop -> Wallpaper ->
// Separate Lockscreen Wallpaper is on (WallpaperFace.qml swaps it in for the
// plain "Wallpapers" title).
//
// Same ingredients as SortChip / SegmentSwitch (outline, hard shadow, a thumb that
// slides and overshoots a little), at header size and with an icon on each side.
// The two sides are told apart by more than the label, so it can't be misread:
// the thumb is the desktop's cyan-to-mint under Desktop and the lockscreen's own
// candy-pink-to-mint (LockPalette, so it follows the theme) under Lockscreen.
//
// Pure UI: it only says picked("desktop") / picked("lock").
Item {
    id: root

    property string current: "desktop"      // "desktop" | "lock"
    signal picked(string id)

    readonly property bool lock: root.current === "lock"
    readonly property real slot: (root.width - 6) / 2

    // What the thumb is filled with. Animated, so the colour glides over with it.
    property color thumbA: root.lock ? LockPalette.pink : Theme.accentCyan
    property color thumbB: root.lock ? LockPalette.mint : Theme.accentMint
    Behavior on thumbA { ColorAnimation { duration: 220 } }
    Behavior on thumbB { ColorAnimation { duration: 220 } }

    width: 292
    height: 40

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset - 1
        y: Theme.shadowOffset - 1
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    // the pill
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true
    }

    // the thumb
    Rectangle {
        y: 3
        height: root.height - 6
        width: root.slot
        x: 3 + (root.lock ? root.slot : 0)
        radius: height / 2
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.thumbA }
            GradientStop { position: 1.0; color: root.thumbB }
        }

        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    Repeater {
        model: [
            { id: "desktop", label: "Desktop", icon: "desktop_windows" },
            { id: "lock", label: "Lockscreen", icon: "lock" }
        ]

        delegate: Item {
            id: seg
            required property var modelData
            required property int index
            readonly property bool on: seg.modelData.id === root.current

            x: 3 + seg.index * root.slot
            y: 0
            width: root.slot
            height: root.height

            Row {
                anchors.centerIn: parent
                spacing: 7

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: seg.modelData.icon
                    size: 20
                    weight: 600
                    color: seg.on ? Theme.colBorder : Theme.colSubText
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label
                    color: seg.on ? Theme.colBorder : Theme.colSubText
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyleBold
                    font.weight: Font.ExtraBold
                    font.pixelSize: 14
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(seg.modelData.id)
            }
        }
    }
}

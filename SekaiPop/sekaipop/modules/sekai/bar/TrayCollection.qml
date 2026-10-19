import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.modules.common
import qs.modules.common.widgets

// The "Tray Collection" capsule from Figma: navy fill, white ring,
// navy outline, hard shadow — same three-layer Pill as Weather and
// Clock — holding one icon per tray app.
//
// Used twice:
//   - the dropdown under the tray button (the apps that aren't pinned),
//     50px tall
//   - the pinned widget in the bar (the pinned apps *and* the dropdown's
//     arrow button, one pill), `compact`, 36px tall so it sits level
//     with Weather and Clock
//
// Pure UI apart from IconImage / ScriptModel (Quickshell's own icon
// widget, which understands the icon strings tray items publish, and
// a list model that keeps existing icons in place when the list
// changes). It never calls the tray items itself: it says what was
// clicked and lets Bar.qml / TrayPopups.qml decide what that means.
//
// Motion:
//   - when `present` turns true the room opens up first (the capsule's
//     `shownWidth` glides — consumers size it with that, not with
//     implicitWidth) and then the capsule pops in; when it turns false
//     it pops out and then the room closes. It glides to its new width
//     when icons come and go.
//   - a new icon eases in (no bounce); icons after a removed one slide over
//   - `leavingItem` (an app that's about to be pinned / unpinned)
//     shrinks away before it actually leaves the list
//   - `activeItem` (the app whose right-click menu is open) stays
//     lifted so you can see which icon the menu belongs to
Pill {
    id: root

    // Array of SystemTrayItem (or anything with an `icon`).
    property var model: []
    property bool compact: false

    // The pinned widget on a standing bar (left / right edge): the icons
    // stack in one column, and the capsule glides open and shut along its
    // height (`shownHeight`) instead of its width.
    property bool vertical: false

    // False collapses the capsule away (the pinned widget when nothing
    // is pinned). Animated.
    property bool present: true

    // False: every size change, the pop and every arriving icon snap
    // instead of animating. The dropdown keeps this off while it's closed and for a
    // moment after it opens, so it appears fully formed instead of
    // gliding / popping into shape (a hidden window only lays itself out
    // once it's shown, which would otherwise play as an animation).
    property bool animated: true

    property var activeItem: null
    property var leavingItem: null

    // Which button, plus the icon tile that was clicked so the popup
    // can put a menu next to it.
    signal itemClicked(var item, int button, Item icon)
    // The wheel over an icon: the item, the wheel delta (120 per notch, sign as
    // the wheel reports it) and whether it was a sideways scroll. The owner
    // passes it on to the app (SystemTrayItem.scroll).
    signal itemScrolled(var item, real delta, bool horizontal)

    // false: the wheel is not sent to apps (Settings -> Bar -> Scroll on tray icons).
    property bool scrollEnabled: true

    // Figma: 22px icons, 18px apart, in a 115x50 capsule (ring 8 there; 6 here, like the bar's pills).
    // Compact keeps the same look at the bar's 36px pill height.
    readonly property int iconSize: compact ? (root.capsule ? 16 : 18) : 22
    readonly property int iconGap: compact ? 10 : 18
    // (A pill that is only the arrow button is about as wide as the old
    // standalone button was.)
    // (Ring 6 everywhere, like every other pill. Compact = in the bar: padY 3 so the
    // capsule is exactly the bar pills' height: 18 + 2 x 3 + 2 x 6 + shadow = 40.
    // The padding is 2 more than it was with the old ring of 8 wherever that
    // ring was, so the sizes (the dropdown's 115 x 50 capsule, a standing bar's
    // width) stay what they were.)
    readonly property int padX: vertical ? (root.capsule ? Math.max(8, (Theme.capVChip - iconSize) / 2) : 8) : (compact ? (root.capsule ? ((empty && showToggle) ? 3 : 8) : ((empty && showToggle) ? 2 : 12)) : 21)
    readonly property int padY: vertical ? 8 : (compact ? 3 : 8)
    readonly property int maxPerRow: 6

    readonly property int count: model ? model.length : 0
    readonly property bool empty: count === 0

    // (Capsule bar: a flat chip, no ring to leave room for.)
    ringWidth: root.capsule ? 0 : 6
    fillColor: Theme.chipFill

    // The tray toggle: with `showToggle` the capsule also holds the
    // dropdown's arrow button as its last cell, so the pinned icons and
    // the button are one pill (pinning an icon just pops one into it).
    property bool showToggle: false
    property bool toggleOpen: false
    property bool toggleAttention: false
    // Degrees to turn the arrow (standing bars point it at the dropdown).
    property real glyphRotation: 0
    // Real screen pixels per design pixel. Not used by the arrow (it is a
    // font glyph); kept so the owner that sets it doesn't break.
    property real texel: 1
    signal toggleRequested()
    // The button cell, so the dropdown can be centered under it.
    readonly property Item toggleItem: toggleCell

    readonly property real toggleSize: iconSize
    readonly property real toggleW: showToggle ? toggleSize : 0
    readonly property real toggleGap: (showToggle && !empty) ? iconGap : 0

    readonly property real bodyWidth: empty ? (showToggle ? 0 : emptyLabel.implicitWidth) : grid.implicitWidth
    readonly property real bodyHeight: empty ? (showToggle ? 0 : emptyLabel.implicitHeight) : grid.implicitHeight

    readonly property real contentWidth: vertical
        ? Math.max(bodyWidth, toggleW)
        : bodyWidth + toggleGap + toggleW
    readonly property real contentHeight: vertical
        ? bodyHeight + toggleGap + toggleW
        : Math.max(bodyHeight, toggleW)

    // Where the capsule is headed (`present` aside)...
    readonly property real fullWidth: contentWidth + padX * 2 + ringWidth * 2
    // ...the narrowest it gets with one icon in it...
    readonly property real minWidth: iconSize + padX * 2 + ringWidth * 2
    readonly property real minHeight: iconSize + padY * 2 + ringWidth * 2 + Theme.shadowOffset

    implicitWidth: fullWidth
    implicitHeight: Math.max(contentHeight + padY * 2, Theme.pillHeight - ringWidth * 2)
        + ringWidth * 2 + Theme.shadowOffset

    // The capsule appears and goes in two steps, so it never sweeps
    // open or shut while it is visible:
    //   appear: the room opens up first (neighbours glide aside, the
    //           capsule itself is still invisible), then it pops in
    //           (scale + fade) in the space that's there.
    //   go:     it pops out first, then the room closes up (neighbours
    //           glide back).
    // `slotOpen` is "there's room for it" and `popT` is the pop, 0..1.
    // Both follow `present` (the handler below plays the two steps).
    property bool slotOpen: present
    property real popT: present ? 1 : 0

    // The size it had while it had icons, held while it pops out (when
    // the model is already empty) so it leaves as the capsule it was.
    property real keptWidth: fullWidth
    property real keptHeight: implicitHeight
    onFullWidthChanged: {
        if (present)
            keptWidth = fullWidth
        if (ready && present && animated && popT > 0.99)
            bumpAnim.restart()
    }
    onImplicitHeightChanged: if (present) keptHeight = implicitHeight

    property bool ready: false
    Component.onCompleted: ready = true

    onPresentChanged: {
        if (!ready)
            return
        popInAnim.stop()
        popOutAnim.stop()
        if (!animated) {
            slotOpen = present
            popT = present ? 1 : 0
        } else if (present) {
            slotOpen = true
            popInAnim.restart()
        } else {
            popOutAnim.restart()
        }
    }

    SequentialAnimation {
        id: popInAnim
        PauseAnimation { duration: 70 }
        NumberAnimation { target: root; property: "popT"; to: 1; duration: 170
            easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    }

    SequentialAnimation {
        id: popOutAnim
        NumberAnimation { target: root; property: "popT"; to: 0; duration: 120; easing.type: Easing.InCubic }
        ScriptAction { script: root.slotOpen = false }
    }

    // ...and where it is right now. Give the capsule this as its width
    // (or Layout.preferredWidth).
    property real shownWidth: slotOpen ? (present ? fullWidth : keptWidth) : 0
    Behavior on shownWidth {
        enabled: root.animated
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    // The same for height: what a standing bar sizes the capsule with.
    property real shownHeight: slotOpen ? (present ? implicitHeight : keptHeight) : 0
    Behavior on shownHeight {
        enabled: root.animated
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    // 0 -> 1 as the capsule opens up from nothing. Lets a layout take
    // back the gap it leaves around a collapsed capsule gradually
    // instead of all at once.
    readonly property real reveal: vertical
        ? Math.max(0, Math.min(1, shownHeight / minHeight))
        : Math.max(0, Math.min(1, shownWidth / minWidth))

    // A small pop each time icons come or go (the width changes).
    property real bump: 1
    NumberAnimation {
        id: bumpAnim
        target: root
        property: "bump"
        from: 0.95
        to: 1
        duration: 170
        easing.type: Easing.OutBack
        easing.overshoot: 2.0
    }

    // The pop: fades up while growing from a little smaller, about its
    // middle.
    opacity: Math.min(1, popT * 2)
    scale: (0.8 + 0.2 * popT) * bump

    cornerRadius: Math.min(compact ? Theme.radiusBadge : 25, (height - Theme.shadowOffset) / 2)

    // "The wheel works on these icons" (pinned capsule in the bar only: the
    // dropdown is a popup, and the bar's hints are for the bar).
    ScrollHint {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -6
        anchors.rightMargin: -6
        active: root.compact && root.scrollEnabled && !root.empty && !root.capsule
    }

    // Everything inside is clipped to the fill, so icons don't spill out
    // of a capsule that's still growing.
    Item {
        id: clipper
        anchors.fill: parent
        clip: true

        // Nothing in the tray — same idea as the media pill's "Nothing Playing".
        Text {
            id: emptyLabel
            anchors.centerIn: parent
            // (Not in the pinned pill: with nothing pinned that is just the
            // arrow button.)
            visible: root.empty && !root.showToggle && (!root.compact || root.present)
            text: "Nothing here"
            color: Theme.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        // Left-aligned by the padding (not centered) so icons already
        // there stay put while the capsule widens around them.
        Grid {
            id: grid
            x: root.padX
            y: (root.vertical && root.showToggle) ? root.padY : (clipper.height - height) / 2
            visible: !root.empty
            columns: root.vertical ? 1 : Math.max(1, Math.min(root.count, root.maxPerRow))
            columnSpacing: root.iconGap
            rowSpacing: root.vertical ? root.iconGap : 12

            Repeater {
                model: ScriptModel { values: root.model }

                delegate: Item {
                    id: tile

                    required property var modelData

                    readonly property bool leaving: root.leavingItem !== null && tile.modelData === root.leavingItem
                    readonly property bool active: root.activeItem !== null && tile.modelData === root.activeItem

                    width: root.iconSize
                    height: root.iconSize

                    // Arrival: a beat after being created (so the capsule
                    // has started widening), ease in -- no overshoot.
                    // Departure: shrink and fade, quickly. In a capsule
                    // that isn't animating (the dropdown as it opens)
                    // icons are just there.
                    property bool arrived: !root.animated
                    Timer {
                        interval: 30
                        running: true
                        onTriggered: tile.arrived = true
                    }

                    property real presence: (tile.arrived && !tile.leaving) ? 1 : 0
                    Behavior on presence {
                        enabled: root.animated
                        NumberAnimation {
                            duration: tile.leaving ? 110 : 190
                            easing.type: tile.leaving ? Easing.InCubic : Easing.OutBack
                            easing.overshoot: 1.6
                        }
                    }

                    // Lifts a touch under the cursor (and while its menu
                    // is open), pushes in while held, like the other
                    // buttons.
                    property real lift: area.pressed ? 0.85 : ((area.containsMouse || tile.active) ? 1.12 : 1.0)
                    Behavior on lift {
                        NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }

                    opacity: Math.min(1, tile.presence)
                    scale: (0.4 + 0.6 * tile.presence) * tile.lift

                    IconImage {
                        anchors.fill: parent
                        source: tile.modelData?.icon ?? ""
                    }

                    // "Needs attention": a coral dot that breathes on the
                    // icon's corner, so a message waiting is seen from across
                    // the room.
                    readonly property bool attention: tile.modelData?.status === Status.NeedsAttention
                    Rectangle {
                        visible: tile.attention
                        width: 9
                        height: 9
                        radius: 4.5
                        x: parent.width - 6
                        y: -3
                        color: "#ff5c7a"
                        border.width: 2
                        border.color: Theme.chipFill
                        antialiasing: true

                        SequentialAnimation on scale {
                            running: tile.attention
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    MouseArea {
                        id: area
                        // A little bigger than the icon so it's easy to hit
                        // (half the gap on each side, so tiles never overlap).
                        anchors.fill: parent
                        anchors.margins: -root.iconGap / 2 + 1
                        enabled: !tile.leaving
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => root.itemClicked(tile.modelData, mouse.button, tile)
                        onWheel: wheel => {
                            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                            const d = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
                            if (!root.scrollEnabled || d === 0) {
                                wheel.accepted = false
                                return
                            }
                            root.itemScrolled(tile.modelData, d, horizontal)
                        }
                    }
                }
            }
        }

        // The dropdown's toggle: the last cell of the pill. Pinned to the
        // pill's far end so it rides along as the pill changes size.
        Item {
            id: toggleCell
            opacity: root.showToggle ? 1 : 0
            enabled: root.showToggle
            width: root.toggleSize
            height: root.toggleSize
            x: root.vertical
                ? (clipper.width - width) / 2
                : clipper.width - root.padX - width
            y: root.vertical
                ? clipper.height - root.padY - height
                : (clipper.height - height) / 2

            // Lifts under the cursor and while the dropdown is open, pushes
            // in while held (like the icons).
            property real lift: toggleArea.pressed ? 0.85 : ((toggleArea.containsMouse || root.toggleOpen) ? 1.12 : 1.0)
            Behavior on lift {
                enabled: root.animated
                NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            }
            scale: lift

            // One Material Symbols Rounded glyph, "arrow_drop_down" (a font
            // glyph, crisp at any scale), turned upside down while the
            // dropdown is open so the arrow swaps with a little spin.
            Item {
                anchors.centerIn: parent
                width: 28
                height: 28
                rotation: root.glyphRotation

                MaterialIcon {
                    anchors.centerIn: parent
                    name: "arrow_drop_down"
                    size: 28
                    fill: 1
                    color: Theme.chipInk
                    rotation: root.toggleOpen ? 180 : 0
                    Behavior on rotation {
                        enabled: root.animated
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Something in the dropdown wants attention: a coral dot.
            Rectangle {
                visible: root.toggleAttention
                width: 9
                height: 9
                radius: 4.5
                x: parent.width - 6
                y: -3
                color: "#ff5c7a"
                border.width: 2
                border.color: Theme.chipFill
                antialiasing: true

                SequentialAnimation on scale {
                    running: root.toggleAttention
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                anchors.margins: -root.iconGap / 2 + 1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRequested()
            }
        }
    }
}

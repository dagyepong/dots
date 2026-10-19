import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Workspace switcher, drawn natively (Pill.qml) instead of from
// exported PNG/SVG assets — no image files to manage, and it's true
// vector at every size since nothing's ever rasterized.
//
// Pure UI (no Quickshell imports): tell it which workspace is active
// and it emits requested(n) when the user clicks a badge or scrolls
// over the row.
//
// Figma spec this follows:
//   idle badge   36 x 36, cyan fill, 8px white ring
//   active badge 42 x 42, one color per workspace, grows from centre
//   gap 6, per-workspace colors: cyan / pink / yellow / lavender / mint
//
// Behavior: no hover magnification (no macOS-dock cursor tracking).
// Every badge keeps its original 36x36 box in the row at all times —
// nothing is ever resized or squashed, and the row itself never
// reflows. The active badge is made "42px" purely by scaling it up in
// place around its own centre. Every badge on its left shifts further
// left, and every badge on its right shifts further right, by exactly
// the extra radius that zoom adds — so the gap right next to the
// active badge keeps matching every other gap, and the whole row
// reads as splitting evenly around whichever badge is active (works
// the same whether that's an end badge or one in the middle). Both
// the zoom and the shift ease in with a soft bounce (Behavior below)
// rather than snapping or morphing — only scale/position animate,
// width and height never do, so the badge's real dimensions never
// change.
Item {
    id: root

    property int active: 1      // 1-based number of the active workspace
    property int count: 5

    // Workspace ids that currently have windows (fed in by the bar).
    property var occupied: []

    // The workspace number each badge stands for, in order: 1..count always,
    // then any workspace above `count` that has windows or is the active one.
    // So an empty 7th badge turns into the 8th when you move to 8.
    readonly property var ids: {
        const out = []
        for (let i = 1; i <= root.count; i++)
            out.push(i)
            const extra = []
            for (const w of root.occupied)
                if (w > root.count && extra.indexOf(w) < 0)
                    extra.push(w)
                    if (root.active > root.count && extra.indexOf(root.active) < 0)
                        extra.push(root.active)
                        extra.sort((a, b) => a - b)
                        return out.concat(extra)
    }
    readonly property int total: root.ids.length

    // In the Capsule bar style the badges are redrawn as small ringed dots, the
    // active one a wide pill: no numbers, no zoom, nothing shifts aside (see
    // `dotRow` below). On a standing bar the dots stack in a column and the active
    // one is a tall pill.
    readonly property bool capsule: Theme.capsuleFor(root)

    // True on a standing bar (left / right edge): the badges stack in a
    // column instead of sitting in a row. Everything else — the zoom, the
    // shifting, the colours — works the same, just along the other axis.
    property bool vertical: false

    signal requested(int workspace)

    readonly property real gap: 6
    readonly property real idleSize: 36

    // Standing bar only: the most length (px) the column may take, worked out by
    // Status_Bar.qml from what the rest of the bar leaves free (-1 = no limit).
    // With 10 workspaces the column is taller than that on most screens, and a
    // bar that cannot fit its middle group drops the whole group, so instead the
    // column shows only the badges around the active workspace: as many as fit
    // (never fewer than 3), and the window follows the active workspace as you
    // switch or scroll.
    property real maxLength: -1
    readonly property real slotLen: root.capsule ? Theme.capDot + Theme.capGap : root.idleSize + Theme.shadowOffset + root.gap
    readonly property int shown: {
        if (!root.vertical || root.maxLength < 0)
            return root.total
            // (Capsule: the active dot is longer than the rest by this much.)
            const extra = root.capsule ? Theme.capDotActive - Theme.capDot : 0
            const fit = Math.floor((root.maxLength - extra + root.gap) / root.slotLen)
            return Math.max(Math.min(3, root.total), Math.min(root.total, fit))
    }
    // 0-based index of the first badge drawn.
    readonly property int first: Math.max(0, Math.min(root.total - root.shown,
                                                      root.active - 1 - Math.floor(root.shown / 2)))

    // How far (px) the workspace number sits below the middle of its
    // box. Digits have no descenders, so with the text centered by its
    // line box they read slightly high; this nudges them down to the
    // visual middle. Raise it to push them further down, 0 to undo.
    readonly property real numberNudge: 2
    readonly property real activeSize: 42

    // Scale factor that makes an idleSize badge read as activeSize.
    readonly property real activeZoom: activeSize / idleSize

    // How far every badge on either side of the active one shifts
    // away from it — half the size difference, i.e. exactly how far
    // the zoomed badge's edge now extends past its original slot.
    readonly property real neighborShift: root.capsule ? 0 : (activeSize - idleSize) / 2

    // The five attribute pastels (Theme.attributeColors: the same five colours in
    // every theme but Monochrome, where they are greys).
    readonly property var activeColors: Theme.attributeColors

    // Flat bar: as wide as the row, activeSize + shadow tall.
    // Standing bar: activeSize wide, as tall as the column.
    // Capsule: a column of dots, with the 4 px of shadow room every pill of a standing bar has.
    height: root.capsule ? (root.vertical ? dotRow.height + Theme.shadowOffset : Theme.capDot)
    : (root.vertical ? row.height : activeSize + Theme.shadowOffset)
    width: root.capsule ? (root.vertical ? Theme.capDot : dotRow.width) : (root.vertical ? activeSize : row.width)
    implicitHeight: height
    implicitWidth: width

    // The badges sit in this box, each placed by hand (x / y on the
    // wrapper below) so the same delegate can be a row or a column.
    Item {
        id: row
        width: root.vertical ? root.idleSize : root.total * root.idleSize + (root.total - 1) * root.gap
        height: root.vertical
        ? root.shown * (root.idleSize + Theme.shadowOffset) + (root.shown - 1) * root.gap
        : root.idleSize + Theme.shadowOffset
        x: root.vertical ? (root.width - width) / 2 : 0
        // Flat bar: the row's bottom sits 6 above the bottom of this
        // item. Nudged up a touch so the badges line up with the other
        // pills in the bar instead of sitting slightly low. (Was 12 —
        // that overshot and left the badges a few px above the rest
        // of the bar; eased back down to close that gap. Nudge this
        // value up/down a couple px if it's still slightly off.)
        y: root.vertical ? 0 : root.height - height - 6

        Repeater {
            id: repeater
            model: root.capsule ? 0 : root.total

            // Fixed-size wrapper: this is always exactly idleSize, so
            // the Row's layout never reflows when the active
            // workspace changes. Any visual growth happens on the
            // Pill inside it via a transform, not a size change.
            delegate: Item {
                id: wrap

                required property int index
                readonly property int number: root.ids[index]
                readonly property bool isActive: root.active === number
                readonly property real shift: number < root.active ? -root.neighborShift
                : number > root.active ? root.neighborShift
                : 0
                // Which way the neighbours get out of the active one's
                // way: sideways on a flat bar, up / down on a standing one.
                readonly property real xOffset: root.vertical ? 0 : shift
                readonly property real yOffset: root.vertical ? shift : 0

                // root.active is a live reflection of the real,
                // external compositor state (see Bar.qml) — it
                // updates the same way whether a switch came from
                // clicking this badge, scrolling, or a Hyprland
                // keybind that never touched this bar at all. So a
                // keyboard-shortcut switch has no local press to
                // react to; instead, whichever badge NEWLY becomes
                // active pulses itself: a quick programmatic
                // press-then-pop, same animation a click gives.
                property bool keyPulse: false

                // Swallows that auto-pulse for a moment right after
                // THIS badge was the one physically clicked — the
                // real MouseArea press/release below already gave it
                // tactile feedback, so there's no need to pulse it a
                // second time once Hyprland confirms the switch a
                // beat later.
                property bool suppressPulse: false

                onIsActiveChanged: {
                    if (isActive && !suppressPulse) {
                        keyPulse = true
                        pulseRelease.restart()
                    }
                }

                Timer {
                    id: pulseRelease
                    interval: 90 // matches Pill's press-down leg, so it lets go right as the push-in finishes
                    onTriggered: wrap.keyPulse = false
                }

                Timer {
                    id: suppressGrace
                    interval: 400 // covers the round-trip to Hyprland and back
                    onTriggered: wrap.suppressPulse = false
                }

                // Place in the drawn window (the whole row unless the column is
                // cut short, see maxLength); badges outside it are not drawn.
                readonly property int slot: index - root.first
                visible: !root.vertical || (slot >= 0 && slot < root.shown)

                width: root.idleSize
                height: root.idleSize + Theme.shadowOffset
                x: root.vertical ? 0 : index * (root.idleSize + root.gap)
                y: root.vertical ? slot * (root.idleSize + Theme.shadowOffset + root.gap) : 0

                Pill {
                    id: badge
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: wrap.xOffset
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: wrap.yOffset

                    cornerRadius: Theme.radiusBadge
                    ringWidth: 8
                    fillColor: wrap.isActive
                    ? root.activeColors[(wrap.number - 1) % root.activeColors.length]
                    : Theme.accentCyan

                    // Always the original 36px box — the "grows to
                    // 42px when selected" look comes entirely from
                    // the scale below, never from resizing this.
                    width: root.idleSize
                    height: root.idleSize + Theme.shadowOffset

                    scale: wrap.isActive ? root.activeZoom : 1.0

                    // Physical press: pushes into its own shadow on
                    // mouse-down, pops back on release. Combines the
                    // real MouseArea press below with the auto-pulse
                    // above, so it looks the same whether a human
                    // clicked it or a keyboard shortcut switched to it.
                    pressed: badgeArea.pressed || wrap.keyPulse

                    // Soft bounce on the way in and out — tuned down
                    // from a full dock-style overshoot so it reads as
                    // smooth rather than springy. Only scale/position
                    // ease; width and height are never animated, so
                    // the badge's real size never morphs.
                    Behavior on scale {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    Behavior on anchors.horizontalCenterOffset {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    Behavior on anchors.verticalCenterOffset {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -Theme.shadowOffset / 2 + root.numberNudge
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        text: wrap.number
                    }
                }

                // Deliberately NOT declared inside the Pill above.
                // Pill's "default property alias content: fill.data"
                // reparents anything declared inside it onto its inset
                // "fill" rectangle, two levels below "badge" — and QML
                // anchors can only target an item's actual parent or
                // sibling, not an arbitrary ancestor. "anchors.fill:
                // badge" from inside the Pill silently fails (logged
                // as "Cannot anchor to an item that isn't a parent or
                // sibling") and leaves the MouseArea sized 0x0 — fully
                // unclickable, not just undersized.
                //
                // Declaring it here instead, as a sibling of "badge"
                // (both children of "wrap"), makes the anchor valid.
                // Centered + offset the same way badge is, sized to
                // activeSize so it fully covers the badge whether
                // it's idle (36px) or scaled up as the active one
                // (42px) — scale is a render transform, not a size
                // change, so a plain anchors.fill: badge here would
                // still only match badge's unscaled 36px box.
                MouseArea {
                    id: badgeArea
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: wrap.xOffset
                    anchors.verticalCenterOffset: wrap.yOffset
                    width: root.activeSize
                    height: root.activeSize + Theme.shadowOffset
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requested(wrap.number)
                    onPressed: wrap.suppressPulse = true
                    onReleased: suppressGrace.restart()
                    onCanceled: suppressGrace.restart()
                }
            }
        }
    }

    // ===== Capsule style: ringed dots =====
    // 12 px of colour inside a 3 px ring (the bar's rim colour), 6 px apart; the active
    // workspace is a wide pill (28 px of colour) that glides open as it takes over.
    // Each workspace keeps its own colour (Theme.capWsColors, from the active theme), idle or active.
    Grid {
        id: dotRow
        visible: root.capsule
        // One row, or (standing bar) one column; dots outside the drawn window are hidden
        // and the grid skips them.
        columns: root.vertical ? 1 : Math.max(1, root.total)
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        spacing: Theme.capGap

        Repeater {
            model: root.capsule ? root.total : 0

            delegate: Item {
                id: dot

                required property int index
                readonly property int number: root.ids[index]
                readonly property bool isActive: root.active === number

                // Which dot of the drawn window this is (a standing bar may show only some).
                readonly property int slot: index - root.first
                visible: !root.vertical || (slot >= 0 && slot < root.shown)

                width: dot.isActive && !root.vertical ? Theme.capDotActive : Theme.capDot
                height: dot.isActive && root.vertical ? Theme.capDotActive : Theme.capDot

                Behavior on width {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
                Behavior on height {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                // Pressed: shrinks a little, like the other buttons dip.
                scale: dotArea.pressed ? 0.88 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: dotArea.pressed ? 70 : 200; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.capRim
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.capDotRing
                    radius: height / 2
                    color: Theme.capWsColors[(dot.number - 1) % Theme.capWsColors.length]
                    antialiasing: true
                }

                // Half the gap each side, so neighbours never overlap and the
                // 18 px dot is an easy target.
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    anchors.margins: -Theme.capGap / 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requested(dot.number)
                }
            }
        }
    }

    // Spans the whole row purely to catch scroll-to-switch; it no
    // longer tracks cursor position, so there's nothing left for
    // hoverEnabled to do. acceptedButtons: NoButton means it never
    // intercepts a press, so clicks fall straight through to each
    // badge's own MouseArea.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        property bool ready: true
        Timer {
            id: cooldown
            interval: 140
            onTriggered: hoverArea.ready = true
        }

        onWheel: wheel => {
            if (!ready)
                return
                const dir = wheel.angleDelta.y < 0 ? 1 : -1
                const i = root.ids.indexOf(root.active)
                let next = -1
                if (i >= 0 && i + dir >= 0 && i + dir < root.total) {
                    next = root.ids[i + dir]
                } else if (dir > 0 && (root.active <= root.count || root.occupied.indexOf(root.active) >= 0)) {
                    // Past the last badge: open the next workspace, but only from a
                    // real one, so scrolling can't pile up empty workspaces.
                    next = root.active + 1
                }
                if (next >= 1) {
                    root.requested(next)
                    ready = false
                    cooldown.restart()
                }
        }
    }
}

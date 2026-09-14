// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R O U S E L                                                        │
// │   horizontal carousel · the centred tile enlarged                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A horizontal strip of tiles with the current one centred and enlarged.
//
// Only `position` animates; each tile derives its offset and scale from its
// distance to it, so a step is one animation and a held arrow key retargets
// it instead of queueing. Delegates are `CarouselTile`s, which read the
// geometry through `parent`.
Item {
    id: root

    property alias model: repeater.model
    property alias delegate: repeater.delegate

    property int current: 0
    readonly property int count: repeater.count

    property int tileWidth: 160
    property int tileHeight: 100
    property real centreScale: 1.25
    property int gap: 12

    // Tiles further than this from the centre are not drawn.
    property real reach: 3

    // The centre tile was clicked, or Enter was pressed.
    signal activated(int index)

    // Fractional while sliding.
    property real position: root.current

    Behavior on position {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    implicitHeight: Math.ceil(root.tileHeight * root.centreScale)
    clip: true

    // Offset of a tile `distance` steps from the centre. The first step spans
    // half the large tile and half a small one; later steps a small one.
    // Linear in between, so sliding is continuous.
    readonly property real firstStep:
        root.tileWidth * root.centreScale / 2 + root.gap + root.tileWidth / 2
    readonly property real stride: root.tileWidth + root.gap

    function offsetOf(distance: real): real {
        const away = Math.abs(distance)
        const offset = away <= 1
            ? away * root.firstStep
            : root.firstStep + (away - 1) * root.stride
        return distance < 0 ? -offset : offset
    }

    function scaleOf(distance: real): real {
        return 1 + (root.centreScale - 1) * Math.max(0, 1 - Math.abs(distance))
    }

    function goTo(index: int): void {
        if (root.count === 0)
            return
        root.current = Math.max(0, Math.min(root.count - 1, index))
    }

    function step(delta: int): void {
        root.goTo(root.current + delta)
    }

    // Clicking the centre tile activates it; any other tile scrolls to it.
    function press(index: int): void {
        if (index === root.current)
            root.activated(index)
        else
            root.goTo(index)
    }

    Repeater { id: repeater }

    // Touchpads send many small deltas; accumulate them to one step per 120.
    WheelHandler {
        property real turned: 0

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
            turned += delta
            while (Math.abs(turned) >= 120) {
                root.step(turned < 0 ? 1 : -1)
                turned -= 120 * Math.sign(turned)
            }
        }
    }
}

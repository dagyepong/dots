import QtQuick

// Scales a whole window's worth of UI without touching any of it.
//
// Everything in this shell is laid out in fixed design pixels. To make a
// window bigger or smaller, the window itself is given `design size x
// factor` real pixels, and its contents go in here: this item hands them
// a coordinate space that is (real size / factor) big and then draws it
// scaled by `factor`. Inside, `parent.width`, anchors.fill and friends
// all work exactly as before — they just see the design-sized room. From
// outside, mapToItem(null, ...) returns real window pixels, since Qt
// folds the scale into the mapping.
//
// Usage — fill the window (or popup) with it and put the UI inside:
//
//   ScaleHost {
//       anchors.fill: parent
//       factor: ShellScale.forScreen(win.screen)
//       Item { ... }
//   }
//
// The window's own size is then design size * factor (see the callers).
Item {
    id: host

    property real factor: 1
    default property alias content: inner.data

    readonly property real f: Math.max(0.1, host.factor)

    Item {
        id: inner
        width: host.width / host.f
        height: host.height / host.f
        scale: host.f
        transformOrigin: Item.TopLeft
    }
}

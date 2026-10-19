import QtQuick
import qs.modules.common

// One mouse-wheel feel for every scrolling list in the shell (the phone's
// notifications, Settings, the launcher's clipboard, the Quick Panel dialogs...).
// Put it next to the Flickable / ListView / GridView (same parent) and point
// `scroller` at it:
//
//   WheelScroll { scroller: list }
//   ListView { id: list ... }
//
// A mouse notch moves `Theme.wheelStep` px (a bit more than Qt's own, which is
// small and differs from one list to the next); a touchpad moves 1:1 with the
// fingers (both through Theme.wheelPx). It only takes wheel events, so clicks and
// drags go through to the list as before. `orientation: Qt.Horizontal` is for a
// row that scrolls sideways. It is hidden / disabled whenever the list is, so a
// list that is faded out or switched off does not keep eating the wheel.
Item {
    id: root

    property Flickable scroller: null
    property real step: Theme.wheelStep
    property int orientation: Qt.Vertical

    anchors.fill: scroller
    z: 50
    visible: root.scroller ? root.scroller.visible : true
    enabled: root.scroller ? root.scroller.enabled : true

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const f = root.scroller
            if (!f)
                return
            const sideways = root.orientation === Qt.Horizontal
            // `step` rescales a mouse notch when an instance asks for a different
            // size; a touchpad (pixelDelta) stays 1:1 with the fingers.
            const px = event.pixelDelta.y !== 0 || (sideways && event.pixelDelta.x !== 0)
            const d = Theme.wheelPx(event, sideways) * (px ? 1 : root.step / Theme.wheelStep)
            if (d === 0)
                return
            // The same range a drag can reach: the list's own top / bottom
            // margin is scroll room too (the phone's notification list keeps
            // a big bottomMargin so its last card can come up clear of the
            // screen edge). Clamping to the bare content left the wheel
            // stopping short while a left-click drag went on further.
            if (sideways) {
                const lo = f.originX - f.leftMargin
                const hi = Math.max(lo, f.originX + f.contentWidth - f.width + f.rightMargin)
                if (hi <= lo)
                    return
                f.cancelFlick()
                f.contentX = Math.max(lo, Math.min(hi, f.contentX - d))
            } else {
                const lo = f.originY - f.topMargin
                const hi = Math.max(lo, f.originY + f.contentHeight - f.height + f.bottomMargin)
                if (hi <= lo)
                    return
                f.cancelFlick()
                f.contentY = Math.max(lo, Math.min(hi, f.contentY - d))
            }
        }
    }
}

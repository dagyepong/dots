import QtQuick
import qs.services

// What a desktop widget does so the shelf can show it as it really looks.
// While Edit Desktop is on, this takes a picture of the widget's own card once
// a second (Item.grabToImage) and files it in EditMode.setPreview(); the
// shelf (EditTray.qml / EditTraySlot.qml) draws that picture. So the shelf
// never has its own idea of what a widget looks like: it is the widget's own
// pixels, a second old at most, and the clock keeps ticking in it.
//
// Put one in each widget window (anywhere at the window's top level):
//
//   EditPreview {
//       widgetId: "clock"          // the same id EditMode.widgetList uses
//       target: card               // the Item to photograph: the whole card
//       pixelRatio: win.uiScale    // design pixels -> picture pixels
//   }
//
// It works on a card that is switched off too (the card is only scaled to
// nothing then, and a grab ignores the grabbed item's own scale), which is
// what lets the shelf show a widget that is not on the desktop yet.
//
// Nothing runs outside Edit Desktop. When the mode ends the picture is dropped.
Timer {
    id: root

    property string widgetId: ""
    property Item target: null
    // Picture pixels per design pixel. The monitor's scale is plenty: the shelf
    // only ever draws the card smaller than that.
    property real pixelRatio: 1

    // The grab result has to stay alive for its url to stay valid.
    property var shot: null

    // Only the shelf's WIDGETS tab draws these pictures (EditTraySlot.qml), so the
    // grab (a GPU render plus a read-back into RAM, once a second per widget) is
    // skipped while the BAR / THEME / PRESETS tab is showing. The last picture is
    // kept, so coming back to WIDGETS shows it at once and it is refreshed within
    // the first tick; it is dropped when Edit Desktop ends, as before.
    readonly property bool wanted: EditMode.active && EditMode.currentTab === "widgets"

    interval: 1000
    repeat: true
    running: root.wanted && root.target !== null && root.widgetId !== ""
    triggeredOnStart: true

    onTriggered: root.snap()

    onRunningChanged: {
        if (!root.running && !EditMode.active) {
            EditMode.setPreview(root.widgetId, "", 0, 0)
            root.shot = null
        }
    }

    function snap() {
        const t = root.target
        if (!t || !t.visible || t.width < 2 || t.height < 2)
            return
        const k = Math.max(1, root.pixelRatio)
        t.grabToImage(function (result) {
            if (!result || !root.running)
                return
            root.shot = result
            EditMode.setPreview(root.widgetId, result.url.toString(), t.width, t.height)
        }, Qt.size(Math.max(1, Math.round(t.width * k)), Math.max(1, Math.round(t.height * k))))
    }
}

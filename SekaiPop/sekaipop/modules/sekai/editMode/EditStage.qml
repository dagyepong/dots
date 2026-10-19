import QtQuick
import qs.services

// Wraps a full-screen desktop window's content so it follows Edit Desktop's
// shrink. Put it directly inside the window and put the content inside it:
//
//   EditStage {
//       id: stage
//       screenObj: win.screen
//       uiScale: win.uiScale
//       ScaleHost { ... }
//   }
//
// Out of edit mode (or on a monitor that is not being edited) it is exactly
// the window: scale 1, no offset. While editing it is the same picture
// scaled down about the top-left corner and moved to where the card is, in
// the same numbers the wallpaper window uses (services/EditMode.qml), so a
// widget stays put on the wallpaper as both shrink.
//
// A window's input `mask` has to follow too: its rectangles are in window
// pixels, so run them through `stage.x` / `stage.y` / `stage.scale`.
//
// The bar and the dock use it too. Their windows are as big as the screen on
// the axis that matters (see Bar.qml / Dock.qml) and never change size, so the
// card is worked out from the SCREEN's size, not the window's:
//
//   refWidth / refHeight   the size the card is worked out from. Defaults to
//                          this window's size (right for a full-screen
//                          window); the dock passes the screen's, because its
//                          window stops short of the screen's edge.
//   originX / originY      where the window's top-left corner is on the screen,
//                          when it is not the screen's own (a dock on the left
//                          edge starts a little in from it).
Item {
    id: root

    // The window's screen (a ShellScreen) and its UI scale.
    property var screenObj: null
    property real uiScale: 1

    readonly property string screenName: root.screenObj ? root.screenObj.name : ""

    property real originX: 0
    property real originY: 0

    property real refWidth: root.width
    property real refHeight: root.height
    // True while this monitor is the one being edited and the mode is on
    // (false once Done has been pressed, while the card is growing back).
    readonly property bool editing: EditMode.active && EditMode.editing(root.screenName)

    width: root.parent ? root.parent.width : 0
    height: root.parent ? root.parent.height : 0

    // The picture is scaled about the stage's own top-left corner, so a window
    // that starts at (originX, originY) on the screen is moved by (scale - 1)
    // times that on top of the card's position.
    x: EditMode.xFor(root.screenName, root.refWidth, root.refHeight, root.uiScale)
       + (root.scale - 1) * root.originX
    y: EditMode.yFor(root.screenName, root.refWidth, root.refHeight, root.uiScale)
       + (root.scale - 1) * root.originY
    scale: EditMode.scaleFor(root.screenName, root.refWidth, root.refHeight, root.uiScale)
    transformOrigin: Item.TopLeft
}

import QtQuick
import qs.modules.common

// The shell's scroll bar: the slim round bar the Quick Panel's notification
// list has (6 wide, the panel's ring gray), only there when there is more than
// fits. Put it INSIDE the list / grid / flickable it belongs to and it needs
// nothing else:
//
//   ListView {
//       id: list
//       ...
//       SekaiScrollBar {}
//   }
//
// It rides in the view's content and follows its visible area, so it works in
// any parent (a Column, a card) and does not take part in the view's layout.
// To use it from outside a view, set `view`.
Rectangle {
    id: bar

    // The Flickable / ListView / GridView it belongs to (default: the one it
    // sits in; a child of a Flickable has the content item as its parent).
    property var view: parent ? parent.parent : null
    // Gap above and below the track, and from the view's right edge.
    property real margin: 8
    property real inset: 2

    // Only a Flickable / ListView / GridView has a visible area; anything else it
    // might find as `view` (before it is parented, or in a plain Item) shows no bar.
    readonly property bool flickable: view !== null && view !== undefined && view.visibleArea !== undefined
    readonly property real ratio: flickable ? view.visibleArea.heightRatio : 1
    readonly property real track: view ? view.height - 2 * margin : 0

    visible: flickable && ratio < 1 && track > 40
    z: 100
    width: 6
    radius: 3
    color: Theme.pSurfaceRing
    antialiasing: true

    x: flickable ? view.contentX + view.width - width - inset : 0
    y: flickable ? view.contentY + margin + view.visibleArea.yPosition * track : 0
    height: Math.max(30, ratio * track)
}

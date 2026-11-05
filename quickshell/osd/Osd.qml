import QtQuick
import Quickshell

// Volume / brightness OSD. One window per style (only the one of the current style is on screen):
//   island    -> right edge, tall pill (as it always was)
//   classic   -> bottom, horizontal pill
//   dash      -> right edge, vertical slider (pill version); in the Attached version the bar itself becomes the OSD
//   side      -> right edge, fused with the frame, volume and brightness one under the other
Scope {
    Variants { model: Quickshell.screens; OsdRight  {} }
    Variants { model: Quickshell.screens; OsdBottom {} }
    Variants { model: Quickshell.screens; OsdSide   {} }
}

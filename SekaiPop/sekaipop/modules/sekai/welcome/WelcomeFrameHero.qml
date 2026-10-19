import QtQuick
import qs.modules.common
import "../../common/functions/WelcomeMath.js" as WM

// The framed picture from the end of the reference video, sharp-cornered and
// with no border or shadow. The picture is the desktop's own wallpaper.
Item {
    id: root

    property real unit: 1
    property real reveal: 0
    // Path of an image file, or "" (then a plain gradient in the theme colours).
    property string wallpaper: ""

    width: 490 * root.unit
    height: 276 * root.unit
    scale: 0.95 + 0.05 * WM.easeOutCubic(root.reveal)
    transformOrigin: Item.Center

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.pal.A }
            GradientStop { position: 1.0; color: Theme.pal.B }
        }
    }

    Image {
        anchors.fill: parent
        visible: root.wallpaper !== ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
        source: root.wallpaper !== "" ? ("file://" + root.wallpaper) : ""
    }
}

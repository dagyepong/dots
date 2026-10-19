import QtQuick
import QtMultimedia

// A video wallpaper: plays `path` silently, looping, cropped to fill. Loaded on
// demand by WallpaperLayer.qml (through a Loader), and kept in a file of its
// own on purpose: it is the only place that needs QtMultimedia
// (`qt6-multimedia` + a backend such as `qt6-multimedia-ffmpeg`), so a system
// without it just fails to load this one component and keeps showing the
// video's first frame, instead of breaking the whole wallpaper layer.
Item {
    id: root

    property string path: ""
    property string screenName: ""
    // Paused while something hides the desktop (or by the layer, for edit mode).
    property bool paused: false
    property bool restartOnPause: false
    // Same interface as MpvpaperWallpaper.qml. Not used here: this player draws inside the
    // wallpaper card, so Edit Desktop only needs it paused (`paused`), and it shrinks with the card.
    property bool hidden: false

    MediaPlayer {
        id: player
        source: root.path !== "" ? ("file://" + root.path) : ""
        loops: MediaPlayer.Infinite
        videoOutput: out
        // No audioOutput: a wallpaper stays silent.
        Component.onCompleted: if (!root.paused) play()
    }

    onPausedChanged: {
        if (paused) {
            player.pause()
        } else {
            if (root.restartOnPause)
                player.position = 0
            player.play()
        }
    }

    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The picture of one entry in the Files stack (DockFilesCard.qml): the real file
// (a picture, in a small outlined frame) while it is one that can be drawn, and
// its type in the icon theme otherwise (a folder, a PDF, a video...). Nothing here
// is made up: a file whose picture can't be read just keeps its type icon.
//
// A video shows one frame of itself, made once by FilesStackService (ffmpegthumbnailer or
// ffmpeg, cached) a moment after the card shows it; until then, or without those tools,
// it keeps its type icon. A small play mark on the frame tells it from a picture.
//
// A thumbnail is decoded by the Image itself at twice the size it is shown (so
// not at the picture's full size), off the UI thread, and Qt's pixmap cache keeps it
// while it is in use; pictures over FilesStackService.thumbMaxBytes are not decoded
// at all.
Item {
    id: root

    property string name: ""
    property url source
    property bool isDir: false
    property real bytes: 0
    property string path: ""
    property var modified: 0
    property real iconSize: 46

    readonly property string suffix: FilesStackService.suffixOf(root.name)
    readonly property bool wantThumb: !root.isDir && FilesStackService.isImage(root.suffix)
        && root.bytes > 0 && root.bytes <= FilesStackService.thumbMaxBytes

    readonly property bool wantVideo: !root.isDir && root.path !== "" && root.bytes > 0
        && FilesStackService.videoThumbsOk && FilesStackService.isVideo(root.suffix)
    readonly property string videoKey: root.wantVideo
        ? FilesStackService.videoThumbKey(root.path, root.bytes, Number(root.modified)) : ""
    readonly property bool videoReady: root.wantVideo && FilesStackService.videoDone[root.videoKey] === true

    readonly property bool thumbReady: (root.wantThumb || root.videoReady) && thumb.status === Image.Ready

    // Ask for the frame while this icon is on screen; drop the ask when it goes (or changes file).
    property string asked: ""

    function syncAsk() {
        if (root.asked !== "" && root.asked !== root.videoKey)
            FilesStackService.cancelVideoThumb(root.asked)
        root.asked = root.videoKey
        if (root.asked !== "")
            FilesStackService.requestVideoThumb(root.asked, root.path)
    }

    onVideoKeyChanged: root.syncAsk()
    Component.onCompleted: root.syncAsk()
    Component.onDestruction: {
        if (root.asked !== "")
            FilesStackService.cancelVideoThumb(root.asked)
    }

    width: root.iconSize
    height: root.iconSize

    Image {
        anchors.fill: parent
        visible: !root.thumbReady
        asynchronous: true
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        source: IconCursorService.path(FilesStackService.iconNameFor(root.isDir, root.suffix, root.name),
                                       root.isDir ? "folder" : "text-x-generic")
    }

    Item {
        anchors.fill: parent
        visible: root.thumbReady

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: Theme.surface
            antialiasing: true
        }

        Image {
            id: thumb
            anchors.fill: parent
            anchors.margins: 3
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            source: root.wantThumb ? root.source
                    : (root.videoReady ? FilesStackService.videoThumbUrl(root.videoKey) : "")
        }

        // A video's frame carries a small play mark in the corner.
        Rectangle {
            visible: root.videoReady
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.max(12, root.iconSize * 0.36)
            height: width
            radius: width / 2
            color: Theme.surface
            border.width: 1.5
            border.color: Theme.line
            antialiasing: true

            MaterialIcon {
                anchors.centerIn: parent
                name: "play_arrow"
                size: parent.width * 0.74
                fill: 1
                color: Theme.ink
            }
        }

        // The outline goes on top, so the picture's square corners sit under it.
        Rectangle {
            anchors.fill: parent
            radius: 7
            color: "transparent"
            border.width: 2
            border.color: Theme.line
            antialiasing: true
        }
    }

    // (The thumbnail Image sits inside the frame, which is only drawn once the picture
    // is Ready; an Image loads whether or not it is drawn, so it starts at once.)
}

import QtQuick
import Quickshell
import Quickshell.Io

// The cover art of the current track, for the end4-style visualizers (the same
// approach as end4-pC's VisualizerWidget.qml): the art is downloaded once into
// ${XDG_CACHE_HOME:-~/.cache}/sekaipop/cover-art/<md5 of the url> (a file:// art is used
// as it is), and ColorQuantizer takes the most saturated colours from it, lifted so
// they read on any wallpaper.
//
//   coverUrl   a local file url, "" until the cover is there (or when `enabled` is off)
//   palette    [c1, c2, c3], or null when there is no cover / too few colours
Item {
    id: root
    visible: false

    property string artUrl: ""
    property bool enabled: false

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/sekaipop/cover-art"
    readonly property string filePath: root.cacheDir + "/" + Qt.md5(root.artUrl)
    property bool downloaded: false

    readonly property string coverUrl: {
        if (!root.enabled || root.artUrl.length === 0) return "";
        if (root.artUrl.startsWith("file://")) return root.artUrl;
        return root.downloaded ? Qt.resolvedUrl(root.filePath) : "";
    }

    readonly property var palette: {
        const list = Array.from(quantizer.colors).sort((a, b) => b.hslSaturation - a.hslSaturation);
        if (list.length < 3) return null;
        const lifted = list.map(c => Qt.hsla(Math.max(c.hslHue, 0), Math.max(c.hslSaturation, 0.45),
            Math.min(Math.max(c.hslLightness, 0.62), 0.85), 1));
        return lifted.slice(0, 3);
    }

    onFilePathChanged: root.fetch()
    onEnabledChanged: root.fetch()

    function fetch() {
        root.downloaded = false;
        if (!root.enabled || root.artUrl.length === 0 || root.artUrl.startsWith("file://")) return;
        downloader.command = ["bash", "-c",
            'mkdir -p "$(dirname "$1")"; [ -s "$1" ] || curl -fsSL --max-time 20 "$2" -o "$1" || rm -f "$1"; [ -s "$1" ]',
            "_", root.filePath, root.artUrl];
        downloader.running = true;
    }

    Process {
        id: downloader
        // exit 0 = the file is there and not empty
        onExited: code => root.downloaded = code === 0
    }

    ColorQuantizer {
        id: quantizer
        source: root.coverUrl
        depth: 2
        rescaleSize: 64
    }
}

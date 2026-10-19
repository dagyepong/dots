import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.sekai.visualizer
import "../../common/functions/PaletteMath.js" as PM

// Reads colours from a picture and hands them to PaletteService.fillFrom():
//
//   kind "wallpaper"  the picture on the screen now (a video wallpaper gives its first
//                     frame; no frame yet = no colours)
//   kind "music"      the cover art of the playing track (VisualizerCover downloads a
//                     web cover once into the cache and reuses the file)
//   kind "random"     nothing to read
//
// It is Quickshell's own ColorQuantizer (median cut on a 64 px copy, eight colours),
// the same one the visualizer's cover uses, so nothing extra is installed. It only
// runs while `active` (the tool is open) and only reads; it never writes the theme.
//
// When the wallpaper changes or the next song starts while the tool is open, the new
// colours arrive on their own (locked swatches stay). Opening the tool does not replace
// a palette you left on the strip (see `primed`).
Item {
    id: root
    visible: false

    property string kind: "wallpaper"
    property bool active: false
    // The MediaSource the cover comes from
    property var media: null

    readonly property string wallpaperUrl: {
        const p = WallpaperService.imagePath
        return p ? "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
    }
    readonly property string imageUrl: {
        if (!root.active)
            return ""
        if (root.kind === "wallpaper")
            return root.wallpaperUrl
        if (root.kind === "music")
            return cover.coverUrl
        return ""
    }

    // Why there is nothing to read, for the tool to say out loud ("" = all good)
    readonly property string problem: {
        if (root.kind === "wallpaper")
            return root.wallpaperUrl === "" ? "No picture for this wallpaper yet" : ""
        if (root.kind === "music") {
            if (!root.media || !root.media.present)
                return "Nothing is playing"
            if (root.media.artUrl === "")
                return "This player gives no cover art"
            return root.imageUrl === "" ? "Fetching the cover..." : ""
        }
        return ""
    }

    // Read what the quantizer has now (also when the same tab is tapped again).
    function push() {
        if (!root.active || root.imageUrl === "")
            return
        const list = []
        const cs = Array.from(quantizer.colors)
        for (let i = 0; i < cs.length; i++)
            list.push(PM.fromRgb(cs[i].r * 255, cs[i].g * 255, cs[i].b * 255))
        if (list.length > 0)
            PaletteService.fillFrom(list, root.kind)
    }

    // The first colours that arrive after the tool opens are NOT poured onto the strip
    // (you may have a favourite loaded, which must survive closing and reopening); the
    // one exception is a tool that has never been used, which starts from the picture.
    // Anything after that (another tab, a new wallpaper, the next song) is a change you
    // asked for or can see happening, so it is.
    property bool primed: false
    onActiveChanged: if (!root.active) root.primed = false

    function arrived() {
        if (!root.active || root.imageUrl === "")
            return
        if (!root.primed) {
            root.primed = true
            if (!PaletteService.fresh)
                return
        }
        root.push()
    }

    VisualizerCover {
        id: cover
        artUrl: root.media ? root.media.artUrl : ""
        enabled: root.active && root.kind === "music"
    }

    ColorQuantizer {
        id: quantizer
        source: root.imageUrl
        depth: 3
        rescaleSize: 64
        onColorsChanged: root.arrived()
    }
}

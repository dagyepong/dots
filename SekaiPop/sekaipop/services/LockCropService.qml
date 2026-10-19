pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/LockCrop.js" as LC

// Which parts of a wallpaper the Calendar lockscreen cuts its picture frames from.
//
// For a picture, scripts/wallpapers/lock-crop.sh prints a tiny copy (96 px on the long
// side, plain-text PPM); modules/common/functions/LockCrop.js turns that into a map of
// the interesting parts. The map is all that is kept (a few thousand numbers per
// picture, the last eight pictures). LockCalendar.qml, on every monitor and in
// LockRing.qml's copy of the picture, asks for the same map and runs the same
// deterministic planner on it, so the picture shown while the lock arrives is the one
// the real lock surface shows.
//
// One picture is read at a time, at low priority, the first time something asks for it
// (the lock surface asks as soon as it exists, long before you lock). Nothing runs
// when the Calendar style is off, and nothing runs in the background after that.
//
// Without ImageMagick (or for a picture it cannot read) the picture is marked failed
// and the lockscreen uses its fixed frame positions instead (LockCrop.fixedPlan).
Singleton {
    id: root

    // path -> { w, h, sal }
    property var grids: ({})
    // path -> true, for a picture that could not be read
    property var failed: ({})
    // Bumped whenever one of the two above changes, so bindings re-run.
    property int revision: 0

    // Paths in the order they were read (oldest first), to forget the old ones.
    property var order: []
    property var queue: []
    // The path being read right now, "" when idle.
    property string reading: ""

    readonly property int keep: 8
    readonly property string script: Directories.script("wallpapers/lock-crop.sh")

    // The map for a picture, or null (not read yet, failed, or no such picture).
    function gridFor(path) {
        root.revision
        return path && root.grids[path] ? root.grids[path] : null
    }

    // True once there is nothing more to wait for: the map is there, or reading failed.
    function settled(path) {
        root.revision
        return !path || !!root.grids[path] || !!root.failed[path]
    }

    function request(path) {
        if (!path || root.grids[path] || root.failed[path] || root.reading === path
            || root.queue.indexOf(path) >= 0)
            return
        root.queue = root.queue.concat([path])
        root.next()
    }

    function next() {
        if (root.reading !== "" || root.queue.length === 0)
            return
        const path = root.queue[0]
        root.queue = root.queue.slice(1)
        root.reading = path
        reader.forPath = path
        reader.exec(["sh", root.script, path])
    }

    function finish(path, text) {
        // A late answer for a read that already timed out.
        if (path === "" || path !== root.reading)
            return
        const img = LC.parsePpm(text)
        if (img) {
            const g = LC.saliency(img)
            const next = Object.assign({}, root.grids)
            next[path] = { w: g.w, h: g.h, sal: g.sal }
            const order = root.order.concat([path])
            while (order.length > root.keep)
                delete next[order.shift()]
            root.order = order
            root.grids = next
        } else {
            const bad = Object.assign({}, root.failed)
            bad[path] = true
            root.failed = bad
        }
        root.reading = ""
        root.revision++
        root.next()
    }

    Process {
        id: reader
        property string forPath: ""
        stdout: StdioCollector {
            onStreamFinished: root.finish(reader.forPath, text)
        }
    }

    // A read that never answers (a stuck disk, a missing sh) must not hold the
    // lockscreen up: it counts as failed.
    Timer {
        running: root.reading !== ""
        interval: 8000
        onTriggered: {
            const path = root.reading
            reader.running = false
            root.finish(path, "")
        }
    }
}

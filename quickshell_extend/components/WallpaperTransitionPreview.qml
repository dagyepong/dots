// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W A L L P A P E R   T R A N S I T I O N   P R E V I E W                │
// │   looping preview of a wallpaper transition                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

import "../theme"
import "../services"

// A looping miniature of an awww transition between the current wallpaper
// and the next one, alternating direction so the loop never cuts.
//
// The incoming picture fills a Shape (`fillItem`) whose outline is the
// revealed region at `progress`. Wipe angle and wave shape approximate
// awww's.
Item {
    id: root

    // A row id from `WallpaperService.transitions`.
    property string effect: "fade"

    implicitWidth: 84
    implicitHeight: 48

    // "random" cycles through these, one per pass.
    readonly property var pool: ["fade", "wipe", "wave", "circle", "outer"]
    property int pass: 0
    readonly property string drawn: root.effect === "random"
        ? root.pool[root.pass % root.pool.length] : root.effect

    // The current wallpaper and the next one in the list.
    readonly property var pictures: {
        const list = WallpaperService.wallpapers
        const at = Math.max(0, list.findIndex(entry => entry.path === WallpaperService.currentWallpaper))
        const first = list[at] ? list[at].path : ""
        const second = list.length > 1 ? list[(at + 1) % list.length].path : ""
        return [first, second]
    }

    // Index of the picture underneath this pass.
    property int showing: 0
    property real progress: 0

    readonly property real reach: Math.hypot(root.width, root.height) / 2

    // ── SHAPES ──────────────────────────────────────────────────────────────

    function frame(): var {
        return [Qt.point(0, 0), Qt.point(root.width, 0),
                Qt.point(root.width, root.height), Qt.point(0, root.height)]
    }

    // The frame clipped to the half-plane nx·x + ny·y <= t.
    function halfPlane(nx: real, ny: real, t: real): var {
        const corners = [[0, 0], [root.width, 0], [root.width, root.height], [0, root.height]]
        const out = []
        for (let i = 0; i < 4; i++) {
            const a = corners[i], b = corners[(i + 1) % 4]
            const da = nx * a[0] + ny * a[1] - t
            const db = nx * b[0] + ny * b[1] - t
            if (da <= 0)
                out.push(Qt.point(a[0], a[1]))
            if ((da <= 0) !== (db <= 0)) {
                const f = da / (da - db)
                out.push(Qt.point(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
            }
        }
        return out
    }

    function circle(radius: real): var {
        const out = []
        const cx = root.width / 2, cy = root.height / 2
        for (let i = 0; i < 36; i++) {
            const angle = i / 36 * 2 * Math.PI
            out.push(Qt.point(cx + radius * Math.cos(angle), cy + radius * Math.sin(angle)))
        }
        return out
    }

    // Left to right, with a sinusoidal edge.
    function wave(p: real): var {
        const amplitude = root.height / 6
        const out = [Qt.point(0, 0)]
        for (let i = 0; i <= 14; i++) {
            const y = root.height * i / 14
            const edge = p * (root.width + 2 * amplitude) - amplitude
                + amplitude * Math.sin(y / root.height * 2 * Math.PI * 1.2)
            out.push(Qt.point(Math.max(0, Math.min(root.width, edge)), y))
        }
        out.push(Qt.point(0, root.height))
        return out
    }

    function outline(): var {
        const p = root.progress
        switch (root.drawn) {
        case "wipe":
            // Top-right to bottom-left.
            return root.halfPlane(-1, 1, -root.width + p * (root.width + root.height))
        case "wave":
            return root.wave(p)
        case "circle":
            return root.circle(p * root.reach)
        default:
            return root.frame()
        }
    }

    // "outer": the frame minus a shrinking circle.
    function hole(): var {
        return root.drawn === "outer" ? root.circle((1 - root.progress) * root.reach) : []
    }

    // ── SCREEN ──────────────────────────────────────────────────────────────

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.surface

        Image {
            anchors.fill: parent
            source: root.pictures[root.showing] !== "" ? `file://${root.pictures[root.showing]}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 168
            sourceSize.height: 96
        }

        // The incoming picture, drawn only through the shape below.
        Item {
            id: arriving

            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Theme.accent
            }

            Image {
                anchors.fill: parent
                source: root.pictures[1 - root.showing] !== "" ? `file://${root.pictures[1 - root.showing]}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 168
                sourceSize.height: 96
            }
        }

        ShaderEffectSource {
            id: arrivingTexture

            sourceItem: arriving
            hideSource: true
            live: true
            visible: false
        }

        Shape {
            anchors.fill: parent
            opacity: root.drawn === "fade" ? root.progress : 1
            // "none" is a hard cut halfway through.
            visible: root.drawn !== "none" || root.progress >= 0.5

            ShapePath {
                strokeWidth: -1
                fillItem: arrivingTexture
                fillRule: ShapePath.OddEvenFill

                PathPolyline { path: root.outline() }
                PathPolyline { path: root.hole() }
            }
        }
    }

    // Hold, transition, hold, then swap roles. The swap is invisible, so the
    // loop is seamless.
    SequentialAnimation {
        running: root.visible
        loops: Animation.Infinite

        PauseAnimation { duration: 700 }
        NumberAnimation {
            target: root
            property: "progress"
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 700 }
        ScriptAction {
            script: {
                root.showing = 1 - root.showing
                root.progress = 0
                root.pass += 1
            }
        }
    }
}

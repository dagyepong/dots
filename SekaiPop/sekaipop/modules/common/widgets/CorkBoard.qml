import QtQuick
import qs.modules.common

// The board the Overview's workspace cards are pinned to: a wooden
// frame around a cork face, like the announcement board outside a
// classroom. Purely a backdrop — Overview.qml sizes and places it and
// puts the cards (and the click-eater) on top.
//
// The cork's speckle is a Canvas, painted once per size with a seeded
// PRNG, so it costs nothing after
// the first paint and looks identical every time the Overview opens.
Item {
    id: root

    property real frameWidth: 12
    property real radius: 20

    // Hard offset shadow, same convention as every other card here —
    // in a warm brown so it reads as "board on a wall".
    Rectangle {
        x: 6
        y: 7
        width: root.width
        height: root.height
        radius: root.radius
        color: ScrapbookTheme.frameShade
        opacity: 0.55
    }

    // ===== wooden frame =====
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        border.width: 3
        border.color: ScrapbookTheme.frameShade
        gradient: Gradient {
            GradientStop { position: 0.0; color: ScrapbookTheme.frameHighlight }
            GradientStop { position: 1.0; color: ScrapbookTheme.frameWood }
        }
    }

    // ===== cork face =====
    Rectangle {
        id: cork
        anchors.fill: parent
        anchors.margins: root.frameWidth
        radius: Math.max(4, root.radius - root.frameWidth * 0.5)
        color: ScrapbookTheme.cork
        border.width: 2
        border.color: ScrapbookTheme.frameShade

        Canvas {
            id: cv
            anchors.fill: parent
            anchors.margins: 8   // keep clear of the rounded corners

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                const w = width, h = height;
                if (w < 16 || h < 16)
                    return;

                // small deterministic PRNG (mulberry32), so the cork is
                // the same every time it repaints
                let seed = 20240;
                function rnd() {
                    seed |= 0;
                    seed = (seed + 0x6D2B79F5) | 0;
                    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
                    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
                    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
                }

                function dot(x, y, r) {
                    ctx.beginPath();
                    ctx.arc(x, y, r, 0, Math.PI * 2);
                    ctx.fill();
                }

                const area = w * h;

                // 1. soft light / dark blotches: the uneven pressed-cork tone
                const blotches = Math.round(area / 2200);
                for (let i = 0; i < blotches; i++) {
                    ctx.globalAlpha = 0.07 + rnd() * 0.09;
                    ctx.fillStyle = rnd() < 0.5 ? ScrapbookTheme.corkLight : ScrapbookTheme.corkDark;
                    dot(rnd() * w, rnd() * h, 3 + rnd() * 8);
                }

                // 2. dark grit
                const grit = Math.round(area / 260);
                ctx.fillStyle = ScrapbookTheme.corkSpeck;
                for (let i = 0; i < grit; i++) {
                    ctx.globalAlpha = 0.22 + rnd() * 0.36;
                    dot(rnd() * w, rnd() * h, 0.6 + rnd() * 1.2);
                }

                // 3. pale flecks
                const flecks = Math.round(area / 520);
                ctx.fillStyle = "#f2d9ab";
                for (let i = 0; i < flecks; i++) {
                    ctx.globalAlpha = 0.25 + rnd() * 0.35;
                    dot(rnd() * w, rnd() * h, 0.6 + rnd() * 1.1);
                }

                // 4. a few pin-holes from notices that came down long ago
                const holes = Math.round(area / 14000);
                ctx.fillStyle = ScrapbookTheme.frameShade;
                for (let i = 0; i < holes; i++) {
                    ctx.globalAlpha = 0.35;
                    dot(rnd() * w, rnd() * h, 1.1);
                }
            }
        }

        // Inner shadow along the top and left, so the cork looks
        // recessed into the frame.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            height: 14
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#553a2210" }
                GradientStop { position: 1.0; color: "#003a2210" }
            }
        }
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 4
            width: 10
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#403a2210" }
                GradientStop { position: 1.0; color: "#003a2210" }
            }
        }
    }

    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    Component.onCompleted: cv.requestPaint()
}

import QtQuick
import qs.modules.common

// A short strip of decorative tape: torn zig-zag ends, a faint
// diagonal stripe, a little transparency so whatever it's pressed
// over still reads through at the edges. Purely decorative — give it
// a rotation and sit it across a photo's corner or a page seam, the
// way real washi tape gets pressed down at an angle.
//
// Smooth edges: the strip is drawn `quality` times larger than it is shown and
// scaled back down, inside a transparent margin of `pad` pixels. A canvas the
// exact size of the tape has hard, one-pixel-stepped edges as soon as the item
// is rotated (the picture is only a flat texture, nothing smooths its outline),
// and its torn ends turn into saw teeth. Drawn big and shown small, every edge
// is filtered, and the margin lets the very outermost pixels fade out too. The
// points of the torn ends are rounded a little (`softness`) for the same reason.
Item {
    id: root

    property color color: ScrapbookTheme.tapeTeal
    property real toothSize: 6
    // Corner rounding of the torn ends, in pixels (0 = sharp points as before).
    property real softness: 1.4
    // How many times larger the strip is drawn than shown.
    property int quality: 4
    // Transparent margin round the strip, so the outer edge can fade.
    readonly property real pad: 2

    width: 84
    height: 26

    Canvas {
        id: cv
        // Bigger than the tape by `pad` on every side, then shrunk back.
        x: -root.pad
        y: -root.pad
        width: (root.width + root.pad * 2) * root.quality
        height: (root.height + root.pad * 2) * root.quality
        scale: 1 / root.quality
        transformOrigin: Item.TopLeft
        smooth: true
        antialiasing: true

        // A polygon with its corners rounded by r (arcTo between the midpoints).
        function roundedPoly(ctx, pts, r) {
            const n = pts.length;
            ctx.beginPath();
            ctx.moveTo((pts[n - 1][0] + pts[0][0]) / 2, (pts[n - 1][1] + pts[0][1]) / 2);
            for (let i = 0; i < n; i++) {
                const p = pts[i], q = pts[(i + 1) % n];
                ctx.arcTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2, r);
            }
            ctx.closePath();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const q = root.quality;
            ctx.scale(q, q);
            ctx.translate(root.pad, root.pad);

            const w = root.width, h = root.height;
            const t = Math.min(root.toothSize, w / 5);
            const teeth = 3;

            // torn edges on the short left/right ends only — the long
            // top/bottom edges of a strip of tape are cut straight
            const pts = [[t, 0], [w - t, 0]];
            for (let i = 0; i < teeth; i++) {
                const y0 = (i / teeth) * h;
                const y1 = ((i + 1) / teeth) * h;
                const mid = (y0 + y1) / 2;
                pts.push([i % 2 === 0 ? w : w - t, mid]);
                pts.push([w - t, y1]);
            }
            pts.push([t, h]);
            for (let i = teeth; i > 0; i--) {
                const y0 = (i / teeth) * h;
                const y1 = ((i - 1) / teeth) * h;
                const mid = (y0 + y1) / 2;
                pts.push([i % 2 === 0 ? 0 : t, mid]);
                pts.push([t, y1]);
            }

            // Every corner is rounded by `softness` (a tiny radius: it only
            // takes the needle points off the torn ends).
            if (root.softness > 0) {
                cv.roundedPoly(ctx, pts, root.softness);
            } else {
                ctx.beginPath();
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (let i = 1; i < pts.length; i++)
                    ctx.lineTo(pts[i][0], pts[i][1]);
                ctx.closePath();
            }

            ctx.globalAlpha = 0.86;
            ctx.fillStyle = root.color;
            ctx.fill();

            // faint diagonal stripes, like printed tape texture
            ctx.save();
            ctx.clip();
            ctx.globalAlpha = 0.16;
            ctx.fillStyle = "#ffffff";
            for (let x = -h; x < w + h; x += 9) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x + h * 0.6, h);
                ctx.lineTo(x + h * 0.6 + 3, h);
                ctx.lineTo(x + 3, 0);
                ctx.closePath();
                ctx.fill();
            }
            ctx.restore();
        }
    }

    onColorChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    onSoftnessChanged: cv.requestPaint()
    onToothSizeChanged: cv.requestPaint()
    Component.onCompleted: cv.requestPaint()
}

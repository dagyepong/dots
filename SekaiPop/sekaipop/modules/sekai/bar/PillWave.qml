import QtQuick
import QtQuick.Effects

// Port of end4-pC's WaveVisualizer.qml (modules/common/widgets): a soft filled wave
// of the bands, blurred so the points are not seen. Used in the media pill
// (VisualizerService.pillStyle = "wave"). `fillAlpha` is end4's 0.15 by default.
Canvas {
    id: root

    property var points: []
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: "#000000"
    property real fillAlpha: 0.15

    property bool paintPending: false

    onPointsChanged: {
        // cava can send frames much faster than needed to redraw and re-blur this canvas:
        // bursts are held to the throttle's rate (~30 fps).
        if (!paintThrottle.running) {
            paintThrottle.start();
            root.requestPaint();
        } else {
            root.paintPending = true;
        }
    }

    onLiveChanged: root.requestPaint()

    Timer {
        id: paintThrottle
        interval: 33
        onTriggered: {
            if (root.paintPending) {
                root.paintPending = false;
                root.requestPaint();
                paintThrottle.start();
            }
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const pts = root.points;
        const maxVal = root.maxVisualizerValue || 1;
        const h = height;
        const w = width;
        const n = pts ? pts.length : 0;
        if (n < 2) return;

        const win = root.smoothing;
        const smooth = [];
        for (let i = 0; i < n; ++i) {
            let sum = 0, count = 0;
            for (let j = -win; j <= win; ++j) {
                const idx = Math.max(0, Math.min(n - 1, i + j));
                sum += pts[idx];
                count++;
            }
            smooth.push(sum / count);
        }
        if (!root.live) smooth.fill(0);

        ctx.beginPath();
        ctx.moveTo(0, h);
        for (let i = 0; i < n; ++i) {
            const x = i * w / (n - 1);
            const y = h - (smooth[i] / maxVal) * h;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.fillAlpha);
        ctx.fill();
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        source: root
        saturation: 0.2
        blurEnabled: true
        blurMax: 7
        blur: 1
    }
}

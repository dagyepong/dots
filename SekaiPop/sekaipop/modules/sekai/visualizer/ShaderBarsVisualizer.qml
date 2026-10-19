import QtQuick

// Port of end4-pC's "bars" style (the BarsVisualizer component inside its
// VisualizerWidget.qml): one rounded Rectangle per 12 px of width, standing on the
// bottom edge, coloured from color1 (loud) to color2 (quiet). Plain QML, no shader.
// `points` is the raw cava bands (ShaderVisualizerEngine.raw), `fullWidth` the width
// the bars are spread over (the card's, in design pixels).
Item {
    id: bars

    property var points: []
    property real fullWidth: width
    property color color1: "#8EE3EF"
    property color color2: "#FF9ECB"

    property real barWidth: 4
    property real barSpacing: 8
    property real maxBarHeight: Math.min(220, height)
    property real maxVisualizerValue: 1000
    property real smoothingDuration: 150

    readonly property int barCount: Math.max(1, Math.floor(bars.fullWidth / (barWidth + barSpacing)))

    readonly property var smoothedPoints: {
        const raw = bars.points
        const count = bars.barCount
        if (!raw || raw.length === 0) return Array(count).fill(0)
        const mapped = new Array(count)
        const rawLenM1 = raw.length - 1

        for (let i = 0; i < count; i++) {
            const progress = i / (count - 1 || 1)
            const relPos = progress * rawLenM1
            const low = Math.floor(relPos)
            const high = Math.ceil(relPos)
            const mix = relPos - low
            mapped[i] = (raw[low] * (1 - mix)) + (raw[high] * (high < raw.length ? mix : 0))
        }

        const smoothed = new Array(count)
        const sW = 0.2
        for (let j = 0; j < count; j++) {
            const p = mapped[Math.max(0, j - 1)]
            const n = mapped[Math.min(count - 1, j + 1)]
            smoothed[j] = (p * sW) + (mapped[j] * (1.0 - 2 * sW)) + (n * sW)
        }
        return smoothed
    }

    property real activityOpacity: 0
    Behavior on activityOpacity {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    Timer {
        id: silenceTimer
        interval: 1000
        onTriggered: bars.activityOpacity = 0
    }

    onPointsChanged: {
        if (points && points.some(p => p > 0)) {
            bars.activityOpacity = 1.0
            silenceTimer.restart()
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: bars.barSpacing
        opacity: bars.activityOpacity

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: bars.barCount

            Rectangle {
                required property int index

                width: bars.barWidth
                property real pointValue: {
                    const v = bars.smoothedPoints[index] ?? 0
                    return Math.max(bars.barWidth, (v / bars.maxVisualizerValue) * bars.maxBarHeight)
                }
                height: pointValue
                topLeftRadius: bars.barWidth / 2
                topRightRadius: bars.barWidth / 2
                anchors.bottom: parent.bottom

                property real intensity: pointValue / bars.maxBarHeight
                color: Qt.rgba(
                    bars.color1.r * intensity + bars.color2.r * (1 - intensity),
                    bars.color1.g * intensity + bars.color2.g * (1 - intensity),
                    bars.color1.b * intensity + bars.color2.b * (1 - intensity),
                    1
                )

                Behavior on height {
                    NumberAnimation { duration: bars.smoothingDuration; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}

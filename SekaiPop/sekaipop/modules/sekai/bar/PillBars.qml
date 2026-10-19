import QtQuick

// Port of end4-pC's bar Visualizer.qml (modules/ii/bar, horizontal only): a few
// round-ended bars centred on the middle line. Used in the media pill
// (VisualizerService.pillStyle = "dots"). Idle: every bar is a dot at 30% opacity.
Item {
    id: root

    property var points: []
    property bool live: false
    property color contentColor: "#000000"
    property int barCount: 5
    property real dotSize: 3
    property real dotSpacing: 3
    property real maxBarHeight: height
    property real maxVisualizerValue: 1000

    implicitWidth: barCount * (dotSize + dotSpacing) - dotSpacing

    Row {
        anchors.centerIn: parent
        spacing: root.dotSpacing

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index

                width: root.dotSize
                property real pointValue: {
                    if (!root.live || !root.points || root.points.length === 0) return root.dotSize
                    const idx = Math.floor(index * root.points.length / root.barCount)
                    const v = root.points[idx] ?? 0
                    return Math.max(root.dotSize, (v / root.maxVisualizerValue) * root.maxBarHeight)
                }
                height: pointValue
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.contentColor
                opacity: root.live ? 0.85 : 0.3

                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
}

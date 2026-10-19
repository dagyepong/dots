import QtQuick
import qs.modules.common

// Tide's picture, drawn by one fragment shader (shaders/visualizer/tide.frag) instead of
// QML Shapes. TideVisualizer.qml still does the motion and calls setSheet / setPins
// every frame; this only forwards the numbers. Needs shaders/visualizer/tide.frag.qsb
// (build it with shaders/visualizer/build.sh; there is no fallback).
ShaderEffect {
    id: root

    property color ink: "#1c2a4a"
    property color shadowColor: Qt.rgba(0, 0, 0, 0.28)
    property color fillBack: "#A5E6A5"
    property color fillMid: "#8EE3EF"
    property color fillFront: "#FF9ECB"
    property real columns: 80
    property real pad: 28
    property real lineW: 3
    property real shadowDrop: 6

    readonly property vector2d resolution: Qt.vector2d(width, height)
    readonly property real ncols: root.columns
    readonly property real padX: root.pad
    readonly property real shadowOff: root.shadowDrop
    readonly property real px: 1 / Math.max(1, Screen.devicePixelRatio)
    readonly property vector4d inkCol: Qt.vector4d(ink.r, ink.g, ink.b, ink.a)
    readonly property vector4d shadowCol: Qt.vector4d(shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a)
    readonly property vector4d fill0: Qt.vector4d(fillBack.r, fillBack.g, fillBack.b, fillBack.a)
    readonly property vector4d fill1: Qt.vector4d(fillMid.r, fillMid.g, fillMid.b, fillMid.a)
    readonly property vector4d fill2: Qt.vector4d(fillFront.r, fillFront.g, fillFront.b, fillFront.a)

    property vector4d pin0; property vector4d pin1; property vector4d pin2
    property vector4d pin3; property vector4d pin4; property vector4d pin5
    property vector4d pin6; property vector4d pin7; property vector4d pin8
    property vector4d pinS0; property vector4d pinS1; property vector4d pinS2

    property vector4d h0_0; property vector4d h0_1; property vector4d h0_2; property vector4d h0_3; property vector4d h0_4; property vector4d h0_5; property vector4d h0_6; property vector4d h0_7; property vector4d h0_8; property vector4d h0_9; property vector4d h0_10; property vector4d h0_11; property vector4d h0_12; property vector4d h0_13; property vector4d h0_14; property vector4d h0_15; property vector4d h0_16; property vector4d h0_17; property vector4d h0_18; property vector4d h0_19; property vector4d h0_20;
    property vector4d h1_0; property vector4d h1_1; property vector4d h1_2; property vector4d h1_3; property vector4d h1_4; property vector4d h1_5; property vector4d h1_6; property vector4d h1_7; property vector4d h1_8; property vector4d h1_9; property vector4d h1_10; property vector4d h1_11; property vector4d h1_12; property vector4d h1_13; property vector4d h1_14; property vector4d h1_15; property vector4d h1_16; property vector4d h1_17; property vector4d h1_18; property vector4d h1_19; property vector4d h1_20;
    property vector4d h2_0; property vector4d h2_1; property vector4d h2_2; property vector4d h2_3; property vector4d h2_4; property vector4d h2_5; property vector4d h2_6; property vector4d h2_7; property vector4d h2_8; property vector4d h2_9; property vector4d h2_10; property vector4d h2_11; property vector4d h2_12; property vector4d h2_13; property vector4d h2_14; property vector4d h2_15; property vector4d h2_16; property vector4d h2_17; property vector4d h2_18; property vector4d h2_19; property vector4d h2_20;

    blending: true
    fragmentShader: Directories.shader("visualizer/tide.frag.qsb")

    // ys: the crest heights (item pixels) of sheet k, columns + 1 of them.
    function setSheet(k, ys) {
        const n = ys.length;
        for (let j = 0; j < 21; j++) {
            const i = j * 4;
            root["h" + k + "_" + j] = Qt.vector4d(
                i < n ? ys[i] : 0, i + 1 < n ? ys[i + 1] : 0,
                i + 2 < n ? ys[i + 2] : 0, i + 3 < n ? ys[i + 3] : 0);
        }
    }

    // marks: [{ x, y, cy, a, s }] as TideVisualizer.rebuild() makes them (nine of them).
    function setPins(marks) {
        const s = [];
        for (let m = 0; m < 9; m++) {
            const k = marks[m];
            root["pin" + m] = k ? Qt.vector4d(k.x, k.y, k.cy, k.a) : Qt.vector4d(0, 0, 0, 0);
            s.push(k ? k.s : 0);
        }
        root.pinS0 = Qt.vector4d(s[0], s[1], s[2], s[3]);
        root.pinS1 = Qt.vector4d(s[4], s[5], s[6], s[7]);
        root.pinS2 = Qt.vector4d(s[8], 0, 0, 0);
    }
}

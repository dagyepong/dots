import QtQuick
import QtQuick.Shapes
import qs.modules.common

// A weather icon drawn as a vector OUTLINE: round-capped strokes, no fill. It
// takes the names OpenMeteo.iconFor gives (via WeatherSource: the Material Symbols
// ones), but it is not drawn with the icon font, so it stays razor sharp at any
// size and has none of the grain the font's glyphs show on some set-ups.
// Anything it does not know is handed to MaterialIcon.
//
//   WeatherGlyph { name: "rainy"; size: 50; color: Theme.accentMint }
//
// Everything is laid out on a 48 x 48 grid and scaled to `size`.
Item {
    id: root

    property string name: "cloud"
    property real size: 24
    property color color: Theme.ink
    // The stroke in real pixels; thin sizes get proportionally more.
    property real stroke: Math.max(1.8, root.size * 0.07)

    width: size
    height: size

    // ---- path pieces (48 grid) ----
    function f(n) { return Math.round(n * 100) / 100 }

    function cloud(dx, dy, k) {
        const P = (x, y) => root.f(dx + x * k) + " " + root.f(dy + y * k)
        return "M" + P(14, 35)
            + " A" + root.f(7 * k) + " " + root.f(7 * k) + " 0 0 1 " + P(14.6, 21.1)
            + " A" + root.f(10 * k) + " " + root.f(10 * k) + " 0 0 1 " + P(33.6, 18.9)
            + " A" + root.f(8 * k) + " " + root.f(8 * k) + " 0 0 1 " + P(34, 35) + " Z "
    }

    function sun(cx, cy, r, ray0, ray1) {
        let s = "M" + root.f(cx - r) + " " + cy + " A" + r + " " + r + " 0 1 1 " + root.f(cx + r) + " " + cy
            + " A" + r + " " + r + " 0 1 1 " + root.f(cx - r) + " " + cy + " Z "
        for (let i = 0; i < 8; i++) {
            const a = i * Math.PI / 4
            s += "M" + root.f(cx + Math.cos(a) * ray0) + " " + root.f(cy + Math.sin(a) * ray0)
               + " L" + root.f(cx + Math.cos(a) * ray1) + " " + root.f(cy + Math.sin(a) * ray1) + " "
        }
        return s
    }

    function moon(dx, dy, k) {
        const P = (x, y) => root.f(dx + x * k) + " " + root.f(dy + y * k)
        return "M" + P(42, 25.58) + " A" + root.f(18 * k) + " " + root.f(18 * k) + " 0 1 1 " + P(22.42, 6)
            + " A" + root.f(14 * k) + " " + root.f(14 * k) + " 0 0 0 " + P(42, 25.58) + " Z "
    }

    readonly property var known: ({
        "sunny": 1, "wb_sunny": 1, "clear_night": 1, "partly_cloudy_day": 1, "partly_cloudy_night": 1,
        "cloud": 1, "foggy": 1, "thunderstorm": 1, "weather_snowy": 1, "rainy": 1
    })

    readonly property string d: {
        switch (root.name) {
        case "sunny":
        case "wb_sunny":
            return root.sun(24, 24, 8.5, 14, 19.5)
        case "clear_night":
            return root.moon(0, 0, 1)
        case "partly_cloudy_day":
            return root.sun(15, 15, 6, 9.5, 13) + root.cloud(12, 14, 0.72)
        case "partly_cloudy_night":
            return root.moon(1, -1, 0.5) + root.cloud(12, 14, 0.72)
        case "cloud":
            return root.cloud(0, 2, 1)
        case "foggy":
            return root.cloud(5, -1, 0.75) + "M11 32 L37 32 M17 39 L31 39 "
        case "thunderstorm":
            return root.cloud(1, -3, 0.9) + "M26 27 L19 35.5 L27 35.5 L21 44 "
        case "weather_snowy":
            return root.cloud(1, -3, 0.9) + "M16 35 L16 35.1 M24 38 L24 38.1 M32 35 L32 35.1 M20 43 L20 43.1 M28 43 L28 43.1 "
        case "rainy":
            return root.cloud(1, -3, 0.9) + "M16 33 L13 41 M25 33 L22 41 M34 33 L31 41 "
        }
        return ""
    }

    // Known names: the vector outline.
    Item {
        visible: root.known[root.name] === 1
        width: 48
        height: 48
        scale: root.size / 48
        transformOrigin: Item.TopLeft

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            layer.enabled: false

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.stroke * 48 / Math.max(1, root.size)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg { path: root.d }
            }
        }
    }

    // Anything else: the icon font.
    MaterialIcon {
        visible: root.known[root.name] !== 1
        anchors.fill: parent
        name: root.name
        size: root.size
        fill: 0
        weight: 500
        color: root.color
    }
}

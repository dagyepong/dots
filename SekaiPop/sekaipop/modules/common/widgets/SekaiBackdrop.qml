import QtQuick
import qs.modules.common

// What the Settings Panel's cards sit on. Not plain white: a pale wash of the
// theme's mint with a halftone fading in from the corners, a few wide
// diagonal bands (cyan, pink, yellow, the same way Project SEKAI's menus
// stripe their backgrounds) and some stars and notes. Everything here is
// decoration; nothing takes the mouse.
//
// `color` is the flat colour of the wash; the page uses it for the soft
// fades at the top and bottom of the scrolling area.
Item {
    id: root

    property color base: Theme.pSurface
    readonly property bool deep: Theme.dark && !Theme.classic
    readonly property color color: Qt.tint(base, Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, deep ? 0.12 : 0.17))

    function mix(c, a) {
        const q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    Rectangle {
        anchors.fill: parent
        color: root.color
    }

    // diagonal bands
    Slant {
        x: -150
        y: -30
        width: 560
        height: 820
        skew: 0.34
        color: root.mix(Theme.accentCyan, root.deep ? 0.12 : 0.16)
    }

    Slant {
        x: 190
        y: -30
        width: 420
        height: 820
        skew: 0.34
        color: root.mix(ScrapbookTheme.accentPink, root.deep ? 0.10 : 0.16)
    }

    Slant {
        x: 330
        y: -30
        width: 340
        height: 820
        skew: 0.34
        color: root.mix(Theme.attributeColors[2], root.deep ? 0.08 : 0.22)
    }

    // halftones
    DotField {
        x: root.width - width
        y: 0
        width: 640
        height: 260
        corner: "tr"
        spacing: 20
        maxRadius: 4.2
        dotColor: root.mix(Theme.colBorder, root.deep ? 0.22 : 0.10)
    }

    DotField {
        x: 0
        y: root.height - height
        width: 420
        height: 300
        corner: "bl"
        spacing: 20
        maxRadius: 4.2
        dotColor: root.mix(Theme.colBorder, root.deep ? 0.22 : 0.10)
    }

    // stars and notes
    MaterialIcon {
        x: 112
        y: 664
        size: 46
        name: "star"
        fill: 1
        rotation: -14
        color: root.mix(Theme.attributeColors[2], 0.9)
    }

    MaterialIcon {
        x: 238
        y: 690
        size: 30
        name: "music_note"
        fill: 1
        rotation: 12
        color: root.mix(ScrapbookTheme.accentPink, 0.8)
    }

    MaterialIcon {
        x: 62
        y: 586
        size: 26
        name: "diamond"
        fill: 1
        rotation: 8
        color: root.mix(Theme.accentCyan, 0.85)
    }
}

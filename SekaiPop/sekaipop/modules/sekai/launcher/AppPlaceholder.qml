import QtQuick
import qs.modules.common

// The icon an app gets in the Apps screen when its .desktop entry has no icon (or names one
// the icon theme does not have, or one that fails to load): a rounded key in one of the five
// card-attribute colours (picked from the app's name, so it is the same colour every time)
// with the app's first letter on it, in the same outline and hard shadow as ShellBadge.qml.
// Three plain shapes and one text: cheap enough to sit in a grid.
//
//   AppPlaceholder { size: 72; name: "Some App" }
//
// The shadow is drawn outside the box (down-right, `size * 0.05`), like ShellBadge.
Item {
    id: root

    property string name: ""
    property real size: 72

    // First letter or digit of the name (so "(Beta) Foo" is still "B"); "?" when there is none.
    readonly property string letter: {
        const m = /[\p{L}\p{N}]/u.exec(root.name || "")
        return m ? m[0].toUpperCase() : "?"
    }

    // Same name, same colour: a small string hash over the five attribute colours.
    readonly property int kind: {
        const s = root.name || ""
        let h = 0
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) | 0
        return Math.abs(h) % Theme.attributeColors.length
    }
    readonly property color ink: Theme.mono ? Theme.colBorder : "#555473"
    readonly property real outline: Math.max(2, root.size * 0.055)

    width: root.size
    height: root.size

    // Hard shadow.
    Rectangle {
        x: Math.round(root.size * 0.05)
        y: Math.round(root.size * 0.05)
        width: root.size
        height: root.size
        radius: root.size * 0.30
        color: root.ink
        antialiasing: true
    }

    // Outline + pastel fill.
    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.30
        color: Theme.attributeColors[root.kind]
        border.width: root.outline
        border.color: root.ink
        antialiasing: true
    }

    // A soft highlight, top-left, so it reads as a raised key.
    Rectangle {
        x: root.size * 0.17
        y: root.size * 0.13
        width: root.size * 0.30
        height: root.size * 0.13
        radius: height / 2
        rotation: -24
        color: Qt.rgba(1, 1, 1, 0.5)
        antialiasing: true
    }

    Text {
        anchors.centerIn: parent
        text: root.letter
        color: "#ffffff"
        style: Text.Outline
        styleColor: root.ink
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.size * 0.5)
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }
}

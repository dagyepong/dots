import QtQuick
import qs.modules.common

// Text as a sticker: a navy outline, a ring in the card's ring colour, the
// colour itself, and the same outline moved down-right as the hard shadow.
// It is the clock widget's StickerDigit, made reusable for the popups. Text
// has no stroke of its own, so each layer is the string drawn several times
// around a small circle; stacked, those copies make a thick edge.
//
//   StickerText { text: "28"; pixelSize: 48; fillColor: Theme.accentMint }
//
// `pop` springs from a little smaller whenever the text changes (not on the
// first value), the same hop the clock's digits do. The item's size is the
// text plus its outline and shadow, so it lays out like any other Item.
Item {
    id: root

    property string text: ""
    property int pixelSize: 40
    property color fillColor: Theme.accentMint
    property color outlineColor: Theme.colBorder
    property color ringColor: Theme.ringWhite
    // How far the navy outline reaches around the glyphs, and the white ring inside it.
    property real outline: Math.max(2.5, root.pixelSize * 0.085)
    // The white ring: the same thin line as a block's (Theme.whiteLine), at every size.
    property real ring: Theme.whiteLine
    property real shadowDx: Math.max(2, root.pixelSize * 0.05)
    property real shadowDy: Math.max(3, root.pixelSize * 0.075)
    property bool popOnChange: true
    property real pop: 1

    // Set once the first text is in, so only later changes hop.
    property bool armed: false
    Component.onCompleted: root.armed = true

    readonly property real edge: root.outline + root.ring + 1

    implicitWidth: Math.ceil(probe.implicitWidth + 2 * root.edge + root.shadowDx)
    implicitHeight: Math.ceil(probe.implicitHeight + 2 * root.edge + root.shadowDy)

    scale: root.pop
    transformOrigin: Item.Center

    onTextChanged: {
        if (root.armed && root.popOnChange)
            popAnim.restart()
    }

    NumberAnimation {
        id: popAnim
        target: root
        property: "pop"
        from: 0.8
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 2.4
    }

    // Only used to measure the string.
    Text {
        id: probe
        visible: false
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }

    // The same string drawn `steps` times around a circle of `radius`.
    component Ring: Item {
        id: ring

        property string value: ""
        property color ink: "#000000"
        property real radius: 4
        property real dx: 0
        property real dy: 0
        property int steps: 8
        property int px: 40

        Repeater {
            model: ring.steps

            Text {
                required property int index

                x: ring.dx + Math.cos(index * 2 * Math.PI / ring.steps) * ring.radius
                y: ring.dy + Math.sin(index * 2 * Math.PI / ring.steps) * ring.radius
                width: ring.width
                height: ring.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: ring.value
                color: ring.ink
                font.family: Theme.fontFamily
                font.pixelSize: ring.px
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    Item {
        id: box
        x: root.edge
        y: root.edge
        width: probe.implicitWidth
        height: probe.implicitHeight

        // hard shadow, outline, ring, colour
        Ring { anchors.fill: parent; value: root.text; px: root.pixelSize; ink: root.outlineColor
               radius: root.outline + root.ring; dx: root.shadowDx; dy: root.shadowDy; steps: 8 }
        Ring { anchors.fill: parent; value: root.text; px: root.pixelSize; ink: root.outlineColor
               radius: root.outline + root.ring; steps: 8 }
        Ring { anchors.fill: parent; value: root.text; px: root.pixelSize; ink: root.ringColor
               radius: root.ring; steps: 8 }
        Ring { anchors.fill: parent; value: root.text; px: root.pixelSize; ink: root.fillColor
               radius: 0; steps: 1 }
    }
}

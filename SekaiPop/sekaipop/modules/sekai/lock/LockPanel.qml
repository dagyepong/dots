import QtQuick
import QtQuick.Effects
import qs.modules.common
import "../../common/functions/LockCrop.js" as LC

// One picture frame of the Calendar lockscreen (LockCalendar.qml): a window of the
// wallpaper, in colour (a little more saturated, so it holds up next to the flat inks)
// or, with `mono`, black and white, under a fine halftone screen, in a plate of the
// shell's block shape (LockPlate.qml: outline, white ring, hard shadow straight down),
// with straight sides and softly rounded corners.
//
// Pure drawing. The caller says which part of the picture to show (`win`, fractions of
// the picture, from LockCrop.js) and how big the picture is decoded (`sourceSize`);
// the frame sizes and places the picture so that window exactly fills it
// (LockCrop.place), flat into a texture the size of the picture area, and the colour
// pass and the rounded-corner mask run on that texture (MultiEffect, no shader file of
// its own).
//
// Every frame of a lockscreen loads the SAME file at the SAME size, so Qt decodes it
// once and the frames share it.
Item {
    id: root

    // The picture: a file:// url, the size it is decoded at, and its width / height.
    property string source: ""
    property size sourceSize: Qt.size(1, 1)
    property real imageAspect: 16 / 9
    // The part to show: { x, y, w, h } as fractions of the picture.
    property var win: ({ x: 0, y: 0, w: 1, h: 1 })

    // Colour (false) or black and white (true). In black and white `tinted` can also
    // wash the picture with `tint`.
    property bool mono: false
    property bool tinted: false
    property color tint: "red"

    // The plate: outline, the ring inside it, the shadow's colour and how far it drops
    // (straight down), and how round the corners are (0 = square).
    property color ink: LockPalette.cBorder
    property color ringColor: LockPalette.paper
    property color shadowColor: LockPalette.cBorder
    property int outline: 4
    property int ringWidth: 3
    property int shadowDy: 12
    property int cornerRadius: 16

    // How strong the halftone screen is (0..1) and how many pixels each of its texels
    // is drawn as (a whole number, so the dots stay crisp).
    property real dotStrength: 0.55
    property int dotScale: 1

    // False while the picture is still being decoded.
    readonly property bool ready: art.status !== Image.Loading

    readonly property real inset: root.outline + root.ringWidth
    readonly property real picW: Math.max(1, root.width - 2 * root.inset)
    readonly property real picH: Math.max(1, root.height - 2 * root.inset)

    readonly property var put: LC.place(root.win, 1000 * root.imageAspect, 1000, root.picW, root.picH)

    LockPlate {
        anchors.fill: parent
        fillColor: root.ringColor
        outlineColor: root.ink
        ringColor: root.ringColor
        shadowColor: root.shadowColor
        outline: root.outline
        ring: root.ringWidth
        shadowDy: root.shadowDy
        cornerRadius: root.cornerRadius
    }

    // The picture area, inside the ring.
    Item {
        x: root.inset
        y: root.inset
        width: root.picW
        height: root.picH

        // The picture and the halftone, flat, the size of the area.
        Item {
            id: flat
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Image {
                id: art
                x: root.put.x
                y: root.put.y
                width: root.put.width
                height: root.put.height
                source: root.source
                sourceSize: root.sourceSize
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Item {
                anchors.fill: parent
                clip: true
                opacity: root.dotStrength

                Item {
                    width: parent.width / root.dotScale
                    height: parent.height / root.dotScale
                    scale: root.dotScale
                    transformOrigin: Item.TopLeft

                    Image {
                        anchors.fill: parent
                        source: "file://" + Directories.asset("images/lock-dots.png")
                        fillMode: Image.Tile
                        smooth: false
                    }
                }
            }
        }

        // The rounded corners, as a mask (the same way the dock rounds its icons).
        Item {
            id: corners
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                anchors.fill: parent
                radius: Math.max(0, root.cornerRadius - root.inset)
                color: "black"
                antialiasing: true
            }
        }

        // ...in colour, a touch more saturated and contrasty so a soft or pale wallpaper
        // still holds its own next to flat ink; or, in `mono`, in black and white (or
        // tinted) with the contrast pushed up so it reads as ink on paper.
        MultiEffect {
            anchors.fill: parent
            source: flat
            maskEnabled: true
            maskSource: corners
            saturation: root.mono ? -1 : 0.25
            contrast: root.mono ? (root.tinted ? 0.45 : 0.35) : 0.12
            brightness: root.mono ? -0.02 : 0
            colorization: root.mono && root.tinted ? 0.9 : 0
            colorizationColor: root.tint
        }
    }
}

import QtQuick
import Quickshell.Widgets
import qs.modules.common

// The Apps screen's wallpaper, drawn the way you picture an LCD: your wallpaper at
// full brightness, seen through a fine pixel mesh (three thin red / green / blue
// stripes to a pixel, dark lines between them), with a little backlight falloff at
// the edges and one soft reflection across the glass.
//
// It is only a picture: it sits UNDER the Apps screen (LauncherFace.qml puts it at
// z -10) and nothing here takes the mouse. It is the shape of the phone's screen
// (the PhoneBody's glass: `inset` in from the face's edge, corners to match), so it
// never reaches the bezel.
//
// Static on purpose. The Apps screen is drawn into one big layer that is only moved
// while nothing in it changes (see LauncherFace's `reveal` note), and a picture that
// never changes keeps it that way: no flicker, no shimmer, no animation here.
//
// Every layer is plain shapes plus one tiny tiled image (assets/images/lcd-mesh.png,
// 24x24 texels = one LCD pixel). No shader, nothing to compile.
ClippingRectangle {
    id: lcd

    // ===== what it is given =====
    // The picture to show, as a file path ("" = no LCD at all, the screen stays
    // plain white).
    property string path: ""
    // Texels per design unit of the face (LauncherFace.renderScale): the picture is
    // decoded at about the size it ends up on the monitor, not at its own size.
    property real renderScale: 1
    // False = nothing is decoded (the Apps screen is not showing), so a 4K
    // wallpaper does not sit in memory while the phone is on another screen.
    property bool active: true

    // ===== things you're likely to change =====
    // How big one LCD pixel is, in design units (the whole face is 654 wide). Bigger
    // reads as a closer, coarser panel; smaller turns to a haze at small sizes.
    property real pitch: 8
    // How much of the screen's own white lies over the picture (0 = the wallpaper as
    // it is, 1 = none of it). Close to 0 on purpose: it is meant to be a screen at full
    // brightness you see the picture straight through. What is written on it (the
    // clock, the date, the app names) sits on its own light chips (LauncherFace.qml),
    // so none of that depends on this. The top is a hair whiter. Raise it for a
    // softer, washed-out screen.
    property real washTop: 0.10
    property real washBody: 0.04
    // How much darker the screen gets right at its edge (the backlight does not
    // reach the corners as well), and how far in that fade reaches (design units).
    property real edgeDark: 0.06
    property real edgeSize: 34
    // The strength of the reflection across the glass (0 = none).
    property real glare: 0.16
    // The mesh as a whole (the tile has its own strength in it): 0 = none, 1 = as drawn.
    property real meshStrength: 1

    // A phone's glass: how far in from the face's edge it starts and how round it is.
    readonly property real inset: Theme.phoneScreenInset
    radius: Math.max(0, Theme.phoneCornerRadius - lcd.inset)
    color: "transparent"

    // Nothing to show: it is not even there (the screen is the plain white one).
    visible: lcd.path !== ""

    // ===== the wallpaper =====
    Image {
        id: wall

        anchors.fill: parent
        source: lcd.active && lcd.path !== "" ? "file://" + lcd.path : ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        // Decoded to the height it is drawn at (the width follows its shape). Some
        // headroom is kept off 8K pictures.
        sourceSize.height: Math.min(2400, Math.ceil(lcd.height * lcd.renderScale))
    }

    // ===== which ink reads over the picture =====
    // The same measuring as the Quick screen's banner (QuickPanelFace.qml,
    // `bannerSampler`): a thumbnail one tenth the size of the screen is read for how
    // bright the picture is under the clock + date (top-left) and under the speed
    // readout (top-right). Darker than 0.30 (linear light) and white ink wins, otherwise
    // the navy one. LauncherFace.qml picks the colour from these two. It reads the
    // picture that is already decoded (`wall`), so it costs no second load, and it only
    // paints when the picture changes. Until it has, the ink stays the navy one.
    property bool darkLeft: false
    property bool darkRight: false

    Canvas {
        id: sampler

        width: 62
        height: 118
        opacity: 0
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        // The picture, once it is in (and empty before / after, like the banner's).
        readonly property url src: wall.status === Image.Ready ? wall.source : ""

        onSrcChanged: {
            if (src.toString() !== "")
                requestPaint()
        }

        // Average brightness (0 black .. 1 white, in linear light) of a rectangle of
        // the thumbnail.
        function brightness(ctx, x, y, w, h) {
            const d = ctx.getImageData(x, y, w, h).data
            let sum = 0
            let n = 0
            for (let i = 0; i < d.length; i += 4) {
                if (d[i + 3] === 0)
                    continue
                const r = Math.pow(d[i] / 255, 2.2)
                const g = Math.pow(d[i + 1] / 255, 2.2)
                const b = Math.pow(d[i + 2] / 255, 2.2)
                sum += 0.2126 * r + 0.7152 * g + 0.0722 * b
                n++
            }
            return n > 0 ? sum / n : 1
        }

        onPaint: {
            if (src.toString() === "")
                return
            const iw = wall.implicitWidth
            const ih = wall.implicitHeight
            if (iw <= 0 || ih <= 0)
                return

            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Drawn the way the screen draws it (PreserveAspectCrop): scaled to cover
            // the thumbnail, centred, the overflow cut off.
            let dw = width
            let dh = width * ih / iw
            if (dh < height) {
                dh = height
                dw = height * iw / ih
            }
            ctx.drawImage(wall, (width - dw) / 2, (height - dh) / 2, dw, dh)

            // Under the clock + date: face x 67..190, y 36..90 = thumbnail x 5..17, y 2..7.
            // Under the speed readout: face x 437..587, y 38..90 = thumbnail x 42..57, y 2..7.
            lcd.darkLeft = brightness(ctx, 5, 2, 12, 5) < 0.30
            lcd.darkRight = brightness(ctx, 42, 2, 15, 5) < 0.30
        }
    }

    // ===== the wash: the screen's own white over the picture =====
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.pSurface, lcd.washTop) }
            GradientStop { position: 0.3; color: Qt.alpha(Theme.pSurface, lcd.washBody) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.pSurface, lcd.washBody) }
        }
    }

    // ===== backlight falloff at the edges =====
    // Four fades from the edge inward; where two meet in a corner it is a little darker,
    // like a real panel's corners.
    readonly property color edgeTint: Qt.rgba(0.24, 0.24, 0.39, lcd.edgeDark)
    readonly property color edgeClear: Qt.rgba(0.24, 0.24, 0.39, 0)

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: lcd.edgeSize
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: lcd.edgeTint }
            GradientStop { position: 1.0; color: lcd.edgeClear }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: lcd.edgeSize
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: lcd.edgeClear }
            GradientStop { position: 1.0; color: lcd.edgeTint }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: lcd.edgeSize
        gradient: Gradient {
            GradientStop { position: 0.0; color: lcd.edgeTint }
            GradientStop { position: 1.0; color: lcd.edgeClear }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: lcd.edgeSize
        gradient: Gradient {
            GradientStop { position: 0.0; color: lcd.edgeClear }
            GradientStop { position: 1.0; color: lcd.edgeTint }
        }
    }

    // ===== the pixel mesh =====
    // The tile is 24 texels = one LCD pixel (red, green, blue stripes, dark lines
    // between them and under them). It is tiled in an item that is `pitch / 24`
    // times the size it shows at and scaled down to it, so a pixel comes out
    // `pitch` design units wide whatever the screen's scale; `mipmap` lets the
    // phone's layer shrink it onto the monitor without it turning to noise.
    Item {
        id: meshScaler

        readonly property real k: lcd.pitch / 24

        width: lcd.width / meshScaler.k
        height: lcd.height / meshScaler.k
        scale: meshScaler.k
        transformOrigin: Item.TopLeft
        opacity: lcd.meshStrength
        visible: lcd.meshStrength > 0.001

        Image {
            anchors.fill: parent
            source: "file://" + Directories.asset("images/lcd-mesh.png")
            fillMode: Image.Tile
            smooth: true
            mipmap: true
        }
    }

    // ===== the reflection =====
    // One soft band of light across the upper part of the glass, a little off
    // level. Wide and faint: it is meant to be felt rather than seen.
    Rectangle {
        visible: lcd.glare > 0.001
        width: lcd.width * 2.2
        height: 190
        x: lcd.width / 2 - width / 2
        y: lcd.height * 0.2 - height / 2
        rotation: -20
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, lcd.glare) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}

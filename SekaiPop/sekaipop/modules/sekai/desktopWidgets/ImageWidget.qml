import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.editMode
import "../../common/functions/ImageMath.js" as IM

// One Custom Image: a picture of your own on the desktop, under your windows, over
// the wallpaper. There is one of these per entry in services/ImageService.qml (a
// Variants in shell.qml hands each its id), and you can have as many as you like.
//
//   Moving it     in Edit Desktop (right-click the desktop) it is always draggable,
//                 by the shield in EditChrome.qml. On the normal desktop only while
//                 "Lock all" (a tile on the Edit Desktop shelf) is off.
//   Editing it    in Edit Desktop, click it: it is "selected". Four diamonds appear
//                 on its corners (drag one to resize) and a panel opens beside it
//                 (ImageInspector.qml): picture, mode, rounding, opacity, border,
//                 shadow, aspect ratio. A right-click removes it. The shelf's
//                 "Image" tile adds another one.
//   Filling it    the shelf's "Image" tile puts an EMPTY frame on the desktop at once
//                 (nothing is asked first). It is a drop target: drag a picture (or
//                 several) from the file manager onto it. The first goes into the frame
//                 (a frame that has a picture already takes the new one in its place);
//                 the rest become frames of their own beside it. Dropping is the only way
//                 in: there is no file chooser. A drop that is not a picture says so on
//                 the frame.
//   Resizing      keeps the picture's aspect ratio (the panel's LOCK RATIO). Holding
//                 Shift while you drag a corner does the opposite for that drag.
//
// The three modes (what the frame, the thing you drag, does to the picture):
//
//   FIT    the whole picture, its own shape; the border, rounding and shadow follow
//          the picture and not the frame, so there are never empty bars inside them
//   FILL   the picture covers the whole frame, centred, the overflow cut off
//   CROP   the same, but you choose the part: while it is selected, drag the
//          picture to pan it and scroll to zoom. (The grip at the frame's top-left
//          corner moves the frame meanwhile, since a drag on the picture pans it.)
//
// PINNED (right-click a picture on the desktop): the picture is moved up to the Overlay
// layer, so it sits IN FRONT of windows and of fullscreen games (the other desktop widgets
// live under them), and every click passes through it to whatever is below. Desktop Focus
// Mode and Game Mode do not hide it (that is the point of pinning). Unpin it from the
// desktop menu (right-click the bare desktop -> Unpin images), from its panel in Edit
// Desktop (PIN ON TOP), or `ipc call image unpin`. Edit Desktop shows it as a normal
// frame while you edit.
//
// A GIF (or animated WebP / APNG) plays while the picture is on screen and is
// paused while it is hidden (Focus Mode, Game Mode, switched off).
//
// How the moving works: exactly like UserCardWidget.qml. A transparent layer window
// on WlrLayer.Background with the frame as an Item inside it; while nothing needs
// the whole screen the window is just the frame plus some room for the shadow, and
// its input `mask` is only the frame (and, while editing, the panel), so every click
// anywhere else passes through to what is underneath. It never takes keyboard focus.
//
// Bind a key / call it from a script:
//   qs -c sekaipop ipc call image toggle          (show / hide all of them)
//   qs -c sekaipop ipc call image addPath <file>  (add a picture you already have)
//   qs -c sekaipop ipc call image resetPosition   (if one ever ends up off-screen)
//   qs -c sekaipop ipc call image pin / unpin     (pin every picture / take them all back)

PanelWindow {
    id: win

    // The entry this window is for (Variants' modelData).
    required property string modelData
    readonly property string imageId: win.modelData
    readonly property string widgetId: "image:" + win.modelData
    readonly property var rec: ImageService.byId[win.modelData] ?? null

    // Plain values out of the record, so the properties below that read them only
    // change when the value does (a slider drag on another picture changes nothing here).
    readonly property real recX: win.rec ? win.rec.x : -1
    readonly property real recY: win.rec ? win.rec.y : -1
    readonly property real recW: win.rec ? win.rec.w : 0
    readonly property real recH: win.rec ? win.rec.h : 0
    readonly property real recScale: win.rec ? win.rec.scale : 0
    readonly property real natW: win.rec ? win.rec.nw : 0
    readonly property real natH: win.rec ? win.rec.nh : 0
    // The size the picture is drawn with the ratio of. Normally the record's (learned once);
    // right after a picture is dropped or picked into a frame the record has not learned it
    // yet, and then the loaded picture's own size is used, so it is never squeezed into the
    // old (empty) frame's shape, not even for the moment before the frame is re-framed.
    readonly property real picW: win.natW > 0 ? win.natW
        : (win.ready && win.activePic.implicitWidth > 0 && win.activePic.implicitHeight > 0 ? win.activePic.implicitWidth : 0)
    readonly property real picH: win.natH > 0 ? win.natH
        : (win.ready && win.activePic.implicitWidth > 0 && win.activePic.implicitHeight > 0 ? win.activePic.implicitHeight : 0)
    readonly property bool reframing: win.rec ? win.rec.reframe : false
    readonly property string mode: win.rec ? win.rec.mode : "fit"
    readonly property bool cropMode: win.mode === "crop"

    // Pinned: in front of everything and click-through. Not while Edit Desktop is open,
    // so the picture can still be selected and moved there.
    readonly property bool pinned: win.rec ? win.rec.pinned : false
    readonly property bool onTop: win.pinned && !win.empty && !EditMode.active

    readonly property string wantedScreen: win.rec ? win.rec.screen : ""
    screen: Quickshell.screens.find(s => s.name === win.wantedScreen) ?? Quickshell.screens[0]

    // This monitor's scale (scale.json / services/ShellScale.qml). The frame is drawn
    // in design pixels inside a ScaleHost, so `roomW` x `roomH` is the screen as the
    // frame sees it (real size / scale); positions and sizes are kept in that space.
    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real fullW: win.screen ? win.screen.width : 0
    readonly property real fullH: win.screen ? win.screen.height : 0
    readonly property real roomW: win.fullW / win.uiScale
    readonly property real roomH: win.fullH / win.uiScale
    // Texture pixels per design pixel.
    readonly property real texel: win.uiScale * (win.screen ? win.screen.devicePixelRatio : 1)

    // ===== a small window while nothing needs the whole screen =====
    // (Same reasoning as UserCardWidget.qml: a full-screen layer makes the compositor
    // blend the whole screen on every frame the picture draws, which for a GIF is all
    // the time.) Only Edit Desktop, a resize and dragging on an unlocked desktop get
    // the whole screen.
    // (A pinned picture is click-through, so it never needs the whole screen to be dragged
    // on: a full-screen Overlay window over a game would be blended on every frame.)
    readonly property bool compact: !EditMode.active && !win.sizing && EditMode.screenName === ""
        && EditMode.compactWindows && (!EditMode.desktopDragAllowed || win.onTop) && win.fullW > 0 && win.placed
    readonly property real shadowReach: win.rec && win.rec.shadowOn ? 110 : 0
    readonly property real boxPad: Math.ceil((0.16 * Math.max(card.width, card.height) + 24 + win.shadowReach) * win.uiScale)
    readonly property real boxX: win.compact ? Math.max(0, Math.floor(card.x * win.uiScale - win.boxPad)) : 0
    readonly property real boxY: win.compact ? Math.max(0, Math.floor(card.y * win.uiScale - win.boxPad)) : 0
    readonly property real boxW: Math.max(1, Math.min(win.fullW,
        Math.ceil((card.x + card.width) * win.uiScale + win.boxPad)) - win.boxX)
    readonly property real boxH: Math.max(1, Math.min(win.fullH,
        Math.ceil((card.y + card.height) * win.uiScale + win.boxPad)) - win.boxY)

    // ===== on / off =====
    // Pops in with a little overshoot, swallowed on the way out (the clock's language).
    // Two fixed animations started from the flag, not one Behavior.
    // Desktop Focus Mode: `gate.show` is false while an application is on this
    // monitor's workspace, so `want` goes false and the swallow + unmap below hide it.
    FocusGate {
        id: gate
        widgetId: "image"
        screenName: win.screen ? win.screen.name : ""
    }

    readonly property bool switchedOn: ImageService.shown && ImageService.loaded && win.rec !== null
    // A pinned picture ignores the gate: Focus Mode / Game Mode hide the desktop's widgets
    // behind your windows, and a pinned one is meant to stay in front of them.
    readonly property bool want: win.switchedOn && (gate.show || win.onTop)
    property real reveal: 0

    // Off while the saved state is read back, so a reload doesn't replay the pop.
    // A picture made after that (you just added it) is armed at once and pops in.
    property bool armed: false

    // Stays false until the frame has been put on its saved spot, and keeps it drawn
    // at size 0 until then (see UserCardWidget.qml: a frame placed in a window that has
    // not been told its real size yet would sit at the top-left corner for a moment).
    property bool placed: false

    onWantChanged: {
        if (!win.armed) {
            popIn.stop()
            swallow.stop()
            win.reveal = win.want ? 1 : 0
        } else if (win.want) {
            swallow.stop()
            popIn.restart()
        } else {
            popIn.stop()
            swallow.restart()
        }
    }

    NumberAnimation {
        id: popIn
        target: win
        property: "reveal"
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.9
    }

    NumberAnimation {
        id: swallow
        target: win
        property: "reveal"
        to: 0
        duration: 300
        easing.type: Easing.InCubic
    }

    Timer {
        interval: 800
        running: ImageService.loaded && !win.armed
        onTriggered: win.armed = true
    }

    // Pinned a moment ago (not the saved state coming back at start-up): the note shows.
    onPinnedChanged: {
        if (win.pinned && win.armed)
            pinTimer.restart()
    }

    // `live`: on, or still being swallowed. A GIF plays only then.
    readonly property bool live: win.want || win.reveal > 0.001

    // Not mapped while it is off.
    visible: win.rec !== null && ImageService.loaded && (win.live || EditMode.active)

    // Always BELOW the dock (see UserCardWidget.qml); up a layer while it is edited or
    // moved, so the one edited last is in front of the other widgets.
    // Pinned: the Overlay layer, above windows and fullscreen games (Hyprland draws it over
    // a fullscreen window too).
    WlrLayershell.layer: win.onTop ? WlrLayer.Overlay
        : ((chrome.raised || WallpaperService.restacking) ? WlrLayer.Bottom : WlrLayer.Background)
    WlrLayershell.namespace: "sekaipop-image"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        left: true
        right: !win.compact
        bottom: !win.compact
    }

    margins {
        left: win.boxX
        top: win.boxY
    }

    implicitWidth: win.boxW
    implicitHeight: win.boxH

    // Only the frame (and the panel while one is open) takes clicks; the rest of the
    // screen falls through. In real window pixels. A pinned picture takes none at all
    // (a 1 px corner of the window's empty margin stands in for "nothing": an empty
    // region would mean "the whole window" to Qt).
    mask: Region {
        item: cardMask

        Region {
            item: inspMask
        }
    }

    Item {
        id: cardMask
        // Edit Desktop widens it: the outline, the tag, the corner diamonds and the
        // move grip all sit outside the frame.
        readonly property real m: stage.editing ? 44 : 0
        readonly property real k: win.uiScale * stage.scale
        readonly property real x1: shifter.x + stage.x + (card.x + card.width + m) * k
        readonly property real y1: shifter.y + stage.y + (card.y + card.height + m) * k
        readonly property bool none: !win.live || win.onTop
        x: cardMask.none ? 0 : Math.max(0, Math.round(shifter.x + stage.x + (card.x - m) * k))
        y: cardMask.none ? 0 : Math.max(0, Math.round(shifter.y + stage.y + (card.y - m) * k))
        width: cardMask.none ? 1 : Math.max(0, Math.ceil(x1) - x)
        height: cardMask.none ? 1 : Math.max(0, Math.ceil(y1) - y)
    }

    Item {
        id: inspMask
        x: shifter.x + insp.x
        y: shifter.y + insp.y
        width: insp.visible ? Math.ceil(insp.width * win.uiScale) : 0
        height: insp.visible ? Math.ceil(insp.height * win.uiScale) : 0
    }

    // ===== where the picture is, and what it is drawn as =====
    function place(force) {
        if (win.roomW <= 0 || win.roomH <= 0 || win.recW <= 0 || win.recH <= 0)
            return
        // Not before the saved spot has been read, and not while the window is still
        // smaller than the frame (the clamp below would put it at 0, 0).
        if (!force && (!ImageService.loaded || win.roomW < card.width || win.roomH < card.height))
            return
        let x = win.recX
        let y = win.recY
        if (x < 0 || y < 0) {
            // Never placed: the middle of the screen, each new one a step down-right.
            const n = Math.max(0, ImageService.ids.indexOf(win.imageId)) % 8
            x = (win.roomW - card.width) / 2 + n * 32
            y = (win.roomH - card.height) / 2 + n * 32
        } else if (win.recScale > 0 && win.uiScale > 0) {
            // Saved at another shell scale: same spot on the screen, not the same
            // design pixels (the frame keeps its top-left corner).
            const k = win.recScale / win.uiScale
            x *= k
            y *= k
        }
        const p = IM.keepOn(x, y, card.width, card.height, win.roomW, win.roomH)
        card.x = p.x
        card.y = p.y
        win.placed = true
    }

    // After a reload the window, the monitor list and scale.json all settle over a few
    // frames; place again once they have, so the frame always ends on its saved spot
    // (never while it is being dragged or resized).
    Timer {
        id: settle
        interval: 300
        onTriggered: {
            // A position saved before the scale was kept with it: it was in design pixels
            // of the scale in use now, so keep that from here on.
            if (ImageService.loaded && win.rec && win.recX >= 0 && win.recScale <= 0 && !dragArea.drag.active && !win.sizing)
                ImageService.update(win.imageId, { scale: win.uiScale })
            if (!chrome.dragging && !dragArea.drag.active && !win.sizing)
                win.place(!win.placed && ImageService.loaded)
        }
    }

    onWidthChanged: { win.place(); settle.restart() }
    onHeightChanged: { win.place(); settle.restart() }
    onUiScaleChanged: { win.place(); settle.restart() }
    onScreenChanged: { win.place(); settle.restart() }
    onVisibleChanged: settle.restart()

    Component.onCompleted: {
        // Made at start-up: simply there. Made later (just added): it pops in.
        win.armed = ImageService.settled
        win.reveal = (win.want && !ImageService.settled) ? 1 : 0
        win.place()
        if (ImageService.settled && win.want)
            popIn.restart()
    }

    // The saved spot or size changed under us (a position written by the service, the
    // picture's size learned, a reset): put the frame there, unless the user is
    // moving it right now. Several of them arrive one after the other, so wait a beat.
    onRecXChanged: follow.restart()
    onRecYChanged: follow.restart()
    onRecWChanged: follow.restart()
    onRecHChanged: follow.restart()
    onRecScaleChanged: follow.restart()

    Timer {
        id: follow
        interval: 16
        onTriggered: {
            if (chrome.dragging || dragArea.drag.active || win.sizing || grip.dragging)
                return
            win.place()
        }
    }

    // ===== the numbers that draw it =====
    // Live while a resize or a crop-pan is going on (nothing is saved until you let go),
    // the saved ones otherwise.
    property bool sizing: false
    property real liveW: 0
    property real liveH: 0
    property bool panning: false
    property real livePanX: 0
    property real livePanY: 0

    readonly property real frameW: win.sizing ? win.liveW : win.recW
    readonly property real frameH: win.sizing ? win.liveH : win.recH
    readonly property real panX: win.panning ? win.livePanX : (win.rec ? win.rec.panX : 0)
    readonly property real panY: win.panning ? win.livePanY : (win.rec ? win.rec.panY : 0)
    readonly property real zoom: win.rec ? win.rec.zoom : 1

    readonly property var shapeR: IM.shapeRect(win.frameW, win.frameH, win.picW, win.picH, win.mode)
    readonly property real radiusPx: win.rec ? win.rec.roundness * Math.min(win.shapeR.w, win.shapeR.h) / 2 : 0

    // The border (stroke) is drawn on the shape's outer edge, over the picture. The picture
    // itself is kept INSIDE it: pulled in from the shape's edge by the stroke's width less a
    // pixel (that pixel runs under the stroke, so no gap shows between them). Without this
    // the picture's own edge (its antialiased rounded mask, or a half-covered pixel of a
    // plain cut) sticks out past the stroke's outer edge as a thin fringe of the picture.
    readonly property real borderPx: win.rec && win.rec.borderOn
        ? Math.min(win.rec.borderWidth, Math.min(win.shapeR.w, win.shapeR.h) / 2) : 0
    readonly property real picPad: win.borderPx > 1 ? win.borderPx - 1 : 0
    readonly property real innerW: Math.max(1, win.shapeR.w - win.picPad * 2)
    readonly property real innerH: Math.max(1, win.shapeR.h - win.picPad * 2)
    readonly property real innerRadius: Math.max(0, Math.min(win.radiusPx - win.picPad, Math.min(win.innerW, win.innerH) / 2))
    readonly property bool round: win.innerRadius > 0.5

    // Where the picture is stretched to, inside that inner area. FIT covers the inner area
    // instead of fitting it: the same picture (the shape already has its ratio) a hair
    // larger, with the overflow cut off, so a thick border never squeezes it out of shape.
    readonly property var drawR: IM.drawRect(win.innerW, win.innerH, win.picW, win.picH,
                                            win.mode === "fit" ? "fill" : win.mode, win.zoom, win.panX, win.panY)
    readonly property real picOpacity: win.rec ? win.rec.opacity : 1

    readonly property color borderCol: {
        const c = win.rec ? win.rec.borderColor : "white"
        return c === "navy" ? Theme.colBorder
            : c === "mint" ? Theme.accentMint
            : c === "cyan" ? Theme.accentCyan
            : c === "pink" ? Theme.irisColorPink
            : c === "black" ? "#000000"
            : "#ffffff"
    }

    // ===== the picture file =====
    readonly property string path: win.rec ? win.rec.path : ""
    readonly property url srcUrl: win.path !== "" ? PanelImages.urlFor(win.path) : ""
    readonly property bool animated: /\.(gif|apng|webp)$/i.test(win.path)

    readonly property var activePic: win.animated ? anim : still
    readonly property bool ready: win.activePic.status === Image.Ready
    // A frame with no picture yet: a drop target (below), not a broken picture.
    readonly property bool empty: win.rec !== null && win.path === ""
    readonly property bool failed: win.path !== "" && win.activePic.status === Image.Error

    // A still picture is decoded no bigger than the frame needs here (plus the zoom),
    // so a 12000-pixel photo doesn't sit in memory at full size; the first decode, before
    // its size is known, is capped at 4096 for the same reason. (An animated picture
    // is left at its own size: its frames are normally small.)
    readonly property int decodeSide: win.natW > 0
        ? IM.decodeSide(win.recW, win.recH, win.texel, win.cropMode ? win.zoom : 1, 4096) : 4096
    readonly property size stillDecode: Qt.size(win.decodeSide, win.decodeSide)

    // Tells the service how big the picture really is (once: a new one gets its first
    // frame, a replaced one the new ratio), and gives a picture that can't be loaded a
    // frame anyway, so it can still be seen, replaced or deleted.
    function report() {
        if (!win.rec)
            return
        const p = win.activePic
        // Only the picture of the CURRENT file counts (a replaced one is still showing the
        // old file for a moment).
        if (p.status === Image.Ready && String(p.source) !== String(win.srcUrl))
            return
        if (p.status === Image.Ready && p.implicitWidth > 0 && p.implicitHeight > 0) {
            if (win.natW <= 0 || win.rec.reframe)
                ImageService.noteSize(win.imageId, p.implicitWidth, p.implicitHeight, win.roomW, win.roomH)
        } else if (p.status === Image.Error && win.recW <= 0) {
            ImageService.update(win.imageId, { w: 240, h: 240 }, true)
        }
    }

    // A dropped or picked picture is told to the service on the picture's loading status, but
    // that alone is not enough: the same file put into a frame again does not change its
    // status, and the size can show up a moment after "Ready". So the record being reset for
    // a new picture (nw -> 0, reframe on) and the picture's own size changing ask again.
    // Deferred, so that the picture's source has been updated by then.
    onNatWChanged: Qt.callLater(win.report)
    onReframingChanged: Qt.callLater(win.report)

    // ===== Edit Desktop =====
    Item {
        id: shifter
        x: -win.boxX
        y: -win.boxY
        width: win.fullW
        height: win.fullH

    // Edit Desktop shrinks every desktop window into the same card with the same
    // transform (EditStage.qml). Out of edit mode this is a no-op: scale 1, no offset.
    EditStage {
        id: stage
        screenObj: win.screen
        uiScale: win.uiScale

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Item {
                id: card

                width: win.frameW
                height: win.frameH

                scale: Math.max(0, win.reveal) * ((win.placed && win.recW > 0) ? 1 : 0)
                transformOrigin: Item.Center

                // A new size (a different monitor or scale) keeps the frame on screen;
                // not while it is being dragged or resized, then they own the position.
                onWidthChanged: {
                    if (!chrome.dragging && !dragArea.drag.active && !win.sizing)
                        win.place()
                }
                onHeightChanged: {
                    if (!chrome.dragging && !dragArea.drag.active && !win.sizing)
                        win.place()
                }

                // ----- shadow -----
                // Soft: the shape's silhouette, blurred. It sits in an item bigger than the
                // shape by `pad` on every side, or the blur would be cut at the edge.
                Item {
                    id: softShadow
                    readonly property real blurPx: 8 + (win.rec ? win.rec.shadowDepth : 0) * 40
                    readonly property real pad: Math.ceil(softShadow.blurPx * 1.6)
                    visible: win.ready && win.rec !== null && win.rec.shadowOn && win.rec.shadowKind === "soft"
                    z: 0
                    x: win.shapeR.x - softShadow.pad
                    y: win.shapeR.y - softShadow.pad + 6 + (win.rec ? win.rec.shadowDepth : 0) * 10
                    width: win.shapeR.w + softShadow.pad * 2
                    height: win.shapeR.h + softShadow.pad * 2
                    opacity: 0.55 * win.picOpacity

                    layer.enabled: softShadow.visible
                    layer.smooth: true
                    layer.textureSize: Qt.size(Math.max(1, Math.ceil(softShadow.width * win.texel)),
                                               Math.max(1, Math.ceil(softShadow.height * win.texel)))
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blur: 1.0
                        blurMax: Math.min(64, Math.max(4, Math.round(softShadow.blurPx * win.texel)))
                    }

                    Rectangle {
                        x: softShadow.pad
                        y: softShadow.pad
                        width: win.shapeR.w
                        height: win.shapeR.h
                        radius: win.radiusPx
                        color: "black"
                        antialiasing: true
                    }
                }

                // Hard: the same silhouette, navy, offset down-right with no blur: the
                // shell's own sticker shadow.
                Rectangle {
                    readonly property real d: 4 + (win.rec ? win.rec.shadowDepth : 0) * 14
                    visible: win.ready && win.rec !== null && win.rec.shadowOn && win.rec.shadowKind === "hard"
                    z: 0
                    x: win.shapeR.x + d
                    y: win.shapeR.y + d
                    width: win.shapeR.w
                    height: win.shapeR.h
                    radius: win.radiusPx
                    color: Theme.colBorder
                    opacity: win.picOpacity
                    antialiasing: true
                }

                // ----- the picture, its border -----
                // One group so the opacity applies to the whole (the border does not show
                // the picture through itself). A layer only while it is below 100%.
                Item {
                    id: shape
                    z: 1
                    x: win.shapeR.x
                    y: win.shapeR.y
                    width: win.shapeR.w
                    height: win.shapeR.h
                    opacity: win.picOpacity
                    visible: win.ready

                    layer.enabled: win.picOpacity < 0.999
                    layer.smooth: true
                    layer.textureSize: Qt.size(Math.max(1, Math.ceil(shape.width * win.texel)),
                                               Math.max(1, Math.ceil(shape.height * win.texel)))

                    readonly property real over: win.animated ? 1.25 : 2

                    // The picture, clipped to the shape: rounded through a mask, or by plain
                    // clipping while there are no corners (cheaper, and a GIF redraws it
                    // every frame).
                    Item {
                        id: picLayer
                        anchors.fill: parent
                        anchors.margins: win.picPad
                        clip: true

                        layer.enabled: win.round
                        layer.smooth: true
                        layer.textureSize: Qt.size(Math.max(1, Math.ceil(win.innerW * win.texel * shape.over)),
                                                   Math.max(1, Math.ceil(win.innerH * win.texel * shape.over)))
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: picMask
                        }

                        Image {
                            id: still
                            visible: !win.animated
                            source: win.animated ? "" : win.srcUrl
                            x: win.drawR.x
                            y: win.drawR.y
                            width: win.drawR.w
                            height: win.drawR.h
                            fillMode: Image.Stretch
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            autoTransform: true
                            sourceSize: win.stillDecode
                            onStatusChanged: win.report()
                            onImplicitWidthChanged: win.report()
                            onImplicitHeightChanged: win.report()
                        }

                        AnimatedImage {
                            id: anim
                            visible: win.animated
                            source: win.animated ? win.srcUrl : ""
                            x: win.drawR.x
                            y: win.drawR.y
                            width: win.drawR.w
                            height: win.drawR.h
                            fillMode: Image.Stretch
                            asynchronous: true
                            smooth: true
                            playing: win.live
                            onStatusChanged: win.report()
                            onImplicitWidthChanged: win.report()
                            onImplicitHeightChanged: win.report()
                        }
                    }

                    // The rounded mask, at the same texture density as the picture so its
                    // edge is as sharp as the picture.
                    Item {
                        id: picMask
                        anchors.fill: parent
                        anchors.margins: win.picPad
                        visible: false

                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: picLayer.layer.textureSize

                        Rectangle {
                            anchors.fill: parent
                            radius: win.innerRadius
                            color: "black"
                            antialiasing: true
                        }
                    }

                    Rectangle {
                        z: 2
                        anchors.fill: parent
                        visible: win.rec !== null && win.rec.borderOn
                        color: "transparent"
                        border.width: win.borderPx
                        border.color: win.borderCol
                        radius: win.radiusPx
                        antialiasing: true
                    }
                }

                // ----- a picture that can't be shown -----
                // (File moved away, or not a picture any more.) Kept as a frame, so it
                // can be replaced from the panel or removed.
                Rectangle {
                    id: missing
                    visible: win.failed && win.recW > 0
                    z: 1
                    anchors.fill: parent
                    radius: Theme.radiusOuter
                    color: Theme.pSurface
                    border.width: Theme.borderWidth
                    border.color: Theme.pLine
                    antialiasing: true

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "broken_image"
                            size: Math.max(16, Math.min(46, Math.min(missing.width, missing.height) * 0.4))
                            color: Theme.pInkSub
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: missing.width > 120 && missing.height > 90
                            text: "PICTURE MISSING"
                            color: Theme.pInkSub
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                            font.letterSpacing: 1.2
                        }
                    }
                }

                // ----- an empty frame -----
                // Waiting for its first picture: a card with a dashed outline that says
                // what to do. It is on the desktop from the moment it is added, and it
                // lights up while a file is held over it. (Drawing only: the
                // DropArea is a separate item below.)
                Item {
                    id: emptyFace
                    z: 1
                    anchors.fill: parent
                    visible: win.empty

                    readonly property bool hot: drops.containsDrag
                    readonly property bool roomy: width >= 170 && height >= 130
                    readonly property bool small: width < 110 || height < 90
                    readonly property real inset: 9
                    readonly property real arc: Math.max(4, Math.min(Theme.radiusOuter - inset, Math.min(width, height) / 2 - inset))

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusOuter
                        color: emptyFace.hot ? Theme.accentMint : Theme.pSurface
                        border.width: Theme.borderWidth
                        border.color: Theme.pLine
                        antialiasing: true

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    // The dashed outline, inside the card.
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            id: dash

                            readonly property real x0: emptyFace.inset
                            readonly property real y0: emptyFace.inset
                            readonly property real x1: emptyFace.width - emptyFace.inset
                            readonly property real y1: emptyFace.height - emptyFace.inset
                            readonly property real r: emptyFace.arc

                            strokeColor: emptyFace.hot ? Theme.colBorder : Theme.pInkSub
                            strokeWidth: 3
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [3, 2.4]
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"

                            startX: dash.x0 + dash.r
                            startY: dash.y0
                            PathLine { x: dash.x1 - dash.r; y: dash.y0 }
                            PathArc { x: dash.x1; y: dash.y0 + dash.r; radiusX: dash.r; radiusY: dash.r; direction: PathArc.Clockwise }
                            PathLine { x: dash.x1; y: dash.y1 - dash.r }
                            PathArc { x: dash.x1 - dash.r; y: dash.y1; radiusX: dash.r; radiusY: dash.r; direction: PathArc.Clockwise }
                            PathLine { x: dash.x0 + dash.r; y: dash.y1 }
                            PathArc { x: dash.x0; y: dash.y1 - dash.r; radiusX: dash.r; radiusY: dash.r; direction: PathArc.Clockwise }
                            PathLine { x: dash.x0; y: dash.y0 + dash.r }
                            PathArc { x: dash.x0 + dash.r; y: dash.y0; radiusX: dash.r; radiusY: dash.r; direction: PathArc.Clockwise }
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36
                        spacing: 5
                        scale: emptyFace.hot ? 1.07 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                        }

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: emptyFace.hot ? "download" : "add_photo_alternate"
                            size: Math.max(18, Math.min(52, Math.min(emptyFace.width, emptyFace.height) * 0.28))
                            weight: 700
                            color: emptyFace.hot ? Theme.colBorder : Theme.pInk
                        }

                        Text {
                            visible: !emptyFace.small
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: emptyFace.hot ? "RELEASE TO ADD" : "DROP A PICTURE HERE"
                            color: emptyFace.hot ? Theme.colBorder : Theme.pInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                            font.letterSpacing: 1.2
                        }

                        Text {
                            visible: emptyFace.roomy && !emptyFace.hot
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "PNG  JPG  WEBP  GIF  SVG"
                            color: Theme.pInkSub
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                            font.letterSpacing: 1
                        }
                    }
                }

                // ----- dropping files -----
                // Files dragged from a file manager onto the frame (empty or not). It
                // takes no mouse events, so it never gets in the way of the drag area.
                // What was dropped is sorted out and copied by ImageService.drop().
                DropArea {
                    id: drops
                    z: 1
                    anchors.fill: parent

                    onEntered: drag => {
                        drag.accepted = drag.hasUrls || drag.hasText
                    }

                    onDropped: drop => {
                        const urls = []
                        if (drop.hasUrls) {
                            for (const u of drop.urls)
                                urls.push(u.toString())
                        }
                        ImageService.drop(win.imageId, urls, (!drop.hasUrls && drop.hasText) ? drop.text : "")
                        drop.accept()
                    }
                }

                // A full frame with a file held over it: it will take the new picture.
                Rectangle {
                    z: 5
                    visible: drops.containsDrag && !win.empty
                    x: win.shapeR.x
                    y: win.shapeR.y
                    width: win.shapeR.w
                    height: win.shapeR.h
                    radius: win.radiusPx
                    color: Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, 0.4)
                    border.width: 4
                    border.color: Theme.accentMint
                    antialiasing: true

                    Text {
                        anchors.centerIn: parent
                        visible: parent.width > 110 && parent.height > 50
                        text: "DROP TO REPLACE"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 1.2
                    }
                }

                // A drop that was not a picture (a folder, a text file, a web address).
                Rectangle {
                    id: rejectNote
                    z: 14
                    visible: rejectTimer.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: Math.min(parent.width - 16, rejectText.implicitWidth + 24)
                    height: 28
                    radius: 10
                    color: "#ff7a8c"
                    border.width: 3
                    border.color: Theme.colBorder
                    antialiasing: true

                    Text {
                        id: rejectText
                        anchors.centerIn: parent
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: ImageService.rejectCount > 1 ? ImageService.rejectCount + " FILES SKIPPED" : "NOT A PICTURE"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 0.8
                    }
                }

                Timer {
                    id: rejectTimer
                    interval: 1800
                }

                Connections {
                    target: ImageService

                    function onRejectTickChanged() {
                        if (ImageService.rejectId === win.imageId)
                            rejectTimer.restart()
                    }
                }

                // Edit Desktop: outline, corner diamonds, a tag and a drag shield
                // (EditChrome.qml). Draws nothing outside the mode.
                EditChrome {
                    id: chrome
                    widgetId: win.widgetId
                    target: card
                    roomW: win.roomW
                    roomH: win.roomH
                    screenName: win.screen ? win.screen.name : ""
                    onMoved: win.commitMove()
                    onRemoveRequested: ImageService.remove(win.imageId)
                }

                // ----- pinning -----
                // Right-click the picture on the desktop: it is pinned in front of
                // everything. (Under the drag area's z: that one takes the left button
                // only, so a right press falls through to this. Edit Desktop's own
                // right-click, "remove", sits above both, and this is off while editing.
                // Once pinned the window is click-through, so there is nothing to click.)
                MouseArea {
                    id: pinArea
                    z: 9
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    enabled: !EditMode.active && !win.pinned && !win.empty && win.rec !== null
                    onClicked: ImageService.setPinned(win.imageId, true)
                }

                // A moment of feedback when a picture gets pinned (here, from its panel,
                // or from a script): it can't be clicked any more, so say where it went.
                Rectangle {
                    id: pinNote
                    z: 14
                    visible: pinTimer.running && win.onTop
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    width: Math.min(parent.width - 16, pinText.implicitWidth + 24)
                    height: 28
                    radius: 10
                    color: Theme.accentMint
                    border.width: 3
                    border.color: Theme.colBorder
                    antialiasing: true

                    Text {
                        id: pinText
                        anchors.centerIn: parent
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: "PINNED ON TOP"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 0.8
                    }
                }

                Timer {
                    id: pinTimer
                    interval: 1600
                }

                // Left button: drag the picture on the normal desktop, unless Lock all is
                // on (EditMode.desktopDragAllowed); while editing, the shield in
                // EditChrome.qml moves it, until it is selected: then this does (except in
                // CROP, where the pan area below takes the drag and the grip moves it).
                MouseArea {
                    id: dragArea
                    z: 10
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    readonly property bool movable: EditMode.desktopDragAllowed || (chrome.selected && !win.cropMode)
                    cursorShape: movable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                    drag.target: movable ? card : null
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, win.roomW - card.width)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, win.roomH - card.height)

                    // Remember the new spot when a drag ends (also when it is cut short). A
                    // plain click doesn't save anything.
                    drag.onActiveChanged: {
                        chrome.ownDrag = drag.active
                        if (!drag.active)
                            win.commitMove()
                    }
                }

                // CROP, selected: drag the picture inside the frame, scroll to zoom.
                MouseArea {
                    id: panArea
                    z: 11
                    anchors.fill: parent
                    enabled: chrome.selected && win.cropMode && win.ready
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property point p0
                    property real startX: 0
                    property real startY: 0

                    onPressed: mouse => {
                        p0 = panArea.mapToItem(card.parent, mouse.x, mouse.y)
                        startX = win.panX
                        startY = win.panY
                        win.livePanX = startX
                        win.livePanY = startY
                        win.panning = true
                    }

                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = panArea.mapToItem(card.parent, mouse.x, mouse.y)
                        const r = IM.panBy(win.innerW, win.innerH, win.picW, win.picH, win.zoom,
                                           startX, startY, p.x - p0.x, p.y - p0.y)
                        win.livePanX = r.panX
                        win.livePanY = r.panY
                    }

                    function finish() {
                        if (!win.panning)
                            return
                        ImageService.update(win.imageId, { panX: win.livePanX, panY: win.livePanY })
                        win.panning = false
                    }

                    onReleased: finish()
                    onCanceled: finish()

                    onWheel: wheel => {
                        const z = IM.clamp(win.zoom * (wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1), 1, IM.MAX_ZOOM)
                        ImageService.update(win.imageId, { zoom: z })
                    }
                }

                // The grip that moves the frame while CROP is being edited.
                Item {
                    id: grip
                    z: 20
                    x: -4
                    y: -44
                    width: 40
                    height: 32
                    visible: chrome.selected && win.cropMode
                    readonly property bool dragging: gripArea.drag.active

                    Pill {
                        anchors.fill: parent
                        cornerRadius: 10
                        ringWidth: 3
                        fillColor: Theme.accentMint

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "open_with"
                            size: 16
                            weight: 700
                            color: Theme.colBorder
                        }
                    }

                    MouseArea {
                        id: gripArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        drag.target: card
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 0
                        drag.maximumX: Math.max(0, win.roomW - card.width)
                        drag.minimumY: 0
                        drag.maximumY: Math.max(0, win.roomH - card.height)

                        drag.onActiveChanged: {
                            chrome.ownDrag = drag.active
                            if (!drag.active)
                                win.commitMove()
                        }
                    }
                }

                // The four resize diamonds, on the frame's corners (over the outline's own).
                Repeater {
                    model: ["nw", "ne", "sw", "se"]

                    Item {
                        id: handle

                        required property string modelData
                        readonly property bool east: handle.modelData.charAt(1) === "e"
                        readonly property bool south: handle.modelData.charAt(0) === "s"

                        z: 20
                        width: 36
                        height: 36
                        x: (east ? card.width + 6 : -6) - width / 2
                        y: (south ? card.height + 6 : -6) - height / 2
                        visible: chrome.selected

                        Rectangle {
                            anchors.centerIn: parent
                            width: sizeArea.containsMouse || sizeArea.pressed ? 22 : 18
                            height: width
                            radius: 5
                            rotation: 45
                            color: Theme.accentMint
                            border.width: 3
                            border.color: Theme.colBorder
                            antialiasing: true

                            Behavior on width {
                                NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2 }
                            }
                        }

                        MouseArea {
                            id: sizeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: handle.east === handle.south ? Qt.SizeFDiag : Qt.SizeBDiag

                            property point p0
                            property var start: ({ x: 0, y: 0, w: 0, h: 0 })

                            onPressed: mouse => {
                                p0 = sizeArea.mapToItem(card.parent, mouse.x, mouse.y)
                                start = { x: card.x, y: card.y, w: card.width, h: card.height }
                                win.liveW = start.w
                                win.liveH = start.h
                                win.sizing = true
                            }

                            onPositionChanged: mouse => {
                                if (!pressed || !win.sizing)
                                    return
                                const p = sizeArea.mapToItem(card.parent, mouse.x, mouse.y)
                                // Shift flips the panel's LOCK RATIO for this drag.
                                const lock = (win.rec ? win.rec.lockAspect : true) !== ((mouse.modifiers & Qt.ShiftModifier) !== 0)
                                const r = IM.resize(start, handle.modelData, p.x - p0.x, p.y - p0.y,
                                                    { lock: lock, roomW: win.roomW, roomH: win.roomH })
                                win.liveW = r.w
                                win.liveH = r.h
                                card.x = r.x
                                card.y = r.y
                            }

                            function finish() {
                                if (!win.sizing)
                                    return
                                ImageService.setGeometry(win.imageId, card.x, card.y, win.liveW, win.liveH,
                                                         win.screen ? win.screen.name : "", win.uiScale)
                                win.sizing = false
                            }

                            onReleased: finish()
                            onCanceled: finish()
                        }
                    }
                }
            }
        }
    }

    // ===== the panel =====
    // Beside the frame, drawn at full size (not shrunk with Edit Desktop's card), so
    // it stays readable: it follows where the frame is on the screen. Right of it if
    // there is room, else left, and never over the shelf at the bottom.
    ImageInspector {
        id: insp
        imageId: win.imageId
        uiScale: win.uiScale
        visible: chrome.selected && win.rec !== null

        readonly property real k: win.uiScale * stage.scale
        readonly property real cardL: stage.x + card.x * insp.k
        readonly property real cardT: stage.y + card.y * insp.k
        readonly property real cardR: insp.cardL + card.width * insp.k
        readonly property real wReal: insp.width * win.uiScale
        readonly property real hReal: insp.height * win.uiScale
        readonly property real gap: 26 * win.uiScale
        readonly property real maxX: Math.max(0, win.fullW - insp.wReal)
        readonly property real maxY: Math.max(0, win.fullH - EditMode.trayHeight - insp.hReal)

        x: Math.max(0, Math.min(insp.maxX,
            insp.cardR + insp.gap + insp.wReal <= win.fullW ? insp.cardR + insp.gap
            : (insp.cardL - insp.gap - insp.wReal >= 0 ? insp.cardL - insp.gap - insp.wReal : insp.cardL)))
        y: Math.max(0, Math.min(insp.maxY, insp.cardT))
        scale: win.uiScale
        transformOrigin: Item.TopLeft
        onOriginalRatioRequested: win.applyOriginalRatio()
    }
    }

    // The panel's ORIGINAL RATIO: the frame keeps its corner and width and takes the
    // picture's own ratio (or the largest that still fits the screen).
    function applyOriginalRatio() {
        const f = IM.originalRatio({ x: card.x, y: card.y, w: win.frameW, h: win.frameH },
                                   win.natW, win.natH, win.roomW, win.roomH)
        ImageService.setGeometry(win.imageId, card.x, card.y, f.w, f.h,
                                 win.screen ? win.screen.name : "", win.uiScale)
    }

    // Remember the frame where it is now (after a drag). Saved at once.
    function commitMove() {
        ImageService.setGeometry(win.imageId, card.x, card.y, win.frameW, win.frameH,
                                 win.screen ? win.screen.name : "", win.uiScale)
    }
}

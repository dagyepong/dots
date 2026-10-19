import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Edit Desktop's alignment grid and guides, drawn ABOVE the widgets.
//
// One of these per monitor (shell.qml). It is mapped only while that monitor is
// being edited, never takes a click (its input region is one pixel), and
// draws in the same card space the widgets live in: EditStage + ScaleHost give
// it the same transform the widget windows use, so a point at (x, y) here is
// the same place as a card at (x, y) there.
//
// What it shows (the state is services/EditGrid.qml, the maths
// EditGridMath.js):
//
//   while a card is moving   a field of diamonds on a 20-px grid fades in across
//                            the card (a hairline every cell, a stronger one
//                            every second, a bar every eighth). When the card's edge sits on a grid
//                            line that line lights up and a diamond pings on the
//                            corner. What it lines up with right now is drawn
//                            as light guide lines.
//   on release               four lines, one along each side of the dropped card,
//                            run right across the screen for under half a second so
//                            you can check the alignment by eye (like end4-pC's
//                            snap lines). The guides firm up and are
//                            named (LEFT, TOP, CENTER ...); widgets of the same
//                            size get a bracket with "=" on it, the widgets that
//                            line up flare (EditChrome.qml).
//   then                     everything eases out.
//
// Colours: edges are the theme's cyan, centres its mint, "flush" (touching) is
// white, same size is pink (the shell's fixed Sekai pink), every one with the
// navy outline the rest of Edit Desktop wears. Sizes are kept the same on
// screen whatever the card has shrunk to (`room.u`).
//
// Layer namespace: sekaipop-edit-guides. It maps when the mode starts and
// unmaps when it ends, while it is fully transparent, so Hyprland's own layer
// animation has nothing to show. (If you ever see a flash, give that namespace a
// no_anim layer rule, the same as sekaipop-region.)
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property string screenName: win.screen ? win.screen.name : ""
    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real roomW: win.width / win.uiScale
    readonly property real roomH: win.height / win.uiScale

    visible: EditMode.editing(win.screenName)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sekaipop-edit-guides"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Click-through: only this one pixel (in the stage's dark corner) can take a
    // click, so every click goes to the widgets, the shelf and the wallpaper.
    mask: Region {
        item: hole
    }

    Item {
        id: hole
        x: 0
        y: 0
        width: 1
        height: 1
    }

    EditStage {
        id: stage
        screenObj: win.screen
        uiScale: win.uiScale

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            // The card's picture: everything below is in design pixels.
            Item {
                id: room
                anchors.fill: parent
                clip: true

                // One pixel of an un-shrunk desktop, in design pixels: sizes are
                // multiplied by it so a guide is as thick, and a label as
                // readable, as it would be on the full-size desktop.
                readonly property real u: 1 / Math.max(0.2, stage.scale)

                function lineColor(kind) {
                    if (kind === "center")
                        return Theme.accentMint
                    if (kind === "flush")
                        return "#ffffff"
                    return Theme.accentCyan
                }

                // ===== The grid =====
                Item {
                    id: gridLayer
                    anchors.fill: parent
                    transformOrigin: Item.Center

                    readonly property real want: EditGrid.phase === "drag" ? 1
                        : (EditGrid.phase === "confirm" ? 0.42
                           : (EditGrid.gridAlwaysOn ? 0.5 : 0))

                    opacity: gridLayer.want
                    // It settles into place as it appears, a hair too big at first.
                    scale: gridLayer.want > 0 ? 1 : 1.025

                    Behavior on opacity {
                        NumberAnimation {
                            duration: gridLayer.want > 0.9 ? 260 : EditGrid.fadeMs
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }

                    // Painted once per size (and when the theme's colours change):
                    // hairlines, then a diamond on every crossing, bigger on every
                    // fourth. Only the inside is drawn (no line on the card's own
                    // edge), so nothing pokes out of the card's rounded corners.
                    Canvas {
                        id: cv
                        anchors.fill: parent

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width
                            const h = height
                            if (w < 64 || h < 64)
                                return

                            const c = EditGrid.cell
                            const navy = Qt.color(Theme.colBorder)
                            const cyan = Qt.color(Theme.accentCyan)
                            const mint = Qt.color(Theme.accentMint)
                            const rgba = (col, a) => "rgba(" + Math.round(col.r * 255) + ","
                                + Math.round(col.g * 255) + "," + Math.round(col.b * 255) + "," + a + ")"

                            // hairlines: a navy shadow, then white on it, so they read on
                            // a light wallpaper and a dark one alike. Three weights: every
                            // cell (fine), every second one (medium, the old 40-px grid),
                            // every EditGrid.major-th (bar).
                            const maj = EditGrid.major
                            const tier = n => (n % maj === 0) ? 2 : ((n % 2 === 0) ? 1 : 0)
                            const navyA = [0.07, 0.11, 0.20]
                            const whiteA = [0.08, 0.13, 0.26]
                            const lw = [1, 1.5, 2]
                            for (let pass = 0; pass < 2; pass++) {
                                for (let i = 1; i * c < w - 1; i++) {
                                    const t = tier(i)
                                    ctx.strokeStyle = pass === 0 ? rgba(navy, navyA[t])
                                                                 : "rgba(255,255,255," + whiteA[t] + ")"
                                    ctx.lineWidth = lw[t]
                                    const x = i * c + (pass === 0 ? 1 : 0)
                                    ctx.beginPath()
                                    ctx.moveTo(x, 0)
                                    ctx.lineTo(x, h)
                                    ctx.stroke()
                                }
                                for (let j = 1; j * c < h - 1; j++) {
                                    const t = tier(j)
                                    ctx.strokeStyle = pass === 0 ? rgba(navy, navyA[t])
                                                                 : "rgba(255,255,255," + whiteA[t] + ")"
                                    ctx.lineWidth = lw[t]
                                    const y = j * c + (pass === 0 ? 1 : 0)
                                    ctx.beginPath()
                                    ctx.moveTo(0, y)
                                    ctx.lineTo(w, y)
                                    ctx.stroke()
                                }
                            }

                            // diamonds on the crossings: a big one where two bars meet, a
                            // medium one where two medium lines do (the old grid's), and a
                            // small faint one on the new in-between crossings.
                            for (let i = 1; i * c < w - 1; i++) {
                                for (let j = 1; j * c < h - 1; j++) {
                                    const big = i % maj === 0 && j % maj === 0
                                    const mid = !big && i % 2 === 0 && j % 2 === 0
                                    const r = big ? 6 : (mid ? 3.4 : 1.9)
                                    const x = i * c
                                    const y = j * c
                                    ctx.fillStyle = rgba(navy, big ? 0.30 : (mid ? 0.30 : 0.16))
                                    ctx.beginPath()
                                    ctx.moveTo(x, y - r - 1.2)
                                    ctx.lineTo(x + r + 1.2, y)
                                    ctx.lineTo(x, y + r + 1.2)
                                    ctx.lineTo(x - r - 1.2, y)
                                    ctx.closePath()
                                    ctx.fill()
                                    ctx.fillStyle = rgba(((i + j) % 2 === 0) ? mint : cyan, big ? 0.9 : (mid ? 0.62 : 0.4))
                                    ctx.beginPath()
                                    ctx.moveTo(x, y - r)
                                    ctx.lineTo(x + r, y)
                                    ctx.lineTo(x, y + r)
                                    ctx.lineTo(x - r, y)
                                    ctx.closePath()
                                    ctx.fill()
                                }
                            }
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        Connections {
                            target: Theme

                            function onColBorderChanged() { cv.requestPaint() }
                            function onAccentCyanChanged() { cv.requestPaint() }
                            function onAccentMintChanged() { cv.requestPaint() }
                        }
                    }
                }

                // ===== Everything that fades out together at the end =====
                Item {
                    id: guides
                    anchors.fill: parent

                    opacity: EditGrid.phase === "fade" ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: EditGrid.fadeMs; easing.type: Easing.InOutQuad }
                    }

                    // ===== the four sides of the dropped card =====
                    Repeater {
                        model: 4

                        Item {
                            id: rail
                            required property int index

                            readonly property var r: EditGrid.dropRect
                            readonly property bool vert: rail.index < 2
                            // index: 0 left, 1 right, 2 top, 3 bottom
                            readonly property real pos: rail.r === null ? 0
                                : (rail.index === 0 ? rail.r.x
                                    : (rail.index === 1 ? rail.r.x + rail.r.w
                                        : (rail.index === 2 ? rail.r.y : rail.r.y + rail.r.h)))
                            // where the card is along the line, and how long the line can be
                            readonly property real mid: rail.r === null ? 0
                                : (rail.vert ? rail.r.y + rail.r.h / 2 : rail.r.x + rail.r.w / 2)
                            readonly property real total: rail.vert ? room.height : room.width

                            // 0 -> 1: shoots out of the card to both ends of the screen.
                            property real g: 0

                            // Quick: out and back in well under half a second.
                            opacity: EditGrid.railsLive ? 1 : 0
                            visible: rail.r !== null && rail.opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: 160; easing.type: Easing.InQuad }
                            }

                            NumberAnimation {
                                id: shoot
                                target: rail
                                property: "g"
                                from: 0
                                to: 1
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                            Connections {
                                target: EditGrid

                                function onConfirmSerialChanged() { shoot.restart() }
                            }

                            readonly property real t: 2.4 * room.u
                            readonly property real ol: 1.6 * room.u
                            readonly property real ow: rail.t + 2 * rail.ol
                            readonly property real a0: rail.mid - rail.mid * rail.g
                            readonly property real a1: rail.mid + (rail.total - rail.mid) * rail.g

                            // navy outline
                            Rectangle {
                                x: rail.vert ? rail.pos - rail.ow / 2 : rail.a0
                                y: rail.vert ? rail.a0 : rail.pos - rail.ow / 2
                                width: rail.vert ? rail.ow : rail.a1 - rail.a0
                                height: rail.vert ? rail.a1 - rail.a0 : rail.ow
                                radius: rail.ow / 2
                                color: Theme.colBorder
                                opacity: 0.85
                            }

                            // cyan inside
                            Rectangle {
                                x: rail.vert ? rail.pos - rail.t / 2 : rail.a0
                                y: rail.vert ? rail.a0 : rail.pos - rail.t / 2
                                width: rail.vert ? rail.t : rail.a1 - rail.a0
                                height: rail.vert ? rail.a1 - rail.a0 : rail.t
                                radius: rail.t / 2
                                color: Theme.accentCyan
                                opacity: 0.9
                            }
                        }
                    }

                    // ===== the grid lines the card sits on =====
                    Repeater {
                        model: EditGrid.hits.xs

                        Rectangle {
                            required property var modelData

                            x: modelData - width / 2
                            y: 0
                            width: 2.4 * room.u
                            height: room.height
                            color: Theme.accentMint
                            opacity: 0.4

                            NumberAnimation on opacity {
                                from: 0
                                to: 0.4
                                duration: 240
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Repeater {
                        model: EditGrid.hits.ys

                        Rectangle {
                            required property var modelData

                            x: 0
                            y: modelData - height / 2
                            width: room.width
                            height: 2.4 * room.u
                            color: Theme.accentMint
                            opacity: 0.4

                            NumberAnimation on opacity {
                                from: 0
                                to: 0.4
                                duration: 240
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // A diamond pings on the corner that lands on a crossing.
                    Repeater {
                        model: EditGrid.hits.corners

                        Item {
                            id: ping
                            required property var modelData

                            x: modelData.x
                            y: modelData.y
                            width: 0
                            height: 0

                            property real pop: 0
                            property real ring: 0

                            NumberAnimation on pop {
                                from: 0
                                to: 1
                                duration: 420
                                easing.type: Easing.OutBack
                                easing.overshoot: 3
                            }

                            NumberAnimation on ring {
                                from: 0
                                to: 1
                                duration: 560
                                easing.type: Easing.OutCubic
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 22 * room.u
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 2 * room.u
                                border.color: Theme.accentMint
                                scale: 0.5 + ping.ring * 1.8
                                opacity: (1 - ping.ring) * 0.85
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 13 * room.u
                                height: width
                                radius: 2.5 * room.u
                                rotation: 45
                                color: Theme.accentMint
                                border.width: 1.6 * room.u
                                border.color: Theme.colBorder
                                antialiasing: true
                                scale: ping.pop
                            }
                        }
                    }

                    // ===== same size =====
                    Repeater {
                        model: EditGrid.sizeMarks

                        Item {
                            id: mark
                            required property var modelData

                            readonly property bool wide: mark.modelData.axis === "w"

                            Repeater {
                                model: mark.modelData.rects

                                Item {
                                    id: br
                                    required property var modelData
                                    required property int index

                                    readonly property bool mine: br.modelData.id === mark.modelData.mine
                                    readonly property real u: room.u
                                    readonly property real off: 17 * br.u
                                    readonly property real ow: 3 * br.u + 3.2 * br.u
                                    // The bracket sits outside the widget, on the side with room.
                                    readonly property bool flip: mark.wide
                                        ? (br.modelData.y + br.modelData.h + 40 * br.u > room.height)
                                        : (br.modelData.x + br.modelData.w + 40 * br.u > room.width)
                                    readonly property real axisPos: mark.wide
                                        ? (br.flip ? br.modelData.y - br.off : br.modelData.y + br.modelData.h + br.off)
                                        : (br.flip ? br.modelData.x - br.off : br.modelData.x + br.modelData.w + br.off)
                                    readonly property real a0: mark.wide ? br.modelData.x : br.modelData.y
                                    readonly property real alen: mark.wide ? br.modelData.w : br.modelData.h

                                    // 0 -> 1 as it draws on from the middle; the one just dropped
                                    // first, the others a beat after, one by one.
                                    property real g: 0

                                    SequentialAnimation {
                                        running: true

                                        PauseAnimation { duration: br.mine ? 0 : 110 + br.index * 80 }

                                        NumberAnimation {
                                            target: br
                                            property: "g"
                                            to: 1
                                            duration: 340
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    // the bar: navy outline, pink inside
                                    Rectangle {
                                        x: mark.wide ? br.a0 + br.alen * (1 - br.g) / 2 : br.axisPos - br.ow / 2
                                        y: mark.wide ? br.axisPos - br.ow / 2 : br.a0 + br.alen * (1 - br.g) / 2
                                        width: mark.wide ? br.alen * br.g : br.ow
                                        height: mark.wide ? br.ow : br.alen * br.g
                                        radius: br.ow / 2
                                        color: Theme.colBorder
                                    }

                                    Rectangle {
                                        x: mark.wide ? br.a0 + br.alen * (1 - br.g) / 2 + 3.2 * br.u / 2 : br.axisPos - 1.5 * br.u
                                        y: mark.wide ? br.axisPos - 1.5 * br.u : br.a0 + br.alen * (1 - br.g) / 2 + 3.2 * br.u / 2
                                        width: mark.wide ? Math.max(0, br.alen * br.g - 3.2 * br.u) : 3 * br.u
                                        height: mark.wide ? 3 * br.u : Math.max(0, br.alen * br.g - 3.2 * br.u)
                                        radius: 1.5 * br.u
                                        color: Theme.irisColorPink
                                    }

                                    // the two end ticks, standing across the bar
                                    Repeater {
                                        model: 2

                                        Item {
                                            id: tick
                                            required property int index

                                            readonly property real along: br.a0 + (tick.index === 0 ? 0 : br.alen)
                                            x: mark.wide ? tick.along : br.axisPos
                                            y: mark.wide ? br.axisPos : tick.along
                                            width: 0
                                            height: 0
                                            scale: br.g

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: mark.wide ? br.ow : 15 * br.u
                                                height: mark.wide ? 15 * br.u : br.ow
                                                radius: br.ow / 2
                                                color: Theme.colBorder

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: mark.wide ? 3 * br.u : 11.8 * br.u
                                                    height: mark.wide ? 11.8 * br.u : 3 * br.u
                                                    radius: 1.5 * br.u
                                                    color: Theme.irisColorPink
                                                }
                                            }
                                        }
                                    }

                                    // the "=" in the middle: a little disc on every one, and a
                                    // named sticker on the widget that was just dropped
                                    Item {
                                        id: badge
                                        x: mark.wide ? br.a0 + br.alen / 2 : br.axisPos
                                        y: mark.wide ? br.axisPos : br.a0 + br.alen / 2
                                        width: 0
                                        height: 0
                                        scale: br.u * Math.max(0, (br.g - 0.5) * 2)
                                        opacity: br.g > 0.5 ? 1 : 0

                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: !br.mine
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: Theme.irisColorPink
                                            border.width: 2
                                            border.color: Theme.colBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: "="
                                                color: Theme.colBorder
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                font.weight: Font.ExtraBold
                                                font.styleName: Theme.fontStyleBold
                                            }
                                        }

                                        Pill {
                                            id: sticker
                                            visible: br.mine
                                            x: -sticker.width / 2
                                            y: -sticker.height / 2
                                            width: stickerText.implicitWidth + 24
                                            height: 26
                                            cornerRadius: 10
                                            ringWidth: 3
                                            fillColor: Theme.irisColorPink

                                            Text {
                                                id: stickerText
                                                anchors.centerIn: parent
                                                text: mark.wide ? "= SAME WIDTH" : "= SAME HEIGHT"
                                                color: Theme.colBorder
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.ExtraBold
                                                font.styleName: Theme.fontStyleBold
                                                font.letterSpacing: 0.8
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ===== the guide lines =====
                    Repeater {
                        model: EditGrid.slotCount

                        Item {
                            id: slot
                            required property int index

                            readonly property var cur: EditGrid.slots[slot.index] ?? null
                            // The last line this slot showed: kept while it shrinks away.
                            property var line: null

                            onCurChanged: {
                                if (slot.cur)
                                    slot.line = slot.cur
                            }

                            readonly property bool on: slot.cur !== null
                            readonly property bool strong: EditGrid.phase === "confirm" || EditGrid.phase === "fade"
                            readonly property bool vert: slot.line !== null && slot.line.axis === "v"
                            readonly property color tint: room.lineColor(slot.line ? slot.line.kind : "edge")

                            visible: slot.line !== null && slot.grow > 0.001

                            // 0 -> 1: the line draws on from its middle outwards.
                            property real grow: slot.on ? 1 : 0

                            Behavior on grow {
                                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                            }

                            // Light while the card is moving, full strength once dropped.
                            property real str: slot.strong ? 1 : 0

                            Behavior on str {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }

                            // The stamp when the card is dropped: the line thickens and settles.
                            property real stampT: 0

                            SequentialAnimation {
                                id: stamp

                                NumberAnimation {
                                    target: slot
                                    property: "stampT"
                                    to: 1
                                    duration: 110
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: slot
                                    property: "stampT"
                                    to: 0
                                    duration: 460
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 3
                                }
                            }

                            Connections {
                                target: EditGrid

                                function onConfirmSerialChanged() {
                                    if (slot.on)
                                        stamp.restart()
                                }
                            }

                            readonly property real t: (2.4 + 1.2 * slot.str) * room.u * (1 + 0.65 * slot.stampT)
                            readonly property real ol: 1.6 * room.u
                            readonly property real ow: slot.t + 2 * slot.ol

                            readonly property real px: slot.line ? slot.line.pos : 0
                            readonly property real len: slot.line ? slot.line.to - slot.line.from : 0
                            readonly property real mid: slot.line ? (slot.line.from + slot.line.to) / 2 : 0
                            readonly property real half: slot.len * slot.grow / 2

                            // the line's outline box
                            readonly property real bx: slot.vert ? slot.px - slot.ow / 2 : slot.mid - slot.half
                            readonly property real by: slot.vert ? slot.mid - slot.half : slot.px - slot.ow / 2
                            readonly property real bw: slot.vert ? slot.ow : slot.half * 2
                            readonly property real bh: slot.vert ? slot.half * 2 : slot.ow

                            readonly property real alpha: 0.6 + 0.4 * slot.str

                            Rectangle {
                                x: slot.bx
                                y: slot.by
                                width: slot.bw
                                height: slot.bh
                                radius: slot.ow / 2
                                color: Theme.colBorder
                                opacity: slot.alpha
                            }

                            Rectangle {
                                x: slot.bx + slot.ol
                                y: slot.by + slot.ol
                                width: Math.max(0, slot.bw - 2 * slot.ol)
                                height: Math.max(0, slot.bh - 2 * slot.ol)
                                radius: Math.min(width, height) / 2
                                color: slot.tint
                                opacity: slot.alpha
                            }

                            // a diamond at each end of the line
                            Repeater {
                                model: 2

                                Rectangle {
                                    id: cap
                                    required property int index

                                    readonly property real size: 12 * room.u
                                    readonly property real along: slot.mid + (cap.index === 0 ? -slot.half : slot.half)

                                    x: (slot.vert ? slot.px : cap.along) - cap.size / 2
                                    y: (slot.vert ? cap.along : slot.px) - cap.size / 2
                                    width: cap.size
                                    height: cap.size
                                    radius: 2.2 * room.u
                                    rotation: 45
                                    color: slot.tint
                                    border.width: 1.6 * room.u
                                    border.color: Theme.colBorder
                                    antialiasing: true
                                    scale: slot.grow
                                    opacity: slot.alpha
                                }
                            }

                            // a dot on every widget the line runs through (once dropped)
                            Repeater {
                                model: slot.line ? slot.line.dots : []

                                Rectangle {
                                    id: dot
                                    required property var modelData

                                    readonly property real size: 10 * room.u

                                    x: dot.modelData.x - dot.size / 2
                                    y: dot.modelData.y - dot.size / 2
                                    width: dot.size
                                    height: dot.size
                                    radius: dot.size / 2
                                    color: "#ffffff"
                                    border.width: 1.8 * room.u
                                    border.color: Theme.colBorder
                                    antialiasing: true
                                    scale: (slot.strong && slot.on && slot.grow > 0.85) ? 1 : 0

                                    Behavior on scale {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                    }
                                }
                            }

                            // the name: LEFT, TOP, CENTER ... (once dropped)
                            Item {
                                id: lab
                                readonly property bool want: slot.strong && slot.on && slot.grow > 0.85

                                width: labPill.width
                                height: labPill.height

                                readonly property real half_w: lab.width * room.u / 2
                                readonly property real half_h: lab.height * room.u / 2
                                readonly property real gap: 12 * room.u

                                // Beyond the line's first end (above a vertical line, left of
                                // a horizontal one); past its other end if that would be off
                                // the card; and inside it, at the start, for a line that runs
                                // the whole card (the screen's middle).
                                readonly property real span: lab.half_w * 2
                                readonly property real spanV: lab.half_h * 2
                                readonly property int place: {
                                    if (slot.line === null)
                                        return 0
                                    if (slot.vert) {
                                        if (slot.line.from - lab.gap - lab.spanV >= 0)
                                            return 0
                                        return slot.line.to + lab.gap + lab.spanV <= room.height ? 1 : 2
                                    }
                                    if (slot.line.from - lab.gap - lab.span >= 0)
                                        return 0
                                    return slot.line.to + lab.gap + lab.span <= room.width ? 1 : 2
                                }
                                readonly property real cx: slot.line === null ? 0
                                    : (slot.vert ? slot.px
                                        : (lab.place === 0 ? slot.line.from - lab.gap - lab.half_w
                                            : (lab.place === 1 ? slot.line.to + lab.gap + lab.half_w
                                                : slot.line.from + lab.gap + lab.half_w)))
                                readonly property real cy: slot.line === null ? 0
                                    : (slot.vert
                                        ? (lab.place === 0 ? slot.line.from - lab.gap - lab.half_h
                                            : (lab.place === 1 ? slot.line.to + lab.gap + lab.half_h
                                                : slot.line.from + lab.gap + lab.half_h))
                                        : slot.px)

                                x: lab.cx - lab.width / 2
                                y: lab.cy - lab.height / 2

                                property real pop: lab.want ? 1 : 0

                                Behavior on pop {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                                }

                                scale: room.u * lab.pop
                                visible: lab.pop > 0.01
                                transformOrigin: Item.Center

                                Pill {
                                    id: labPill
                                    width: labText.implicitWidth + 24
                                    height: 26
                                    cornerRadius: 10
                                    ringWidth: 3
                                    fillColor: slot.tint

                                    Text {
                                        id: labText
                                        anchors.centerIn: parent
                                        text: slot.line ? slot.line.label : ""
                                        color: Theme.colBorder
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.ExtraBold
                                        font.styleName: Theme.fontStyleBold
                                        font.letterSpacing: 0.8
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

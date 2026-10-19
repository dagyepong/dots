import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// The Wallpapers phone's carousel: a Ferris wheel of wallpapers.
//
//    ◇     ◇     ◇     ◇     ◇     ◇        the track: a slim band, in the layers
//  ═════●═══════●═══════●═══════●═════       of the shell's keys, whose top arc is
//     ╱ ╲     ╱ ╲     ╱ ╲                     all you see; the beat diamonds set in
//   ┌──┐     ┌────────┐     ┌──┐              it turn with the wheel
//   └──┘     │        │     └──┘
//            │ centre │                       every wallpaper hangs from a bolt on
//            └────────┘                       the track by two wires, like a picture
//          <name> [tags]                      on its frame wire, taped at the ends: it
//     [ Set as Desktop ][ Set as Lock ]       stays upright, gets smaller and paler
//                                             the further round, swings when the
//                                             wheel is spun and settles with a wobble
//
// Turn it by dragging sideways, the mouse wheel (one notch = one picture),
// Left/Right (WallpaperFace.qml forwards the keys), or by clicking a picture
// that is not in front. Click the one in front to open it in the viewer; the
// two keys under it set it as the desktop's or the lockscreen's wallpaper
// straight away (Shift+click: every monitor, same as the viewer's keys).
//
// With seven or more pictures the wheel is a true wheel and goes round and
// round; with fewer it stops at its ends. Only nine gondolas exist: they are
// handed pictures as they come round (so a folder of 500 costs no more than
// one of 9).
//
// It is built from the shell's own parts so it sits with the rest of it: the
// wallpaper board's framed picture, washi tape and "also on the lockscreen"
// sticker, the board's dotted tray behind it, the clock's beat diamonds along
// the track (the two either side of the front picture light up and pop each
// time a new one comes round), the clock's sticker text for the name, and
// the Settings' leaning keys for the tags.
//
// A new list (first open, a search, a sort) is dealt: the wheel spins in from
// the side and the pictures swing as it settles.
//
// Pure UI: it only reports what was asked for (opened / set...Requested) and
// WallpaperFace.qml does the rest.
Item {
    id: root

    clip: true

    // ===== given by WallpaperFace.qml =====
    // [{ fileName, filePath, ... }] in the order shown (what the search lets through).
    property var items: []
    // The applied picture of the side being marked, and the other side's.
    property string currentPath: ""
    property string otherPath: ""
    property string desktopPath: ""
    property string lockPath: ""
    property bool lockMode: false
    // "desktop" / "lock" for a moment after one was set (the key says Applied).
    property string justSet: ""
    property real renderScale: 1
    // Only reacts to the mouse / wheel while it is the thing on show.
    property bool active: true

    signal opened(int index)
    signal setDesktopRequested(string path, bool all)
    signal setLockRequested(string path, bool all)

    // ===== the wheel's numbers (design units) =====
    readonly property real cardW: 440
    readonly property real cardH: 275          // 16:10, like most wallpapers
    readonly property real hang: 44            // from the track down to the picture's top edge
    readonly property real wireDx: 92          // how far out from the middle the two wires reach
    readonly property real trackHalf: 10       // half the track's width
    readonly property real wheelR: 900
    readonly property real stepDeg: 21         // how far round the track one picture is
    readonly property real pivotY: 18          // where the middle of the track is, at the top
    readonly property real cx: root.width / 2
    readonly property real hubY: root.pivotY + root.wheelR
    readonly property real dragPx: 300         // a drag of this many px = one picture

    // ===== the turn =====
    readonly property int count: root.items.length
    readonly property bool wrapping: root.count >= 7

    // The wheel's turn, in pictures: the picture whose place in the list is
    // `pos` is at the very top. Not wrapped, so it keeps counting up as the
    // wheel goes round (the gondolas take it modulo the list).
    property real pos: 0

    readonly property int centerIndex: root.count === 0 ? -1 : root.mod(Math.round(root.pos), root.count)
    readonly property string focusPath: root.centerIndex >= 0 ? (root.items[root.centerIndex].filePath || "") : ""
    readonly property string focusName: root.centerIndex >= 0 ? root.baseName(root.items[root.centerIndex].fileName || "") : ""

    // The side being marked wears its own colours (the lockscreen's on its tab):
    // the check badge goes markA -> markB, the ring and the lit things are markB.
    // What the panel under the front picture shows: the picture the wheel is
    // on, but a beat late while it is turning, so the name, counter and tags
    // don't flicker through every picture that goes past.
    property int shownIndex: -1
    readonly property bool shownOk: root.shownIndex >= 0 && root.shownIndex < root.count
    readonly property string shownPath: root.shownOk ? (root.items[root.shownIndex].filePath || "") : ""
    readonly property string shownName: root.shownOk ? root.baseName(root.items[root.shownIndex].fileName || "") : ""

    function syncShown() {
        root.shownIndex = root.centerIndex
    }

    Timer {
        id: shownTimer
        interval: 90
        onTriggered: root.syncShown()
    }

    onCenterIndexChanged: {
        if (root.rested || !root.shownOk)
            root.syncShown()
        else
            shownTimer.restart()
    }

    onRestedChanged: {
        if (root.rested)
            root.syncShown()
    }

    readonly property color markA: root.lockMode ? LockPalette.mint : Theme.accentCyan
    readonly property color markColor: root.lockMode ? LockPalette.pink : Theme.accentMint
    readonly property color otherColor: root.lockMode ? Theme.accentCyan : LockPalette.pink

    readonly property var tapeColors: [ScrapbookTheme.tapeTeal, ScrapbookTheme.tapeCoral,
                                       ScrapbookTheme.tapeMint, ScrapbookTheme.tapePink]

    function mod(a, n) {
        return ((a % n) + n) % n
    }

    function baseName(fileName) {
        const i = fileName.lastIndexOf(".")
        return i > 0 ? fileName.slice(0, i) : fileName
    }

    // The name as it fits the sticker text (which can't elide itself).
    function shortName(n) {
        return n.length > 30 ? n.slice(0, 14) + "\u2026" + n.slice(-13) : n
    }

    // A number 0..59 worked out from the file name, which picks a picture's
    // tape (colour, angle): the same as the wallpaper board's, so a wallpaper
    // wears the same tape here as there.
    function variantFor(fileName) {
        let h = 7
        for (let i = 0; i < fileName.length; i++)
            h = (h * 31 + fileName.charCodeAt(i)) | 0
        return Math.abs(h) % 60
    }

    // How big a gondola is at distance d (in pictures) from the top: 1 in front,
    // smoothly down to a bit over half far round.
    function scaleFor(d) {
        return 0.54 + 0.46 * Math.exp(-d * d / 1.6)
    }

    NumberAnimation {
        id: turnAnim
        target: root
        property: "pos"
        easing.type: Easing.OutCubic
    }

    // Go to a place `p` (not wrapped), gliding (`ms`: how long, else it
    // depends on how far).
    function turnTo(p, ms) {
        const t = root.wrapping ? p : Math.max(0, Math.min(Math.max(0, root.count - 1), p))
        const dist = Math.abs(t - root.pos)
        if (dist < 0.0005)
            return
        turnAnim.stop()
        turnAnim.from = root.pos
        turnAnim.to = t
        turnAnim.duration = ms !== undefined ? ms : Math.round(Math.min(950, 260 + 110 * Math.sqrt(dist)))
        turnAnim.start()
    }

    // Deal a new list: spin in from the left to the first picture.
    function deal() {
        turnAnim.stop()
        if (root.count === 0) {
            root.pos = 0
            return
        }
        root.pos = root.wrapping ? -2.6 : -1.4
        Qt.callLater(function() { root.turnTo(0, 1000) })
    }

    // Presses in a row add up instead of each starting from where the wheel is.
    function stepBy(n) {
        if (root.count === 0)
            return
        const base = turnAnim.running ? turnAnim.to : Math.round(root.pos)
        root.turnTo(base + n)
    }

    // The shortest way round to picture i of the list.
    function rotateTo(i) {
        if (root.count === 0 || i < 0 || i >= root.count)
            return
        const base = Math.round(root.pos)
        let delta = i - root.mod(base, root.count)
        if (root.wrapping) {
            if (delta > root.count / 2)
                delta -= root.count
            else if (delta < -root.count / 2)
                delta += root.count
        }
        root.turnTo(base + delta)
    }

    function toStart() {
        const base = Math.round(root.pos)
        root.turnTo(root.wrapping ? base - root.mod(base, root.count) : 0)
    }

    function toEnd() {
        const base = Math.round(root.pos)
        root.turnTo(root.wrapping ? base - root.mod(base, root.count) + root.count - 1 : root.count - 1)
    }

    // After a drag lets go: carry on a little with the speed it had (cards per
    // second), then settle on a picture.
    function release(vel) {
        const lead = Math.max(-3, Math.min(3, vel * 0.3))
        root.turnTo(Math.round(root.pos + lead))
    }

    // A new list (a search, a sort, a refresh) starts at its first picture.
    onItemsChanged: {
        root.syncShown()
        root.deal()
    }

    // ===== swing and rest =====
    // Gondolas lag behind the turn: while the wheel moves they lean back
    // against it, and when it stops they swing out and settle.
    property real swingTarget: 0
    property real swing: root.swingTarget
    property real lastPos: 0
    // False while it is moving (and for a moment after): the front picture
    // only loads its full-size version once the wheel has rested.
    property bool rested: true

    Behavior on swing {
        SpringAnimation {
            spring: 2.2
            damping: 0.14
            epsilon: 0.02
        }
    }

    Timer {
        id: swingReset
        interval: 70
        onTriggered: root.swingTarget = 0
    }

    Timer {
        id: restTimer
        interval: 160
        onTriggered: root.rested = true
    }

    onPosChanged: {
        const dp = root.pos - root.lastPos
        root.lastPos = root.pos
        root.swingTarget = -Math.max(-8, Math.min(8, dp * 60))
        swingReset.restart()
        root.rested = false
        restTimer.restart()
    }

    // ===== input =====
    DragHandler {
        id: drag

        enabled: root.active && root.count > 0
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        acceptedButtons: Qt.LeftButton

        property real startPos: 0
        property real lastT: 0
        property real lastX: 0
        property real vel: 0

        onActiveChanged: {
            if (drag.active) {
                turnAnim.stop()
                drag.startPos = root.pos
                drag.lastT = Date.now()
                drag.lastX = 0
                drag.vel = 0
            } else {
                root.release(drag.vel)
            }
        }

        onTranslationChanged: {
            if (!drag.active)
                return
            const now = Date.now()
            const dx = drag.translation.x
            let p = drag.startPos - dx / root.dragPx
            if (!root.wrapping)
                p = Math.max(-0.35, Math.min(root.count - 1 + 0.35, p))
            const dt = Math.max(1, now - drag.lastT)
            const inst = -(dx - drag.lastX) / root.dragPx / dt * 1000
            drag.vel = drag.vel * 0.6 + inst * 0.4
            drag.lastT = now
            drag.lastX = dx
            root.pos = p
        }
    }

    // One mouse notch = one picture; a trackpad adds up to the same.
    WheelHandler {
        property real acc: 0

        enabled: root.active
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (dy === 0)
                return
            acc += dy
            if (Math.abs(acc) >= 120) {
                root.stepBy(acc > 0 ? -1 : 1)
                acc = 0
            }
            event.accepted = true
        }
    }

    // ===== the wheel itself =====
    // The tray inside the track: the wallpaper board's own (its tray colour and
    // its dot grid, which follow the colour theme), kept inside the circle.
    Rectangle {
        x: root.cx - root.wheelR
        y: root.pivotY
        width: 2 * root.wheelR
        height: 2 * root.wheelR
        radius: root.wheelR
        color: Qt.rgba(ScrapbookTheme.boardBg.r, ScrapbookTheme.boardBg.g, ScrapbookTheme.boardBg.b, 0.88)
        antialiasing: true
    }

    Canvas {
        id: trayDots

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width <= 0 || height <= 0)
                return
            ctx.fillStyle = String(ScrapbookTheme.boardDot)
            const inner = root.wheelR - root.trackHalf - 14
            for (let y = 8; y < height; y += 22) {
                for (let x = 8; x < width; x += 22) {
                    const dx = x - root.cx
                    const dy = y - root.hubY
                    if (dx * dx + dy * dy > inner * inner)
                        continue
                    ctx.beginPath()
                    ctx.arc(x, y, 1.6, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: ScrapbookTheme

            function onBoardDotChanged() {
                trayDots.requestPaint()
            }
        }
    }

    // The track the pictures hang from: a band in the same layers as the
    // shell's keys (navy outline, pale fill, navy outline) with the hard
    // shadow down and right, and the beat diamonds set into it. Three rings:
    // the band, then its two edges.
    Rectangle {
        // shadow
        x: root.cx - root.wheelR - root.trackHalf + Theme.shadowOffset - 1
        y: root.pivotY - root.trackHalf + Theme.shadowOffset
        width: 2 * (root.wheelR + root.trackHalf)
        height: 2 * (root.wheelR + root.trackHalf)
        radius: root.wheelR + root.trackHalf
        color: "transparent"
        border.width: 2 * root.trackHalf
        border.color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        // the band
        x: root.cx - root.wheelR - root.trackHalf
        y: root.pivotY - root.trackHalf
        width: 2 * (root.wheelR + root.trackHalf)
        height: 2 * (root.wheelR + root.trackHalf)
        radius: root.wheelR + root.trackHalf
        color: "transparent"
        border.width: 2 * root.trackHalf
        border.color: Theme.pSurface
        antialiasing: true
    }

    Rectangle {
        // outer edge
        x: root.cx - root.wheelR - root.trackHalf
        y: root.pivotY - root.trackHalf
        width: 2 * (root.wheelR + root.trackHalf)
        height: 2 * (root.wheelR + root.trackHalf)
        radius: root.wheelR + root.trackHalf
        color: "transparent"
        border.width: 3
        border.color: Theme.pLine
        antialiasing: true
    }

    Rectangle {
        // inner edge
        x: root.cx - root.wheelR + root.trackHalf - 3
        y: root.pivotY + root.trackHalf - 3
        width: 2 * (root.wheelR - root.trackHalf + 3)
        height: 2 * (root.wheelR - root.trackHalf + 3)
        radius: root.wheelR - root.trackHalf + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.pLine
        antialiasing: true
    }

    // The clock's beat diamonds set into the track, one between every two pictures.
    // They turn with the wheel; the two either side of the front picture are
    // lit (and pop as they light), so each picture that comes round is a beat.
    Repeater {
        model: 10

        delegate: DiamondDot {
            id: beat

            required property int index

            readonly property real fracP: root.pos - Math.floor(root.pos)
            readonly property real deg: (beat.index - 5 + 0.5 - beat.fracP) * root.stepDeg
            readonly property real ang: beat.deg * Math.PI / 180

            x: root.cx + root.wheelR * Math.sin(beat.ang) - width / 2
            y: root.hubY - root.wheelR * Math.cos(beat.ang) - height / 2
            size: 12
            lit: Math.abs(beat.deg) < root.stepDeg * 0.75
            litColor: root.markColor
            offColor: Theme.pSurfaceHover
            lineColor: Theme.pLine
        }
    }

    // ===== the gondolas =====
    Repeater {
        id: gondolas

        model: 9

        delegate: Item {
            id: gon

            required property int index

            // A gondola keeps its picture for as long as that picture is on the
            // wheel: slot k always takes the places k, k + 9, k - 9 ... of the
            // endless row, whichever of those is nearest the top. So a picture
            // moving across the screen never changes gondola, and the only
            // time one is handed a new picture is at the far edge, out of sight.
            readonly property int logical: gon.index + 9 * Math.round((root.pos - gon.index) / 9)
            readonly property real d: gon.logical - root.pos
            readonly property real near: Math.abs(gon.d)
            readonly property bool valid: root.count > 0
                                          && (root.wrapping || (gon.logical >= 0 && gon.logical < root.count))
            readonly property int itemIndex: gon.valid ? root.mod(gon.logical, root.count) : -1
            readonly property var entry: gon.valid ? root.items[gon.itemIndex] : null
            readonly property string path: gon.entry ? (gon.entry.filePath || "") : ""

            readonly property bool front: gon.near < 0.5
            readonly property bool applied: gon.path !== "" && gon.path === root.currentPath
            readonly property bool other: root.otherPath !== "" && gon.path === root.otherPath
            readonly property bool video: gon.path !== "" && WallpaperService.isVideo(gon.path)
            // Not while the wheel is moving: pictures sliding under a still mouse would
            // otherwise lift and drop one after another.
            readonly property bool hot: area.containsMouse && gon.visible && root.rested

            // where it hangs from
            readonly property real th: gon.d * root.stepDeg * Math.PI / 180

            // its tape (colour and angle), the same as on the wallpaper board
            readonly property int variant: gon.entry ? root.variantFor(gon.entry.fileName || "") : 0
            readonly property real tapeTilt: (((gon.variant * 3) % 7) - 3) * 2.2
            readonly property real tapeShift: ((gon.variant % 5) - 2) * 9

            // The front picture's cyan edge: fades in over the last stretch
            // before it is in front (a hard switch at the half-way mark made
            // the edges blink as pictures went by).
            readonly property real glow: Math.max(gon.hot ? 1 : 0, 1 - Math.min(1, gon.near * 2))

            // a hop when the wheel comes to rest on it, like the clock's digits
            // (only then: pictures going past would otherwise all hop)
            property real popK: 1

            // The full-size picture, for the one in front once the wheel has
            // rested. Kept while it moves away (so it doesn't drop back to the
            // blurrier thumbnail the moment the wheel moves) and let go once
            // it is well away.
            property bool sharpOn: false
            onNearChanged: {
                if (gon.near > 1.4 && gon.sharpOn)
                    gon.sharpOn = false
            }

            Connections {
                target: root

                function onRestedChanged() {
                    if (!root.rested || !gon.valid || gon.near >= 0.25)
                        return
                    if (!gon.video && gon.path !== "")
                        gon.sharpOn = true
                    popAnim.restart()
                }
            }

            NumberAnimation {
                id: popAnim
                target: gon
                property: "popK"
                from: 1.07
                to: 1
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }

            width: root.cardW
            height: root.hang + root.cardH + 14
            // The bolt is the pivot: placing, growing and swinging
            // are all about it.
            x: root.cx + root.wheelR * Math.sin(gon.th) - width / 2
            y: root.hubY - root.wheelR * Math.cos(gon.th)
            transformOrigin: Item.Top
            scale: root.scaleFor(gon.d) * gon.popK
            rotation: root.swing
            z: 100 - gon.near * 10
            visible: gon.valid && gon.near < 3.2
            opacity: Math.max(0, Math.min(1, (3.2 - gon.near) / 0.8))

            // pushes into its shadow while pressed, lifts a hair when hot
            readonly property real push: area.pressed ? 6 : (gon.hot && gon.front ? -2 : 0)

            // the two wires, like a picture hung on its frame wire: from the bolt
            // on the track down to where the tape holds each end (they end on the
            // body's own, animated, position so they stay with it when it is pressed)
            Repeater {
                model: [-1, 1]

                delegate: Rectangle {
                    id: wire

                    required property int modelData

                    readonly property real endX: gon.width / 2 + wire.modelData * root.wireDx + body.x
                    readonly property real endY: body.y + 4
                    readonly property real dx: wire.endX - gon.width / 2

                    x: gon.width / 2 - width / 2
                    y: 0
                    width: 3
                    height: Math.sqrt(wire.dx * wire.dx + wire.endY * wire.endY)
                    transformOrigin: Item.Top
                    // turned clockwise by this much, the line that points straight
                    // down ends dx to the left; so the left wire (dx < 0) turns +
                    rotation: -Math.atan2(wire.dx, wire.endY) * 180 / Math.PI
                    color: Theme.pLine
                    antialiasing: true
                }
            }

            // the picture's hard shadow, then the picture
            Rectangle {
                x: 10
                y: root.hang + 10
                width: root.cardW
                height: root.cardH
                radius: 22
                color: Theme.pLineShadow
            }

            Rectangle {
                id: body

                x: gon.push
                y: root.hang + gon.push
                width: root.cardW
                height: root.cardH
                radius: 22
                color: Theme.pSurface
                border.width: 5
                border.color: Qt.tint(Theme.pLine, Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, gon.glow))

                Behavior on x {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                // The picture sits in a white frame, like the board's cards:
                // its corners concentric with the card's own.
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 11
                    radius: 11
                    color: Theme.pSurfaceHover

                    Image {
                        id: thumb

                        anchors.fill: parent
                        source: gon.valid ? WallpaperService.thumbUrl(gon.path) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Math.ceil((root.cardW - 22) * root.renderScale * 2)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }
                    }

                    // The picture itself, for the one in front once the wheel
                    // has stopped (the cached thumbnail is smaller than it).
                    Image {
                        id: sharp

                        anchors.fill: parent
                        source: gon.sharpOn && gon.valid && gon.path !== "" ? "file://" + gon.path : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Math.ceil((root.cardW - 22) * root.renderScale * 2)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 220 }
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        size: 56
                        name: gon.video ? "movie" : "image"
                        color: Theme.pInkSub
                    }

                    // the further round, the paler
                    Rectangle {
                        anchors.fill: parent
                        color: "#ffffff"
                        opacity: Math.min(0.5, gon.near * 0.32)
                    }

                    // a hairline, so a pale picture still has an edge against its frame
                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.pLine
                        opacity: 0.35
                        antialiasing: true
                    }

                    // a video wears a play badge
                    Rectangle {
                        visible: gon.video
                        x: parent.width - width - 14
                        y: parent.height - height - 14
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.pSurface
                        border.width: 3
                        border.color: Theme.pLine

                        MaterialIcon {
                            anchors.centerIn: parent
                            size: 24
                            name: "play_arrow"
                            color: Theme.colBorder
                        }
                    }
                }

                // "this is the one that's applied": a ring round the card, in
                // the side's colour inside a navy one, as on the board ...
                Rectangle {
                    visible: gon.applied
                    anchors.fill: parent
                    anchors.margins: -6
                    radius: 28
                    color: "transparent"
                    border.width: 4
                    border.color: root.markColor
                    antialiasing: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 31
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.pLine
                        antialiasing: true
                    }
                }

                // ... and a check badge on its top-right corner
                Rectangle {
                    visible: gon.applied
                    x: parent.width - 26
                    y: -22
                    width: 46
                    height: 46
                    radius: 23
                    border.width: 3
                    border.color: Theme.pLine
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.markA }
                        GradientStop { position: 1.0; color: root.markColor }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 28
                        name: "check"
                        weight: 700
                        color: Theme.colBorder
                    }
                }

                // "... and also the other side's": a tilted sticker on the
                // picture's corner, clear of the tape.
                Item {
                    visible: gon.other
                    x: 22
                    y: 22
                    width: otherRow.width + 24
                    height: 34
                    rotation: -3

                    Rectangle {
                        x: 3
                        y: 3
                        width: parent.width
                        height: parent.height
                        radius: 17
                        color: Theme.pLineShadow
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 17
                        color: root.otherColor
                        border.width: 3
                        border.color: Theme.pLine
                        antialiasing: true

                        Row {
                            id: otherRow

                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.lockMode ? "desktop_windows" : "lock"
                                size: 20
                                weight: 650
                                color: Theme.colBorder
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.lockMode ? "Desktop" : "Lockscreen"
                                color: Theme.colBorder
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }
                        }
                    }
                }
            }

            // a strip of washi tape over each wire end, in two of the board's
            // colours; the same pair as the board gives this wallpaper
            Repeater {
                model: [-1, 1]

                delegate: WashiTape {
                    required property int modelData

                    x: gon.width / 2 + modelData * root.wireDx - width / 2 + body.x
                    y: body.y - 12
                    width: 70
                    height: 26
                    rotation: modelData * -8 + gon.tapeTilt * 0.6
                    color: root.tapeColors[(gon.variant + (modelData > 0 ? 1 : 0)) % 4]
                }
            }

            // a star on the front picture's corner, like the ones on the screen's backdrop
            MaterialIcon {
                x: -16 + body.x
                y: body.y - 28
                size: 44
                name: "star"
                rotation: -14
                color: Theme.attributeColors[2]
                opacity: Math.max(0, 1 - gon.near * 2.4)
            }

            // the bolt the wires hang from, set in the track: lit on the one in front
            Rectangle {
                x: gon.width / 2 - 11
                y: -11
                width: 22
                height: 22
                radius: 11
                color: Qt.tint(Theme.pSurface, Qt.rgba(root.markColor.r, root.markColor.g, root.markColor.b,
                                                       1 - Math.min(1, gon.near * 1.6)))
                border.width: 3
                border.color: Theme.pLine
                antialiasing: true

                // the small round head of the bolt
                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.pLine
                }
            }

            // A sibling of the body, not inside it: the body moves while pressed
            // and a MouseArea riding along would slide out from under a click.
            MouseArea {
                id: area

                x: 0
                y: root.hang
                width: root.cardW
                height: root.cardH
                enabled: root.active
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (gon.front)
                        root.opened(gon.itemIndex)
                    else
                        root.turnTo(gon.logical)
                }
            }
        }
    }

    // ===== under the front picture =====
    // Nothing here dims or moves while the wheel turns: the keys stay put and
    // only the name, counter and tags change (a beat after the wheel).
    Item {
        id: info

        x: 0
        y: root.pivotY + root.hang + root.cardH + 22
        width: root.width
        height: root.height - info.y
        visible: root.count > 0
        z: 200

        // The name, as the clock's sticker text: it hops each time it changes.
        StickerText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            text: root.shortName(root.shownName)
            pixelSize: 27
            fillColor: root.markColor
        }

        // The counter stays in the middle; the "On your ..." tags fade in on
        // either side of it, so nothing slides about when they come and go.
        Item {
            id: tagRow

            y: 50
            width: parent.width
            height: 44

            Tag {
                id: countTag

                x: root.cx - width / 2
                text: (root.shownIndex + 1) + " / " + root.count
            }

            Tag {
                x: countTag.x + countTag.width + 12
                text: "On your desktop"
                lit: true
                opacity: root.shownPath !== "" && root.shownPath === root.desktopPath ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }

            Tag {
                x: countTag.x - 12 - width
                text: "On your lockscreen"
                lit: true
                litA: LockPalette.pink
                litB: LockPalette.mint
                opacity: root.shownPath !== "" && root.shownPath === root.lockPath ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }
        }

        Row {
            id: keys

            y: 100
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22

            WallpaperActionKey {
                capW: 320
                capH: 64
                icon: "desktop_windows"
                label: "Set as Desktop"
                done: root.justSet === "desktop"
                onClicked: all => root.setDesktopRequested(root.shownPath, all)
            }

            WallpaperActionKey {
                capW: 320
                capH: 64
                icon: "lock"
                label: "Set as Lockscreen"
                done: root.justSet === "lock"
                onClicked: all => root.setLockRequested(root.shownPath, all)
            }
        }

        SekaiNavKey {
            x: root.cx - keys.width / 2 - 20 - width
            y: keys.y + (keys.height - height) / 2
            icon: "chevron_left"
            label: "Previous"
            onClicked: root.stepBy(-1)
        }

        SekaiNavKey {
            x: root.cx + keys.width / 2 + 20
            y: keys.y + (keys.height - height) / 2
            icon: "chevron_right"
            label: "Next"
            onClicked: root.stepBy(1)
        }
    }

    // A small leaning plate, like the Settings' keys: the counter and the
    // "On your ..." tags. `lit` washes it in the side's colours (litA -> litB,
    // the desktop's cyan -> mint unless told otherwise).
    component Tag: Item {
        id: tag

        property string text: ""
        property bool lit: false
        property color litA: Theme.accentMint
        property color litB: Theme.accentCyan

        implicitWidth: tagKey.capW + 7
        implicitHeight: tagKey.capH + 4

        SekaiKey {
            id: tagKey

            capW: tagLabel.implicitWidth + 40
            capH: 40
            radius: 15
            lit: tag.lit
            ringExtra: 4
            borderBase: 3
            borderLit: 3
            shadowBaseX: 3
            shadowBaseY: 3
            litGradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: tag.litA }
                GradientStop { position: 1.0; color: tag.litB }
            }

            Text {
                id: tagLabel

                anchors.centerIn: parent
                text: tag.text
                color: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, tagKey.litP))
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }
}

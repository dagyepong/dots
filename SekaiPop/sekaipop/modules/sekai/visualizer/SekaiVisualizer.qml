import QtQuick
import qs.services
import "KeyBedMath.js" as KB
import qs.modules.common
import qs.modules.common.widgets

// The desktop audio visualizer's picture: a pocket player whose screen is a
// sheet of keycaps with the album cover printed on it, and the music PRESSES
// the keys instead of lighting them.
//
//   the key-bed   a lattice of springs (KeyBedMath.js). Every key is a mass tied
//                 to its neighbours: a key that is pushed goes down into its hard
//                 shadow, pulls the keys around it after it, bounces back past
//                 rest and sends the dent out as a ripple. Raised keys catch the
//                 light and throw a longer shadow, pressed ones go dark and small.
//                   kick        a drum-head press in the middle, a ring runs out
//                   snare       a slap: a line of presses sweeps across, then back
//                   hi-hat      a tiny sharp tap high up, the key glints
//                   bass note   a dent at its pitch along the bottom
//                   voice       a green finger that follows the singer's pitch,
//                               pressing steadily as it travels
//                   spectrum    twelve little diamonds along the foot are emitters,
//                               one per lane (low on the left): each rocks the
//                               sheet at its own speed, so the wavelength you see
//                               is the pitch you hear and quiet lanes stay quiet
//   the cover     the keys are coloured from the album art (a mosaic, the sides
//                 mirrored). A new track re-keys the sheet: a wave of presses runs
//                 out from the middle and each key swaps colour at the bottom of its
//                 press. Without art the keys wear the Sekai attribute colours or the
//                 theme's two accents (Settings -> Desktop -> Visualizer colors).
//   playback      paused, the sheet settles, the colours sleep under a veil and the
//                 play key is up; playing, the veil lifts and the key goes down lit.
//   the deck      previous / play / next as real keycaps (the same press and spring
//                 as every pill), and a lane with a diamond playhead. Press and drag the lane to seek.
//   the surface   it is a toy as much as a display: press and drag on the keys and
//                 they go down under your finger and spring up when you let go;
//                 double-click plays / pauses; right-click is next, middle-click
//                 previous (the sheet slaps in that direction); the wheel is the
//                 player's volume (the bottom row of keys rises as far as it reaches).
//   the tag       a sticker with the title and the artist is stuck on when the
//                 track changes, and peeled off a few seconds later (hover to bring
//                 it back).
//
// A critical hit (a big accent) also throws a gold star sticker, the way the
// clock's digits do. It draws from VisualizerEngine (levels, hits, the lead tone) and
// does no work while the sheet is at rest. No shader, nothing to compile.
Item {
    id: root

    required property VisualizerEngine engine
    // The player behind the cover, the tag and the keys (MediaSource.qml), or null.
    property var media: null
    // False while Edit Desktop moves the card: no presses, no clicks.
    property bool interactive: true
    // false while the widget is switched off or folded away: nothing here may tick then
    property bool active: true

    readonly property int perf: VisualizerService.perf
    readonly property bool flatKeys: root.perf >= 2
    readonly property var cellMins: [16.5, 19, 23]
    readonly property var keyBudgets: [330, 240, 150]

    // 0 the cover's own colours (the Sekai pattern while there is none),
    // 1 the five card attributes, 2 the theme's two accents.
    readonly property int colorMode: VisualizerService.colorMode
    readonly property var attr: Theme.attributeColors

    readonly property var player: root.media ? root.media.player : null
    readonly property bool hasPlayer: root.media ? root.media.present : false
    readonly property bool playing: root.media ? root.media.playing : root.engine.fade > 0.08
    readonly property string artUrl: root.media ? root.media.artUrl : ""
    readonly property string title: root.media ? root.media.title : ""
    readonly property string artist: root.media ? root.media.artist : ""

    // The game's gold, for the critical star; the green of the slide, for the voice.
    readonly property color cCrit: "#ffd640"
    readonly property color cVoice: "#3de085"

    // ===== colours of the screen =====
    readonly property color well: Theme.colBorder
    readonly property color wellDeep: Theme.colDeep
    readonly property color keyShadow: Qt.rgba(wellDeep.r, wellDeep.g, wellDeep.b, 0.92)

    // ===== geometry =====
    readonly property bool compact: width < 290
    // The same hard shadow as the To-Do card: straight down, Theme.shadowOffset.
    readonly property real shDx: 0
    readonly property real shDy: Theme.shadowOffset
    readonly property real pad: 14
    readonly property real deckH: compact ? 36 : 40
    readonly property real deckGap: 12
    readonly property real screenX: pad
    readonly property real screenY: pad
    readonly property real screenW: width - shDx - 2 * pad
    readonly property real screenH: Math.max(60, height - shDy - 2 * pad - deckH - deckGap)
    readonly property real bedMargin: 8
    readonly property real footH: 14                 // room under the keys for the emitter diamonds
    readonly property real bedW: screenW - 2 * bedMargin
    readonly property real bedH: screenH - 2 * bedMargin - footH + 6
    readonly property real cellTarget: Math.max(root.cellMins[root.perf] ?? 16.5,
        Math.sqrt(bedW * bedH / (root.keyBudgets[root.perf] ?? 330)))
    readonly property int cols: Math.max(6, Math.round(bedW / cellTarget))
    readonly property int rows: Math.max(4, Math.round(bedH / cellTarget))
    readonly property real kw: bedW / cols
    readonly property real kh: bedH / rows
    readonly property real bedX: screenX + bedMargin
    readonly property real bedY: screenY + bedMargin
    // The cover takes the middle of the sheet at about 1.2 : 1; the rest is mirrored.
    readonly property int coverCols: Math.min(cols, Math.max(4, Math.round(rows * 1.2)))
    readonly property real tx: Math.max(1.2, Math.min(kw, kh) * 0.085)      // shadow offset, x
    readonly property real ty: tx * 1.6                                      // shadow offset, y
    readonly property real gap: 1.1
    readonly property real capW: kw - gap - tx
    readonly property real capH: kh - gap - ty
    readonly property real capR: Math.min(capW, capH) * 0.3

    // ===== the sheet =====
    property var bed: KB.create(cols, rows)
    property var keyColors: []              // one [r, g, b, wing] per key
    property var coverCells: null         // coverCols x rows tuned [r, g, b], from the album art
    property bool awake: false
    property bool pointerDown: false
    property double voiceSeen: 0
    property real voiceLane: 6
    property int starHead: 0
    property real fingerX: 0
    property real fingerY: 0
    property real fingerAmp: 0

    // Sleep veil: 0 playing, 1 paused.
    property real sleepAmt: root.playing ? 0 : 1
    Behavior on sleepAmt {
        NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
    }

    onColsChanged: root.rebuild()
    onRowsChanged: root.rebuild()
    onColorModeChanged: {
        if (root.colorMode === 0)
            root.sample()
        root.refreshPalette(true)
    }

    Connections {
        target: Theme

        function onAccentCyanChanged() { root.refreshPalette(false) }
        function onAccentMintChanged() { root.refreshPalette(false) }
    }

    Component.onCompleted: root.rebuild()

    function rebuild() {
        root.bed = KB.create(root.cols, root.rows)
        root.coverCells = null
        root.refreshPalette(false)
        root.sample()
    }

    // ===== colours of the keys =====
    function colorOf(c) {
        return Qt.rgba(c[0], c[1], c[2], 1)
    }

    function patternAt(i) {
        const col = i % root.cols
        const row = Math.floor(i / root.cols)
        if (root.colorMode === 2) {
            const t = Math.max(0, Math.min(1, col / Math.max(1, root.cols - 1) * 0.65 + row / Math.max(1, root.rows - 1) * 0.35))
            const a = Theme.accentCyan, b = Theme.accentMint
            const k = ((col + row) % 2 === 0) ? 1.0 : 0.93
            return [(a.r + (b.r - a.r) * t) * k, (a.g + (b.g - a.g) * t) * k, (a.b + (b.b - a.b) * t) * k, 0]
        }
        const c = Qt.color(root.attr[(col + 2 * row) % root.attr.length])
        return [c.r, c.g, c.b, 0]
    }

    // Rebuild the colour of every key. `sweep`: re-key with the wave instead of at once.
    function refreshPalette(sweep) {
        const n = root.cols * root.rows
        let pal
        if (root.colorMode === 0 && root.coverCells !== null) {
            pal = KB.layCover(root.coverCells, root.coverCols, root.rows, root.cols, root.rows)
        } else {
            pal = new Array(n)
            for (let i = 0; i < n; i++)
                pal[i] = root.patternAt(i)
        }
        root.keyColors = pal
        if (sweep && root.visible && keys.count === n) {
            KB.rekey(root.bed)
            root.awake = true
        } else {
            for (let i = 0; i < n; i++) {
                const k = keys.itemAt(i)
                if (k)
                    k.setBase(root.paint(i))
            }
        }
    }

    // The key's colour: the palette's, with the mirrored sides washed towards the screen.
    function paint(i) {
        const c = root.keyColors[i]
        if (!c)
            return root.well
        const col = root.colorOf(c)
        return c[3] > 0 ? Qt.tint(col, Qt.rgba(root.well.r, root.well.g, root.well.b, 0.38)) : col
    }

    // ===== the cover =====
    Image {
        id: art
        source: root.artUrl
        visible: false
        asynchronous: true
        sourceSize: Qt.size(192, 192)
        fillMode: Image.PreserveAspectFit
        onStatusChanged: root.sample()
    }

    function sample() {
        if (root.colorMode !== 0)
            return
        if (art.status === Image.Ready)
            sampler.begin()
        else if (art.status === Image.Null && root.coverCells !== null) {
            // the track has no art any more: back to the pattern
            root.coverCells = null
            root.refreshPalette(true)
        }
    }

    // The Image above has already fetched the art (a file, or a web address that
    // the player gave us), so the canvas draws that item. If a build of Qt will not
    // draw an item into a canvas (a blank result), it loads the address itself.
    Canvas {
        id: sampler
        readonly property int over: 4
        width: root.coverCols * over
        height: root.rows * over
        opacity: 0
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        property url src: ""
        property bool viaUrl: false

        function begin() {
            sampler.src = art.source
            if (sampler.src.toString() === "")
                return
            if (sampler.viaUrl && !sampler.isImageLoaded(sampler.src))
                sampler.loadImage(sampler.src)
            else
                sampler.requestPaint()
        }

        onImageLoaded: requestPaint()

        onPaint: {
            if (src.toString() === "")
                return
            if (viaUrl && !isImageLoaded(src))
                return
            const iw = art.implicitWidth
            const ih = art.implicitHeight
            if (iw <= 0 || ih <= 0)
                return
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            let dw = width
            let dh = width * ih / iw
            if (dh < height) {
                dh = height
                dw = height * iw / ih
            }
            let px = null
            try {
                ctx.drawImage(viaUrl ? src : art, (width - dw) / 2, (height - dh) / 2, dw, dh)
                px = ctx.getImageData(0, 0, width, height).data
            } catch (e) {
                px = null
            }
            let seen = false
            if (px !== null) {
                for (let k = 3; k < px.length; k += 4) {
                    if (px[k] > 0) {
                        seen = true
                        break
                    }
                }
            }
            if (!seen) {
                // nothing came out: try the other way once
                if (!viaUrl) {
                    viaUrl = true
                    loadImage(src)
                }
                return
            }
            const cw = root.coverCols
            const ch = root.rows
            const cells = []
            const o = sampler.over
            for (let cy = 0; cy < ch; cy++) {
                for (let cx = 0; cx < cw; cx++) {
                    let r = 0, g = 0, b = 0, n = 0
                    for (let yy = 0; yy < o; yy++) {
                        for (let xx = 0; xx < o; xx++) {
                            const k = ((cy * o + yy) * width + (cx * o + xx)) * 4
                            if (px[k + 3] === 0)
                                continue
                            // average the squares, so a bright spot is not muddied
                            r += px[k] * px[k]
                            g += px[k + 1] * px[k + 1]
                            b += px[k + 2] * px[k + 2]
                            n++
                        }
                    }
                    if (n === 0) {
                        cells.push([0.5, 0.5, 0.5])
                        continue
                    }
                    cells.push(KB.tuneColor(Math.sqrt(r / n) / 255, Math.sqrt(g / n) / 255, Math.sqrt(b / n) / 255))
                }
            }
            root.coverCells = cells
            root.refreshPalette(true)
        }
    }

    // ===== hits from the engine =====
    readonly property bool named: root.engine.analyzer || root.engine.demo

    // The fastest each kind may press again (ms), so a burst of hats is a patter and
    // not a wall.
    readonly property var gaps: ({ kick: 70, snare: 110, hat: 55, bass: 110 })
    property var lastAt: ({ kick: 0, snare: 0, hat: 0, bass: 0 })

    function press(kind, lane, strength) {
        const now = Date.now()
        const gap = root.gaps[kind]
        if (gap !== undefined) {
            if (now - root.lastAt[kind] < gap)
                return
            root.lastAt[kind] = now
        }
        // Lift the quiet end: a soft hit still reads, a loud one is the biggest.
        KB.hit(root.bed, kind, lane, Math.min(1, 0.4 + 0.8 * strength))
        root.awake = true
    }

    function listen(kind, strength, lane) {
        if (kind === "k")
            root.press("kick", lane, strength)
        else if (kind === "s")
            root.press("snare", lane, strength)
        else if (kind === "h")
            root.press("hat", lane, strength)
        else if (kind === "b")
            root.press("bass", lane, strength)
    }

    function hit(lane, width, code) {
        if (code <= 0)
            return
        const type = Math.floor(code)
        const strength = Math.max(0, Math.min(1, code - type))
        if (type > 2)          // 3 = the slide's head note: the green finger shows that
            return
        let kind
        if (type === 2)
            kind = "crit"
        else if (root.named)   // heard it already, whole
            return
        else if (type === 1)
            kind = "hat"
        else if (lane < 4.5)
            kind = width > 2 ? "kick" : "bass"   // a kick is 2.6 wide, a bass note 1.3
        else if (lane < 8.5)
            kind = "snare"
        else
            kind = "hat"
        if (kind === "crit") {
            KB.hit(root.bed, kind, lane, strength)
            root.lastAt.kick = Date.now()
        } else {
            root.press(kind, lane, strength)
        }
        root.awake = true
        if (kind === "crit") {
            const s = stars.itemAt(root.starHead)
            root.starHead = (root.starHead + 1) % 3
            if (s)
                s.fire(root.bedX + root.bedW / 2 + (root.starHead - 1) * root.bedW * 0.18, root.bedY + root.bedH * 0.5, strength)
        }
    }

    Connections {
        target: root.engine
        // The engine may keep running with the card away (Desktop Focus Mode, background
        // listening); there is nothing to put a sticker on then.
        enabled: root.active

        function onNoteSpawned(slot, lane, width, t0, code) {
            root.hit(lane, width, code)
        }

        function onHeard(kind, strength, lane) {
            root.listen(kind, strength, lane)
        }

        function onRibbonWritten(slot, x, w, pulse, t0) {
            if (w > 0) {
                root.voiceLane = x
                root.voiceSeen = Date.now()
            }
        }

        function onCleared() {
            root.voiceSeen = 0
        }
    }

    // ===== the loop =====
    function advance(dt) {
        const b = root.bed
        KB.voiceSet(b, Date.now() - root.voiceSeen < 240, root.voiceLane)
        const out = KB.step(b, dt, { levels: root.engine.levels, bass: root.engine.bass })
        const P = b.p
        const G = b.g
        for (let j = 0; j < out.swapped.length; j++) {
            const k = keys.itemAt(out.swapped[j])
            if (k)
                k.setBase(root.paint(out.swapped[j]))
        }
        for (let j = 0; j < out.dirty.length; j++) {
            const i = out.dirty[j]
            const k = keys.itemAt(i)
            if (k) {
                k.d = P[i]
                k.g = G[i]
            }
        }
        root.awake = out.awake
        root.fingerX = (b.voice.x + 0.5) * root.kw
        root.fingerY = (b.voice.y + 0.5) * root.kh
        root.fingerAmp = b.voice.amp
        const L = root.engine.levels
        for (let i = 0; i < 12; i++) {
            const e = emitters.itemAt(i)
            if (e)
                e.lvl = L[i]
        }
    }

    FrameAnimation {
        property real acc: 0

        running: root.visible && root.active && (root.awake || root.pointerDown || root.engine.fade > 0.003)
        onTriggered: {
            acc += frameTime
            if (acc < VisualizerService.frameGap)
                return
            root.advance(Math.min(0.05, acc))
            acc = 0
        }
    }

    // ===== The body =====
    Pill {
        anchors.fill: parent
        shadowDx: root.shDx
        shadowDy: root.shDy
        cornerRadius: Theme.radiusOuter
        ringWidth: Theme.borderWidth + Theme.outerRingWidth
        ringColorTop: Theme.pSurfaceRing
        ringColorBottom: ringColorTop
        fillColor: Theme.pSurface
    }

    // ===== the screen =====
    Item {
        id: screen
        x: root.screenX
        y: root.screenY
        width: root.screenW
        height: root.screenH

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: root.well
            border.width: 3
            border.color: root.wellDeep
            antialiasing: true
        }

        // The screen is set into the body: a shade down from the top edge.
        Rectangle {
            x: 3
            y: 3
            width: parent.width - 6
            height: 16
            radius: 7
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.wellDeep.r, root.wellDeep.g, root.wellDeep.b, 0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // The foot: twelve emitters, one per lane. Each lights and pops with its lane.
    Repeater {
        id: emitters
        model: 12

        delegate: Rectangle {
            id: em
            required property int index
            property real lvl: 0
            readonly property real d: root.compact ? 6 : 7
            readonly property bool on: lvl > 0.12

            x: root.bedX + (index + 0.5) / 12 * root.bedW - d / 2
            y: root.bedY + root.bedH + 5
            width: d
            height: d
            radius: 2
            rotation: 45
            color: on ? "#ffffff" : Qt.rgba(1, 1, 1, 0.2)
            border.width: on ? 1.5 : 0
            border.color: root.cVoice
            scale: on ? 0.95 + lvl * 0.5 : 0.72

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            }
        }
    }

    // ===== the keys =====
    Repeater {
        id: keys
        model: root.cols * root.rows

        onItemAdded: (index, item) => item.setBase(root.paint(index))

        delegate: Item {
            id: key
            required property int index

            property real d: 0          // + pressed, - raised
            property real g: 0          // glint
            property color base: root.well

            function setBase(c) {
                key.base = c
            }

            x: root.bedX + (index % root.cols) * root.kw
            y: root.bedY + Math.floor(index / root.cols) * root.kh
            width: root.kw
            height: root.kh

            // the hard shadow: fixed, the cap either covers it or leaves it showing
            Rectangle {
                x: root.gap / 2 + root.tx
                y: root.gap / 2 + root.ty
                width: root.capW
                height: root.capH
                radius: root.capR
                color: root.keyShadow
                antialiasing: true
            }

            Rectangle {
                id: cap
                readonly property real travel: Math.max(-1.25, Math.min(1.1, key.d))
                x: root.gap / 2 + travel * root.tx * 0.92
                y: root.gap / 2 + travel * root.ty * 0.92
                width: root.capW
                height: root.capH
                radius: root.capR
                antialiasing: true
                scale: 1 - 0.12 * travel
                transformOrigin: Item.Center

                // Every key has its own colours, so every gradient is its own texture and its
                // own draw call (about 330 of them). Lite paints the plain colour instead.
                color: key.base
                gradient: root.flatKeys ? null : capGradient

                Gradient {
                    id: capGradient
                    GradientStop { position: 0.0; color: Qt.lighter(key.base, 1.14) }
                    GradientStop { position: 1.0; color: key.base }
                }

                // light on a raised key, shade on a pressed one, white on a glint
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    antialiasing: true
                    color: key.g > 0.02 || key.d < 0 ? "#ffffff" : root.wellDeep
                    opacity: key.g > 0.02
                        ? Math.min(0.85, Math.max(key.g * 0.8, -key.d * 0.2))
                        : (key.d < 0 ? Math.min(0.3, -key.d * 0.22) : Math.min(0.4, key.d * 0.3))
                }
            }
        }
    }

    // Paused: the colours sleep.
    Rectangle {
        x: root.bedX - 2
        y: root.bedY - 2
        width: root.bedW + 4
        height: root.bedH + 4
        radius: 5
        color: root.well
        opacity: 0.5 * root.sleepAmt
        visible: opacity > 0.01
    }

    // ===== the green finger =====
    Item {
        id: finger
        x: root.bedX + root.fingerX
        y: root.bedY + root.fingerY - 10 - 3 * root.fingerAmp
        width: 1
        height: 1
        visible: root.fingerAmp > 0.03
        scale: Math.min(1.1, root.fingerAmp * 1.3)

        Rectangle {
            x: -11 + 2
            y: -11 + 6
            width: 22
            height: 22
            radius: 11
            color: root.wellDeep
            opacity: 0.8
        }

        Rectangle {
            x: -11
            y: -11
            width: 22
            height: 22
            radius: 11
            color: root.cVoice
            border.width: 2.5
            border.color: "#ffffff"

            MaterialIcon {
                anchors.centerIn: parent
                name: "music_note"
                size: 14
                weight: 700
                fill: 1
                color: root.wellDeep
            }
        }
    }

    // ===== the gold star =====
    Repeater {
        id: stars
        model: 3

        delegate: Item {
            id: star
            property real t: 1
            property real pop: 0
            property real power: 0.5
            property real tilt: 0
            readonly property real sz: 24 + power * 12

            width: 1
            height: 1
            visible: star.t < 1

            function fire(cx, cy, p) {
                star.x = cx
                star.y = cy
                star.power = p
                star.tilt = (root.starHead % 2 === 0 ? -1 : 1) * (8 + p * 12)
                floatAnim.restart()
                popAnim.restart()
            }

            NumberAnimation {
                id: floatAnim
                target: star
                property: "t"
                from: 0
                to: 1
                duration: 900
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: popAnim
                target: star
                property: "pop"
                from: 0.3
                to: 1
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 2.8
            }

            Item {
                y: -star.t * 30
                scale: star.pop
                rotation: star.tilt
                opacity: star.t < 0.55 ? 1 : Math.max(0, (1 - star.t) / 0.45)

                MaterialIcon { x: -width / 2 + 2; y: -height / 2 + 3; name: "star"; fill: 1; weight: 700; size: star.sz + 10; color: root.wellDeep }
                MaterialIcon { x: -width / 2; y: -height / 2; name: "star"; fill: 1; weight: 700; size: star.sz + 10; color: Theme.colBorder }
                MaterialIcon { x: -width / 2; y: -height / 2; name: "star"; fill: 1; weight: 700; size: star.sz + 5; color: "#ffffff" }
                MaterialIcon { x: -width / 2; y: -height / 2; name: "star"; fill: 1; weight: 700; size: star.sz; color: root.cCrit }
            }
        }
    }

    // ===== the surface =====
    function toggle() {
        if (!root.media)
            return
        const was = root.playing
        root.media.togglePlaying()
        // a thunk of the whole sheet either way
        KB.hit(root.bed, "kick", 6, was ? 1 : 0.6)
        root.awake = true
    }

    function skip(dir) {
        if (!root.media)
            return
        if (dir > 0)
            root.media.next()
        else
            root.media.previous()
        KB.slap(root.bed, dir, 1)
        root.awake = true
    }

    MouseArea {
        id: surface
        x: root.bedX
        y: root.bedY
        width: root.bedW
        height: root.bedH
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        function cell(v, size, count) {
            return Math.max(0, Math.min(count - 1, v / size - 0.5))
        }

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.pointerDown = true
                KB.pointerSet(root.bed, true, cell(mouse.x, root.kw, root.cols), cell(mouse.y, root.kh, root.rows))
                root.awake = true
            }
        }

        onPositionChanged: mouse => {
            if (root.pointerDown)
                KB.pointerSet(root.bed, true, cell(mouse.x, root.kw, root.cols), cell(mouse.y, root.kh, root.rows))
        }

        onReleased: mouse => {
            if (root.pointerDown) {
                root.pointerDown = false
                KB.pointerSet(root.bed, false, 0, 0)
                root.awake = true
            }
        }

        onCanceled: {
            if (root.pointerDown) {
                root.pointerDown = false
                KB.pointerSet(root.bed, false, 0, 0)
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.skip(1)
            else if (mouse.button === Qt.MiddleButton)
                root.skip(-1)
        }

        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.toggle()
        }

        onWheel: wheel => {
            if (root.media && root.media.volumeAvailable) {
                const dir = wheel.angleDelta.y > 0 ? 1 : -1
                // the same five points a notch as the media pill; the player reports
                // the new volume a moment later, so show where it is going
                const to = Math.max(0, Math.min(1, (root.player.volume ?? 0) + dir * 0.05))
                root.media.changeVolume(dir)
                KB.volumeShow(root.bed, to)
                root.awake = true
            }
        }
    }

    // ===== the deck =====
    component DeckKey: Item {
        id: dk

        property string icon: "play_arrow"
        property bool lit: false
        property bool enabledKey: true
        property real keyW: 36
        property real keyH: 34
        signal clicked()

        readonly property real sdx: lit ? 3.5 : 2.5
        readonly property real sdy: lit ? 4.5 : 3.5

        width: keyW + 4
        height: keyH + 5
        opacity: enabledKey ? 1 : 0.4

        Pill {
            anchors.fill: parent
            cornerRadius: 12
            borderWidth: dk.lit ? 3 : 2.5
            ringWidth: dk.lit ? 5 : 3
            shadowDx: dk.sdx
            shadowDy: dk.sdy
            pressed: area.pressed && dk.enabledKey
            fillColor: area.containsMouse && dk.enabledKey ? Theme.pSurfaceHover : Theme.pSurface
            fillGradient: dk.lit ? litGrad : null

            Gradient {
                id: litGrad
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }

            MaterialIcon {
                anchors.centerIn: parent
                name: dk.icon
                size: dk.keyW > 44 ? 22 : 19
                fill: 1
                color: dk.lit ? Theme.colBorder : Theme.pInk
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            enabled: dk.enabledKey && root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dk.clicked()
        }
    }

    Row {
        id: deck
        x: root.screenX - 2
        y: root.screenY + root.screenH + root.deckGap - 1
        spacing: 5
        height: root.deckH

        DeckKey {
            icon: "skip_previous"
            keyW: root.compact ? 32 : 36
            enabledKey: root.hasPlayer && (root.player ? root.player.canGoPrevious : false)
            onClicked: root.skip(-1)
        }

        DeckKey {
            icon: root.playing ? "pause" : "play_arrow"
            lit: root.playing
            keyW: root.compact ? 46 : 54
            enabledKey: root.hasPlayer
            onClicked: root.toggle()
        }

        DeckKey {
            icon: "skip_next"
            keyW: root.compact ? 32 : 36
            enabledKey: root.hasPlayer && (root.player ? root.player.canGoNext : false)
            onClicked: root.skip(1)
        }
    }

    // The lane: how much of the track is gone. The same lane as the user card's TODAY.
    Item {
        id: lane
        x: deck.x + deck.width + 10
        y: deck.y
        width: root.screenX + root.screenW - x + 2
        height: root.deckH

        readonly property real length: root.player && root.player.lengthSupported ? Math.max(0, root.player.length) : 0
        readonly property bool seekable: root.player ? (root.player.canSeek && root.player.positionSupported && length > 0) : false
        property real shownFrac: 0
        property bool dragging: false
        property real dragFrac: 0
        readonly property real frac: dragging ? dragFrac : shownFrac

        function fmt(sec) {
            sec = Math.max(0, Math.floor(sec))
            const m = Math.floor(sec / 60)
            const s = sec % 60
            return m + ":" + ("0" + s).slice(-2)
        }

        function readPosition() {
            if (!root.player || length <= 0 || !root.player.positionSupported) {
                shownFrac = 0
                return
            }
            const f = Math.max(0, Math.min(1, root.player.position / length))
            // Players report their position a little unevenly. While it plays the
            // head only goes forward for that; a real seek or a new track still moves it.
            if (root.playing && !dragging && (shownFrac - f) * length > 0 && (shownFrac - f) * length < 2.5)
                return
            shownFrac = f
        }

        Timer {
            running: root.visible && root.active && root.hasPlayer && root.player && root.player.positionSupported
            interval: 450
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (root.playing)
                    root.player.positionChanged()
                lane.readPosition()
            }
        }

        Connections {
            target: root

            function onTitleChanged() { lane.readPosition() }
        }

        Item {
            id: track
            x: 4
            width: parent.width - 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            height: 22

            readonly property real headSize: 13
            readonly property real headX: Math.min(width - headSize, Math.max(0, width * lane.frac - headSize / 2))

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 12
                radius: 6
                color: Theme.pSurfaceDivider
                border.width: 2
                border.color: Theme.pLine
            }

            Rectangle {
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                radius: 4
                width: Math.max(0, track.headX + track.headSize / 2 - 2)

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accentMint }
                    GradientStop { position: 1.0; color: Theme.accentCyan }
                }

                Behavior on width {
                    enabled: !lane.dragging && root.perf === 0
                    NumberAnimation { duration: 440 }
                }
            }

            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    x: track.width * (index + 1) / 4 - 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 12
                    radius: 1.5
                    color: Theme.pLine
                    opacity: 0.45
                }
            }

            // The playhead: a diamond that lifts while you hold it. It does not bounce: no hop on the beat, no overshoot.
            Rectangle {
                id: head
                x: track.headX
                y: (track.height - height) / 2 - (lane.dragging ? 3 : 0)
                width: track.headSize
                height: track.headSize
                radius: 3
                rotation: 45
                scale: lane.dragging ? 1.25 : 1
                color: Theme.accentMint
                border.width: 2
                border.color: Theme.pLine

                Behavior on x {
                    enabled: !lane.dragging && root.perf === 0
                    NumberAnimation { duration: 440 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            // elapsed time, only while you are holding the playhead
            Pill {
                visible: opacity > 0.01
                opacity: lane.dragging ? 1 : 0
                x: Math.max(-4, Math.min(track.width - width + 4, track.headX + track.headSize / 2 - width / 2))
                y: -height - 4
                width: timeText.implicitWidth + 18
                height: 25
                cornerRadius: 8
                borderWidth: 2
                ringWidth: 2.5
                shadowDy: 3
                fillColor: Theme.chipFill

                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: lane.fmt(lane.dragFrac * lane.length)
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: lane.seekable && root.interactive
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function frac(mx) {
                return Math.max(0, Math.min(1, (mx - track.x) / track.width))
            }

            onPressed: mouse => {
                lane.dragFrac = frac(mouse.x)
                lane.dragging = true
            }

            onPositionChanged: mouse => {
                if (lane.dragging)
                    lane.dragFrac = frac(mouse.x)
            }

            onReleased: mouse => {
                if (!lane.dragging)
                    return
                lane.dragging = false
                lane.shownFrac = lane.dragFrac
                root.player.position = lane.dragFrac * lane.length
                // seeking chirps across the keys, the way a scrubbed tape does
                KB.slap(root.bed, 1, 0.7)
                root.awake = true
            }

            onCanceled: lane.dragging = false
        }
    }

    // ===== the tag =====
    property bool tagWanted: false
    property real tagShow: 0
    readonly property bool tagOn: root.tagWanted || hover.hovered

    onTagOnChanged: root.tagShow = root.tagOn ? 1 : 0
    onTitleChanged: {
        if (root.title !== "") {
            root.tagWanted = true
            tagTimer.restart()
        }
    }

    Timer {
        id: tagTimer
        interval: 4800
        onTriggered: root.tagWanted = false
    }

    Behavior on tagShow {
        NumberAnimation {
            duration: root.tagOn ? 460 : 300
            easing.type: root.tagOn ? Easing.OutBack : Easing.InBack
            easing.overshoot: root.tagOn ? 2.2 : 1.6
        }
    }

    HoverHandler {
        id: hover
        enabled: root.interactive
    }

    Pill {
        id: tag

        readonly property real maxText: Math.max(60, root.screenW - 24 - 52)
        readonly property real textW: Math.min(maxText, Math.max(titleText.implicitWidth, artistText.implicitWidth))

        visible: root.title !== "" && root.tagShow > 0.01
        x: root.screenX + 6
        y: root.screenY - 12 - (1 - Math.min(1, root.tagShow)) * 16
        width: textW + 52
        height: 44
        cornerRadius: 13
        borderWidth: 3
        ringWidth: 3.5
        shadowDx: 3
        shadowDy: 4
        rotation: -2.5 + (1 - Math.min(1, root.tagShow)) * 14
        scale: Math.max(0.05, root.tagShow)
        opacity: Math.min(1, root.tagShow * 1.6)
        transformOrigin: Item.TopLeft
        z: 30

        Rectangle {
            x: 11
            y: (tag.capHeight - 3 * 2 - height) / 2 + 3
            width: 10
            height: 10
            radius: 3
            rotation: 45
            color: Theme.accentMint
            border.width: 2
            border.color: Theme.pLine
        }

        Column {
            x: 30
            y: 3
            width: tag.textW
            height: tag.capHeight - 6 * 2 + 4
            spacing: 0

            Item {
                width: 1
                height: root.artist !== "" ? 1 : 7
            }

            Text {
                id: titleText
                width: Math.min(implicitWidth, tag.maxText)
                text: root.title
                elide: Text.ElideRight
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                id: artistText
                width: Math.min(implicitWidth, tag.maxText)
                visible: root.artist !== ""
                text: root.artist
                elide: Text.ElideRight
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
    }
}

import QtQuick
import qs.services
import "PadMath.js" as PM
import qs.modules.common

// The console's screen (460 x 270 design pixels): the equalizer as a rhythm
// game's chart. Ten lanes, one per band, narrowing toward the top like the
// highway; the glowing line through the ten jewels is the curve. DRAG A JEWEL up
// or down (8 px = 1 dB); the wheel moves the lane under the pointer 1 dB, a
// double or right click puts it back to 0. A lane's gain also shows as a hold
// note from the 0 dB line to its jewel, and notes fall in every lane and land on
// the curve while the song plays.
//
// The bar along the top: AUTO (lit while it follows the song's genre), the
// preset's name between two arrows (click the name for the shelf of presets),
// the preamp gauge, and the gear (setup). Pages that open over the chart: the
// shelf, SAVE AS and setup.
Item {
    id: scr

    property real u: 1
    property real renderScale: 1
    property bool animate: false
    property int sel: 4
    property string page: "chart"           // chart | presets | saveas | setup
    signal prevPreset()
    signal nextPreset()

    readonly property var eq: EqualizerService
    readonly property var gains: EqualizerService.bands
    property int dragIdx: -1
    property int hoverIdx: -1
    readonly property int infoIdx: scr.dragIdx >= 0 ? scr.dragIdx : (scr.hoverIdx >= 0 ? scr.hoverIdx : scr.sel)
    property real phase: 0
    readonly property var allPresets: EqualizerService.presetNames.concat(EqualizerService.customNames)

    function d(v) {
        return v * scr.u
    }

    // The SAVE AS page, with the cursor already in the name field.
    function openSaveAs() {
        scr.page = "saveas"
        saveName.text = ""
        Qt.callLater(() => saveName.focusInput())
    }

    width: 460 * u
    height: 270 * u

    // How many times a second the notes may move (the phase itself runs at the
    // screen's rate; the notes are only redrawn when it crosses one of these steps).
    readonly property int noteSteps: 78                 // 2600 ms loop -> 30 per second
    readonly property int noteStep: Math.floor(scr.phase * scr.noteSteps)

    onGainsChanged: {
        chartTop.requestPaint()
        chartNotes.requestPaint()
    }
    onInfoIdxChanged: {
        chartBase.requestPaint()
        chartTop.requestPaint()
    }
    onDragIdxChanged: chartNotes.requestPaint()
    onNoteStepChanged: if (scr.animate) chartNotes.requestPaint()
    onAnimateChanged: chartNotes.requestPaint()

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 2600
        loops: Animation.Infinite
        running: scr.animate
    }

    // ---- the chart ---------------------------------------------------------------
    // The chart is three stacked canvases, so that what moves every frame is the
    // cheap one: this one is the stage, the lanes, the judgement line and the
    // axis labels (shadow blur and all), painted again only when the lane in hand
    // changes or the size does.
    Canvas {
        id: chartBase
        width: parent.width * scr.renderScale
        height: parent.height * scr.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / scr.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: PadPalette
            function onPChanged() { chartBase.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / 460
            ctx.scale(k, k)
            var gs = scr.gains
            var info = scr.infoIdx
            var TOP = PM.TOP, BOT = PM.BOT, ZERO = PM.ZERO
            var i
            // the stage
            var bg = ctx.createLinearGradient(0, 0, 0, 270)
            bg.addColorStop(0, PM.css(PadPalette.stageTop))
            bg.addColorStop(0.55, PM.css(PadPalette.stageMid))
            bg.addColorStop(1, PM.css(PadPalette.stageBottom))
            ctx.fillStyle = bg
            ctx.fillRect(0, 0, 460, 270)

            var bm = ctx.createLinearGradient(0, 0, 0, 234)
            bm.addColorStop(0, "rgba(255,255,255,0.14)")
            bm.addColorStop(1, "rgba(255,255,255,0)")
            ctx.fillStyle = bm
            ctx.beginPath()
            ctx.moveTo(60, 0); ctx.lineTo(150, 0); ctx.lineTo(230, 234); ctx.lineTo(110, 234); ctx.closePath()
            ctx.moveTo(310, 0); ctx.lineTo(400, 0); ctx.lineTo(350, 234); ctx.lineTo(230, 234); ctx.closePath()
            ctx.fill()

            var stars = [[40, 50, 4, 0.7], [420, 70, 5, 0.7], [110, 24, 3, 0.5], [360, 22, 3, 0.5], [20, 150, 3, 0.4], [440, 170, 4, 0.5]]
            for (var s = 0; s < stars.length; s++) {
                var st = stars[s]
                ctx.fillStyle = "rgba(255,255,255," + st[3] + ")"
                ctx.beginPath()
                ctx.moveTo(st[0], st[1] - st[2])
                ctx.quadraticCurveTo(st[0], st[1], st[0] + st[2], st[1])
                ctx.quadraticCurveTo(st[0], st[1], st[0], st[1] + st[2])
                ctx.quadraticCurveTo(st[0], st[1], st[0] - st[2], st[1])
                ctx.quadraticCurveTo(st[0], st[1], st[0], st[1] - st[2])
                ctx.fill()
            }

            // the lanes
            for (i = 0; i < 10; i++) {
                ctx.beginPath()
                ctx.moveTo(PM.laneEdge(i, TOP), TOP)
                ctx.lineTo(PM.laneEdge(i + 1, TOP), TOP)
                ctx.lineTo(PM.laneEdge(i + 1, BOT), BOT)
                ctx.lineTo(PM.laneEdge(i, BOT), BOT)
                ctx.closePath()
                ctx.fillStyle = PM.alpha(PadPalette.groups[PM.group(i)], i === info ? 0.2 : 0.05)
                ctx.fill()
            }
            ctx.strokeStyle = "rgba(255,255,255,0.16)"
            ctx.lineWidth = 1
            for (i = 0; i <= 10; i++) {
                ctx.beginPath()
                ctx.moveTo(PM.laneEdge(i, TOP), TOP)
                ctx.lineTo(PM.laneEdge(i, BOT), BOT)
                ctx.stroke()
            }
            ctx.setLineDash([2, 5])
            ctx.strokeStyle = "rgba(255,255,255,0.4)"
            ctx.beginPath()
            ctx.moveTo(PM.laneEdge(0, ZERO), ZERO)
            ctx.lineTo(PM.laneEdge(10, ZERO), ZERO)
            ctx.stroke()
            ctx.setLineDash([])

            // the judgement line
            ctx.save()
            ctx.shadowColor = PM.alpha(PadPalette.litB, 0.9)
            ctx.shadowBlur = 10
            ctx.fillStyle = "rgba(255,255,255,0.6)"
            ctx.fillRect(0, 232.5, 460, 2)
            ctx.restore()

            ctx.font = "700 8px '" + Theme.fontFamily + "'"
            ctx.textAlign = "left"
            ctx.fillStyle = "rgba(255,255,255,0.55)"
            ctx.fillText("+12", 3, 44)
            ctx.fillText("0", 3, 131)
            ctx.fillText("\u221212", 3, 230)
        }
    }

    // The notes falling down the lanes: the only canvas that repaints while the
    // song plays (`noteSteps` times a second at most), and it has no blur in it.
    Canvas {
        id: chartNotes
        width: parent.width * scr.renderScale
        height: parent.height * scr.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / scr.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: PadPalette
            function onPChanged() { chartNotes.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / 460
            ctx.scale(k, k)
            var gs = scr.gains
            var info = scr.infoIdx
            var TOP = PM.TOP, BOT = PM.BOT, ZERO = PM.ZERO
            var yj = []
            for (var i = 0; i < 10; i++)
                yj.push(PM.gainToY(gs[i] || 0))
            // notes falling in every lane
            for (i = 0; i < 10; i++) {
                if (i === scr.dragIdx)
                    continue
                var grp = PM.group(i)
                for (var n = 0; n < 2; n++) {
                    var ny, na
                    if (scr.animate) {
                        var t = (scr.phase + n * 0.5 + i * 0.137) % 1
                        ny = TOP + 6 + (yj[i] - TOP - 6) * t
                        na = Math.min(1, t * 6) * (t > 0.93 ? (1 - t) / 0.07 : 1) * 0.9
                    } else {
                        ny = Math.max(TOP + 6, yj[i] - (n === 0 ? 44 : 88))
                        na = n === 0 ? 0.9 : 0.45
                    }
                    var sc = PM.s(ny), nw = 32 * sc, nh = 12 * sc, nx = PM.laneX(i, ny)
                    var ng = ctx.createLinearGradient(0, ny - nh / 2, 0, ny + nh / 2)
                    ng.addColorStop(0, PM.css(PadPalette.groupsLight[grp]))
                    ng.addColorStop(1, PM.css(PadPalette.groupsDark[grp]))
                    ctx.globalAlpha = na
                    ctx.beginPath()
                    PM.rr(ctx, nx - nw / 2, ny - nh / 2, nw, nh, 5 * sc)
                    ctx.fillStyle = ng
                    ctx.fill()
                    ctx.strokeStyle = "rgba(255,255,255,0.8)"
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                    ctx.globalAlpha = 1
                }
            }
        }
    }

    // The hold notes, the curve with its glow, the jewels, lane tiles and the
    // readout: painted again only when a gain or the lane in hand changes.
    Canvas {
        id: chartTop
        width: parent.width * scr.renderScale
        height: parent.height * scr.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / scr.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: PadPalette
            function onPChanged() { chartTop.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / 460
            ctx.scale(k, k)
            var gs = scr.gains
            var info = scr.infoIdx
            var TOP = PM.TOP, BOT = PM.BOT, ZERO = PM.ZERO
            var yj = []
            for (var i = 0; i < 10; i++)
                yj.push(PM.gainToY(gs[i] || 0))
            // hold notes: the gain, from the 0 dB line to the jewel
            for (i = 0; i < 10; i++) {
                if (Math.abs(gs[i] || 0) < 0.5)
                    continue
                var gi = PM.group(i)
                var h0 = 10 * PM.s(ZERO), h1 = 10 * PM.s(yj[i])
                var x0 = PM.laneX(i, ZERO), x1 = PM.laneX(i, yj[i])
                ctx.beginPath()
                ctx.moveTo(x0 - h0, ZERO); ctx.lineTo(x0 + h0, ZERO); ctx.lineTo(x1 + h1, yj[i]); ctx.lineTo(x1 - h1, yj[i]); ctx.closePath()
                ctx.fillStyle = PM.alpha(PadPalette.groups[gi], 0.42)
                ctx.fill()
                ctx.strokeStyle = PM.alpha(PadPalette.groupsLight[gi], 0.9)
                ctx.lineWidth = 1.2
                ctx.stroke()
                ctx.strokeStyle = "rgba(255,255,255,0.6)"
                ctx.beginPath()
                ctx.moveTo(x0, ZERO); ctx.lineTo(x1, yj[i])
                ctx.stroke()
            }

            // the curve
            var pts = []
            for (i = 0; i < 10; i++)
                pts.push({ x: PM.laneX(i, yj[i]), y: yj[i] })
            ctx.save()
            ctx.shadowColor = PM.alpha(PadPalette.litB, 0.9)
            ctx.shadowBlur = 12
            ctx.lineCap = "round"
            ctx.lineWidth = 6
            ctx.strokeStyle = PM.alpha(PadPalette.litB, 0.5)
            ctx.beginPath(); PM.smooth(ctx, pts); ctx.stroke()
            ctx.restore()
            var cg = ctx.createLinearGradient(0, 0, 460, 0)
            cg.addColorStop(0, PM.css(PadPalette.litA))
            cg.addColorStop(1, PM.css(PadPalette.litB))
            ctx.lineWidth = 3.2
            ctx.strokeStyle = cg
            ctx.beginPath(); PM.smooth(ctx, pts); ctx.stroke()
            ctx.lineWidth = 1
            ctx.strokeStyle = "rgba(255,255,255,0.8)"
            ctx.beginPath(); PM.smooth(ctx, pts); ctx.stroke()

            // jewels and lane tiles
            for (i = 0; i < 10; i++) {
                var gj = PM.group(i), isel = i === info
                var jx = pts[i].x, jy = pts[i].y, js = PM.s(jy)
                var jw = (isel ? 50 : 42) * js, jh = (isel ? 30 : 24) * js
                if ((gs[i] || 0) >= 3) {
                    ctx.save()
                    ctx.shadowColor = "rgba(255,255,255,0.9)"
                    ctx.shadowBlur = 14
                    ctx.fillStyle = "rgba(255,255,255,0.35)"
                    ctx.beginPath(); ctx.arc(jx, jy, 14 * js, 0, Math.PI * 2); ctx.fill()
                    ctx.restore()
                }
                var jg = ctx.createLinearGradient(0, jy - jh / 2, 0, jy + jh / 2)
                jg.addColorStop(0, PM.css(PadPalette.groupsLight[isel ? 0 : gj]))
                jg.addColorStop(1, PM.css(PadPalette.groupsDark[isel ? 0 : gj]))
                ctx.beginPath()
                PM.rr(ctx, jx - jw / 2, jy - jh / 2, jw, jh, jh * 0.38)
                ctx.fillStyle = jg
                ctx.fill()
                ctx.lineWidth = 1.6
                ctx.strokeStyle = "rgba(255,255,255,0.95)"
                ctx.stroke()
                ctx.beginPath()
                PM.rr(ctx, jx - jw / 2 + 4, jy - jh / 2 + 2.5, jw - 8, jh * 0.34, jh * 0.15)
                ctx.fillStyle = "rgba(255,255,255,0.6)"
                ctx.fill()

                var tx = 23 + i * 46
                ctx.beginPath()
                PM.rr(ctx, tx - 20, 241, 40, 21, 7)
                ctx.fillStyle = isel ? "rgba(255,255,255,0.22)" : "rgba(255,255,255,0.07)"
                ctx.fill()
                ctx.strokeStyle = isel ? "rgba(255,255,255,0.6)" : "rgba(255,255,255,0.22)"
                ctx.lineWidth = 1
                ctx.stroke()
                ctx.font = "700 11px '" + Theme.fontFamily + "'"
                ctx.textAlign = "center"
                ctx.fillStyle = PM.css(PadPalette.groupsLight[gj])
                ctx.fillText(PM.LABELS[i], tx, 255.5)
            }

            // the readout for the lane in hand
            var ix = pts[info].x, iy = pts[info].y
            ctx.beginPath()
            ctx.arc(ix, iy, 23, 0, Math.PI * 2)
            ctx.lineWidth = 1.5
            ctx.strokeStyle = "rgba(255,255,255,0.8)"
            ctx.stroke()
            var by = iy > 180 ? iy - 52 : iy + 26
            var bx = Math.max(60, Math.min(400, ix))
            var gv = Math.round(gs[info] || 0)
            ctx.beginPath()
            PM.rr(ctx, bx - 56, by, 112, 24, 12)
            ctx.fillStyle = PM.css(PadPalette.bubbleBg)
            ctx.fill()
            ctx.strokeStyle = "rgba(255,255,255,0.4)"
            ctx.lineWidth = 1
            ctx.stroke()
            ctx.font = "700 11px '" + Theme.fontFamily + "'"
            ctx.fillStyle = "#ffffff"
            ctx.fillText(PM.HZ[info] + "  " + (gv > 0 ? "+" : (gv < 0 ? "\u2212" : "")) + Math.abs(gv) + " dB", bx, by + 16)
        }
    }

    // ---- the lanes under the pointer ---------------------------------------------------
    MouseArea {
        id: lanes
        x: 0
        y: scr.d(32)
        width: scr.width
        height: scr.height - scr.d(32)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: scr.page === "chart"
        cursorShape: scr.hoverIdx >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

        function dy(mouse) {
            return 32 + mouse.y / scr.u
        }
        function dx(mouse) {
            return mouse.x / scr.u
        }

        onPressed: mouse => {
            var i = PM.laneAt(dx(mouse), dy(mouse))
            if (i < 0)
                return
            scr.sel = i
            if (mouse.button === Qt.RightButton) {
                scr.eq.resetBand(i)
                return
            }
            if (dy(mouse) > 238)
                return
            scr.dragIdx = i
            scr.eq.setBand(i, PM.yToGain(dy(mouse), scr.eq.bandRange))
        }
        onPositionChanged: mouse => {
            if (scr.dragIdx >= 0)
                scr.eq.setBand(scr.dragIdx, PM.yToGain(dy(mouse), scr.eq.bandRange))
            else
                scr.hoverIdx = PM.laneAt(dx(mouse), dy(mouse))
        }
        onReleased: scr.dragIdx = -1
        onCanceled: scr.dragIdx = -1
        onExited: scr.hoverIdx = -1
        onDoubleClicked: mouse => {
            var i = PM.laneAt(dx(mouse), dy(mouse))
            if (i >= 0)
                scr.eq.resetBand(i)
        }
        onWheel: w => {
            var i = PM.laneAt(w.x / scr.u, 32 + w.y / scr.u)
            if (i >= 0) {
                scr.sel = i
                scr.eq.setBand(i, (scr.gains[i] || 0) + (w.angleDelta.y > 0 ? 1 : -1))
            }
        }
    }

    // ---- the bar along the top -----------------------------------------------------------
    Rectangle {
        id: bar
        width: parent.width
        height: scr.d(31)
        color: PadPalette.barBg

        // AUTO
        Rectangle {
            x: scr.d(10)
            y: scr.d(7)
            width: scr.d(56)
            height: scr.d(18)
            radius: height / 2
            antialiasing: true
            border.width: scr.eq.autoEnabled ? 0 : 1
            border.color: Qt.rgba(1, 1, 1, 0.3)
            color: scr.eq.autoEnabled ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
            gradient: scr.eq.autoEnabled ? litGrad : null
            Gradient {
                id: litGrad
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: PadPalette.litA }
                GradientStop { position: 1.0; color: PadPalette.litB }
            }
            Text {
                anchors.centerIn: parent
                text: "\u2605 AUTO"
                color: scr.eq.autoEnabled ? PadPalette.ink : "#ffffff"
                opacity: scr.eq.autoEnabled ? 1 : 0.75
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(9.5)
                font.weight: Font.ExtraBold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!scr.eq.autoEnabled && scr.eq.lastfmKey === "")
                        scr.page = "setup"
                    scr.eq.toggleAuto()
                }
            }
        }

        // the preset, between two arrows
        Text {
            id: nameText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: scr.eq.presetName.toUpperCase()
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: scr.d(16)
            font.weight: Font.Bold
            font.letterSpacing: scr.d(1)
        }
        Text {
            x: nameText.x - scr.d(30)
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25C0"
            color: "#ffffff"
            opacity: 0.85
            font.pixelSize: scr.d(14)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -scr.d(8)
                cursorShape: Qt.PointingHandCursor
                onClicked: scr.prevPreset()
            }
        }
        Text {
            x: nameText.x + nameText.width + scr.d(16)
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25B6"
            color: "#ffffff"
            opacity: 0.85
            font.pixelSize: scr.d(14)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -scr.d(8)
                cursorShape: Qt.PointingHandCursor
                onClicked: scr.nextPreset()
            }
        }
        MouseArea {
            x: nameText.x - scr.d(6)
            width: nameText.width + scr.d(12)
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: scr.page = scr.page === "presets" ? "chart" : "presets"
        }

        // preamp gauge + setup
        Text {
            x: scr.d(330)
            anchors.verticalCenter: parent.verticalCenter
            text: "VOL"
            color: "#ffffff"
            opacity: 0.8
            font.family: Theme.fontFamily
            font.pixelSize: scr.d(9)
            font.weight: Font.Bold
        }
        Rectangle {
            x: scr.d(352)
            anchors.verticalCenter: parent.verticalCenter
            width: scr.d(52)
            height: scr.d(8)
            radius: height / 2
            antialiasing: true
            color: Qt.rgba(1, 1, 1, 0.2)
            Rectangle {
                width: parent.width * (scr.eq.preamp + scr.eq.preampRange) / (2 * scr.eq.preampRange)
                height: parent.height
                radius: height / 2
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: PadPalette.litA }
                    GradientStop { position: 1.0; color: PadPalette.litB }
                }
            }
        }
        Text {
            x: scr.d(408)
            anchors.verticalCenter: parent.verticalCenter
            text: (scr.eq.preamp > 0 ? "+" : "") + Math.round(scr.eq.preamp)
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: scr.d(9)
            font.weight: Font.Bold
        }
        Text {
            x: scr.d(434)
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2699"
            color: scr.page === "setup" ? PadPalette.litA : "#ffffff"
            opacity: 0.9
            font.pixelSize: scr.d(15)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -scr.d(6)
                cursorShape: Qt.PointingHandCursor
                onClicked: scr.page = scr.page === "setup" ? "chart" : "setup"
            }
        }
        // EasyEffects has never saved the chosen preset: say so
        Rectangle {
            visible: scr.eq.needsManualSave
            x: scr.d(300)
            anchors.verticalCenter: parent.verticalCenter
            width: scr.d(16)
            height: width
            radius: width / 2
            antialiasing: true
            color: PadPalette.warn
            Text {
                anchors.centerIn: parent
                text: "!"
                color: PadPalette.ink
                font.pixelSize: scr.d(11)
                font.weight: Font.ExtraBold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: scr.page = "setup"
            }
        }
    }

    // ---- pages over the chart --------------------------------------------------------------
    Rectangle {
        id: sheet
        visible: scr.page !== "chart"
        y: bar.height
        width: parent.width
        height: parent.height - bar.height
        color: PadPalette.sheetBg

        // swallow clicks so the chart under it is not touched
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        // ---- the shelf of presets ----
        Item {
            visible: scr.page === "presets"
            anchors.fill: parent
            anchors.margins: scr.d(14)

            Text {
                text: "PRESETS"
                color: "#ffffff"
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
                font.weight: Font.Bold
                font.letterSpacing: scr.d(1.5)
            }
            Flow {
                y: scr.d(20)
                width: parent.width
                spacing: scr.d(6)
                Repeater {
                    model: scr.allPresets
                    PadChip {
 u: scr.u
                        required property string modelData
                        text: (scr.eq.customNames.indexOf(modelData) >= 0 ? "\u2605 " : "") + modelData
                        lit: scr.eq.presetName === modelData
                        onClicked: {
                            scr.eq.applyAny(modelData)
                            scr.page = "chart"
                        }
                        onRightClicked: {
                            if (scr.eq.customNames.indexOf(modelData) >= 0)
                                scr.eq.deleteCustom(modelData)
                        }
                    }
                }
                PadChip {
 u: scr.u
                    text: "+ SAVE AS"
                    onClicked: scr.openSaveAs()
                }
            }
            Text {
                anchors.bottom: parent.bottom
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Click a preset to load it." + (scr.eq.customNames.length > 0 ? " Right click one of yours (\u2605) to delete it." : "")
                color: "#ffffff"
                opacity: 0.5
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
            }
        }

        // ---- name this curve ----
        Item {
            visible: scr.page === "saveas"
            anchors.fill: parent
            anchors.margins: scr.d(14)
            Text {
                text: "NAME THIS CURVE"
                color: "#ffffff"
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
                font.weight: Font.Bold
                font.letterSpacing: scr.d(1.5)
            }
            Row {
                y: scr.d(24)
                spacing: scr.d(8)
                PadField {
 u: scr.u
                    id: saveName
                    width: scr.d(240)
                    placeholder: "My curve"
                    onSubmitted: value => {
                        scr.eq.saveCustom(value)
                        scr.page = "chart"
                    }
                }
                PadChip {
 u: scr.u
                    text: "SAVE"
                    lit: true
                    onClicked: {
                        scr.eq.saveCustom(saveName.text)
                        scr.page = "chart"
                    }
                }
                PadChip {
 u: scr.u
                    text: "CANCEL"
                    onClicked: scr.page = "chart"
                }
            }
        }

        // ---- setup ----
        Item {
            visible: scr.page === "setup"
            anchors.fill: parent
            anchors.margins: scr.d(14)
            Text {
                text: "EASYEFFECTS PRESET"
                color: "#ffffff"
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
                font.weight: Font.Bold
                font.letterSpacing: scr.d(1.5)
            }
            Flow {
                y: scr.d(18)
                width: parent.width
                spacing: scr.d(6)
                Repeater {
                    model: scr.eq.availablePresets
                    PadChip {
 u: scr.u
                        required property string modelData
                        text: modelData
                        lit: scr.eq.activePreset === modelData
                        onClicked: scr.eq.setActivePreset(modelData)
                    }
                }
            }
            Row {
                y: scr.d(70)
                spacing: scr.d(6)
                PadField {
 u: scr.u
                    id: newChain
                    width: scr.d(190)
                    placeholder: "New preset name"
                    onSubmitted: value => {
                        scr.eq.createActivePreset(value)
                        newChain.text = ""
                    }
                }
                PadChip {
 u: scr.u
                    text: "+ NEW"
                    onClicked: {
                        scr.eq.createActivePreset(newChain.text)
                        newChain.text = ""
                    }
                }
            }
            Text {
                y: scr.d(98)
                width: parent.width
                wrapMode: Text.WordWrap
                text: scr.eq.needsManualSave
                    ? "Save the \u201C" + scr.eq.activePreset + "\u201D preset once in EasyEffects first, or the equalizer would wipe the rest of your chain."
                    : "The equalizer is merged into the one you pick; a new preset replaces what is live in EasyEffects."
                color: scr.eq.needsManualSave ? PadPalette.warn : "#ffffff"
                opacity: scr.eq.needsManualSave ? 1 : 0.5
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
            }
            Text {
                y: scr.d(136)
                text: "LAST.FM KEY (for AUTO)"
                color: "#ffffff"
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
                font.weight: Font.Bold
                font.letterSpacing: scr.d(1.5)
            }
            Row {
                y: scr.d(154)
                spacing: scr.d(6)
                PadField {
 u: scr.u
                    id: keyField
                    width: scr.d(190)
                    secret: true
                    placeholder: "Paste your key"
                    text: scr.eq.lastfmKey
                    onSubmitted: value => scr.eq.setLastfmKey(value)
                }
                PadChip {
 u: scr.u
                    text: "SET"
                    onClicked: scr.eq.setLastfmKey(keyField.text)
                }
            }
            Text {
                y: scr.d(186)
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Free at last.fm/api/account/create. If typing does nothing: qs -c sekaipop ipc call eq lastfmKey <key>"
                color: "#ffffff"
                opacity: 0.5
                font.family: Theme.fontFamily
                font.pixelSize: scr.d(10)
            }
        }
    }
}

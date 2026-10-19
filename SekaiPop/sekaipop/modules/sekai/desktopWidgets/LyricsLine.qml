import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/LyricsMath.js" as LM

// One line of the lyrics, as the lyrics widget draws it. Everything it does is worked out
// from the lyrics clock `t` and how far the line is from the middle of the stack (`d`),
// so it is right wherever the song is: playing, paused, or jumped to somewhere else.
//
//   d       -1 a line ago, 0 the line that is on, +1 the line to come. The line's place,
//           size, tilt and strength all follow from it (LyricsMath.pose), so lines
//           glide into place instead of jumping.
//   words   a line is cut into words (LyricsMath.tokens), each a sticker (LyricsWord.qml).
//           In the last moments before its line starts the words hop up one after another,
//           a little wave running along the line.
//   sung    while it is on, each word is filled with colour as it is sung: the line's time
//           is shared out over the words by their length (a lyrics file only says when a
//           LINE starts, not each word).
//   marker  a small diamond that bounces from word to word, landing on each exactly as it
//           starts; the word it lands on squashes down and a few diamonds fly off. It hops
//           over the words of the tune only: ad libs are skipped.
//   ad libs words in brackets, "(oh oh)", are drawn smaller, raised a little, tilted and in the
//           second accent colour, and they fill when they are sung like any other word.
//   along   a second line at the same moment ("(ooh)" under "hold me") is a small row above
//           the line, filling over the same time, there while the line is on.
//   gap     a line with no words (an intro, an instrumental part) is three diamonds that
//           light up one by one and then shrink away as the singing comes back.
//   takeover  a line can still be being sung when the next one begins (voices that overlap, a
//           quick answer, a line stamped close behind a long one). It is not dropped into the
//           faded "already sung" slot with its words half filled: it is HELD, just above the
//           new line, a little smaller but still strong, and goes on singing there (its
//           colour keeps filling, a small marker keeps hopping). When its last word is done
//           a few diamonds fly off it, and after a moment it lets go and settles into the
//           faded slot. The new line lands with a soft swell, and its own marker hops lower
//           while a line is held above it, so the two do not touch. How much of this a line
//           gets follows from how long it runs on past the next one (LyricsMath.rushOf), so
//           a small overlap is a small change. Like all the rest it is worked out from the
//           lyrics clock, so a pause or a seek leaves it in the right place.
//
// The line is centred on (cx, cy + pose.y).
Item {
    id: line

    property string text: ""
    property real lineStart: 0
    property real lineEnd: 0
    property real t: 0
    property int index: 0
    property int curIndex: -1
    property bool playing: false
    property real d: 0
    // A line that is only there (a message, not a lyric): no singing, no marker.
    property bool still: false
    // Word timing from an enhanced lyrics file (LyricsMath.spansFor); empty for most.
    property var marks: []
    // A voice that sings along with the line: its words and when it starts.
    property string bgText: ""
    property real bgStart: 0
    property real bgEnd: 0
    // How much the next line takes over this one (0 .. 1, LyricsMath.rushOf: this line is still
    // being sung when the stack climbs away from it), the same for the line before this one,
    // and when that line has been sung by. The defaults mean "no neighbour".
    property real rush: 0
    property real prevRush: 0
    property real prevEnd: 0
    property real maxW: 680
    property int px: 38
    property real cx: 0
    property real cy: 0

    // ===== being taken over / taking over =====
    // `held`: how much of `rush` is in force at this moment: full while this line is sung and
    // a moment after, easing off to 0 as it lets go.
    readonly property real held: (line.rush > 0 && !line.still && !line.blank) ? LM.hold(line.t, line.lineEnd, line.rush) : 0
    // How much the line before still holds above this one (it is what the marker hops lower for).
    readonly property real heldAbove: (line.prevRush > 0 && !line.still) ? LM.hold(line.t, line.prevEnd, line.prevRush) : 0
    // The line before it was still being sung as this one started: how much of a takeover
    // that entry was, for the swell as it lands.
    readonly property real entryRush: (line.still || line.index <= 0) ? 0 : LM.rushOf(LM.overrun(line.prevEnd, line.lineStart))
    // The soft swell as a line that took over lands.
    readonly property real land: (line.isCur && line.entryRush > 0) ? LM.landing(line.t - line.lineStart, line.entryRush) : 0
    readonly property var pose: LM.takeover(line.d, line.held)
    readonly property var toks: LM.tokens(line.text)
    readonly property bool blank: line.toks.length === 0 && !line.still
    readonly property var sp: LM.spansFor(line.toks, line.lineStart, Math.max(0.1, line.lineEnd - line.lineStart), line.marks)
    // The words the marker hops over (not the ad libs), and their times.
    readonly property var mainIdx: LM.mainIndexes(line.toks)
    readonly property var mainSp: {
        const out = []
        for (let i = 0; i < line.mainIdx.length; i++)
            out.push(line.sp[line.mainIdx[i]])
        return out
    }
    // The voice that sings along.
    readonly property var bgToks: line.bgText !== "" ? LM.tokens(line.bgText) : []
    readonly property bool hasBg: line.bgToks.length > 0 && !line.still && !line.blank
    readonly property int bgPx: Math.max(14, Math.round(line.px * 0.5))
    readonly property var bgSp: LM.spans(line.bgToks, line.bgStart, Math.max(0.2, Math.max(line.bgEnd, line.lineEnd) - line.bgStart))
    // It comes in as it starts, and stays while the line is on and the one after it.
    readonly property real bgIn: !line.hasBg ? 0
        : (line.index < line.curIndex ? 1 : (line.isCur ? Math.max(0, Math.min(1, (line.t - line.bgStart + 0.12) / 0.3)) : 0))
    readonly property bool isCur: !line.still && line.index === line.curIndex
    // A line that was taken over: the next one has begun and this one is still being sung.
    readonly property bool carried: !line.still && line.index < line.curIndex && line.t >= line.lineStart && line.t < line.lineEnd
    // Being sung now, on the stage or under the line that took it.
    readonly property bool singing: line.isCur || line.carried
    // The line that is on, the one just before it, and one that is still being sung keep
    // the layer that holds the sung colour.
    readonly property bool litOn: !line.still && (line.index === line.curIndex || line.index === line.curIndex - 1 || line.carried)
    // `kmAny`: the word of the tune the marker is on by the clock alone (the last word once
    // the line has been sung, so the marker that is shrinking away stays where it was).
    // `km`: the same, only while the line is being sung (the fill and the squash of each word
    // come from its own times, ad libs included).
    readonly property int kmAny: LM.wordAt(line.mainSp, line.t)
    readonly property int km: line.singing ? line.kmAny : -1
    readonly property real hopP: LM.hop(line.mainSp, line.kmAny, line.t)
    readonly property real pad: Math.round(line.px * 0.95)

    // Dimmed while the music is paused.
    property real dim: line.playing ? 1 : 0.62

    Behavior on dim {
        NumberAnimation { duration: 320 }
    }

    x: line.cx
    y: line.cy + line.pose.y
    width: 0
    height: 0

    // The middle of word `i`, in the line's own coordinates.
    function center(i) {
        const it = reps.itemAt(i)
        return it ? it.x + it.gapW + it.fullW / 2 : 0
    }

    // The diamonds fly off the words of the tune, not the ad libs. A line that is still being
    // sung under the one that took the stage keeps flying them.
    onKmChanged: {
        if (line.singing && line.playing && line.km >= 0) {
            puff.x = line.center(line.mainIdx[line.km])
            puff.y = line.pad + line.px * 0.2
            puff.fire()
        }
    }

    // The singing of a line that was taken over has just ended: a few diamonds off its last
    // word, the sign-off, and then it lets go (LyricsMath.hold). Only when it really ends
    // while playing, not when a seek jumps past it.
    readonly property bool done: !line.still && line.t >= line.lineEnd
    onDoneChanged: {
        if (line.done && line.playing && line.rush > 0.25 && line.index < line.curIndex
                && line.t - line.lineEnd < 0.35 && line.mainIdx.length > 0) {
            signoff.x = line.center(line.mainIdx[line.mainIdx.length - 1])
            signoff.y = line.pad + line.px * 0.2
            signoff.fire()
        }
    }

    Item {
        id: holder

        width: line.blank ? line.px * 3.4 : Math.max(1, row.implicitWidth)
        height: line.blank ? line.px * 1.4 : row.implicitHeight + 2 * line.pad
        x: -width / 2
        y: -height / 2
        transformOrigin: Item.Center
        scale: line.pose.scale * (1 + 0.06 * line.land) * LM.fit(row.implicitWidth, line.maxW)
        rotation: line.pose.rot
        opacity: line.pose.opacity * line.dim
        visible: opacity > 0.01

        Row {
            id: row
            y: line.pad
            visible: !line.blank

            Repeater {
                id: reps
                model: line.toks

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    property alias word: wordItem
                    // An ad lib: smaller, raised, tilted and in the other colour.
                    readonly property bool ad: modelData.adlib === true
                    readonly property real sizeK: cell.ad ? 0.68 : 1
                    readonly property real fullW: Math.round(wordItem.implicitWidth * cell.sizeK)
                    readonly property real gapW: modelData.gap ? Math.round(line.px * 0.3) : 0
                    readonly property var span: line.sp[index]
                    readonly property real sungV: (line.litOn && span !== undefined) ? LM.sung(span, line.t) : 0
                    // The wave before the line starts: word i hops when the line is
                    // (1 - d) of the way up, a little after the one before it.
                    readonly property real stagger: 0.13
                    readonly property real wave: Math.max(0, Math.min(1,
                        (1 - line.d) * (1 + stagger * (line.toks.length - 1)) - index * stagger))
                    readonly property real lift: (line.d > -0.01 && line.d < 1) ? Math.sin(Math.PI * wave) : 0
                    readonly property real hitV: (line.singing && line.playing) ? LM.hit(line.sp, index, line.t) : 0

                    width: gapW + fullW
                    height: wordItem.implicitHeight

                    LyricsWord {
                        id: wordItem
                        // (scaled about its bottom middle, so it is moved to sit in its cell)
                        x: cell.gapW - (wordItem.implicitWidth - cell.fullW) / 2
                        y: -line.px * 0.24 * cell.lift + 3 * cell.hitV - (cell.ad ? line.px * 0.1 : 0)
                        text: cell.modelData.s
                        pixelSize: line.px
                        withFill: line.litOn
                        sung: cell.sungV
                        litColor: cell.ad ? Theme.accentMint : Theme.accentCyan
                        scale: cell.sizeK * (1 + 0.11 * cell.lift)
                        rotation: cell.ad ? -3 : 0
                        transformOrigin: Item.Bottom

                        transform: Scale {
                            origin.x: wordItem.width / 2
                            origin.y: wordItem.height
                            xScale: 1 + 0.07 * cell.hitV
                            yScale: 1 - 0.15 * cell.hitV
                        }
                    }
                }
            }
        }

        // ===== the bouncing marker =====
        Item {
            id: marker

            // (hopping over the words of the tune only: `mainIdx` maps them to the words)
            readonly property int hereM: Math.max(0, line.kmAny)
            readonly property int thereM: Math.min(marker.hereM + 1, Math.max(0, line.mainIdx.length - 1))
            readonly property int here: line.mainIdx.length > 0 ? line.mainIdx[marker.hereM] : 0
            readonly property int there: line.mainIdx.length > 0 ? line.mainIdx[marker.thereM] : 0
            // (the words' places are only known once the row has been laid out, hence the
            // look at its width)
            readonly property bool laidOut: row.implicitWidth > 0
            readonly property real ax: laidOut ? line.center(here) : 0
            readonly property real bx: laidOut ? line.center(there) : 0
            readonly property real arch: LM.arch(line.hopP)
            // How high it hops: lower under a row that sings along, so it does not cross it,
            // and lower while a line that was taken over is held above this one.
            readonly property real archK: (line.hasBg ? 0.5 : 0.85) * (1 - 0.5 * line.heldAbove)
            // It grows in when its line starts and shrinks away when the singing ends (for
            // a line that was taken over that is after the next one has begun), not a blink.
            property real presence: line.singing ? 1 : 0

            Behavior on presence {
                NumberAnimation {
                    duration: line.singing ? 200 : 260
                    easing.type: line.singing ? Easing.OutBack : Easing.InCubic
                }
            }

            visible: !line.blank && marker.presence > 0.01
            x: ax + (bx - ax) * line.hopP
            y: line.pad - line.px * 0.16 - arch * line.px * marker.archK
            rotation: 180 * line.hopP
            scale: (1 + 0.28 * arch) * Math.max(0, marker.presence)

            DiamondDot {
                anchors.centerIn: parent
                lit: true
                litColor: Theme.accentMint
                lineColor: Theme.colBorder
                size: Math.round(line.px * 0.3)
            }
        }

        Burst {
            id: puff
            count: 6
            radius: line.px * 0.95
            size: Math.max(6, Math.round(line.px * 0.2))
            colors: [Theme.accentCyan, Theme.accentMint, "#FFFFFF"]
        }

        // The sign-off of a line that was taken over (see `done` above).
        Burst {
            id: signoff
            count: 8
            radius: line.px * 1.15
            size: Math.max(6, Math.round(line.px * 0.22))
            colors: [Theme.accentMint, "#FFFFFF", Theme.accentCyan]
        }

        // ===== a voice that sings along =====
        // A small row just above the words, filling over the same time. Ad libs are drawn the
        // same way inside the line; this is for a whole second line at the same moment.
        Row {
            id: bgRow
            visible: line.hasBg && line.bgIn > 0.01
            opacity: line.bgIn
            spacing: Math.round(line.bgPx * 0.3)
            x: Math.round((row.implicitWidth - bgRow.width) / 2)
            y: Math.round(line.pad - bgRow.height * 0.8 + line.px * 0.22 + (1 - line.bgIn) * 8)

            Repeater {
                model: line.bgToks

                delegate: LyricsWord {
                    id: bgWord

                    required property var modelData
                    required property int index

                    text: bgWord.modelData.s
                    pixelSize: line.bgPx
                    withFill: true
                    litColor: Theme.accentMint
                    sung: line.bgSp[bgWord.index] ? LM.sung(line.bgSp[bgWord.index], line.t) : 0
                }
            }
        }

        // ===== a gap in the singing =====
        Row {
            visible: line.blank
            anchors.centerIn: parent
            spacing: Math.round(line.px * 0.42)

            Repeater {
                model: 3

                delegate: Item {
                    id: bead

                    required property int index

                    readonly property real room: Math.max(0.5, line.lineEnd - line.lineStart)
                    // They light one by one, then shrink away over the last half second.
                    readonly property real leaving: line.isCur ? Math.max(0, Math.min(1, (line.lineEnd - line.t) / 0.5)) : 1
                    readonly property real breath: (line.isCur && line.playing) ? 1 + 0.14 * Math.sin(line.t * 5 + index * 1.1) : 1

                    width: Math.round(line.px * 0.3)
                    height: width
                    scale: Math.max(0.001, leaving * breath)

                    DiamondDot {
                        anchors.centerIn: parent
                        size: bead.width
                        lit: line.isCur && line.t >= line.lineStart + (bead.index + 1) * bead.room / 4.2
                        litColor: Theme.accentMint
                        offColor: "#FFFFFF"
                        lineColor: Theme.colBorder
                    }
                }
            }
        }
    }
}

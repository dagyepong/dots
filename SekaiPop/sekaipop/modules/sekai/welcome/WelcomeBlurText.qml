import QtQuick
import QtQuick.Effects
import qs.modules.common
import "../../common/functions/WelcomeMath.js" as WM

// Text that blurs in word by word, the caption effect of the reference video:
// each word starts blurred, faint and a little low, then sharpens into place
// while the next one is already starting. Run it backwards (reveal 1 -> 0) and
// the last word is the first to blur away.
//
//   WelcomeBlurText { text: "Pick Your Unit"; reveal: page.textIn; pixelSize: 27 }
//
// The blur is a layer + MultiEffect on a word, but only while that word is on
// its way in or out. A word that is fully in (or not started) has no layer, so
// a finished caption is plain text and costs nothing.
Item {
    id: root

    property string text: ""
    // 0..1: how far the whole text has come in.
    property real reveal: 0
    property real pixelSize: 16
    property int weight: Font.Bold
    property color color: "#000000"
    property int align: Text.AlignHCenter
    // Line height as a multiple of the font size.
    property real lineHeight: 1.18
    // How much of the run each word takes (smaller = more one-after-the-other).
    property real span: 0.5
    // How far a word rises into place, and how strong its blur starts, in px.
    property real rise: root.pixelSize * 0.45
    property int blurMax: 26
    // Timed mode (the video's own pace): word i starts delayMs + i * stepMs into
    // a run that lasts totalMs, and takes wordMs to sharpen. `reveal` is still
    // the 0..1 run, so the page drives it the same way.
    property bool timed: false
    property real totalMs: 1000
    property real delayMs: 0
    property real stepMs: 70
    property real wordMs: 160
    // Leaving: every word blurs away at the same moment, not one after another
    // (the reference's captions go out as one block).
    property bool together: false

    readonly property var lines: WM.splitLines(root.text)
    readonly property int count: WM.wordCount(root.lines)

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col

        spacing: root.pixelSize * (root.lineHeight - 1.0) * 0.5

        Repeater {
            model: root.lines.length

            Row {
                id: lineRow

                required property int index
                readonly property var words: root.lines[index]
                readonly property int first: WM.firstWordOf(root.lines, index)

                spacing: root.pixelSize * 0.27
                x: root.align === Text.AlignHCenter ? (col.implicitWidth - width) / 2
                   : (root.align === Text.AlignRight ? col.implicitWidth - width : 0)

                Repeater {
                    model: lineRow.words.length

                    Text {
                        id: word

                        required property int index
                        readonly property real p: root.together ? WM.clamp01(root.reveal)
                            : (root.timed
                               ? WM.wordProgress(root.reveal, root.totalMs, root.delayMs + (lineRow.first + index) * root.stepMs, root.wordMs)
                               : WM.stagger(root.reveal, lineRow.first + index, root.count, root.span))

                        text: lineRow.words[index]
                        color: root.color
                        font.family: Theme.fontFamily
                        font.pixelSize: root.pixelSize
                        font.weight: root.weight
                        opacity: Math.min(1, word.p * 1.7)
                        y: (1 - WM.easeOutCubic(word.p)) * root.rise

                        layer.enabled: word.p > 0 && word.p < 1
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: root.blurMax
                            blur: (1 - word.p) * (1 - word.p)
                        }
                    }
                }
            }
        }
    }
}

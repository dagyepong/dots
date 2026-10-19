import QtQuick
import qs.modules.common
import "../../common/functions/WelcomeMath.js" as WM

// The caption of a slide: a bold title and, under it, a lighter grey line or
// two (the "Base" / "Repeater on Outline layer" pair in the video). The grey
// part comes in a little after the title. Centred, or left-aligned for the
// last slide.
Item {
    id: root

    property string title: ""
    property string sub: ""
    property real reveal: 0
    property real unit: 1
    property int align: Text.AlignHCenter
    property color ink: Theme.pal.deep
    // Words go out all at once instead of one by one.
    property bool together: false

    // The pace of the video (WelcomeMath.js): how long this caption takes to
    // come in. The page runs `reveal` 0 -> 1 over this many ms.
    readonly property int titleWords: WM.wordCount(WM.splitLines(root.title))
    readonly property int subWords: WM.wordCount(WM.splitLines(root.sub))
    readonly property real totalMs: WM.captionMs(root.titleWords, root.subWords)

    implicitWidth: Math.max(titleText.implicitWidth, subText.implicitWidth)
    implicitHeight: titleText.implicitHeight + (root.sub !== "" ? subText.implicitHeight + 6 * root.unit : 0)

    WelcomeBlurText {
        id: titleText

        x: root.align === Text.AlignHCenter ? (root.width - width) / 2 : 0
        text: root.title
        reveal: root.reveal
        timed: true
        together: root.together
        totalMs: root.totalMs
        stepMs: WM.CAPTION.stepMs
        wordMs: WM.CAPTION.wordMs
        pixelSize: 27 * root.unit
        weight: Font.Bold
        color: root.ink
        align: root.align
        lineHeight: 1.12
    }

    WelcomeBlurText {
        id: subText

        x: root.align === Text.AlignHCenter ? (root.width - width) / 2 : 0
        y: titleText.height + 6 * root.unit
        text: root.sub
        reveal: root.reveal
        timed: true
        together: root.together
        totalMs: root.totalMs
        delayMs: WM.CAPTION.subDelayMs
        stepMs: WM.subStepMs(root.subWords)
        wordMs: WM.CAPTION.subWordMs
        pixelSize: 15.5 * root.unit
        weight: Font.Medium
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        align: root.align
        lineHeight: 1.22
    }
}

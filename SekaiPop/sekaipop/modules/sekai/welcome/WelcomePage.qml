import QtQuick
import QtQuick.Effects
import qs.modules.common
import "../../common/functions/WelcomeMath.js" as WM
import "../../common/functions/WelcomeSlides.js" as WS

// The welcome screen's page: one screen's worth of the reference video's
// layout. A pale page with tiny labels in three corners (what this is, the
// "1/5" counter, the brand), the hero in the middle, a bold title with a grey
// line under it, and on the first and last slide a giant faint copy of the
// logo behind it all.
//
// It knows nothing about windows or Quickshell: WelcomeScreen.qml puts it in a
// layer window and WelcomeService.qml decides when it is there. This file only
// draws, animates and answers keys, and tells its owner two things:
//
//   leaveRequested(skipped)   the person is done (clicked past the last slide,
//                             or pressed Esc: skipped is true)
//   exited()                  the leaving animation has finished; the window
//                             can go away now
//
// How it moves: a few numbers run 0..1 and everything is drawn from them (the
// same shape as Serpantinum's Start.qml, whose single intro animation drives
// scalar progress properties):
//
//   pageIn    the page itself fading in / out over the desktop
//   chromeIn  the corner labels
//   ghostIn   the giant faint logo
//   heroIn    the slide's hero (it spreads its own parts across this number)
//   textIn    the caption (words blur in one by one across this number)
//
// Changing slide plays heroIn and textIn out fast, swaps the slide while both
// are at 0, then plays them in again, like the reference's blur-out / blur-in.
Item {
    id: root

    // Only the screen with the keyboard focus shows the slides; any other screen
    // just gets the page and the ghost, so the desktop is covered everywhere.
    property bool showContent: true
    // Set by the service when the screen should go away (from here or from IPC).
    property bool closing: false
    // Path of the current wallpaper picture, for the framed-picture slide.
    property string wallpaper: ""

    signal leaveRequested(bool skipped)
    signal exited()

    // ---- the page's own sizes ----
    readonly property real u: WM.unitFor(root.width, root.height)
    readonly property real margin: 32 * root.u
    // Theme.pal holds plain strings, so the typed accent colour is the one to
    // take channels from.
    readonly property color paper: Qt.tint("#ffffff", Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, 0.1))
    readonly property color ink: Theme.pal.deep

    // ---- where we are ----
    property int index: 0
    property int pending: 0
    // What the swap animation needs to know about the slide it is going to.
    // They are set in go(), before the animation starts, on purpose: a
    // NumberAnimation reads its `to` and `duration` when the whole sequence
    // starts, not when its own turn comes, so a binding on `root.slide` there
    // would still describe the slide we are leaving.
    property real ghostDuring: 0
    property real ghostAfter: 0
    property int heroMsAfter: 700
    // How long the hero on screen takes to go out, and whether its going is
    // linear (the logo works its own easing out, letter by letter).
    property int leaveMs: 180
    property bool leaveLinear: false
    property int textMsAfter: 600
    // True while the slide (or the whole page) is on its way out: the hero then
    // just blurs and fades as one piece, the caption goes as one block, and
    // nothing unbuilds itself backwards.
    property bool leaving: false
    readonly property int textMs: WM.captionMs(WM.wordCount(WM.splitLines(root.slide.title)),
                                               WM.wordCount(WM.splitLines(WS.subOf(root.slide))))
    readonly property var slide: WS.SLIDES[root.index]
    readonly property int count: WS.SLIDES.length

    // ---- the progress numbers ----
    property real pageIn: 0
    property real chromeIn: 0
    property real ghostIn: 0
    property real heroIn: 0
    property real textIn: 0
    property real idle: 0

    readonly property bool busy: introAnim.running || swapAnim.running || exitAnim.running
    // The hero moves a little for as long as nothing else does; a slide with
    // nothing that moves (the picture, the credits) lets the screen go still.
    readonly property bool idleWanted: root.showContent && !root.closing && root.heroIn >= 1
                                       && (root.slide.kind === "logo" || root.slide.kind === "glyph" || root.slide.kind === "units")

    readonly property var keys: ({
        Escape: Qt.Key_Escape, Right: Qt.Key_Right, Down: Qt.Key_Down, Space: Qt.Key_Space,
        Return: Qt.Key_Return, Enter: Qt.Key_Enter, PageDown: Qt.Key_PageDown,
        Left: Qt.Key_Left, Up: Qt.Key_Up, Backspace: Qt.Key_Backspace, PageUp: Qt.Key_PageUp
    })

    // Next (+1) / back (-1). Ignored while something is moving, so a double
    // click can't skip a slide half way through.
    function go(dir) {
        if (!root.showContent || root.busy || root.closing)
            return;
        const s = WM.step(root.index, root.count, dir);
        if (s.finish) {
            root.leaveRequested(false);
            return;
        }
        if (s.stay)
            return;
        root.pending = s.index;
        const from = root.slide;
        const to = WS.SLIDES[s.index];
        root.ghostDuring = (from.ghost && to.ghost) ? 1 : 0;
        root.ghostAfter = to.ghost ? 1 : 0;
        root.heroMsAfter = WS.heroMs(to.kind);
        root.textMsAfter = WM.captionMs(WM.wordCount(WM.splitLines(to.title)),
                                        WM.wordCount(WM.splitLines(WS.subOf(to))));
        swapAnim.restart();
    }

    function skip() {
        if (!root.closing)
            root.leaveRequested(true);
    }

    focus: root.showContent
    Keys.onPressed: event => {
        const d = WM.keyDirection(event.key, root.keys);
        if (d === null)
            return;
        event.accepted = true;
        if (d === 0)
            root.skip();
        else
            root.go(d);
    }

    onClosingChanged: {
        if (!root.closing)
            return;
        introAnim.stop();
        swapAnim.stop();
        root.leaveMs = WS.leaveMs(root.slide.kind);
        root.leaveLinear = root.slide.kind === "logo";
        exitAnim.restart();
    }

    Component.onCompleted: {
        if (root.showContent)
            root.forceActiveFocus();
        introAnim.start();
    }

    // ================= the animations =================

    // The pace of all of this is the reference video's, counted frame by frame
    // at 30 fps (WelcomeMath.js and WelcomeSlides.js have the numbers):
    //   in    the page and the corner labels fade at once; the hero starts a
    //         couple of frames later and lands on a spring; the caption starts
    //         a couple of frames after the hero and runs at its own word pace
    //   out   4 to 5 frames: the hero and the caption blur away together
    //   swap  a short empty beat, then the next slide comes in the same way
    // The hero's and the caption's numbers run linearly; the spring, the blur
    // and the rest of the look are made from them (see heroBox below).

    SequentialAnimation {
        id: introAnim

        ParallelAnimation {
            NumberAnimation { target: root; property: "pageIn"; to: 1; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "chromeIn"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "ghostIn"; to: root.slide.ghost ? 1 : 0; duration: 420; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 80 }
                NumberAnimation { target: root; property: "heroIn"; to: 1; duration: WS.heroMs(root.slide.kind) }
            }
            SequentialAnimation {
                PauseAnimation { duration: 140 }
                NumberAnimation { target: root; property: "textIn"; to: 1; duration: root.textMs }
            }
        }
    }

    SequentialAnimation {
        id: swapAnim

        // out: the hero, the caption and the ghost blur away together
        ScriptAction { script: root.leaving = true }
        ParallelAnimation {
            NumberAnimation { target: root; property: "heroIn"; to: 0; duration: root.leaveMs; easing.type: root.leaveLinear ? Easing.Linear : Easing.InQuad }
            NumberAnimation { target: root; property: "textIn"; to: 0; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation {
                target: root; property: "ghostIn"
                to: root.ghostDuring
                duration: Math.max(180, root.leaveMs * 0.6); easing.type: Easing.InOutQuad
            }
        }
        // swap: nothing is showing now, so nothing shows the change (and the
        // corner counter ticks over, as it does in the video)
        ScriptAction { script: { root.leaving = false; root.index = root.pending } }
        PauseAnimation { duration: 50 }
        // in
        ParallelAnimation {
            NumberAnimation { target: root; property: "ghostIn"; to: root.ghostAfter; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "heroIn"; to: 1; duration: root.heroMsAfter }
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation { target: root; property: "textIn"; to: 1; duration: root.textMsAfter }
            }
        }
    }

    SequentialAnimation {
        id: exitAnim

        ScriptAction { script: root.leaving = true }
        ParallelAnimation {
            NumberAnimation { target: root; property: "heroIn"; to: 0; duration: root.leaveMs; easing.type: root.leaveLinear ? Easing.Linear : Easing.InQuad }
            NumberAnimation { target: root; property: "textIn"; to: 0; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "chromeIn"; to: 0; duration: Math.max(220, root.leaveMs * 0.7) }
            NumberAnimation { target: root; property: "ghostIn"; to: 0; duration: Math.max(220, root.leaveMs * 0.7) }
        }
        NumberAnimation { target: root; property: "pageIn"; to: 0; duration: 280; easing.type: Easing.InOutQuad }
        ScriptAction { script: root.exited() }
    }

    // A slow turn of one full circle: the hero's floating and twinkling read it.
    NumberAnimation on idle {
        from: 0
        to: Math.PI * 2
        duration: 5200
        loops: Animation.Infinite
        running: root.idleWanted
    }

    // ================= the page =================

    Rectangle {
        anchors.fill: parent
        color: root.paper
        opacity: root.pageIn
    }

    WelcomeGhost {
        anchors.fill: parent
        page: root.paper
        shown: root.ghostIn * root.pageIn
    }

    // Anything that takes clicks sits below the content, so a click anywhere
    // moves on (the video has no buttons: the whole page is the control).
    MouseArea {
        anchors.fill: parent
        enabled: root.showContent
        onClicked: root.go(1)
    }

    // ---- corner labels (what the reference has in three corners) ----
    component Label: Text {
        color: root.ink
        font.family: Theme.fontFamily
        font.pixelSize: 12.5 * root.u
        font.weight: Font.Medium
        font.letterSpacing: 0.3 * root.u
        lineHeight: 1.05
        opacity: root.chromeIn
    }

    Label {
        visible: root.showContent
        x: root.margin
        y: root.margin
        text: "SEKAIPOP\nWELCOME TOUR"
    }

    Label {
        visible: root.showContent
        x: root.margin
        y: root.height - root.margin - height
        text: WM.pageLabel(root.index, root.count)
    }

    Label {
        visible: root.showContent
        x: root.width - root.margin - width
        y: root.height - root.margin - height
        text: "SEKAIPOP \u00b7 QUICKSHELL"
    }

    // ---- the hint at the bottom: how to move on, after a pause ----
    Label {
        id: hint

        visible: root.showContent
        anchors.horizontalCenter: parent.horizontalCenter
        // a line above the corner row, so on a narrow screen it can't run into
        // the counter or the brand
        y: root.height - root.margin - height - 22 * root.u
        text: WM.hintFor(root.index, root.count)
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        font.pixelSize: 11 * root.u
        opacity: root.hintShown ? root.chromeIn : 0

        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    // The hint comes in once a slide has been still for a while, and goes as
    // soon as anything moves again. (`settled` is its own property, and the
    // timer only ever turns the hint on: a single-shot timer sets running back
    // to false the moment it fires, so tying the flag to the timer's own
    // `running` would switch the hint off again right after switching it on.)
    readonly property bool settled: root.showContent && !root.busy && !root.closing
                                    && root.heroIn >= 1 && root.textIn >= 1
    property bool hintShown: false

    onSettledChanged: {
        if (!root.settled)
            root.hintShown = false;
    }

    Timer {
        interval: 2600
        running: root.settled
        onTriggered: root.hintShown = true
    }

    // ---- the hero ----
    //
    // How a hero lands (measured on the video): it starts small, low, tilted
    // and blurred, reaches nearly full size in about 6 frames while it sharpens
    // and fades in, hops about 8% past its size and settles on a spring. The
    // band and the picture open up from a thin line instead (WS.heroPose).
    // Leaving is simpler: it stays where it is and blurs and fades as one piece
    // (the logo is the exception: its own letters collapse into its middle).
    Item {
        id: heroBox

        visible: root.showContent
        anchors.fill: parent

        readonly property var pose: WS.heroPose(root.slide.kind)
        // 0 -> about 1.08 -> 1; while leaving it is not used
        readonly property real k: root.leaving ? 1 : WM.spring(root.heroIn, heroBox.pose.rate)
        readonly property real cx: root.width / 2
        readonly property real cy: root.height * WS.heroCenter(root.slide.kind)
        // The logo's letters pop in one by one, each on its own (WelcomeLogo),
        // so the logo as a whole is not blurred, faded or scaled on the way in;
        // every other hero comes in as one piece.
        readonly property bool ownMotion: root.slide.kind === "logo"
        // Sharp by a third of the way in; no layer at all once it has landed.
        readonly property real blurAmount: heroBox.ownMotion ? 0
                                         : (root.leaving ? WM.clamp01(1 - root.heroIn)
                                                         : WM.clamp01(1 - root.heroIn * 3))

        opacity: heroBox.ownMotion ? (root.heroIn > 0 ? 1 : 0)
                                   : (root.leaving ? root.heroIn : Math.min(1, root.heroIn * 4))
        layer.enabled: heroBox.blurAmount > 0.001
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 40
            blur: heroBox.blurAmount
        }

        transform: [
            Scale {
                origin.x: heroBox.cx
                origin.y: heroBox.cy
                xScale: (root.leaving && !heroBox.ownMotion) ? 0.97 + 0.03 * root.heroIn
                                     : heroBox.pose.scale + (1 - heroBox.pose.scale) * heroBox.k
                yScale: (root.leaving && !heroBox.ownMotion) ? 0.97 + 0.03 * root.heroIn
                                     : heroBox.pose.openY + (1 - heroBox.pose.openY) * heroBox.k
            },
            Rotation {
                origin.x: heroBox.cx
                origin.y: heroBox.cy
                angle: root.leaving ? 0 : heroBox.pose.rotate * (1 - heroBox.k)
            },
            Translate {
                y: root.leaving ? 0 : heroBox.pose.rise * root.u * (1 - heroBox.k)
            }
        ]

        Loader {
            id: heroLoader

            // No width or height of its own on purpose: a Loader that has them
            // resizes the item it loads, and the hero sizes itself.
            x: (root.width - (item ? item.width : 0)) / 2
            y: root.height * WS.heroCenter(root.slide.kind) - (item ? item.height : 0) / 2
            sourceComponent: {
                switch (root.slide.kind) {
                case "logo": return logoHero;
                case "glyph": return glyphHero;
                case "units": return unitsHero;
                case "frame": return frameHero;
                default: return null;
                }
            }
        }
    }

    Component {
        id: logoHero

        WelcomeLogo {
            unit: root.u
            reveal: root.leaving ? 1 : root.heroIn
            leave: root.leaving ? 1 - root.heroIn : 0
            idle: root.idle
            idling: root.idleWanted
        }
    }

    Component {
        id: glyphHero

        WelcomeGlyphHero {
            unit: root.u
            reveal: root.leaving ? 1 : root.heroIn
            idle: root.idle
            idling: root.idleWanted
            glyph: root.slide.glyph || "phone_iphone"
            glyphFill: root.slide.glyphFill || 0
        }
    }

    Component {
        id: unitsHero

        WelcomeUnitsHero {
            unit: root.u
            reveal: root.leaving ? 1 : root.heroIn
            idle: root.idle
            idling: root.idleWanted
            pageWidth: root.width
        }
    }

    Component {
        id: frameHero

        WelcomeFrameHero {
            unit: root.u
            reveal: root.leaving ? 1 : root.heroIn
            wallpaper: root.wallpaper
        }
    }

    // ---- the caption ----
    WelcomeCaption {
        id: caption

        readonly property bool isCredits: root.slide.kind === "credits"
        readonly property real captionWidth: Math.min(root.width - 2 * root.margin, 440 * root.u)

        visible: root.showContent
        width: isCredits ? implicitWidth : captionWidth
        x: (root.width - width) / 2
        y: root.slide.top ? root.height * 0.2 - height / 2
           : (isCredits ? root.height * 0.47 - height / 2 : root.height * 0.745)
        unit: root.u
        title: root.slide.title
        sub: WS.subOf(root.slide)
        reveal: root.textIn
        together: root.leaving
        ink: root.ink
        align: isCredits ? Text.AlignLeft : Text.AlignHCenter
    }
}

import QtQuick
import Quickshell.Io

Item {
    id: root

    property string petColor: "#cba6f7"
    property bool mirror: false
    property string currentState: "idle"
    property real happiness: 0.5
    property real moveSpeed: 0
    property real restDrive: 0
    property string spriteDir: ""
    property var actionMap: ({})

    property var _animData: null
    property string _animName: "Walk"
    property int _frame: 0
    property int _dirRow: 0
    property real zoomiesHue: 0

    readonly property bool useSpriteSheet: _animData !== null && !!_animData["Walk"]

    readonly property var _defaultMap: ({
        "idle": "Idle", "walk": "Walk", "wander": "Walk",
        "sit": "Sleep", "deepsleep": "Laying",
        "react": "Hurt", "zoomies": "Charge", "drag": "Walk",
        "attack": "Attack", "hop": "Hop", "shoot": "Shoot",
        "charge": "Charge", "double": "Double",
        "strike": "Strike", "quickStrike": "QuickStrike",
        "multiStrike": "MultiStrike", "spAttack": "SpAttack", "swing": "Swing",
        "lookUp": "LookUp", "nod": "Nod", "pose": "Pose",
        "eat": "Eat", "trip": "Trip", "wake": "Wake",
        "deepBreath": "DeepBreath", "cringe": "Cringe",
        "sitDown": "Sit", "faint": "Faint",
        "rotate": "Rotate", "twirl": "Twirl",
        "tumble": "Tumble", "tumbleBack": "TumbleBack", "pain": "Pain",
        "hide": "Withdraw", "sink": "Sink", "float": "Float",
        "leapForth": "LeapForth", "hitGround": "HitGround"
    })

    readonly property var _singleRowAnims: ({"Sleep": true, "Laying": true, "Eat": true, "Sit": true})

    function _resolveAnim(state: string): string {
        return actionMap[state] ?? _defaultMap[state] ?? "Walk";
    }

    function setState(name: string): void {
        currentState = name;
        if (name !== "zoomies") zoomiesHue = 0;
        var newAnim = _resolveAnim(name);
        if (_animData && !_animData[newAnim]) {
            var fallbacks = {
                "idle": ["Idle", "Walk"],
                "deepsleep": ["Laying", "Faint", "Sleep"],
                "sit": ["Sleep", "Sit", "Walk"],
                "wake": ["Wake", "Hurt", "Walk"],
                "deepBreath": ["DeepBreath", "Sleep", "Walk"],
                "cringe": ["Cringe", "Hurt", "Walk"],
                "lookUp": ["Pose", "Hurt", "Walk"],
                "nod": ["Nod", "Walk"],
                "pose": ["Pose", "Hop", "Walk"],
                "eat": ["Eat", "Walk"],
                "trip": ["Trip", "LostBalance", "Hurt", "Walk"],
                "sitDown": ["Sit", "Sleep", "Walk"],
                "faint": ["Faint", "Sleep", "Walk"],
                "rotate": ["Rotate", "Twirl", "Charge", "Walk"],
                "twirl": ["Twirl", "Rotate", "Walk"],
                "tumble": ["Tumble", "Trip", "Hurt", "Walk"],
                "tumbleBack": ["TumbleBack", "Tumble", "Hurt", "Walk"],
                "pain": ["Pain", "Hurt", "Walk"],
                "hide": ["Withdraw", "Sink", "Cringe", "Hurt", "Walk"],
                "sink": ["Sink", "Withdraw", "Cringe", "Walk"],
                "float": ["Float", "Pose", "Idle", "Walk"],
                "leapForth": ["LeapForth", "Attack", "Walk"],
                "hitGround": ["HitGround", "TumbleBack", "Hurt", "Walk"],
            };
            var chain = fallbacks[name] || [newAnim, "Walk"];
            newAnim = "Walk";
            for (var i = 0; i < chain.length; i++) {
                if (_animData[chain[i]]) { newAnim = chain[i]; break; }
            }
        }
        if (newAnim !== _animName) { _animName = newAnim; _frame = 0; _ticksInFrame = 0; }
        if (_singleRowAnims[newAnim] || name === "drag" || name === "deepsleep") _dirRow = 0;
        if (!useSpriteSheet) _resetBody();
    }

    function setDirection(angle: real): void {
        if (!useSpriteSheet) return;
        if (_singleRowAnims[_animName] || currentState === "drag") return;
        // map angle to PMD 8-direction row order
        var a = ((angle % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
        var sector = Math.round(a / (Math.PI / 4)) % 8;
        var map = [2, 1, 0, 7, 6, 5, 4, 3];
        _dirRow = map[sector];
    }

    FileView {
        id: animFile
        path: root.spriteDir ? root.spriteDir + "/AnimData.xml" : ""
        onLoaded: {
            root._animData = root._parseAnimData(text());
            // a state entered before the parse finished skipped the fallback
            // chains; re-resolve it against the real animation list
            root.setState(root.currentState);
        }
    }

    function _parseAnimData(xml: string): var {
        var anims = {};
        var blocks = xml.match(/<Anim>[\s\S]*?<\/Anim>/g) || [];
        for (var i = 0; i < blocks.length; i++) {
            var b = blocks[i];
            var name = (b.match(/<Name>(.*?)<\/Name>/) || [])[1];
            var copyOf = (b.match(/<CopyOf>(.*?)<\/CopyOf>/) || [])[1];
            if (copyOf) { anims[name] = { copyOf: copyOf }; continue; }
            var fw = parseInt((b.match(/<FrameWidth>(.*?)<\/FrameWidth>/) || [])[1]) || 0;
            var fh = parseInt((b.match(/<FrameHeight>(.*?)<\/FrameHeight>/) || [])[1]) || 0;
            var durMatches = b.match(/<Duration>(\d+)<\/Duration>/g) || [];
            var durs = [];
            for (var j = 0; j < durMatches.length; j++)
                durs.push(parseInt(durMatches[j].match(/\d+/)[0]));
            // sheet: which -Anim.png holds the frames; CopyOf anims have no
            // PNG of their own and inherit their target's on resolution
            anims[name] = { frameWidth: fw, frameHeight: fh, durations: durs, frameCount: durs.length, sheet: name };
        }
        // multi-pass CopyOf resolution for chained references
        var maxPasses = 10;
        for (var pass = 0; pass < maxPasses; pass++) {
            var unresolved = false;
            for (var n in anims) {
                if (anims[n].copyOf) {
                    var target = anims[anims[n].copyOf];
                    if (target && !target.copyOf) {
                        anims[n] = Object.assign({}, target);
                    } else if (target) {
                        unresolved = true;
                    }
                }
            }
            if (!unresolved) break;
        }
        for (var n2 in anims) if (anims[n2].copyOf) delete anims[n2];
        return anims;
    }

    property var _currentAnim: useSpriteSheet ? (_animData ? (_animData[_animName] || _animData["Walk"] || null) : null) : null
    property int _ticksInFrame: 0

    Timer {
        running: root.useSpriteSheet && root._currentAnim !== null
        interval: {
            var s = root.currentState;
            if (s === "walk" || s === "wander" || s === "zoomies") {
                var sf = Math.max(0.3, root.moveSpeed / 120);
                return Math.max(15, 30 / sf);
            }
            if (s === "sit") return Math.max(60, 250 * root.restDrive);
            if (s === "idle") return root._animName === "Walk" ? 50 : 120;
            return 50;
        }
        repeat: true
        onTriggered: {
            var anim = root._currentAnim;
            if (!anim || !anim.durations || anim.durations.length === 0) return;
            if (root.currentState === "drag") return;
            // _frame can outlive a switch to a shorter fallback anim;
            // durations[_frame] would be undefined and freeze the loop
            if (root._frame >= anim.frameCount) {
                root._frame = 0;
                root._ticksInFrame = 0;
            }
            root._ticksInFrame++;
            if (root._ticksInFrame >= anim.durations[root._frame]) {
                root._ticksInFrame = 0;
                root._frame = (root._frame + 1) % anim.frameCount;
            }
        }
    }

    // One frame of the sheet shown through a clipping viewport. The full
    // sheet loads once and frame changes just move it, so sourceSize is the
    // real image size (with sourceClipRect it would be a single frame's,
    // collapsing the row/column counts to 1 and freezing the animation).
    Item {
        id: viewport
        visible: root.useSpriteSheet && root._currentAnim !== null && sheet.status === Image.Ready
        anchors.centerIn: parent
        readonly property real px: root.width / 32
        readonly property int fw: root._currentAnim ? root._currentAnim.frameWidth : 1
        readonly property int fh: root._currentAnim ? root._currentAnim.frameHeight : 1
        width: fw * px; height: fh * px
        clip: true

        Image {
            id: sheet
            source: root.spriteDir && root._currentAnim
                  ? root.spriteDir + "/" + root._currentAnim.sheet + "-Anim.png" : ""
            smooth: false
            width: sourceSize.width * viewport.px
            height: sourceSize.height * viewport.px
            // PMD sheets vary: most anims have 8 direction rows, some (Sleep,
            // Sink, Tumble, ...) only 1. Clamp so a stale frame or row can
            // never point outside the sheet.
            readonly property int cols: viewport.fw > 0 && sourceSize.width > 0
                ? Math.max(1, Math.floor(sourceSize.width / viewport.fw)) : 1
            readonly property int rows: viewport.fh > 0 && sourceSize.height > 0
                ? Math.max(1, Math.floor(sourceSize.height / viewport.fh)) : 1
            x: -Math.min(root._frame, cols - 1) * viewport.fw * viewport.px
            y: -Math.min(root._dirRow, rows - 1) * viewport.fh * viewport.px
        }
    }

    function _resetBody(): void {
        body.scale = 1.0;
        body.opacity = (currentState === "drag") ? 0.75 : 1.0;
        body.width = (currentState === "sit") ? root.width * 1.15 : root.width;
        body.height = (currentState === "sit") ? root.height * 0.75 : root.height;
    }

    Rectangle {
        // last-resort stand-in if a sheet PNG fails to load: a visible blob
        // beats an invisible pet
        id: body; visible: !root.useSpriteSheet || sheet.status === Image.Error; anchors.centerIn: parent
        width: parent.width; height: parent.height
        radius: (currentState === "sit") ? width * 0.25 : width * 0.2
        color: (currentState === "zoomies") ? Qt.hsla(zoomiesHue, 0.6, 0.7, 1.0)
             : (currentState === "sit") ? Qt.darker(petColor, 1.15)
             : (currentState === "react") ? Qt.lighter(petColor, 1.3)
             : (currentState === "drag") ? Qt.lighter(petColor, 1.2) : petColor
        transform: Scale { origin.x: body.width / 2; origin.y: body.height / 2; xScale: root.mirror ? -1 : 1 }
        Behavior on color { ColorAnimation { duration: 250 } }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: parent.height * 0.22
            spacing: parent.width * 0.22; visible: root.currentState !== "sit"
            Repeater { model: 2; Rectangle { width: body.width * 0.14; height: width; radius: width / 2; color: Qt.darker(root.petColor, 2.5) } }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: parent.height * 0.52
            width: body.width * (0.12 + root.happiness * 0.12); height: body.height * 0.06
            radius: height / 2; color: Qt.darker(root.petColor, 2.2); visible: root.currentState !== "sit"
        }
    }
    SequentialAnimation { running: !useSpriteSheet && currentState === "idle"; loops: Animation.Infinite
        NumberAnimation { target: body; property: "scale"; from: 1.0; to: 1.03; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { target: body; property: "scale"; from: 1.03; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
    }
    SequentialAnimation { running: !useSpriteSheet && currentState === "walk"; loops: Animation.Infinite
        ParallelAnimation {
            NumberAnimation { target: body; property: "width"; from: root.width; to: root.width * 1.08; duration: 180 }
            NumberAnimation { target: body; property: "height"; from: root.height; to: root.height * 0.92; duration: 180 }
        }
        ParallelAnimation {
            NumberAnimation { target: body; property: "width"; from: root.width * 1.08; to: root.width; duration: 180 }
            NumberAnimation { target: body; property: "height"; from: root.height * 0.92; to: root.height; duration: 180 }
        }
    }
    SequentialAnimation { running: !useSpriteSheet && currentState === "react"
        NumberAnimation { target: body; property: "scale"; from: 1.0; to: 1.35; duration: 100; easing.type: Easing.OutBack }
        NumberAnimation { target: body; property: "scale"; from: 1.35; to: 0.9; duration: 120; easing.type: Easing.InQuad }
        NumberAnimation { target: body; property: "scale"; from: 0.9; to: 1.0; duration: 200; easing.type: Easing.OutBounce }
    }
    NumberAnimation on zoomiesHue { running: !useSpriteSheet && currentState === "zoomies"; loops: Animation.Infinite; from: 0; to: 1; duration: 3000 }
}

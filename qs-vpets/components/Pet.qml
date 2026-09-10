import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"
import "ai/Personality.js" as Personality
import "ai/Brain.js" as Brain
import "ai/Perception.js" as Perception
import "ai/Drives.js" as Drives
import "ai/Memory.js" as Memory
import "PetNav.js" as Nav
import "PetPersistence.js" as Persist

Item {
    id: root

    required property var petData
    // the screen this pet's window currently occupies (bound by PetWindow)
    property var petScreen: null
    // the PetWindow hosting this pet (for cross-screen placement)
    property var petWindow: null

    readonly property var _basePersonality: Personality.resolve(
        petData.personality ?? "curious", petData.name ?? "pet", petData.traits ?? null)
    readonly property var personality: {
        if (!learnedTraits) return _basePersonality;
        var p = {};
        var keys = Object.keys(_basePersonality);
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            p[k] = Math.max(0, Math.min(1, _basePersonality[k] + (learnedTraits[k] || 0)));
        }
        return p;
    }

    property string state_: "idle"
    property real moveAngle: 0
    property bool facingRight: true
    property real worldX: 0
    property real worldY: 0

    property real happiness: 0.5
    property real restDrive: 0.1
    property real exploreDrive: 0.3
    property real socialDrive: 0.2
    property real comfortDrive: 0.0
    property real playDrive: 0.1
    property real alertness: 0.5
    property real boredom: 0.0
    property real mood: 0.5
    property var thoughts: []
    property var intention: null
    property var visitedCells: ({})
    property var windowPrefs: ({})
    property var placeMemory: ({})
    property var relationships: ({})
    property var learnedTraits: null
    property real _lastTrackTime: 0
    property int _hour: new Date().getHours()
    readonly property bool isNighttime: _hour >= 23 || _hour < 6

    // home and journey targets live in global (multi-monitor) coordinates
    property real homeGX: 0
    property real homeGY: 0
    readonly property real homeRadius: 200
    property bool onJourney: false
    property int journeyBlocked: 0
    property real targetGX: 0
    property real targetGY: 0

    // what the pet is currently looking at (global coords)
    property real attentionGX: 0
    property real attentionGY: 0
    property real attentionUntil: 0

    // contentment after a completed outing (Brain sets it; damps new goals)
    property real calmUntil: 0
    // learned 24h histogram of user presence (Memory.observeUser)
    property var userRhythm: ({})
    // per-event-type cooldown timestamps (Brain._cooldown)
    property var _eventCooldowns: ({})

    readonly property var windowTracker: WindowTracker
    readonly property var petManager: PetManager
    readonly property var systemMonitor: SystemMonitor
    readonly property var inputTracker: InputTracker
    property alias sprite: sprite

    function screenW() { return petScreen ? petScreen.width : (parent ? parent.width : 1920); }
    function screenH() { return petScreen ? petScreen.height : (parent ? parent.height : 1080); }
    function screenX() { return petScreen ? petScreen.x : 0; }
    function screenY() { return petScreen ? petScreen.y : 0; }
    function allScreens() {
        var out = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i];
            if (s.width > 100 && s.height > 100 && !s.name.startsWith("Unknown"))
                out.push({ x: s.x, y: s.y, width: s.width, height: s.height, name: s.name });
        }
        return out;
    }

    readonly property var _actionFallbackMs: ({
        react: 600, hop: 800, attack: 1000, shoot: 900,
        lookUp: 1500, nod: 800, pose: 1500, eat: 2000, trip: 1000,
        wake: 1200, deepBreath: 2000, cringe: 800, sitDown: 1500,
        faint: 1500, charge: 1200, double: 1000,
        strike: 1000, quickStrike: 800, multiStrike: 1200, spAttack: 1200, swing: 1000,
        rotate: 1200, twirl: 1000, tumble: 900, tumbleBack: 900, pain: 900,
        hide: 1500, sink: 1200, float: 2000, leapForth: 900, hitGround: 900,
    })

    function enterState(s) {
        if (state_ === s) return;
        _stopAllTimers();
        if (s === "drag") {
            onJourney = false;
            intention = null;
        }
        state_ = s;
        sprite.setState(s);
        if (s === "walk" || s === "wander" || s === "zoomies") sprite.setDirection(moveAngle);

        switch (s) {
        case "idle":
            idleTimer.interval = alertness > 0.5 ? (4000 + Math.random() * 7000)
                               : alertness > 0.25 ? (8000 + Math.random() * 12000)
                               : (15000 + Math.random() * 25000);
            idleTimer.restart(); break;
        case "walk":
            walkTimer.interval = 2000 + Math.random() * 3000;
            walkTimer.restart(); break;
        case "wander":
            wanderDirTimer.interval = 2000;
            wanderDirTimer.restart();
            wanderEndTimer.interval = 5000 + Math.random() * 10000;
            wanderEndTimer.restart(); break;
        case "sit":
        case "deepsleep":
            // periodic "stay asleep?" check; Brain.restTick decides, so sleep
            // sessions run as long as the pressure holds (hours, at night)
            sitTimer.interval = 45000 + Math.random() * 75000;
            sitTimer.restart(); break;
        case "zoomies":
            wanderDirTimer.interval = 1000;
            wanderDirTimer.restart();
            zoomiesTimer.interval = 5000 + Math.random() * 10000;
            zoomiesTimer.restart(); break;
        case "drag":
            break;
        default:
            actionTimer.interval = _animDuration() || _actionFallbackMs[s] || 800;
            actionTimer.restart(); break;
        }
    }

    readonly property int _spriteTickMs: 50

    function _animDuration() {
        var anim = sprite._animData ? sprite._animData[sprite._animName] : null;
        if (!anim || !anim.durations) return 0;
        var total = 0;
        for (var i = 0; i < anim.durations.length; i++) total += anim.durations[i];
        return total * _spriteTickMs;
    }

    function restartIdle(mult) {
        var base = alertness > 0.5 ? (4000 + Math.random() * 8000)
                 : alertness > 0.25 ? (9000 + Math.random() * 14000)
                 : (15000 + Math.random() * 30000);
        idleTimer.interval = base * (mult || 1);
        idleTimer.restart();
    }

    // keep resting in the given depth; restarts the rest-check timer even when
    // the state doesn't change (enterState would early-return)
    function continueResting(s) {
        if (s !== state_) { enterState(s); return; }
        sitTimer.interval = 45000 + Math.random() * 75000;
        sitTimer.restart();
    }
    function restartWalk() { walkTimer.interval = 2000 + Math.random() * 3000; walkTimer.restart(); }

    function _stopAllTimers() {
        idleTimer.stop(); walkTimer.stop();
        wanderDirTimer.stop(); wanderEndTimer.stop();
        sitTimer.stop(); actionTimer.stop(); zoomiesTimer.stop();
    }

    Timer { id: idleTimer; onTriggered: Brain.think(root, Nav) }
    Timer { id: walkTimer; onTriggered: Nav.walkArrived(root) }
    Timer { id: wanderEndTimer; onTriggered: root.enterState("idle") }
    Timer { id: actionTimer; onTriggered: root.enterState("idle") }

    Timer { id: sitTimer; onTriggered: Brain.restTick(root) }

    Timer { id: zoomiesTimer; onTriggered: root.enterState("idle") }

    Timer { id: wanderDirTimer; interval: 2000; repeat: true; onTriggered: {
        root.moveAngle += (Math.random() - 0.5) * Math.PI * 0.5;
        root.facingRight = Math.cos(root.moveAngle) >= 0;
        sprite.setDirection(root.moveAngle);
    }}

    Timer {
        id: idleFidgetTimer
        interval: 6000 + Math.random() * 9000
        running: root.state_ === "idle"; repeat: true
        onTriggered: {
            var f = Brain.fidget(root);
            if (f) {
                sprite.setState(f);
                var animDur = _animDuration() || 800;
                fidgetRevert.interval = animDur;
                fidgetRevert.restart();
                if (idleTimer.interval < animDur + 500) {
                    idleTimer.interval = animDur + 500;
                    idleTimer.restart();
                }
            }
            interval = 6000 + Math.random() * 9000;
        }
    }
    Timer {
        id: fidgetRevert
        onTriggered: if (root.state_ === "idle") sprite.setState("idle")
    }

    readonly property var _restingAnims: ({ Idle: true, Sleep: true, Laying: true })

    // While idling, look at whatever holds the pet's attention; otherwise
    // settle back to facing forward.
    Timer {
        id: faceAttentionTimer
        property int _ticks: 0
        interval: 400; repeat: true
        running: root.state_ === "idle" || root.state_ === "sit" || root.state_ === "deepsleep"
        onTriggered: {
            if (fidgetRevert.running) return;
            if (!root._restingAnims[sprite._animName]) return;
            if (Date.now() < root.attentionUntil && root.state_ === "idle") {
                var dx = root.attentionGX - (root.screenX() + root.worldX);
                var dy = root.attentionGY - (root.screenY() + root.worldY);
                if (Math.abs(dx) + Math.abs(dy) > 40) {
                    root.facingRight = dx >= 0;
                    sprite.setDirection(Math.atan2(dy, dx));
                    _ticks = 0;
                    return;
                }
            }
            if (sprite._dirRow === 0) { _ticks = 0; return; }
            _ticks++;
            if (_ticks >= 4) sprite._dirRow = 0;
        }
        onRunningChanged: _ticks = 0
    }

    // Metabolism: integrate drives against real elapsed time.
    property real _lastMetabolism: Date.now()
    property int _metabolismTicks: 0
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root._hour = new Date().getHours();
            var now = Date.now();
            var dt = Math.min(60, (now - root._lastMetabolism) / 1000);
            root._lastMetabolism = now;
            var perc = Perception.perceive(root);
            Drives.integrate(root, perc, dt);
            Memory.observeUser(root, perc);
            if (++root._metabolismTicks % 6 === 0) {
                Memory.decayPreferences(root);
                Memory.decayPlaceMemory(root);
                Memory.decayRelationships(root);
            }
        }
        Component.onCompleted: interval = 4600 + Math.random() * 800
    }

    Timer {
        interval: 30 * 60000; running: true; repeat: true
        onTriggered: Brain.reflect(root)
    }

    readonly property real currentSpeed: {
        if (state_ === "walk") {
            var u = intention ? intention.urgency : 0.5;
            return Config.walkSpeed * (0.7 + u * 0.5);
        }
        if (state_ === "wander") return Config.walkSpeed * 0.35;
        if (state_ === "zoomies") return Config.walkSpeed * 1.4;
        return 0;
    }

    function updateMovement(dt) {
        if (currentSpeed <= 0) return;
        var step = currentSpeed * dt;

        if (onJourney) {
            var gdx = targetGX - (screenX() + worldX);
            var gdy = targetGY - (screenY() + worldY);
            if (Math.sqrt(gdx * gdx + gdy * gdy) <= step) {
                worldX = Math.max(0, Math.min(screenW() - width, targetGX - screenX()));
                worldY = Math.max(0, Math.min(screenH() - height, targetGY - screenY()));
                Nav.walkArrived(root);
                return;
            }
        }

        worldX += Math.cos(moveAngle) * step;
        worldY += Math.sin(moveAngle) * step;
        Memory.trackPosition(root);
    }

    function reflectOffWall(hitX, hitY) { Nav.reflectOffWall(root, hitX, hitY); }

    function onCursorNear() { Brain.onEvent(root, "cursor_near", null, Nav); }
    function onPetted() { Brain.onEvent(root, "petted", null, Nav); }
    function onWindowEvent(cls) { Brain.onEvent(root, "window_focused", { windowClass: cls }, Nav); }
    function onWindowOpened(cls) { Brain.onEvent(root, "window_opened", { windowClass: cls }, Nav); }
    function onWorkspaceChanged() { Brain.onEvent(root, "workspace_changed", null, Nav); }
    function onIdleBegan() { Brain.onEvent(root, "user_idle", null, Nav); }
    function onIdleEnded() { Brain.onEvent(root, "user_active", null, Nav); }

    // called by other pets' Social interactions
    function socialEvent(kind, fromPet) {
        Brain.onEvent(root, "pet_" + kind, { fromPet: fromPet }, Nav);
    }

    SpriteAnimation {
        id: sprite
        anchors.fill: parent
        petColor: petData.color ?? "#cba6f7"
        mirror: !root.facingRight
        happiness: root.happiness
        actionMap: petData.actions ?? {}
        moveSpeed: root.currentSpeed
        restDrive: root.restDrive
        spriteDir: petData.sprite ? Qt.resolvedUrl("../assets/sprites/" + petData.sprite) : ""
    }

    property alias _stateFileView: stateFile
    property alias _stateMkdir: stateMkdir
    property string _statePendingJson: ""

    FileView {
        id: stateFile
        path: Config.configDir + "/state-" + root.petData.name + ".json"
        onLoaded: Persist.load(root)
    }
    Process { id: stateMkdir; command: ["mkdir", "-p", Config.configDir]; onExited: stateFile.setText(root._statePendingJson) }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: Persist.save(root) }

    Component.onCompleted: { PetManager.register(root); enterState("react"); }
    Component.onDestruction: { Persist.save(root); PetManager.unregister(root); }
}

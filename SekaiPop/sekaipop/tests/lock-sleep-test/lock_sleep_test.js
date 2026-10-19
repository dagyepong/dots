// Source / logic checks for "the desktop sleeps while the screen is locked" and for the
// lockscreen copy that is only built while a lock is happening. Like the other QML tests
// here it reads the real files and (for the logic) cuts the real expressions out of them.
// Run:  node tests/lock-sleep-test/lock_sleep_test.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const top = path.join(__dirname, "..", "..");
const read = rel => fs.readFileSync(path.join(top, rel), "utf8");

const shell = read("shell.qml");
const lockState = read("services/LockState.qml");
const ring = read("modules/sekai/lock/LockRing.qml");
const host = read("modules/sekai/lock/LockHost.qml");
const lockscreen = read("modules/sekai/lock/Lockscreen.qml");
const settings = read("services/SettingsService.qml");
const presets = read("services/DesktopPresetService.qml");
const general = read("modules/sekai/settings/SettingsPageGeneral.qml");
const cava = read("services/PcCavaService.qml");
const wall = read("modules/sekai/background/WallpaperLayer.qml");

let n = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); n++; };

// ---- LockState.desktopAsleep: only the "locked" phase, and only with the setting on ----
const m = /readonly property bool desktopAsleep: ([^\n]+)/.exec(lockState);
ok(m, "LockState.desktopAsleep is declared");
const asleep = (phase, setting) => new Function("root", "SettingsService",
    "return " + m[1])({ phase }, { flag: k => (k === "lock.sleepDesktop" ? setting : false) });
for (const ph of ["idle", "locking", "unlocking"]) {
    ok(asleep(ph, true) === false, "not asleep while " + ph + " (the desktop is on screen under the ring)");
}
ok(asleep("locked", true) === true, "asleep while locked");
ok(asleep("locked", false) === false, "the setting turns it off");

// ---- shell.qml: every desktop widget loader waits for the lock and for its turn ----
ok(/readonly property bool widgetsAllowed: [^\n]*!LockState\.desktopAsleep/.test(shell),
   "widgetsAllowed follows the lock sleep");
ok(/property int wakeStep: 99/.test(shell), "nothing waits at start (wakeStep starts at 99)");
const loaders = ["clockWidgetLoader", "userCardWidgetLoader", "weatherCardWidgetLoader", "calendarCardWidgetLoader",
    "todoWidgetLoader", "paletteCardWidgetLoader", "lyricsWidgetLoader", "visualizerWidgetLoader",
    "notesWidgetLoader", "pinnedNotesLoader", "imageWidgetsLoader"];
const steps = [];
for (const id of loaders) {
    const lm = new RegExp("id: " + id + "\\s*\\n\\s*active: shellRoot\\.woke\\((\\d+)\\) && shellRoot\\.widgetsAllowed").exec(shell);
    ok(lm, id + " is gated by woke(n) and widgetsAllowed");
    steps.push(+lm[1]);
}
const maxStep = Math.max(...steps);
const lm2 = /id: wakeTimer\s*\n\s*interval: (\d+)\s*\n\s*repeat: true\s*\n\s*onTriggered: \{\s*\n\s*shellRoot\.wakeStep = shellRoot\.wakeStep \+ 1\s*\n\s*if \(shellRoot\.wakeStep >= (\d+)\)/.exec(shell);
ok(lm2, "wakeTimer steps wakeStep up and stops");
ok(+lm2[2] > maxStep, "the timer runs past the last widget's turn (" + lm2[2] + " > " + maxStep + ")");
ok(Math.min(...steps) === 0, "the first widget is built the moment the unlock begins");
// simulate: asleep -> wakeStep 0 and timer on; every widget is built exactly once, in order
let wake = 0, builtAt = {};
const woke = k => wake >= k;
for (let tick = 0; tick <= +lm2[2]; tick++) {
    loaders.forEach((id, i) => { if (woke(steps[i]) && builtAt[id] === undefined) builtAt[id] = tick; });
    wake++;
}
ok(loaders.every(id => builtAt[id] !== undefined), "all widgets are built by the end of the stagger");
ok(builtAt[loaders[0]] === 0 && builtAt[loaders[10]] >= 9, "built in order, one step apart");
ok(/onDesktopAsleepChanged:[\s\S]*wakeTimer\.restart\(\)/.test(shell), "unlocking starts the stagger");

// the Game Mode / Edit Desktop behaviour is untouched
ok(/GameModeService\.loaded && !GameModeService\.enabled && !LockState\.desktopAsleep/.test(shell),
   "Game Mode is still part of widgetsAllowed");
ok((shell.match(/\|\| EditMode\.active/g) || []).length >= 7, "Edit Desktop still loads the widgets");

// ---- EditGuides: built only while Edit Desktop has a monitor ----
ok(/LazyLoader \{\s*\n\s*active: EditMode\.screenName !== ""\s*\n\s*\n?\s*Scope \{\s*\n\s*Variants \{\s*\n\s*model: Quickshell\.screens\s*\n\s*EditGuides \{\}/.test(shell),
   "EditGuides sits in a LazyLoader on EditMode.screenName");
ok(!/\n    Variants \{\n        model: Quickshell\.screens\n        EditGuides \{\}/.test(shell), "no always-built EditGuides left");

// ---- the lockscreen copy in LockRing is only built while locking / locked / unlocking ----
ok(/id: pic[\s\S]{0,300}live: LockState\.phase !== "idle"/.test(ring), "LockRing builds its copy only when not idle");
ok(/property bool live: true/.test(host), "LockHost is live by default (the real lock surface)");
ok(/id: face\s*\n\s*anchors\.fill: parent\s*\n\s*active: root\.live/.test(host), "LockHost's look sits behind the live switch");
ok(!/live:/.test(lockscreen), "the real lock surface never sets `live`");
ok(/wallpaperReady: face\.item \? face\.item\.wallpaperReady : false/.test(host), "no look -> not ready (the ring waits)");
ok(/function warmCrop\(\)/.test(host) && /LockCropService\.request\(root\.warmFile\)/.test(host),
   "LockHost keeps the Calendar crop map warm");
ok(/id: armTimeout\s*\n(\s*\/\/[^\n]*\n)*\s*interval: 900/.test(ring), "the ring's arm fallback has room for a cold decode");

// ---- the setting ----
ok(/"lock\.sleepDesktop": true/.test(settings), "default on");
ok(/"lock\.sleepDesktop"/.test(presets), "a desktop preset leaves it alone");
ok(/SettingsService\.toggle\("lock\.sleepDesktop"\)/.test(general), "there is a toggle in Settings");

// ---- the rest of what sleeps ----
ok(/wanted: [^\n]*\n?[^\n]*!LockState\.desktopAsleep/.test(cava.replace(/\n\s+&&/g, " &&")), "the bar's cava tap stops while locked");
ok(/restartOnPause: SettingsService\.get\("wallpaper\.videoResume"\) === "restart"\s*\n\s*\|\| \(win\.useMpvpaper && LockState\.desktopAsleep\)/.test(wall),
   "mpvpaper is stopped (not just paused) while asleep");

// ---- brackets balance in every file touched ----
for (const [name, src] of Object.entries({ shell, lockState, ring, host, settings, presets, general, cava, wall })) {
    // strings first ("file://" is not a comment), then comments
    const strip = src.replace(/"(?:[^"\\\n]|\\.)*"/g, '""').replace(/\/\/[^\n]*/g, "");
    for (const [a, b] of [["{", "}"], ["(", ")"], ["[", "]"]]) {
        ok(strip.split(a).length === strip.split(b).length, name + ": " + a + b + " balance");
    }
}

console.log("lock-sleep: " + n + " checks passed");

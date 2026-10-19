// Unit test for the lockscreen-wallpaper logic in services/WallpaperService.qml.
//
// It does NOT re-implement the logic: it cuts the real function bodies out of
// the QML file and runs them against a fake `root` (the singleton) with fake
// savers and a fake Quickshell.screens. Run:  node tests/lock-wallpaper-test/lock_wallpaper_unit.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const src = fs.readFileSync(path.join(__dirname, "..", "..", "services", "WallpaperService.qml"), "utf8");

function braceBody(from) {            // text between the { at/after `from` and its match
    const open = src.indexOf("{", from);
    let depth = 0;
    for (let i = open; i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}" && --depth === 0) return src.slice(open + 1, i);
    }
    throw new Error("unbalanced");
}
function fn(name) {
    const m = new RegExp("\\n    function " + name + "\\(([^)]*)\\)").exec(src);
    if (!m) throw new Error("no function " + name);
    return new Function("root", "Quickshell", ...m[1].split(",").map(s => s.trim()).filter(Boolean), braceBody(m.index));
}
function handler(name) {              // `onFooChanged: { ... }`
    const i = src.indexOf("\n    " + name + ": {");
    if (i < 0) throw new Error("no handler " + name);
    return new Function("root", "Quickshell", braceBody(i));
}

function make(screens) {
    const settings = { "wallpaper.perMonitor": false, "wallpaper.separateLock": false };
    const log = { lockSaves: [], lockScreenSaves: 0, deskSaves: [], stillJobs: [] };
    const Quickshell = { screens: screens.map(n => ({ name: n })) };
    const root = {
        restoring: false, defaultPath: "", screenPaths: {}, lockDefaultPath: "", lockScreenPaths: {}, stills: {},
        get perMonitor() { return !!settings["wallpaper.perMonitor"]; },
        get separateLock() { return !!settings["wallpaper.separateLock"]; },
        get ready() { return !this.restoring; },
        get themeScreen() { return Quickshell.screens.length ? Quickshell.screens[0].name : ""; },
        get lockCurrentPath() { return this.lockPathFor(this.themeScreen); },
        isVideo: p => /\.(mp4|webm|mkv|mov|avi)$/i.test(p || ""),
        imageFor(p) { return !p ? "" : this.isVideo(p) ? (this.stills[p] || "") : p; },
        queueStill(p, t, a, l) { log.stillJobs.push({ p, t, a, l: !!l }); },
        applyWallpaper: null,
    };
    const saver = { save: p => log.deskSaves.push(p) }, screensSaver = { saveAll() {} };
    // The real code refers to these as free identifiers (ids in the QML file).
    const ids = { saver, screensSaver,
        lockSaver: { save: p => log.lockSaves.push(p) },
        lockScreensSaver: { saveAll: () => log.lockScreenSaves++ },
        SettingsService: { set: (k, v) => { settings[k] = v; if (k === "wallpaper.perMonitor") root.__perChanged(); if (k === "wallpaper.separateLock") root.__lockChanged(); } } };
    const names = ["pathFor", "pinMissing", "adoptMain", "forgetScreenPicks", "applyWallpaper", "setWallpaper", "setPerMonitor",
        "forgetLockScreenPicks", "lockPathFor", "seedLock", "adoptMainLock", "setSeparateLock",
        "applyLockWallpaper", "setLockWallpaper", "ensureDefault", "lockImagePathFor"];
    for (const n of names) {
        const f = fn(n);
        // free identifiers -> pass through a Proxy scope
        root[n] = function (...a) {
            const body = f.toString();
            return new Function("root", "Quickshell", "ids", "...args",
                "with (ids) { return (" + body + ").call(null, root, Quickshell, ...args); }")(root, Quickshell, ids, ...a);
        };
    }
    const wrapH = h => () => new Function("root", "Quickshell", "ids", "with (ids) { return (" + h.toString() + ").call(null, root, Quickshell); }")(root, Quickshell, ids);
    const perH = handler("onPerMonitorChanged"), lockH = handler("onSeparateLockChanged");
    root.__perChanged = wrapH(perH);
    root.__lockChanged = wrapH(lockH);
    root.settings = settings; root.log = log;
    return root;
}

let n = 0;
function t(name, f) { f(); n++; console.log("  ok  " + name); }

// ===== single monitor =====
t("option off: lockscreen follows the desktop", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png";
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
    r.setWallpaper("/w/B.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/B.png");
});

t("turning it on keeps what the lockscreen shows (seeds from the desktop)", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png";
    r.setSeparateLock(true);
    assert.strictEqual(r.lockDefaultPath, "/w/A.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
    assert.deepStrictEqual(r.log.lockSaves, ["/w/A.png"]);
});

t("desktop changes do not move the lockscreen wallpaper", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    r.setWallpaper("/w/B.png");
    assert.strictEqual(r.pathFor("DP-1"), "/w/B.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
});

t("lockscreen changes do not touch the desktop wallpaper or its saves", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    const desk = r.log.deskSaves.length;
    r.setLockWallpaper("/w/C.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
    assert.strictEqual(r.pathFor("DP-1"), "/w/A.png");
    assert.strictEqual(r.defaultPath, "/w/A.png");
    assert.strictEqual(r.log.deskSaves.length, desk);
});

t("turning it off follows the desktop; turning it on again brings the pick back", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    r.setLockWallpaper("/w/C.png"); r.setWallpaper("/w/B.png");
    r.setSeparateLock(false);
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/B.png");
    assert.strictEqual(r.lockDefaultPath, "/w/C.png");           // kept
    r.setSeparateLock(true);
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
});

t("enabling again does not re-seed over an earlier choice", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    r.setLockWallpaper("/w/C.png"); r.setSeparateLock(false); r.setWallpaper("/w/Z.png"); r.setSeparateLock(true);
    assert.strictEqual(r.lockDefaultPath, "/w/C.png");
});

t("enabled before there is a desktop wallpaper: nothing breaks, seeds once there is one", () => {
    const r = make(["DP-1"]); r.settings["wallpaper.separateLock"] = true;
    assert.strictEqual(r.lockPathFor("DP-1"), "");
    r.ensureDefault("/w/A.png");
    assert.strictEqual(r.lockDefaultPath, "/w/A.png");
    r.setWallpaper("/w/B.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
});

t("nothing is answered before the state is restored", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.restoring = true;
    assert.strictEqual(r.lockPathFor("DP-1"), "");
    r.setLockWallpaper("/w/C.png");                               // ignored, would be overwritten by the restore
    assert.strictEqual(r.lockDefaultPath, "");
});

t("an empty path is ignored", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    r.setLockWallpaper("");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
});

// ===== video =====
t("a video lock pick waits for its first frame, as a lockscreen job", () => {
    const r = make(["DP-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    r.setLockWallpaper("/w/v.mp4");
    assert.deepStrictEqual(r.log.stillJobs, [{ p: "/w/v.mp4", t: "", a: true, l: true }]);
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");        // unchanged until the frame exists
    r.stills["/w/v.mp4"] = "/cache/v.png";
    r.setLockWallpaper("/w/v.mp4");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/v.mp4");
    assert.strictEqual(r.lockImagePathFor("DP-1"), "/cache/v.png"); // the lockscreen shows the frame
});

// ===== per monitor =====
function twoMonitors() {
    const r = make(["DP-1", "HDMI-A-1"]);
    r.settings["wallpaper.perMonitor"] = true;
    r.defaultPath = "/w/A.png"; r.screenPaths = { "DP-1": "/w/A.png", "HDMI-A-1": "/w/B.png" };
    return r;
}

t("per-monitor: enabling seeds each monitor from its own desktop wallpaper", () => {
    const r = twoMonitors(); r.setSeparateLock(true);
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/B.png");
});

t("per-monitor: a lock pick reaches only its monitor, never the desktop", () => {
    const r = twoMonitors(); r.setSeparateLock(true);
    r.setLockWallpaper("/w/C.png", "DP-1");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/B.png");
    assert.strictEqual(r.pathFor("DP-1"), "/w/A.png");
    assert.strictEqual(r.pathFor("HDMI-A-1"), "/w/B.png");
});

t("per-monitor: desktop changes on either monitor leave both lock wallpapers alone", () => {
    const r = twoMonitors(); r.setSeparateLock(true); r.setLockWallpaper("/w/C.png", "DP-1");
    r.setWallpaper("/w/X.png", "DP-1"); r.setWallpaper("/w/Y.png", "HDMI-A-1"); r.setWallpaper("/w/Q.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/B.png");
});

t("per-monitor: pick for all monitors gives every monitor the same lock wallpaper", () => {
    const r = twoMonitors(); r.setSeparateLock(true); r.setLockWallpaper("/w/C.png", "DP-1");
    r.setLockWallpaper("/w/D.png");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/D.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/D.png");
    assert.deepStrictEqual(r.lockScreenPaths, {});
});

t("per-monitor: a freshly plugged-in monitor shows the lockscreen default, not the desktop's", () => {
    const r = twoMonitors(); r.setSeparateLock(true); r.setLockWallpaper("/w/D.png");
    assert.strictEqual(r.lockPathFor("DP-2"), "/w/D.png");
});

t("per-monitor off: the main monitor's lock wallpaper is kept, the rest forgotten", () => {
    const r = twoMonitors(); r.setSeparateLock(true);
    r.setLockWallpaper("/w/C.png", "DP-1"); r.setLockWallpaper("/w/E.png", "HDMI-A-1");
    r.setPerMonitor(false);
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/C.png");
    assert.deepStrictEqual(r.lockScreenPaths, {});
});

t("per-monitor off: the desktop side still behaves as before (main monitor adopted)", () => {
    const r = twoMonitors(); r.setSeparateLock(true); r.setLockWallpaper("/w/C.png", "DP-1");
    r.setPerMonitor(false);
    assert.strictEqual(r.pathFor("DP-1"), "/w/A.png");
    assert.deepStrictEqual(r.screenPaths, {});
});

t("per-monitor off then on: lock picks start again from the default", () => {
    const r = twoMonitors(); r.setSeparateLock(true); r.setLockWallpaper("/w/C.png", "DP-1");
    r.setPerMonitor(false); r.setPerMonitor(true);
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/C.png");
});

t("a monitor-specific call with per-monitor off acts on the one lockscreen wallpaper", () => {
    const r = make(["DP-1", "HDMI-A-1"]); r.defaultPath = "/w/A.png"; r.setSeparateLock(true);
    r.setLockWallpaper("/w/C.png", "HDMI-A-1");
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/C.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/C.png");
});

t("option off in per-monitor mode: lockscreen mirrors each monitor's desktop wallpaper", () => {
    const r = twoMonitors();
    assert.strictEqual(r.lockPathFor("DP-1"), "/w/A.png");
    assert.strictEqual(r.lockPathFor("HDMI-A-1"), "/w/B.png");
});

console.log("\n" + n + " passed");

// Source / logic checks for the Calendar lockscreen. Like the other QML tests here it
// does NOT re-implement the code: it reads the real files, cuts out the real function
// bodies and bindings, and runs them against fakes. Run:
//   node tests/lock-calendar-test/calendar_source_test.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const top = path.join(__dirname, "..", "..");
const read = rel => fs.readFileSync(path.join(top, rel), "utf8");

const host = read("modules/sekai/lock/LockHost.qml");
const calendar = read("modules/sekai/lock/LockCalendar.qml");
const panel = read("modules/sekai/lock/LockPanel.qml");
const key = read("modules/sekai/lock/LockPowerKey.qml");
const context = read("modules/sekai/lock/LockContext.qml");
const lockscreen = read("modules/sekai/lock/Lockscreen.qml");
const ring = read("modules/sekai/lock/LockRing.qml");
const settings = read("services/SettingsService.qml");
const presets = read("services/DesktopPresetService.qml");
const general = read("modules/sekai/settings/SettingsPageGeneral.qml");
const palette = read("modules/common/LockPalette.qml");
const service = read("services/LockCropService.qml");

function braceBody(src, from) {            // text between the { at/after `from` and its match
    const open = src.indexOf("{", from);
    let depth = 0;
    for (let i = open; i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}" && --depth === 0) return src.slice(open + 1, i);
    }
    throw new Error("unbalanced");
}
function fn(src, name, ...scopeNames) {
    const m = new RegExp("\\n    function " + name + "\\(([^)]*)\\)").exec(src);
    if (!m) throw new Error("no function " + name);
    const params = m[1].split(",").map(s => s.trim()).filter(Boolean);
    return new Function(...scopeNames, ...params, braceBody(src, m.index));
}

// ---- every new / changed QML file has balanced braces, brackets and parens
for (const [name, text] of Object.entries({ host, calendar, panel, key, context, lockscreen, ring, service, palette, general })) {
    for (const [o, c] of [["{", "}"], ["[", "]"], ["(", ")"]]) {
        const code = text.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/\/\/.*$/gm, "");
        assert.strictEqual(code.split(o).length, code.split(c).length, name + ": unbalanced " + o + c);
    }
}

// ---- the look is chosen in ONE place, and both users of it go through it
assert.ok(/SettingsService\.get\("lock\.style"\) === "calendar"/.test(host), "LockHost reads lock.style");
assert.ok(/LockSurface \{/.test(host) && /LockCalendar \{/.test(host), "LockHost has both looks");
assert.ok(/LockHost \{/.test(lockscreen) && !/\n\s+LockSurface \{/.test(lockscreen), "the real lock surface uses LockHost");
assert.ok(/LockHost \{\s*\n\s*id: pic/.test(ring) && !/LockSurface \{/.test(ring), "the ring's copy uses LockHost");
assert.ok(/wallpaperReady: face\.item \? face\.item\.wallpaperReady : false/.test(host), "LockRing's wait is forwarded");
assert.ok(/readonly property bool wallpaperReady/.test(calendar), "the calendar look answers wallpaperReady");

// ---- settings: defaults, kept across presets, and a control for each
assert.ok(/"lock\.style": "gacha"/.test(settings), "default style is the old look");
assert.ok(/"lock\.crop": "auto"/.test(settings) && /"lock\.powerButtons": true/.test(settings));
assert.ok(/"lock\.tone": "color"/.test(settings), "the pictures are in colour by default");
for (const k of ["lock.style", "lock.crop", "lock.powerButtons", "lock.tone"]) {
    assert.ok(presets.includes('"' + k + '"'), k + " is in the preset keep list");
    assert.ok(general.includes('"' + k + '"'), k + " has a control in Settings");
}

// ---- Ctrl / Enter: Ctrl+Enter sleeps, plain Enter unlocks, Ctrl is tracked on press and release
{
    const body = braceBody(calendar, calendar.indexOf("Keys.onPressed:"));
    const enter = body.slice(body.indexOf("Key_Return"), body.indexOf("Key_A"));
    assert.ok(/ControlModifier\)\s*\n\s*root\.context\.sleep\(\)\s*\n\s*else\s*\n\s*root\.context\.tryUnlock\(\)/.test(enter), "Ctrl+Enter sleeps, Enter unlocks");
    assert.ok(/ctrlHeld = event\.key === Qt\.Key_Control/.test(body), "pressing Ctrl is noticed");
    const rel = braceBody(calendar, calendar.indexOf("Keys.onReleased:"));
    assert.ok(/ctrlHeld = event\.key !== Qt\.Key_Control/.test(rel), "releasing Ctrl clears it");
    assert.ok(/onActiveFocusChanged:[\s\S]*ctrlHeld = false/.test(calendar), "losing the keyboard clears it");
    assert.ok(/name: "coffee"/.test(calendar) && /text: enterKey\.coffee \? "SLEEP" : "ENTER"/.test(calendar), "the Enter key becomes the coffee key");
    assert.ok(/enterKey\.coffee \|\| mouse\.button === Qt\.RightButton/.test(calendar), "clicking it while Ctrl is held, or right-clicking, sleeps");
    assert.ok(/restart_alt/.test(calendar) && /power_settings_new/.test(calendar), "restart and shutdown keys exist");
    assert.ok(/powerPress\("reboot"\)/.test(calendar) && /powerPress\("poweroff"\)/.test(calendar));
    assert.ok(/visible: controls\.power/.test(calendar) && /SettingsService\.flag\("lock\.powerButtons"\)/.test(calendar), "the keys can be hidden");
}
// The unlock key's old behaviour is untouched in the old look.
assert.ok(!/ctrlHeld/.test(read("modules/sekai/lock/LockSurface.qml")), "the gacha look is unchanged");

// ---- LockContext: powerPress asks twice, sleep / power only act on a really locked session
function makeContext(phase) {
    const log = [];
    const root = { armed: "", ctrlHeld: false, typed: "x", clearText() { this.typed = ""; } };
    const timer = { restarts: 0, stops: 0, restart() { this.restarts++; }, stop() { this.stops++; } };
    const scope = { root, LockState: { phase }, armTimer: timer,
        rebootAction: { set running(v) { log.push("reboot"); } },
        powerOffAction: { set running(v) { log.push("poweroff"); } },
        sleepAction: { set running(v) { log.push("sleep"); } } };
    const names = Object.keys(scope);
    const bind = f => (...a) => f(...names.map(n => scope[n]), ...a);
    root.powerPress = bind(fn(context, "powerPress", ...names));
    root.sleep = bind(fn(context, "sleep", ...names));
    return { root, log, timer };
}
{
    const c = makeContext("locked");
    c.root.powerPress("reboot");
    assert.strictEqual(c.root.armed, "reboot"); assert.deepStrictEqual(c.log, []); assert.strictEqual(c.timer.restarts, 1);
    c.root.powerPress("poweroff");               // a different key: arms that one instead, nothing runs
    assert.strictEqual(c.root.armed, "poweroff"); assert.deepStrictEqual(c.log, []);
    c.root.powerPress("poweroff");
    assert.deepStrictEqual(c.log, ["poweroff"]); assert.strictEqual(c.root.armed, "");
    c.root.powerPress("reboot"); c.root.powerPress("reboot");
    assert.deepStrictEqual(c.log, ["poweroff", "reboot"]);
    c.root.powerPress("hibernate");              // unknown kinds do nothing
    assert.strictEqual(c.root.armed, "");
    c.root.armed = "reboot"; c.root.sleep();
    assert.deepStrictEqual(c.log, ["poweroff", "reboot", "sleep"]); assert.strictEqual(c.root.armed, ""); assert.strictEqual(c.root.typed, "", "sleeping wipes what was typed");
}
for (const phase of ["idle", "locking", "unlocking"]) {
    const c = makeContext(phase);
    c.root.powerPress("reboot"); c.root.powerPress("reboot"); c.root.powerPress("poweroff"); c.root.sleep();
    assert.deepStrictEqual(c.log, [], "nothing runs in phase " + phase);
    assert.strictEqual(c.root.armed, "", "nothing is armed in phase " + phase);
}
assert.ok(/ctrlHeld = false\s*\n\s*armed = ""/.test(braceBody(context, context.indexOf("function reset()"))), "a fresh lock starts disarmed");
assert.ok(/interval: 4000/.test(context) && /onTriggered: root\.armed = ""/.test(context), "an armed key gives up after a few seconds");
assert.ok(/systemctl suspend \|\| loginctl suspend/.test(context) && /systemctl reboot \|\| loginctl reboot/.test(context) && /systemctl poweroff \|\| loginctl poweroff/.test(context));

// ---- the month strip: the day list, for months of every length
{
    const m = /readonly property var monthDays: \{/.exec(calendar);
    const build = new Function("root", braceBody(calendar, m.index));
    const month = (y, mo) => build({ yearNow: y, monthNow: mo });
    const oct = month(2026, 9);
    assert.strictEqual(oct.length, 31);
    assert.strictEqual(oct[0].wd, 4, "1 October 2026 is a Thursday");
    assert.deepStrictEqual(oct.filter(d => d.weekend).map(d => d.day), [3, 4, 10, 11, 17, 18, 24, 25, 31]);
    assert.strictEqual(month(2028, 1).length, 29, "leap February");
    assert.strictEqual(month(2027, 1).length, 28);
    assert.strictEqual(month(2026, 10).length, 30);
    for (const n of [28, 29, 30, 31])
        assert.ok(Math.ceil(n / 2) * 2 >= n && Math.ceil(n / 2) <= 16, "two rows hold " + n + " days");
}

// ---- layout: the three frames never touch each other or the bar, on any screen shape
{
    const num = name => {
        const m = new RegExp("readonly property rect " + name + ": Qt\\.rect\\(Math\\.round\\(([\\d.]+) \\* root\\.width\\), Math\\.round\\(([\\d.]+) \\* root\\.height\\),\\s*Math\\.round\\(([\\d.]+) \\* root\\.width\\), Math\\.round\\(([\\d.]+) \\* root\\.height\\)\\)").exec(calendar);
        assert.ok(m, "frame " + name);
        return m.slice(1).map(Number);
    };
    const [A, B, C] = ["rectA", "rectB", "rectC"].map(num);
    const barFrac = Number(/barTop: root\.height - Math\.round\(root\.height \* ([\d.]+)\)/.exec(calendar)[1]);
    const rect = (f, W, H) => ({ x: f[0] * W, y: f[1] * H, r: (f[0] + f[2]) * W, b: (f[1] + f[3]) * H });
    const apart = (p, q) => p.r <= q.x || q.r <= p.x || p.b <= q.y || q.b <= p.y;
    for (const [W, H] of [[1920, 1080], [1728, 1080], [2560, 1080], [3440, 1440], [1440, 1080], [3840, 2160], [1366, 768], [1280, 1024]]) {
        const [a, b, c] = [A, B, C].map(f => rect(f, W, H));
        assert.ok(apart(a, b) && apart(a, c) && apart(b, c), "frames apart at " + W + "x" + H);
        const barTop = H - Math.round(H * barFrac);
        assert.ok(a.b < barTop && b.b < barTop && c.b < barTop, "frames above the bar at " + W + "x" + H);
        assert.ok(a.x > 0 && b.r < W && a.y > 0, "frames inside the screen at " + W + "x" + H);
        // The left column (label, time) has room: at least 480 px at 1080 tall, wide enough that the time can shrink to fit.
        const u = Math.max(0.55, H / 1080);
        assert.ok((c.x - 30 * u - a.x) / u > 480, "left column wide enough at " + W + "x" + H + ": " + ((c.x - 30 * u - a.x) / u).toFixed(0));
    }
}

// ---- the frame: straight sides, a plate with a hard shadow straight down, picture toned and masked
assert.ok(!/cuts|cornerTriangles|outlinePoints|PathPolyline|PathMultiline|import QtQuick\.Shapes/.test(panel + calendar), "no cut (diagonal) corners anywhere in the Calendar look");
assert.ok(/saturation: root\.mono \? -1 : /.test(panel) && /colorization: root\.mono && root\.tinted/.test(panel), "colour by default, black and white / tinted in mono");
assert.ok(/maskEnabled: true/.test(panel) && /maskSource: corners/.test(panel), "the picture is masked to the plate's rounded corners");
assert.ok(/LC\.place\(/.test(panel), "placement comes from the tested maths");
{
    const plate = read("modules/sekai/lock/LockPlate.qml");
    assert.ok(/y: root\.shadowDy/.test(plate) && !/shadowDx/.test(plate) && !/\n\s+x: root\.shadow/.test(plate), "the hard shadow only ever drops straight down");
    assert.ok(/y: root\.pressed \? root\.shadowDy : 0/.test(plate), "a pressed plate sinks onto its shadow");
    assert.ok(/LockPlate \{/.test(panel) && /LockPlate \{/.test(calendar) && /LockPlate \{/.test(key), "frames, bottom row and round keys are all plates");
}
assert.ok(/SettingsService\.get\("lock\.tone"\) === "mono"/.test(calendar), "the colour mode is read from lock.tone");
assert.ok(/shadowColor: root\.mono \? root\.ink : root\.accent/.test(calendar), "coloured shadows, the border colour in black and white");
for (const c of ["calPaper", "calAccent", "calMint", "calLilac"])
    assert.ok(new RegExp("readonly property color " + c + ": hsl\\(hue\\((cGlint|pink|mint)\\)").test(palette), c + " comes from a theme colour, not a fixed hex");
assert.ok(!/#[0-9a-fA-F]{6}/.test(calendar.replace(/\/\/.*$/gm, "") + panel.replace(/\/\/.*$/gm, "") + read("modules/sekai/lock/LockPlate.qml").replace(/\/\/.*$/gm, "")), "no fixed hex colours in the Calendar look");
assert.ok(/Theme\.attributeColors\[/.test(calendar), "password dots use the shell's five card-attribute colours");
assert.ok(!/inline|component /.test(key.replace(/\/\/.*$/gm, "")), "the key is a file of its own");
assert.ok(!/Math\.round\(root\.height \* 0\.17\)[\s\S]*Rectangle \{\s*id: bar/.test(calendar), "no black bar any more");

// ---- the clock: four keys, hours dark, minutes mint, two diamonds between
{
    const m = /readonly property var timeDigits: \{/.exec(calendar);
    const digits = text => new Function("root", braceBody(calendar, m.index))({ timeText: text });
    assert.strictEqual(JSON.stringify(digits("10:42")), '["1","0","4","2"]');
    assert.strictEqual(JSON.stringify(digits("01:05")), '["0","1","0","5"]');
    assert.strictEqual(JSON.stringify(digits("")), '["0","0","0","0"]', "a bad time still gives four keys");
    assert.ok(/model: root\.timeDigits/.test(calendar) && /readonly property bool hours: keyPlate\.index < 2/.test(calendar));
    assert.strictEqual((calendar.match(/rotation: 45/g) || []).length >= 3, true, "the diamonds");
}

// ---- the planner is shared, deterministic and runs the same everywhere
assert.ok(/LC\.plan\(root\.grid, root\.specs\)/.test(calendar) && /LC\.fixedPlan\(root\.imageAspect, root\.specs\)/.test(calendar));
assert.ok(/LockCropService\.request\(/.test(calendar) && /LockCropService\.settled\(/.test(calendar));
assert.ok(/pragma Singleton/.test(service) && /lock-crop\.sh/.test(service) && /interval: 8000/.test(service), "the service times out a stuck read");
assert.ok(/readonly property int keep: 8/.test(service));
assert.ok(fs.existsSync(path.join(top, "scripts/wallpapers/lock-crop.sh")) && fs.existsSync(path.join(top, "assets/images/lock-dots.png")));

// ---- nothing in the Calendar look keeps animating on its own
{
    const loops = calendar.match(/loops: Animation\.Infinite/g) || [];
    assert.strictEqual(loops.length, 1, "only the unlock spinner loops");
    assert.ok(/running: spinner\.visible/.test(calendar), "...and only while it shows");
    assert.ok(!/Sparkle|SequentialAnimation\s*\{\s*running: true/.test(calendar), "no always-on twinkles");
}

console.log("Calendar lockscreen: all checks passed");

// Unit test for the lock/unlock transition wiring (WallpaperService.qml's
// transitionMsFor / transitionLinearFor / lockShaderStemFor, LockRing.qml,
// shaders/*_lock.*). Like lock_wallpaper_unit.js it runs the REAL function
// bodies cut out of the QML, and it cross-checks them against WallpaperLayer.qml
// so the lock can never drift from how the wallpaper switcher plays a style.
// Run:  node tests/lock-transition-test/lock_transition_unit.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const root = path.join(__dirname, "..", "..");
const read = p => fs.readFileSync(require("../lib/locate")(p), "utf8");
const svc = read("services/WallpaperService.qml");
const layer = read("WallpaperLayer.qml");
const lockRing = read("LockRing.qml");

function braceBody(src, from) {
    const open = src.indexOf("{", from);
    let depth = 0;
    for (let i = open; i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}" && --depth === 0) return src.slice(open + 1, i);
    }
    throw new Error("unbalanced");
}
function fn(name) {
    const m = new RegExp("\\n    function " + name + "\\(([^)]*)\\)").exec(svc);
    if (!m) throw new Error("no function " + name);
    return new Function("root", ...m[1].split(",").map(s => s.trim()).filter(Boolean), braceBody(svc, m.index));
}

let passed = 0;
function ok(name, f) { f(); passed++; console.log("  ok  " + name); }

const fake = { ringDuration: 1234, transitionDuration: 900 };
const ms = style => fn("transitionMsFor")(fake, style);
const linear = style => fn("transitionLinearFor")(fake, style);
const stem = style => fn("lockShaderStemFor")(fake, style);

// every style WallpaperLayer.qml knows (its shaderBase switch), plus the default
const layerStyles = [...layer.matchAll(/case "(\w+)": return "(\w+)";/g)].map(m => [m[1], m[2]]);
ok("WallpaperLayer lists the five styles we expect (plus the fade default)", () => {
    assert.deepStrictEqual(layerStyles.map(s => s[0]).sort(),
        ["diagonalBlocks", "sekaiFlash", "sekaiIris", "sekaiRing", "star"].sort());
});

ok("timing matches WallpaperLayer.blendAnim for every style", () => {
    // blendAnim: iris 2000, ring/star/blocks ringDuration, others transitionDuration;
    // Linear for those four and the transitionEasing for the rest.
    assert.strictEqual(ms("sekaiIris"), 2000);
    for (const s of ["sekaiRing", "star", "diagonalBlocks"]) assert.strictEqual(ms(s), 1234, s);
    for (const s of ["sekaiFlash", "fade", "nonsense"]) assert.strictEqual(ms(s), 900, s);
    for (const s of ["sekaiIris", "sekaiRing", "star", "diagonalBlocks"]) assert.strictEqual(linear(s), true, s);
    for (const s of ["sekaiFlash", "fade"]) assert.strictEqual(linear(s), false, s);
    // and the layer really does use that rule
    assert.ok(/activeStyle === "sekaiIris" \? 2000/.test(layer));
    assert.ok(/=== "sekaiRing"\s*\|\|\s*win\.activeStyle === "star"\s*\|\|\s*win\.activeStyle === "diagonalBlocks"\) \? WallpaperService\.ringDuration/.test(layer));
});

ok("every wallpaper style maps to <its wallpaper shader>_lock, and unknown falls back to fade", () => {
    for (const [style, base] of layerStyles) assert.strictEqual(stem(style), base + "_lock", style);
    assert.strictEqual(stem("fade"), "fade_lock");
    assert.strictEqual(stem("whatever"), "fade_lock");
});

function block(t) {
    const m = /uniform buf \{([\s\S]*?)\} ubuf;/.exec(t);
    return m[1].split("\n").map(l => l.replace(/\/\/.*/, "").trim()).filter(Boolean);
}
const stems = new Set([...layerStyles.map(s => s[1] + "_lock"), "fade_lock"]);
ok("each lock shader pair exists, its blocks match, and `unlocking` is a uniform in both", () => {
    for (const s of stems) {
        const f = read("shaders/" + s + ".frag"), v = read("shaders/" + s + ".vert");
        assert.deepStrictEqual(block(f), block(v), s + ": vert/frag uniform blocks differ");
        assert.ok(block(f).includes("int unlocking;"), s + ": no unlocking");
        assert.ok(/uniform sampler2D source1;/.test(f) && !/source2/.test(f.replace(/\/\/.*/g, "")), s + ": must read ONE texture");
        assert.strictEqual((f.match(/\{/g) || []).length, (f.match(/\}/g) || []).length, s + ": braces");
    }
});

ok("each lock shader only reads uniforms its block declares, and LockRing supplies them", () => {
    const effect = lockRing.slice(lockRing.indexOf("ShaderEffect {"));
    const supplied = new Set([...effect.matchAll(/property \w+ (\w+):/g)].map(m => m[1]));
    for (const s of stems) {
        const f = read("shaders/" + s + ".frag");
        const declared = new Set(block(f).map(l => l.split(/[ ;]+/)[1]));
        const used = new Set([...f.replace(/\/\/.*/g, "").matchAll(/ubuf\.(\w+)/g)].map(m => m[1]));
        for (const u of used) assert.ok(declared.has(u), s + ": uses undeclared " + u);
        for (const d of declared) {
            if (["qt_Matrix", "qt_Opacity"].includes(d)) continue;
            assert.ok(supplied.has(d), s + ": LockRing's ShaderEffect has no property `" + d + "`");
        }
    }
});

ok("lock ends are exact: p=0 / p=1 give desktop / lockscreen (locking) and the reverse (unlocking)", () => {
    for (const s of ["sekai_star_lock", "sekai_blocks_lock"]) {
        const f = read("shaders/" + s + ".frag");
        assert.ok(/if \(p <= 0\.0\) \{\s*fragColor = \(leaving \? lockC : vec4\(0\.0\)\)/.test(f), s + " p<=0");
        assert.ok(/if \(p >= 1\.0\) \{\s*fragColor = \(leaving \? vec4\(0\.0\) : lockC\)/.test(f), s + " p>=1");
    }
});

ok("LockRing falls back to the ring when a lock shader fails to load", () => {
    assert.ok(/status === ShaderEffect\.Error && styleName !== "sekaiRing"/.test(lockRing));
    assert.ok(/LockState\.styleFallback = true/.test(lockRing));
    const ls = read("services/LockState.qml");
    assert.ok(/transitionStyle: root\.styleFallback \? "sekaiRing" : root\.wantedStyle/.test(ls));
    assert.ok(/onWantedStyleChanged: root\.styleFallback = false/.test(ls));
    assert.ok(/ringMs: WallpaperService\.transitionMsFor\(root\.transitionStyle\)/.test(ls));
});

// ===== "Random" transition =====
function randomRoot(setting) {
    const r = { transitionSetting: setting, switchStyleRolled: "sekaiRing", switchRolledAt: 0, lockStyleRolled: "sekaiRing" };
    r.randomStyles = JSON.parse(/randomStyles: (\[[^\]]*\])/.exec(svc)[1]);
    r.pickRandomStyle = a => fn("pickRandomStyle")(r, a);
    return r;
}

ok("random only picks styles WallpaperLayer can draw, never plain fade", () => {
    const r = randomRoot("random");
    assert.deepStrictEqual([...r.randomStyles].sort(), layerStyles.map(s => s[0]).sort());
    assert.ok(!r.randomStyles.includes("fade"));
});

ok("pickRandomStyle never repeats the last style and reaches every style", () => {
    const r = randomRoot("random");
    const seen = new Set();
    let last = "sekaiRing";
    for (let i = 0; i < 500; i++) {
        const next = r.pickRandomStyle(last);
        assert.notStrictEqual(next, last);
        assert.ok(r.randomStyles.includes(next));
        seen.add(next);
        last = next;
    }
    assert.strictEqual(seen.size, r.randomStyles.length);
});

ok("styleForSwitch: a fixed style is returned as is; random rolls once per change, not once per monitor", () => {
    const fixed = randomRoot("star");
    assert.strictEqual(fn("styleForSwitch")(fixed), "star");
    assert.strictEqual(fixed.switchRolledAt, 0);

    const r = randomRoot("random");
    const a = fn("styleForSwitch")(r);
    const b = fn("styleForSwitch")(r); // second monitor, same moment
    assert.strictEqual(a, b);
    r.switchRolledAt -= 1000;          // a later change
    const c = fn("styleForSwitch")(r);
    assert.notStrictEqual(c, a);
});

ok("rollLockStyle changes the lock style only in random mode", () => {
    const fixed = randomRoot("sekaiIris");
    fn("rollLockStyle")(fixed);
    assert.strictEqual(fixed.lockStyleRolled, "sekaiRing");
    const r = randomRoot("random");
    fn("rollLockStyle")(r);
    assert.notStrictEqual(r.lockStyleRolled, "sekaiRing");
});

ok("wiring: layer takes its style per switch, lock rolls at lock and unlock, Settings offers Random", () => {
    assert.ok(/win\.activeStyle = WallpaperService\.styleForSwitch\(\)/.test(layer));
    assert.ok(!/WallpaperService\.transitionStyle/.test(layer.replace(/\/\/.*$/gm, "")));
    const ls = read("services/LockState.qml");
    assert.strictEqual((ls.match(/WallpaperService\.rollLockStyle\(\)/g) || []).length, 2);
    assert.ok(/id: "random"/.test(read("SettingsPageDesktop.qml")));
});

console.log("\n" + passed + " passed");

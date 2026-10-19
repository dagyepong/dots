// node tests/media-test/media_source_test.js   (run from the sekaipop folder)
// Quickshell can't be run here, so this reads the source of the media card to hold
// it to what it promises (the look itself still has to be checked on a live shell):
//   1. Bar.qml's wiring still fits: source, eqRequested, and the SekaiPopup frame;
//   2. it is built from the shell's own parts and Theme tokens, not a black box of
//      hard-coded colours (the old turntable was always black);
//   3. every player action is still there (keys, jacket, tabs, seek, keyboard);
//   4. brackets balance and no id is used twice in a file.
const assert = require("assert"), fs = require("fs"), path = require("path")
const top = path.join(__dirname, "..", "..")
const dir = path.join(top, "modules/sekai/mediaControls")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")
const read = f => fs.readFileSync(path.join(dir, f), "utf8")
const files = ["MediaPopup.qml", "MediaKey.qml", "MediaTab.qml"]
const pop = code(read("MediaPopup.qml"))

// 1. wiring
const bar = code(fs.readFileSync(path.join(top, "modules/sekai/bar/Bar.qml"), "utf8"))
for (const p of ["parentWindow: win", "anchorItem: statusBar.mediaToggle", "source: mediaSource", "onCloseRequested", "onEqRequested"])
    assert.ok(bar.includes(p), "Bar.qml no longer wires " + p)
assert.ok(/^\s*SekaiPopup\s*\{/m.test(pop), "the card must be a SekaiPopup")
assert.ok(/signal eqRequested\(\)/.test(pop) && /property var source/.test(pop), "eqRequested / source are the card's API")
assert.ok(!/\bbare\s*:\s*true/.test(pop), "the card is a normal Sekai card now (outline, ring, hard shadow), not a bare one")

// 2. the shell's own parts and tokens
for (const part of ["Pill", "DiamondDot", "ClippingRectangle", "VisualizerCover", "MediaKey", "MediaTab", "SekaiPlate"])
    assert.ok(new RegExp("\\b" + part + "\\s*\\{").test(pop), "MediaPopup should use " + part)
// still no tape / burst / wave: the plate and the seek lane are the only additions to the plain card
for (const part of ["WashiTape", "Slant", "Burst", "MediaWave"])
    assert.ok(!new RegExp("\\b" + part + "\\b").test(pop), "MediaPopup should not use " + part + " any more")
assert.ok(!fs.existsSync(path.join(dir, "MediaWave.qml")), "MediaWave.qml is gone")
assert.ok(!/barHeights|stampWord|fullCombo|enterAnim/.test(pop), "no stamp or entrance animation")
assert.ok(/Pill\s*\{/.test(code(read("MediaKey.qml"))), "keys are Pills (they press into their shadow)")
for (const f of files) {
    const c = code(read(f))
    // colours must come from Theme / the cover / the app. The only literals allowed: the hover scrim.
    const lits = (c.match(/"#[0-9a-fA-F]{3,8}"/g) || []).filter(x => x !== '"#55000000"')
    assert.deepStrictEqual(lits, [], f + " has hard-coded colours: " + lits.join(", "))
}
assert.ok(!/QtQuick\.Shapes|MultiEffect|FastBlur|GaussianBlur/.test(pop), "no blur / shape effects (GPU)")

// 3. nothing the player could do before is lost
for (const a of ["togglePlaying()", "p.next()", "p.previous()", "p.position =", "positionChanged()", "openPlayerWindow()", "eqRequested()", "Key_Space", "Key_N", "Key_P", "Key_Right", "Key_Left", "root.picked ="])
    assert.ok(pop.includes(a), "missing: " + a)
assert.ok(/canGoPrevious/.test(pop) && /canGoNext/.test(pop) && /canTogglePlaying/.test(pop), "keys still dim when the player cannot do them")
assert.ok(/onePerApp/.test(pop) && /youtubeThumb/.test(pop), "one entry per app + the YouTube cover fallback are kept")
assert.ok(/pressed:\s*jacketArea\.pressed \|\| !root\.playing/.test(pop), "the jacket is raised while playing, pressed when paused")
assert.ok(/seekBy\(5\)/.test(pop) && /seekBy\(-5\)/.test(pop) && /if \(!root\.seekable\)/.test(pop), "seeking is by the arrow keys and only when seekable")
// the seek lane: drag / click to change the time, sent only on release, only when the player can seek
assert.ok(/id:\s*seekArea/.test(pop) && /enabled:\s*root\.seekable/.test(pop), "the track is a MouseArea that is only enabled when the player can seek")
assert.ok(/onReleased:[\s\S]*?seekToFrac\(/.test(pop), "the jump is sent when the pointer is released")
assert.ok(!/onPositionChanged:[^}]*\.position\s*=/.test(pop), "dragging only moves the playhead; it must not write the player's position on every move")
assert.ok(/function seekToFrac\(f\)\s*\{\s*if \(!root\.seekable\)/.test(pop), "seekToFrac refuses when the player cannot seek")
assert.ok(/running:\s*root\.open && root\.playing && !root\.scrubbing/.test(pop), "the position is only polled while the card is open and playing")
assert.ok(/onWheel:[\s\S]*?seekBy\(wheel\.angleDelta\.y > 0 \? 5 : -5\)/.test(pop), "the wheel over the track seeks by five seconds")
assert.ok(/MM\.fmt\(/.test(pop) && /MM\.left\(/.test(pop) && /MM\.ratio\(/.test(pop), "the lane uses the tested time helpers")
assert.ok(/visible: root\.multi/.test(pop) && /visible: !root\.multi/.test(pop), "tabs only with several players, the app name otherwise")

// 4. brackets and ids
for (const f of files) {
    const c = code(read(f)).replace(/"(?:[^"\\]|\\.)*"/g, '""')
    for (const [o, cl] of ["{}", "()", "[]"].map(x => [x[0], x[1]]))
        assert.strictEqual(c.split(o).length, c.split(cl).length, f + ": unbalanced " + o + cl)
    const ids = [...c.matchAll(/\bid:\s*(\w+)/g)].map(m => m[1])
    assert.strictEqual(new Set(ids).size, ids.length, f + ": an id is used twice")
}
// every id the popup refers to exists in it
for (const id of ["jacketArea", "coverImage", "jacket", "stack", "song", "info", "keys", "tabRow", "wheelGate", "cover", "lane", "track", "seekArea", "elapsedChip", "totalChip", "settleTimer"])
    assert.ok(new RegExp("\\bid:\\s*" + id + "\\b").test(pop), "id " + id + " is used but not declared")
console.log("media_source_test: all passed")

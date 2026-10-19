// scripts/state/lyrics-cache.sh and lyrics-state.sh, run for real in a temp home.
// Run: node cache_unit.js
const assert = require("assert"), fs = require("fs"), os = require("os"), path = require("path")
const { spawnSync } = require("child_process")
const top = path.join(__dirname, "..", "..")
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "lyr-"))
const env = Object.assign({}, process.env, { XDG_CACHE_HOME: path.join(tmp, "cache"), XDG_STATE_HOME: path.join(tmp, "state") })
const run = (s, ...a) => spawnSync("sh", [path.join(top, "scripts", "state", s), ...a], { env, encoding: "utf8" })
const key = "0123456789abcdef0123456789abcdef"

// the cache
assert.strictEqual(run("lyrics-cache.sh", "get", key).stdout, "", "nothing cached yet: nothing printed")
assert.strictEqual(run("lyrics-cache.sh", "get", key).status, 0)
const json = JSON.stringify({ synced: "[00:01.00]made up line", plain: "made up line" })
assert.strictEqual(run("lyrics-cache.sh", "put", key, json).status, 0)
assert.strictEqual(run("lyrics-cache.sh", "get", key).stdout.trim(), json, "what was put comes back")
assert.ok(fs.existsSync(path.join(tmp, "cache", "sekaipop", "lyrics", key + ".json")))
// keys that are not 32 hex digits are refused (no path can be named from outside)
for (const bad of ["", "../../etc/passwd", "ABCDEF0123456789abcdef0123456789", "0123", key + "0", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"])
    assert.strictEqual(run("lyrics-cache.sh", "get", bad).status, 2, "refused: " + bad)
assert.strictEqual(run("lyrics-cache.sh", "put", "../x", "{}").status, 2)

// a .lrc beside a local file
const music = path.join(tmp, "my music"); fs.mkdirSync(music)
fs.writeFileSync(path.join(music, "tune one.flac"), "x")
fs.writeFileSync(path.join(music, "tune one.lrc"), "[00:01.00]made up line\n")
const url = "file://" + path.join(music, "tune one.flac").replace(/ /g, "%20")
assert.strictEqual(run("lyrics-cache.sh", "local", url).stdout, "[00:01.00]made up line\n", "the .lrc beside the file, spaces and all")
// a Japanese file name arrives percent-encoded, byte by byte
fs.writeFileSync(path.join(music, "\u3046\u305f.mp3"), "x"); fs.writeFileSync(path.join(music, "\u3046\u305f.lrc"), "[00:02.00]made up\n")
assert.strictEqual(run("lyrics-cache.sh", "local", "file://" + music.replace(/ /g, "%20") + "/" + encodeURIComponent("\u3046\u305f.mp3")).stdout, "[00:02.00]made up\n", "UTF-8 file names too")
assert.strictEqual(run("lyrics-cache.sh", "local", "file://" + path.join(music, "other.flac")).stdout, "", "no .lrc: nothing")
assert.strictEqual(run("lyrics-cache.sh", "local", "https://example.com/a.mp3").stdout, "", "not a local file: nothing")
fs.writeFileSync(path.join(music, "big.lrc"), "x".repeat(300000))
assert.strictEqual(run("lyrics-cache.sh", "local", "file://" + path.join(music, "big.flac")).stdout, "", "a huge file is not read")
assert.strictEqual(run("lyrics-cache.sh", "nope").status, 2)

// the widget's state
assert.strictEqual(run("lyrics-state.sh", "load").stdout, "")
assert.strictEqual(run("lyrics-state.sh", "save", '{"x":1}').status, 0)
assert.strictEqual(run("lyrics-state.sh", "load").stdout.trim(), '{"x":1}')
assert.ok(fs.existsSync(path.join(tmp, "state", "sekaipop", "lyrics.json")))
console.log("cache_unit: all checks passed")

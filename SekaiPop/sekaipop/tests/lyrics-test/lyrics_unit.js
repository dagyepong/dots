// The maths behind the desktop lyrics widget (modules/common/functions/LyricsMath.js).
// The lines used here are made up for the test. Run: node lyrics_unit.js
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const src = fs.readFileSync(path.join(__dirname, "..", "..", "modules", "common", "functions", "LyricsMath.js"), "utf8")
const LM = new Function(src.replace(".pragma library", "") + "\nreturn { " +
    [...src.matchAll(/^function (\w+)/gm)].map(m => m[1]).join(", ") + ", POSES, HELD_POSES, GAP_MIN, DEFAULT_RATE, CLOCK_WINDOW, ADLIB_SHARE, OVERLAP_BELOW, MAX_OVERLAP, RUSH_FROM, RUSH_FULL, HOLD_TAIL, RELEASE, RUSH_LEAD, LANDING }")()
const near = (a, b, e = 1e-6) => assert.ok(Math.abs(a - b) <= e, a + " vs " + b)

// ---------- parseLrc ----------
let L = LM.parseLrc("[ar:Someone]\n[ti:Song]\n[00:05.00]la la la\n[00:09.50] sing   it loud \n[01:02.250]end\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "la la la", "sing it loud", "end"], "an intro gap is put before a first line that is late")
assert.strictEqual(L[0].t, 0)
near(L[1].t, 5); near(L[2].t, 9.5); near(L[3].t, 62.25)
L = LM.parseLrc("[00:02.5]one\n[00:04]two\n")
assert.deepStrictEqual(L.map(l => l.text), ["one", "two"], "an early first line has no intro gap")
near(L[1].t, 4)
// several stamps on one line, out of order, and word tags
L = LM.parseLrc("[00:30.00][00:10.00]chorus line\n[00:20.00]<00:20.10>mid <00:20.50>line\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "chorus line", "mid line", "chorus line"])
assert.deepStrictEqual(L.map(l => l.t), [0, 10, 20, 30])
// gaps: two in a row are one
L = LM.parseLrc("[00:01.00]a\n[00:03.00]\n[00:04.00]\n[00:08.00]b\n")
assert.deepStrictEqual(L.map(l => l.text), ["a", "", "b"])
// the offset tag: positive shows lines earlier
L = LM.parseLrc("[offset:+500]\n[00:02.00]x\n")
near(L[0].t, 1.5)
L = LM.parseLrc("[offset:-250]\n[00:02.00]x\n")
near(L[0].t, 2.25)
assert.deepStrictEqual(LM.parseLrc(""), [])
assert.deepStrictEqual(LM.parseLrc("just words\nno stamps"), [])
assert.deepStrictEqual(LM.parseLrc(null), [])

// ---------- tokens ----------
assert.deepStrictEqual(LM.tokens("hello big world"), [{ s: "hello", gap: false }, { s: "big", gap: true }, { s: "world", gap: true }])
assert.deepStrictEqual(LM.tokens("  spaced   out "), [{ s: "spaced", gap: false }, { s: "out", gap: true }])
assert.deepStrictEqual(LM.tokens("wait, what?!").map(t => t.s), ["wait,", "what?!"], "punctuation stays on its word")
assert.deepStrictEqual(LM.tokens(""), [])
// no spaces: groups of three, never a lone character
assert.deepStrictEqual(LM.tokens("\u3042\u3044\u3046\u3048\u304a\u304b").map(t => t.s), ["\u3042\u3044\u3046", "\u3048\u304a\u304b"])
assert.deepStrictEqual(LM.tokens("\u3042\u3044\u3046\u3048").map(t => t.s), ["\u3042\u3044\u3046\u3048"], "four stay together: no lone one")
assert.deepStrictEqual(LM.tokens("\u3042\u3044\u3002").map(t => t.s), ["\u3042\u3044\u3002"], "a CJK mark stays with its word")
assert.deepStrictEqual(LM.tokens("go \u3042\u3044\u3046 go").map(t => [t.s, t.gap]), [["go", false], ["\u3042\u3044\u3046", true], ["go", true]])
assert.strictEqual(LM.tokens("ab\u3042\u3044").length, 2, "Latin then CJK are two tokens")
assert.strictEqual(LM.tokens("ab\u3042\u3044")[1].gap, false, "and there is no space between them")

// ---------- syllables and morae ----------
const syl = w => LM.latinSyllables(w)
assert.deepStrictEqual(["love", "time", "kissed", "wanted", "hello", "little", "people", "beautiful", "the", "hmm", "yeah", "2", "I'm"].map(syl),
    [1, 1, 1, 2, 2, 2, 2, 3, 1, 1, 1, 1, 1], "syllables of English words")
assert.strictEqual(syl("!!"), 0, "no letters, no syllables")
const wu = (s, k = 2) => LM.wordUnits(s, k)
assert.strictEqual(wu("\u3042\u308a\u304c\u3068\u3046"), 5, "five kana, five morae")
assert.strictEqual(wu("\u304d\u3087\u3046"), 2, "a small yo is said with the kana before it")
assert.strictEqual(wu("\u304c\u3063\u3053\u3046"), 4, "a small tsu is a beat of its own")
assert.strictEqual(wu("\u30b3\u30fc\u30d2\u30fc"), 4, "so is a long vowel mark")
assert.strictEqual(wu("\u4e16\u754c"), 4, "a kanji in a line with kana is about two")
assert.strictEqual(wu("\u4e16\u754c", 1), 2, "and one in Chinese")
assert.strictEqual(wu("\uc0ac\ub791"), 2, "a Hangul block is a syllable")
assert.strictEqual(wu("go\u3042"), 2, "Latin and kana in one word")
assert.strictEqual(LM.lineUnits("one two (three)"), 1 + 1 + LM.ADLIB_SHARE, "an ad lib counts for less")

// ---------- sungSpan / songRate ----------
near(LM.DEFAULT_RATE, 4.2)
// no room known: the amount of singing at the song's rate, a fifth longer (the held note)
near(LM.sungSpan("one two three four", Infinity, 4), (4 / 4 + 0.25) * 1.2)
near(LM.sungSpan("one two three four", 0, 4), (4 / 4 + 0.25) * 1.2)
// followed at once: sung over most of the room, not stretched past it
near(LM.sungSpan("one two three four five six seven eight nine ten", 2, 4), 2 * 0.92, 1e-9)
// a break after it: the line's own length, not the break
near(LM.sungSpan("one two three four", 9, 4), (4 / 4 + 0.25) * 1.2, 1e-9)
assert.ok(LM.sungSpan("x", 0.1, 4) <= 0.25, "a one-syllable line is never stretched past what it takes at the pace")
assert.ok(LM.sungSpan("x", 3, 4) >= 0.4, "never a blink")
// a line that says how long it is sung is believed, up to the next line
near(LM.sungSpan("one two three four", 9, 4, 2.2), 2.2)
near(LM.sungSpan("one two three four", 2, 4, 2.2), 2.2, 1e-9, "an end stamp after the next line's start (overlapping voices) is believed")
near(LM.sungSpan("one two three four", 2, 4, 9), 4, 1e-9, "but only up to two seconds into the next line")
assert.ok(LM.sungSpan("one two three four", 9, undefined) > 0, "no rate: the default")
// the song's own rate: a fast song's lines are shorter than a slow song's
assert.ok(LM.sungSpan("one two three four five six", 20, 6) < LM.sungSpan("one two three four five six", 20, 3))
{
    // eight lines of six syllables, each followed at once by the next after 2 s: 3 per second
    const dense = []
    for (let i = 0; i < 8; i++) dense.push({ t: i * 2, text: "one two three four five six" })
    near(LM.songRate(dense), 6 / (2 * 0.92), 1e-9)
    // end stamps are believed over the room (a break follows each line)
    const ended = []
    for (let i = 0; i < 6; i++) ended.push({ t: i * 10, text: "one two three four five six", end: i * 10 + 3 })
    near(LM.songRate(ended), 2, 1e-9, "6 syllables in 3 s")
    assert.strictEqual(LM.songRate(dense.slice(0, 3)), LM.DEFAULT_RATE, "too few lines to learn from")
    assert.strictEqual(LM.songRate([]), LM.DEFAULT_RATE)
    // one fast line among slow ones does not decide it
    const mixed = dense.slice()
    mixed[3] = { t: 6, text: "one two three four five six seven eight nine ten eleven twelve thirteen" }
    near(LM.songRate(mixed), 6 / (2 * 0.92), 1e-9)
    // blank lines and one-word lines are not counted; bounds hold
    assert.strictEqual(LM.songRate([{ t: 0, text: "" }, { t: 5, text: "oh" }]), LM.DEFAULT_RATE)
    const absurd = []
    for (let i = 0; i < 6; i++) absurd.push({ t: i * 1, text: "a b c d e f g h i j k l m n o p q r s t" })
    assert.ok(LM.songRate(absurd) <= 9, "a rate has an upper bound")
}

// ---------- a fast entry ----------
{
    const sung = "one two three four five six seven eight nine ten eleven twelve"
    const raw = LM.lineUnits(sung) / 4                       // what it takes at 4 syllables a second
    assert.ok(raw > 3, "a long line")
    // the next line comes 1.2 s later, far sooner than this one could be sung: it is not squeezed into 1.1 s
    const fast = LM.sungSpan(sung, 1.2, 4)
    near(fast, Math.min(raw * 0.9, 1.2 + LM.MAX_OVERLAP), 1e-9)
    assert.ok(fast > 1.2 * 0.92 * 2, "it takes more than twice what the room would have given it")
    assert.ok(fast > 1.2, "and runs on under the next line")
    // never more than its own length, and never more than MAX_OVERLAP past the next line
    assert.ok(LM.sungSpan(sung, 0.2, 4) <= raw * 0.9 + 1e-9 && LM.sungSpan(sung, 0.2, 4) <= 0.2 + LM.MAX_OVERLAP + 1e-9)
    // lines that fit their room are not fast entries: a song of lines that follow at once keeps its fill right up to the next line
    near(LM.sungSpan(sung, raw, 4), raw * 0.92, 1e-9)
    near(LM.sungSpan(sung, raw * 0.73, 4), raw * 0.73 * 0.92, 1e-9, "a room of 73 % of its length is still a room")
    const edge = LM.OVERLAP_BELOW * raw
    near(LM.sungSpan(sung, edge + 0.01, 4), (edge + 0.01) * 0.92, 1e-9)
    assert.ok(LM.sungSpan(sung, edge - 0.01, 4) > (edge - 0.01) * 0.92 + 0.1, "below 65 % it is one")
    // the words are shared out over that longer time, so they do not rush through it
    const toks = LM.tokens(sung)
    const w = LM.spans(toks, 0, fast)
    const squeezed = LM.spans(toks, 0, 1.2 * 0.92)
    assert.ok(w[5].to > squeezed[5].to * 2, "the sixth word is reached more than twice as late as when squeezed into the room")
    assert.ok(w[11].to > 1.2, "and the last word is sung after the next line has begun")
}

// ---------- spans ----------
const sp = LM.spans(LM.tokens("go beautiful go"), 10, 4)
assert.strictEqual(sp.length, 3)
near(sp[0].from, 10); near(sp[2].to, 14)
near(sp[0].to, sp[1].from); near(sp[1].to, sp[2].from)
assert.ok(sp[1].to - sp[1].from > sp[0].to - sp[0].from, "a three-syllable word takes longer than a one-syllable one")
assert.ok(sp[2].to - sp[2].from > sp[0].to - sp[0].from, "and the last word is held a little")
assert.strictEqual(LM.spans([], 0, 3).length, 0)
{
    // an ad lib does not take the line's time from the words around it
    const withAd = LM.spans(LM.tokens("I want you (I want you)"), 0, 6)
    const plain = LM.spans(LM.tokens("I want you I want you"), 0, 6)
    assert.ok(withAd[2].to > plain[2].to, "the main words get more of the line when the echo is an ad lib")
    near(withAd[5].to, 6)
    // morae: five kana take longer than two
    const jp = LM.spans(LM.tokens("\u3042\u308a\u304c\u3068\u3046 \u3042\u3044"), 0, 7)
    assert.strictEqual(jp.length, 3, "five kana are cut into three and two, then the second word")
    assert.ok(jp[0].to - jp[0].from > jp[1].to - jp[1].from, "three morae take longer than two")
    near(jp[2].to, 7)
}

// ---------- word tags in a file ----------
{
    const toks = LM.tokens("so long goodbye")
    const marks = [{ cs: 0, t: 15 }, { cs: 2, t: 15.6 }, { cs: 6, t: 17.5 }]
    const w = LM.spansFor(toks, 15, 3.5, marks)
    near(w[0].from, 15); near(w[0].to, 15.6)
    near(w[1].from, 15.6); near(w[1].to, 17.5)
    near(w[2].from, 17.5); near(w[2].to, 18.5)
    // no marks: shared out by syllables, as spans()
    assert.deepStrictEqual(LM.spansFor(toks, 15, 3.5, []), LM.spans(toks, 15, 3.5))
    assert.deepStrictEqual(LM.spansFor(toks, 15, 3.5, undefined), LM.spans(toks, 15, 3.5))
    // tags that only reach part of the way: the word between two tags is placed between them
    const half = LM.spansFor(LM.tokens("aaaa bbbb"), 0, 4, [{ cs: 0, t: 0 }, { cs: 8, t: 4 }])
    near(half[1].from, 2)
    // brackets and spaces are not counted: the ad lib in the middle is reached by the tags too
    const ad = LM.spansFor(LM.tokens("go (oh) go"), 0, 3, [{ cs: 0, t: 0 }, { cs: 2, t: 1 }, { cs: 4, t: 2 }])
    near(ad[1].from, 1); near(ad[2].from, 2)
    // never backwards, even when the file is
    const back = LM.spansFor(LM.tokens("aa bb cc"), 0, 3, [{ cs: 0, t: 2 }, { cs: 2, t: 1 }, { cs: 4, t: 0.5 }])
    for (let i = 1; i < back.length; i++) assert.ok(back[i].from >= back[i - 1].from && back[i].to >= back[i].from)
}

// ---------- an echo that comes in while the line is still being sung ----------
{
    const song = [{ t: 0, text: "" }]
    for (let i = 1; i <= 6; i++) song.push({ t: i * 4, text: "one two three four five six seven eight" })
    const mk = (extra) => song.concat(extra)
    // 11 syllables at about 2.5 a second: 4.5 s. An echo at +1.2 s is during it; at +4 it is after it.
    const main = { t: 28, text: "I can not stop thinking about you baby" }
    let f = LM.foldEchoes(mk([main, { t: 29.2, text: "(about you)", adlib: true }, { t: 33, text: "next" }]))
    assert.deepStrictEqual(f.map(l => l.text), song.map(l => l.text).concat(["I can not stop thinking about you baby", "next"]), "the echo is not a line of its own")
    assert.deepStrictEqual(f[f.length - 2].bg, { t: 29.2, text: "(about you)" }, "it sings along from its own stamp")
    f = LM.foldEchoes(mk([main, { t: 32.2, text: "(about you)", adlib: true }, { t: 35, text: "next" }]))
    assert.strictEqual(f[f.length - 2].adlib, true, "one stamped after the line is done stays a line")
    // a line that is not in brackets is never folded: it is a fast entry, and has the stage
    f = LM.foldEchoes(mk([main, { t: 29.2, text: "about you" }, { t: 33, text: "next" }]))
    assert.strictEqual(f.length, song.length + 3)
    // an end stamp says it for certain
    f = LM.foldEchoes([{ t: 0, text: "one two three", end: 6 }, { t: 5, text: "(oh)", adlib: true }, { t: 9, text: "x" }])
    assert.strictEqual(f.length, 2); assert.deepStrictEqual(f[0].bg, { t: 5, text: "(oh)" })
    f = LM.foldEchoes([{ t: 0, text: "one two three", end: 6 }, { t: 5.9, text: "(oh)", adlib: true }, { t: 9, text: "x" }])
    assert.strictEqual(f.length, 3, "an echo after the line's end stamp is a line")
    // several echoes join; a line that already sings along keeps its own voice first
    f = LM.foldEchoes([{ t: 0, text: "one two three four five six", end: 8 }, { t: 3, text: "(a)", adlib: true }, { t: 5, text: "(b)", adlib: true }, { t: 9, text: "x" }])
    assert.deepStrictEqual(f[0].bg, { t: 3, text: "(a) (b)" })
    // not folded into a line of ad libs, a gap, the first line, or something at the same moment
    assert.strictEqual(LM.foldEchoes([{ t: 0, text: "(a)", adlib: true }, { t: 1, text: "(b)", adlib: true }]).length, 2)
    assert.strictEqual(LM.foldEchoes([{ t: 0, text: "" }, { t: 1, text: "(b)", adlib: true }]).length, 2)
    assert.strictEqual(LM.foldEchoes([{ t: 0, text: "one two three", end: 5 }, { t: 0.1, text: "(b)", adlib: true }]).length, 2, "same moment is parseLrc's job")
    // the input is not changed, and short or empty input is fine
    const input = mk([main, { t: 29.2, text: "(about you)", adlib: true }])
    const copy = JSON.stringify(input)
    LM.foldEchoes(input)
    assert.strictEqual(JSON.stringify(input), copy)
    assert.deepStrictEqual(LM.foldEchoes([]), []); assert.deepStrictEqual(LM.foldEchoes(null), [])
    assert.strictEqual(LM.foldEchoes([{ t: 1, text: "a" }]).length, 1)
}

// ---------- ad libs ----------
assert.deepStrictEqual(LM.tokens("I want you (I want you)").map(t => [t.s, !!t.adlib]),
    [["I", false], ["want", false], ["you", false], ["I", true], ["want", true], ["you", true]])
assert.deepStrictEqual(LM.tokens("(hey) hold me").map(t => [t.s, !!t.adlib]), [["hey", true], ["hold", false], ["me", false]])
assert.deepStrictEqual(LM.tokens("hold (oh) me").map(t => [t.s, t.gap, !!t.adlib]), [["hold", false, false], ["oh", true, true], ["me", true, false]])
assert.deepStrictEqual(LM.tokens("hold(oh)me").map(t => [t.s, t.gap]), [["hold", false], ["oh", false], ["me", false]], "no spaces, no gaps")
assert.deepStrictEqual(LM.tokens("\uff08\u3042\u3042\uff09\u3042\u3044\u3046").map(t => [t.s, !!t.adlib]), [["\u3042\u3042", true], ["\u3042\u3044\u3046", false]], "full-width brackets")
assert.deepStrictEqual(LM.tokens("go (oh oh").map(t => !!t.adlib), [false, true, true], "an open bracket runs to the end of the line")
assert.deepStrictEqual(LM.tokens("go) on").map(t => !!t.adlib), [false, false], "a stray closing bracket is only dropped")
assert.deepStrictEqual(LM.mainIndexes(LM.tokens("I want you (I want you)")), [0, 1, 2], "the marker skips the ad libs")
assert.deepStrictEqual(LM.mainIndexes(LM.tokens("(oh oh)")), [0, 1], "a line of only ad libs is hopped over whole")
assert.deepStrictEqual(LM.mainIndexes([]), [])
assert.strictEqual(LM.isAdlibLine("(oh oh oh)"), true)
assert.strictEqual(LM.isAdlibLine("(oh) (oh)"), true)
assert.strictEqual(LM.isAdlibLine("(oh)..."), true)
assert.strictEqual(LM.isAdlibLine("hold me (oh)"), false)
assert.strictEqual(LM.isAdlibLine("hold me"), false)
assert.strictEqual(LM.isAdlibLine(""), false)
L = LM.parseLrc("[00:05.00]hold me\n[00:08.00](oh oh)\n[00:11.00]tell me\n")
assert.deepStrictEqual(L.map(l => !!l.adlib), [false, false, true, false], "a line of only ad libs is flagged (after the intro gap)")
// two lines at the same moment: the one without brackets stays the line, the other sings along
L = LM.parseLrc("[00:05.00]hold me\n[00:05.00](ooh)\n[00:09.00]tell me\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "hold me", "tell me"])
assert.deepStrictEqual(L[1].bg, { t: 5, text: "(ooh)" })
L = LM.parseLrc("[00:05.00](ooh)\n[00:05.10]hold me\n[00:09.00]tell me\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "hold me", "tell me"], "the order in the file does not matter")
assert.strictEqual(L[1].bg.text, "(ooh)")
assert.strictEqual(LM.parseLrc("[00:05.00]a\n[00:05.00]b\n[00:05.00]c\n[00:09.00]d")[1].bg.text, "b c", "several voices at once")
assert.strictEqual(LM.parseLrc("[00:05.00]a\n[00:05.60]b\n")[1].text, "a", "0.6 s apart are two lines")
assert.strictEqual(LM.parseLrc("[00:05.00]a\n[00:05.60]b\n")[2].text, "b")
// a [bg: ...] tag, with its own stamp or on the row after a line
L = LM.parseLrc("[00:05.00]hold me[bg: (ooh)]\n[00:09.00]tell me\n")
assert.strictEqual(L[1].text, "hold me"); assert.strictEqual(L[1].bg.text, "(ooh)", "the brackets stay in the text, tokens() drops them")
L = LM.parseLrc("[00:05.00]hold me\n[bg: (ooh)]\n[00:09.00]tell me\n")
assert.strictEqual(L[1].bg.text, "(ooh)"); assert.strictEqual(L[1].bg.t, 5)
L = LM.parseLrc("[00:05.00][bg: ooh ooh]\n[00:09.00]tell me\n")
assert.deepStrictEqual([L[1].text, L[1].adlib], ["ooh ooh", true], "a stamp with only a [bg:] tag is a line of ad libs, not a gap")
// the offset moves the ad lib with its line
L = LM.parseLrc("[offset:+1000]\n[00:05.00]hold me\n[00:05.00](ooh)\n")
near(L[1].t, 4); near(L[1].bg.t, 4)

// ---------- where a line ends ----------
L = LM.parseLrc("[00:05.00]hold me close\n[00:08.00]\n[00:09.00]tell me\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "hold me close", "tell me"], "a stamp with no words right before the next line is not a gap")
near(L[1].end, 8)
L = LM.parseLrc("[00:05.00]hold me close\n[00:08.00]\n[00:20.00]tell me\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "hold me close", "", "tell me"], "a long one is")
near(L[1].end, 8)
assert.strictEqual(LM.parseLrc("[00:05.00]a\n[00:09.00]b\n")[1].end, undefined, "no stamp, no end")
L = LM.parseLrc("[00:05.00]<00:05.00>so <00:05.60>long<00:07.00>\n[00:07.50]\n[00:09.00]b")
near(L[1].end, 7, 1e-9); assert.deepStrictEqual(L[1].marks.map(m => m.cs), [0, 2])
assert.strictEqual(L[1].text, "so long")
assert.strictEqual(LM.parseLrc("[00:01.00]a\n[00:30.00]\n[00:40.00]b")[1].end, undefined, "an end half a minute later is not an end")
near(LM.GAP_MIN, 3.5)
L = LM.parseLrc("[00:05.00]a\n[00:30.00]\n")
assert.deepStrictEqual(L.map(l => l.text), ["", "a", ""], "the quiet at the end of the song stays")

// ---------- lineIndexAt / cursor ----------
const lines = [{ t: 0, text: "" }, { t: 5, text: "a" }, { t: 10, text: "b" }, { t: 20, text: "c" }]
assert.strictEqual(LM.lineIndexAt(lines, -1), -1)
assert.strictEqual(LM.lineIndexAt(lines, 0), 0)
assert.strictEqual(LM.lineIndexAt(lines, 4.99), 0)
assert.strictEqual(LM.lineIndexAt(lines, 5), 1)
assert.strictEqual(LM.lineIndexAt(lines, 99), 3)
assert.strictEqual(LM.lineIndexAt([], 3), -1)
assert.strictEqual(LM.cursor(lines, 6, 0.4), 1, "far from the next line the stack is at rest")
near(LM.cursor(lines, 9.8, 0.4), 1.5, 1e-9)
assert.ok(LM.cursor(lines, 9.99, 0.4) < 2 && LM.cursor(lines, 9.99, 0.4) > 1.9)
assert.strictEqual(LM.cursor(lines, 10, 0.4), 2, "at the line's start the stack has arrived")
assert.strictEqual(LM.cursor(lines, 30, 0.4), 3, "after the last line it stays")
// continuous across a line change: just before and just after the same place
near(LM.cursor(lines, 9.9999, 0.4), LM.cursor(lines, 10, 0.4), 1e-3)
// a line that is on for half a second is not mostly leaving: the climb takes the last 40 % of its time
{
    const quick = [{ t: 0, text: "a" }, { t: 0.5, text: "b" }, { t: 10, text: "c" }]
    assert.strictEqual(LM.cursor(quick, 0.29, 0.45), 0, "60 % of its time it is simply on")
    near(LM.cursor(quick, 0.4, 0.45), 0.5, 1e-9)
    assert.strictEqual(LM.cursor(quick, 0.5, 0.45), 1)
    near(LM.cursor(quick, 0.4999, 0.45), LM.cursor(quick, 0.5, 0.45), 1e-2)
    // a line that is on for a long time has the whole lead, as before
    near(LM.cursor(quick, 9.775, 0.45), 1.5, 1e-9)
    // still continuous at the start of the quick line itself
    near(LM.cursor(quick, 0, 0.45), 0, 1e-9)
}
// before the first line the stack comes up from -1
const late = [{ t: 4, text: "x" }]
assert.strictEqual(LM.cursor(late, 1, 0.5), -1)
near(LM.cursor(late, 3.75, 0.5), -0.5, 1e-9)

// ---------- pose ----------
let p0 = LM.pose(0)
assert.deepStrictEqual([p0.y, p0.scale, p0.opacity, p0.rot], [0, 1, 1, 0])
assert.strictEqual(LM.pose(5).opacity, 0); assert.strictEqual(LM.pose(-5).opacity, 0)
assert.ok(LM.pose(1).y > 0 && LM.pose(-1).y < 0, "the next line is under, the last one over")
assert.ok(LM.pose(1).opacity > LM.pose(-1).opacity, "the one to come is stronger than the one that has been")
assert.ok(LM.pose(0.5).scale < 1 && LM.pose(0.5).scale > LM.pose(1).scale)
let prev = LM.pose(-2)
for (let d = -2; d <= 2; d += 0.05) {
    const q = LM.pose(d)
    assert.ok(Math.abs(q.y - prev.y) < 14 && Math.abs(q.opacity - prev.opacity) < 0.12, "no jumps at " + d)
    prev = q
}

// ---------- a line that is taken over ----------
{
    // leaveAt: when the stack starts to climb away from a line, exactly where cursor() starts it
    near(LM.leaveAt(0, 10, 0.45), 9.55)
    near(LM.leaveAt(0, 0.5, 0.45), 0.3, 1e-12, "a line on for half a second: the last 40 % of it")
    near(LM.leaveAt(9.9, 10, 0.45), 9.95, 1e-12, "never less than 50 ms")
    {
        const cl = [{ t: 0, text: "a" }, { t: 10, text: "b" }, { t: 10.6, text: "c" }, { t: 30, text: "d" }]
        for (let i = 0; i < 3; i++) {
            const from = LM.leaveAt(cl[i].t, cl[i + 1].t, 0.45)
            assert.strictEqual(LM.cursor(cl, from - 1e-6, 0.45), i, "has not started to climb just before it")
            assert.ok(LM.cursor(cl, from + 0.01, 0.45) > i, "has started just after")
        }
    }

    // overrun: how long a line is still being sung once it has to go
    near(LM.overrun(5, 3), 2)
    assert.strictEqual(LM.overrun(3, 5), 0, "sung by the time the next begins")
    assert.strictEqual(LM.overrun(5, Infinity), 0, "no next line")
    assert.strictEqual(LM.overrun(NaN, 3), 0)

    // rushOf: nothing for a breath of overlap, all of it for a real one, no jump between
    assert.strictEqual(LM.rushOf(0), 0)
    assert.strictEqual(LM.rushOf(LM.RUSH_FROM), 0)
    assert.strictEqual(LM.rushOf(LM.RUSH_FULL), 1)
    assert.strictEqual(LM.rushOf(9), 1)
    let last = 0
    for (let o = 0; o <= 1; o += 0.01) {
        const r = LM.rushOf(o)
        assert.ok(r >= last - 1e-12 && r - last < 0.06, "rushOf rises smoothly, no step at " + o)
        last = r
    }

    // hold: full while sung and a moment after, then lets go over RELEASE, never below 0
    assert.strictEqual(LM.hold(5, 8, 0), 0, "a line that is not taken over is never held")
    assert.strictEqual(LM.hold(5, 8, -1), 0)
    near(LM.hold(5, 8, 1), 1)
    near(LM.hold(8 + LM.HOLD_TAIL, 8, 1), 1, 1e-12, "held until the note has rung")
    near(LM.hold(8 + LM.HOLD_TAIL + LM.RELEASE / 2, 8, 1), 0.5, 1e-9, "half way through the release")
    assert.strictEqual(LM.hold(8 + LM.HOLD_TAIL + LM.RELEASE, 8, 1), 0)
    assert.strictEqual(LM.hold(99, 8, 1), 0)
    near(LM.hold(5, 8, 0.4), 0.4, 1e-12, "a mild takeover is held mildly")
    last = 1
    for (let t = 7; t < 9.5; t += 0.01) {
        const h = LM.hold(t, 8, 1)
        assert.ok(h <= last + 1e-12, "the hold only ever lets go")
        last = h
    }

    // takeover: exactly the usual pose when nothing is held, the held pose when fully held
    for (let d = -2.5; d <= 2.5; d += 0.1)
        assert.deepStrictEqual(LM.takeover(d, 0), LM.pose(d), "no hold, no change at " + d)
    assert.deepStrictEqual(LM.takeover(0, 1), LM.pose(0), "the line on the stage is not moved by being held")
    near(LM.takeover(-1, 1).y, -76, 1e-9)
    near(LM.takeover(-1, 1).opacity, 0.78, 1e-9)
    assert.ok(LM.takeover(-1, 1).opacity > LM.pose(-1).opacity + 0.4, "held: still strong, not faded")
    assert.ok(LM.takeover(-1, 1).scale > LM.pose(-1).scale, "and bigger than the faded slot")
    assert.ok(LM.takeover(-1, 1).y < LM.pose(-1).y, "and clear above it, away from the new line's marker")
    assert.deepStrictEqual(LM.takeover(1, 1), LM.pose(1), "the line to come is not touched")
    assert.deepStrictEqual(LM.takeover(-3, 1), LM.pose(-3), "a line long gone is invisible either way")
    assert.strictEqual(LM.takeover(-3, 1).opacity, 0)
    // in between h values: in between poses
    const mid = LM.takeover(-1, 0.5)
    near(mid.y, (LM.pose(-1).y + LM.takeover(-1, 1).y) / 2, 1e-9)
    // continuous in d and in h
    let pd = LM.takeover(-2.5, 1)
    for (let d = -2.5; d <= 0.5; d += 0.02) {
        const q = LM.takeover(d, 1)
        assert.ok(Math.abs(q.y - pd.y) < 4 && Math.abs(q.opacity - pd.opacity) < 0.06 && Math.abs(q.scale - pd.scale) < 0.03, "held pose has no jumps at d " + d)
        pd = q
    }
    let ph = LM.takeover(-1, 0)
    for (let h = 0; h <= 1; h += 0.01) {
        const q = LM.takeover(-1, h)
        assert.ok(Math.abs(q.y - ph.y) < 0.4 && Math.abs(q.opacity - ph.opacity) < 0.01, "and none in h at " + h)
        ph = q
    }
    for (let i = 0; i < LM.HELD_POSES.length; i++) {
        assert.strictEqual(LM.HELD_POSES[i].d, LM.POSES[i].d, "same stops as the usual stack")
        if (LM.POSES[i].d >= 0)
            assert.deepStrictEqual(LM.HELD_POSES[i], LM.POSES[i], "only the line that has gone differs")
    }
}

// ---------- landing ----------
{
    assert.strictEqual(LM.landing(0.1, 0), 0, "an ordinary entry does not pulse")
    assert.strictEqual(LM.landing(0.1, undefined), 0)
    assert.strictEqual(LM.landing(-1, 1), 0, "not before it has started")
    assert.strictEqual(LM.landing(0, 1), 0)
    assert.strictEqual(LM.landing(LM.LANDING, 1), 0, "gone by the end")
    assert.strictEqual(LM.landing(5, 1), 0)
    near(LM.landing(LM.LANDING / 2, 1), 1, 1e-12, "full in the middle")
    near(LM.landing(LM.LANDING / 2, 0.5), 0.5, 1e-12, "a milder takeover lands milder")
    let top = 0
    let lastV = 0
    let maxStep = 0
    for (let tau = 0; tau <= LM.LANDING + 0.1; tau += 0.002) {
        const v = LM.landing(tau, 1)
        assert.ok(v >= 0 && v <= 1)
        top = Math.max(top, v)
        maxStep = Math.max(maxStep, Math.abs(v - lastV))
        lastV = v
    }
    assert.ok(top > 0.999)
    assert.ok(maxStep < 0.02, "no step anywhere in it: " + maxStep)
    // it starts and ends at rest (the speed of a pulse that is then used as a size is nothing)
    const e = 1e-4
    assert.ok(Math.abs(LM.landing(e, 1)) / e < 0.01 && Math.abs(LM.landing(LM.LANDING - e, 1)) / e < 0.01)
}

// ---------- cursor with a takeover ----------
{
    const rl = [{ t: 0, text: "a" }, { t: 10, text: "b" }, { t: 20, text: "c" }]
    // no rush given, or none: exactly what it was
    for (let t = 8; t < 11; t += 0.05) {
        assert.strictEqual(LM.cursor(rl, t, 0.45), LM.cursor(rl, t, 0.45, 0))
        assert.strictEqual(LM.cursor(rl, t, 0.45), LM.cursor(rl, t, 0.45, undefined))
    }
    // a full takeover gets a longer climb: it has not started at the usual lead, and it still arrives exactly on the start
    const ahead = 0.45 * (1 + LM.RUSH_LEAD)
    assert.strictEqual(LM.cursor(rl, 10 - ahead - 0.001, 0.45, 1), 0)
    assert.ok(LM.cursor(rl, 10 - 0.45 - 0.001, 0.45, 1) > 0, "starts earlier than the usual lead")
    assert.strictEqual(LM.cursor(rl, 10 - 0.45 - 0.001, 0.45, 0), 0, "(the usual one has not started yet)")
    near(LM.cursor(rl, 10 - ahead / 2, 0.45, 1), 0.5, 1e-9)
    assert.strictEqual(LM.cursor(rl, 10, 0.45, 1), 1)
    // smooth and in order the whole way: it goes up, never back
    let pv = 0
    for (let t = 9; t <= 10.2; t += 0.005) {
        const c = LM.cursor(rl, t, 0.45, 1)
        assert.ok(c >= pv - 1e-12 && c <= 1 + 1e-12, "never goes back, never past its place: " + c)
        assert.ok(c - pv < 0.04, "and in small steps")
        pv = c
    }
    // a milder takeover is in between
    assert.ok(LM.cursor(rl, 10 - 0.45 - 0.05, 0.45, 0.5) > 0 && LM.cursor(rl, 10 - 0.45 - 0.05, 0.45, 0.5) < LM.cursor(rl, 10 - 0.45 - 0.05, 0.45, 1) + 1e-12)
    // a line that is on only briefly is still not mostly leaving, takeover or not
    const quick = [{ t: 0, text: "a" }, { t: 0.5, text: "b" }, { t: 10, text: "c" }]
    assert.strictEqual(LM.cursor(quick, 0.29, 0.45, 1), 0)
    near(LM.cursor(quick, 0.4, 0.45, 1), 0.5, 1e-9)
}

// ---------- a whole takeover, frame by frame ----------
{
    // a long line, then a line stamped 1.2 s behind it, then a quiet one
    const sungText = "one two three four five six seven eight nine ten eleven twelve"
    const next = "and then some more words"
    const tl = [{ t: 10, text: sungText }, { t: 11.2, text: next }, { t: 18, text: "last" }]
    const rate = 4
    const end = [10 + LM.sungSpan(sungText, 1.2, rate), 11.2 + LM.sungSpan(next, 6.8, rate), 18 + LM.sungSpan("last", Infinity, rate)]
    const rushOfLine = i => i + 1 >= tl.length ? 0 : LM.rushOf(LM.overrun(end[i], LM.leaveAt(tl[i].t, tl[i + 1].t, 0.45)))
    const rush0 = rushOfLine(0)
    assert.strictEqual(rush0, 1, "this is a full takeover: it runs on 1.5 s past the next line")
    assert.strictEqual(rushOfLine(1), 0, "the next line fits its room: not one")

    const frame = 1 / 60
    let prevA = null, prevB = null
    let maxDy = 0, maxDo = 0, maxDs = 0
    let sawHeld = false, sawRelease = false
    let nowOn = -1
    for (let t = 9; t <= 14; t += frame) {
        const ci = Math.max(0, LM.lineIndexAt(tl, t))
        const cv = LM.cursor(tl, t, 0.45, ci + 1 < tl.length ? LM.rushOf(LM.overrun(end[ci], tl[ci + 1].t)) : 0)
        const A = LM.takeover(0 - cv, LM.hold(t, end[0], rush0))
        const B = LM.takeover(1 - cv, LM.hold(t, end[1], 0))
        if (prevA) {
            maxDy = Math.max(maxDy, Math.abs(A.y - prevA.y), Math.abs(B.y - prevB.y))
            maxDo = Math.max(maxDo, Math.abs(A.opacity - prevA.opacity), Math.abs(B.opacity - prevB.opacity))
            maxDs = Math.max(maxDs, Math.abs(A.scale - prevA.scale), Math.abs(B.scale - prevB.scale))
        }
        prevA = A; prevB = B
        if (t > 11.2 && t < end[0]) {
            // while A is still being sung, under the new line: held, strong, clear of the stage
            sawHeld = true
            assert.ok(A.opacity > 0.7 && A.scale > 0.6, "A is still strong while it is being sung under the new line (t " + t.toFixed(2) + ")")
            assert.ok(A.y < -60, "and above the line that took the stage")
            assert.ok(B.scale > 0.95 && B.opacity > 0.95, "B has the stage")
            nowOn = A.opacity
        }
        if (t > end[0] + LM.HOLD_TAIL + 0.05 && t < end[0] + LM.HOLD_TAIL + LM.RELEASE) {
            sawRelease = true
            assert.ok(A.opacity < nowOn + 1e-9, "while it lets go it only fades")
        }
    }
    assert.ok(sawHeld && sawRelease)
    assert.ok(maxDy < 7, "no frame moves a line by a jump: " + maxDy.toFixed(2) + " px")
    assert.ok(maxDy < 6.6, "and the fastest move is only a little faster than an ordinary line's (5.7 px a frame): " + maxDy.toFixed(2))
    assert.ok(maxDo < 0.06, "none changes its strength by a jump: " + maxDo.toFixed(3))
    assert.ok(maxDs < 0.03, "none changes its size by a jump: " + maxDs.toFixed(3))
    // at the end of the release A is exactly in the usual faded slot, nothing is left to snap
    const done = LM.takeover(-1, LM.hold(end[0] + LM.HOLD_TAIL + LM.RELEASE, end[0], rush0))
    assert.deepStrictEqual(done, LM.pose(-1))
}

// ---------- a line whose last word is still being sung as the stack climbs away ----------
{
    // not a fast entry at all: the next line is 3 s away, the line is sung up to 92 % of that, so its
    // singing ends 0.21 s INTO the climb (the stack leaves 0.45 s before the next line). It must not
    // shrink and fade while its last word is still filling.
    const text = "one two three four five six seven eight nine ten"
    const tl = [{ t: 10, text }, { t: 13, text: "next" }]
    const end = 10 + LM.sungSpan(text, 3, 4)
    const leave = LM.leaveAt(10, 13, 0.45)
    assert.ok(end > leave + 0.1 && end < 13, "it ends inside the climb, before the next line: " + end + " vs " + leave)
    const rush = LM.rushOf(LM.overrun(end, leave))
    assert.ok(rush > 0.6 && rush <= 1, "that is held with some strength: " + rush)
    assert.strictEqual(LM.rushOf(LM.overrun(end, 13)), 0, "but it is no takeover: it is sung by the time the next line starts")
    // while it is still being sung it is held, strong, and never fainter than half way to the faded slot
    for (let t = leave; t <= end; t += 0.01) {
        const cv = LM.cursor(tl, t, 0.45, rush)
        const A = LM.takeover(0 - cv, LM.hold(t, end, rush))
        const plain = LM.pose(0 - cv)
        assert.ok(A.opacity >= plain.opacity - 1e-12 && A.scale >= plain.scale - 1e-12, "never weaker than the usual line that is leaving")
    }
    // and its place is the usual one both before it has to go and long after
    near(LM.takeover(0, LM.hold(leave - 0.01, end, rush)).y, 0, 1e-12)
    assert.deepStrictEqual(LM.takeover(-1, LM.hold(end + 5, end, rush)), LM.pose(-1))
    // a line that is sung well before the climb is not touched at all
    const early = LM.rushOf(LM.overrun(10 + LM.sungSpan("one two", 3, 4), leave))
    assert.strictEqual(early, 0)
    // gaps are never a takeover, however the numbers fall: the widget does not ask for one
    // (LyricsWidget.rushAfter), but the arithmetic would say so, so it is the widget's guard that matters
    assert.ok(LM.rushOf(LM.overrun(13, LM.leaveAt(10, 13, 0.45))) === 1)
}

// ---------- the marker maths copes with a missing time ----------
{
    // while a new song's lyrics arrive, a line can for a moment have words and no times for them
    const holey = [{ from: 1, to: 2 }, undefined, { from: 3, to: 4 }]
    assert.strictEqual(LM.wordAt(holey, 5), 0, "stops at the gap instead of throwing")
    assert.strictEqual(LM.wordAt([undefined], 5), -1)
    assert.strictEqual(LM.hop(holey, 0, 1.5), 0)
    assert.strictEqual(LM.hop(holey, 1, 1.5), 0)
    assert.strictEqual(LM.hit(holey, 1, 1.5), 0)
    assert.strictEqual(LM.hit([], 0, 1), 0)
    // and is exactly what it was when nothing is missing
    const whole = [{ from: 1, to: 2 }, { from: 2, to: 3 }, { from: 3, to: 4 }]
    assert.strictEqual(LM.wordAt(whole, 2.5), 1)
    near(LM.hop(whole, 1, 2.5), 0.5)
    near(LM.hit(whole, 1, 2.0), 1)
}

// ---------- fit ----------
assert.strictEqual(LM.fit(300, 600), 1)
near(LM.fit(1200, 600), 0.5)
assert.strictEqual(LM.fit(5000, 600), 0.45)
assert.strictEqual(LM.fit(0, 600), 1)

// ---------- the marker ----------
assert.strictEqual(LM.wordAt(sp, 9), -1)
assert.strictEqual(LM.wordAt(sp, 10), 0)
assert.strictEqual(LM.wordAt(sp, sp[1].from + 0.01), 1)
assert.strictEqual(LM.wordAt(sp, 99), 2)
assert.strictEqual(LM.hop(sp, 0, sp[0].from), 0)
near(LM.hop(sp, 0, (sp[0].from + sp[1].from) / 2), 0.5)
assert.strictEqual(LM.hop(sp, 0, sp[1].from + 5), 1)
assert.strictEqual(LM.hop(sp, 2, 13), 0, "the last word has no hop")
assert.strictEqual(LM.hop(sp, -1, 5), 0)
assert.strictEqual(LM.arch(0), 0); assert.strictEqual(LM.arch(1), 0); assert.strictEqual(LM.arch(0.5), 1)
assert.strictEqual(LM.hit(sp, 1, sp[1].from), 1)
assert.strictEqual(LM.hit(sp, 1, sp[1].from + 1), 0)
assert.ok(LM.hit(sp, 1, sp[1].from + 0.11) > 0.4 && LM.hit(sp, 1, sp[1].from + 0.11) < 0.6)
assert.strictEqual(LM.hit(sp, -1, 3), 0)
assert.strictEqual(LM.hit(sp, 1, sp[1].from - 2), 0, "a word that has not started is not squashed")
assert.strictEqual(LM.sung({ from: 2, to: 4 }, 1), 0)
assert.strictEqual(LM.sung({ from: 2, to: 4 }, 3), 0.5)
assert.strictEqual(LM.sung({ from: 2, to: 4 }, 9), 1)

// ---------- the clock ----------
let st = { pos: 10, at: 1000, hist: [], cand: null }
near(LM.estimate(st, 3000, true), 12)
near(LM.estimate(st, 3000, false), 10, 0)
assert.deepStrictEqual(LM.clockReset(7, 500), { pos: 7, at: 500, hist: [], cand: null })
let r = LM.observe(LM.clockReset(0, 0), 5, 1000, true)
near(r.pos, 5); assert.strictEqual(r.at, 1000, "the first reading is taken as it is")
r = LM.observe(st, 12, 3000, false)
assert.deepStrictEqual(r, { pos: 12, at: 3000, hist: [], cand: null }, "paused: whatever the player says")
{
    // a steady player: readings are exact and the clock stays on them
    let c = LM.clockReset(0, 0)
    for (let i = 1; i <= 40; i++) c = LM.observe(c, i * 0.25, i * 250, true)
    near(LM.estimate(c, 10250, true), 10.25, 1e-9)
    // a late reading (the player said 0.2 s ago) does not pull the clock back
    const before = LM.estimate(c, 10500, true)
    c = LM.observe(c, 10.5 - 0.2, 10500, true)
    near(LM.estimate(c, 10500, true), before, 1e-9)
    assert.strictEqual(c.cand, null, "a small lateness is not a candidate")
    // a better reading (the clock was behind) moves it at once
    let slow = LM.clockReset(0, 0)
    slow = LM.observe(slow, 0, 0, true)
    slow = LM.observe(slow, 0.25 - 0.3, 250, true)    // late, ignored: 0.3 behind is within a late reading
    slow = LM.observe(slow, 0.5, 500, true)           // exact
    near(LM.estimate(slow, 500, true), 0.5, 1e-9)
    // a seek forward is taken at once
    let f = LM.clockReset(0, 0)
    for (let i = 1; i <= 8; i++) f = LM.observe(f, i * 0.25, i * 250, true)
    f = LM.observe(f, 60, 2250, true)
    near(LM.estimate(f, 2250, true), 60, 1e-9)
    // a seek back a long way too
    f = LM.observe(f, 20, 2500, true)
    near(LM.estimate(f, 2500, true), 20, 1e-9)
    // a seek back of a second is believed after three readings that agree
    let g = LM.clockReset(0, 0)
    for (let i = 1; i <= 8; i++) g = LM.observe(g, i * 0.25, i * 250, true)       // 2.0 at 2000
    g = LM.observe(g, 2.25 - 1.0, 2250, true)
    assert.ok(Math.abs(LM.estimate(g, 2250, true) - 2.25) < 1e-9, "not yet")
    g = LM.observe(g, 2.5 - 1.0, 2500, true)
    assert.ok(Math.abs(LM.estimate(g, 2500, true) - 2.5) < 1e-9, "not yet")
    g = LM.observe(g, 2.75 - 1.0, 2750, true)
    near(LM.estimate(g, 2750, true), 1.75, 1e-9)
    // one of half a second looks like a slow reply, so it takes eight in a row
    let q = LM.clockReset(0, 0)
    for (let i = 1; i <= 8; i++) q = LM.observe(q, i * 0.25, i * 250, true)
    for (let i = 1; i <= 7; i++) q = LM.observe(q, 2 + i * 0.25 - 0.5, 2000 + i * 250, true)
    near(LM.estimate(q, 3750, true), 3.75, 1e-9, "seven readings are not enough")
    q = LM.observe(q, 2 + 8 * 0.25 - 0.5, 4000, true)
    near(LM.estimate(q, 4000, true), 3.5, 1e-9, "eight are")
    // readings that keep getting later (a player that moves once a second) never are
    let h = LM.clockReset(0, 0)
    h = LM.observe(h, 3, 3000, true)
    for (let i = 1; i <= 3; i++) h = LM.observe(h, 3, 3000 + i * 250, true)
    near(LM.estimate(h, 3750, true), 3.75, 1e-9, "the same position over and over: the clock goes on")
    assert.ok(h.cand === null || h.cand.n < 3)
    // the history is bounded
    let big = LM.clockReset(0, 0)
    for (let i = 1; i <= 50; i++) big = LM.observe(big, i * 0.25, i * 250, true)
    assert.strictEqual(big.hist.length, LM.CLOCK_WINDOW)
    assert.strictEqual(LM.clockSpread(big), 0, "exact readings: no spread")
    assert.strictEqual(LM.clockSpread(null), 0)
}

// ---------- the clock against players that report badly ----------
// What the widget did before (the readings averaged in 25 % at a time, a jump of more than
// 0.3 s taken at once) and what it does now, on the same made-up readings. The truth is the
// song's second `x` at wall time `x` (a player at normal speed).
{
    function oldRetune(state, polled, nowMs) {
        const est = state.pos + (nowMs - state.at) / 1000
        if (Math.abs(polled - est) > 0.3) return { pos: polled, at: nowMs }
        return { pos: est + (polled - est) * 0.25, at: nowMs }
    }
    let seed = 12345
    const rnd = () => (seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296
    const players = {
        // exact, a little late on the bus now and then
        exact: tt => tt - rnd() * 0.04,
        // moves its position once a second, at moments the polls do not line up with
        stairs: tt => Math.floor(tt - 0.13) + 0.13,
        stairs2: tt => Math.floor(tt - 0.61) + 0.61,
        // a busy machine: every reply is between 0 and 0.45 s old
        laggy: tt => tt - rnd() * 0.45,
        // exact, but now and then a very late reply
        spiky: tt => tt - (rnd() < 0.12 ? 0.3 + rnd() * 0.5 : rnd() * 0.02)
    }
    const report = {}
    for (const name of Object.keys(players)) {
        let o = { pos: 0, at: 0 }, n = LM.clockReset(0, 0)
        let oldSq = 0, newSq = 0, oldMax = 0, newMax = 0, cnt = 0, nextPoll = 250
        let lastStale = { prev: -1, stale: 0 }
        for (let ms = 0; ms <= 120000; ms += 16) {
            while (nextPoll <= ms) {
                const tt = nextPoll / 1000
                const reading = players[name](tt)
                o = oldRetune(o, reading, nextPoll)
                const trust = LM.pollTrust(lastStale.prev, reading, lastStale.stale, true)
                lastStale = { prev: reading, stale: trust.stale }
                if (trust.use) n = LM.observe(n, reading, nextPoll, true)
                nextPoll += 250
            }
            if (ms < 5000) continue
            const eo = o.pos + (ms - o.at) / 1000 - ms / 1000
            const en = LM.estimate(n, ms, true) - ms / 1000
            oldSq += eo * eo; newSq += en * en
            oldMax = Math.max(oldMax, Math.abs(eo)); newMax = Math.max(newMax, Math.abs(en)); cnt++
        }
        report[name] = { oldRms: Math.sqrt(oldSq / cnt), newRms: Math.sqrt(newSq / cnt), oldMax, newMax }
    }
    for (const name of Object.keys(report)) {
        const x = report[name]
        console.log("  clock " + name.padEnd(6) + " rms " + (x.oldRms * 1000).toFixed(0).padStart(4) + " -> " + (x.newRms * 1000).toFixed(0).padStart(4) +
            " ms,  worst " + (x.oldMax * 1000).toFixed(0).padStart(4) + " -> " + (x.newMax * 1000).toFixed(0).padStart(4) + " ms")
        assert.ok(x.newMax <= x.oldMax + 1e-9, name + ": never worse in the worst case")
    }
    for (const n of ["stairs", "stairs2"]) {
        assert.ok(report[n].newMax < 0.3, "a player that moves once a second: within 0.3 s")
        assert.ok(report[n].newRms < report[n].oldRms * 0.6, "and steadier than before")
    }
    assert.ok(report.laggy.newMax < 0.5 && report.laggy.newRms < report.laggy.oldRms * 0.6)
    assert.ok(report.spiky.newMax < 0.3, "late replies do not move it")
    assert.ok(report.exact.newMax < 0.06)
}

// ---------- a position that does not move ----------
let pt = LM.pollTrust(10, 10.4, 0, true)
assert.deepStrictEqual(pt, { use: true, stale: 0 }, "a moving position is trusted")
pt = LM.pollTrust(10, 10, 0, true); assert.deepStrictEqual(pt, { use: true, stale: 1 }, "one equal reading is only a maybe")
pt = LM.pollTrust(10, 10, 1, true); assert.deepStrictEqual(pt, { use: true, stale: 2 })
pt = LM.pollTrust(10, 10, 2, true); assert.deepStrictEqual(pt, { use: false, stale: 3 }, "three in a row: the player is not keeping it")
pt = LM.pollTrust(10, 10, 7, true); assert.strictEqual(pt.use, false)
pt = LM.pollTrust(10, 25, 7, true); assert.deepStrictEqual(pt, { use: true, stale: 0 }, "it moves again (a seek): trusted again")
pt = LM.pollTrust(10, 10, 7, false); assert.deepStrictEqual(pt, { use: true, stale: 0 }, "paused: whatever it says is true")

// ---------- asking ----------
assert.strictEqual(LM.cleanTitle("Some Song (Official Video)"), "Some Song")
assert.strictEqual(LM.cleanTitle("Some Song [Lyrics] (feat. Guest)"), "Some Song")
assert.strictEqual(LM.cleanTitle("Some Song (Remastered 2011)"), "Some Song")
assert.strictEqual(LM.cleanTitle("Some Song (Acoustic)"), "Some Song (Acoustic)", "a version the song really has is kept")
assert.strictEqual(LM.cleanTitle("Some Song - Official Audio"), "Some Song")
assert.strictEqual(LM.cleanArtist("Some Band - Topic"), "Some Band")
assert.strictEqual(LM.cleanArtist("SomeBandVEVO"), "SomeBand")
assert.strictEqual(LM.firstArtist("A, B"), "A")
assert.strictEqual(LM.firstArtist("A feat. B"), "A")
assert.deepStrictEqual(LM.candidates("Band", "Tune (Official Video)"), [{ artist: "Band", title: "Tune" }])
assert.deepStrictEqual(LM.candidates("A, B", "Tune").map(c => c.artist), ["A, B", "A"])
assert.deepStrictEqual(LM.candidates("Some Channel", "Band - Tune"), [{ artist: "Some Channel", title: "Band - Tune" }, { artist: "Band", title: "Tune" }])
assert.deepStrictEqual(LM.candidates("", ""), [])
const results = [
    { duration: 300, syncedLyrics: "[00:01.00]x" },
    { duration: 201, syncedLyrics: "" },
    { duration: 203, syncedLyrics: "[00:01.00]y" },
    { duration: 199, syncedLyrics: "[00:01.00]z" }
]
assert.strictEqual(LM.pickBest(results, 200).duration, 199, "the closest length with synced lyrics")
assert.strictEqual(LM.pickBest(results, 100), null, "nothing within four seconds")
assert.strictEqual(LM.pickBest([{ duration: 5, syncedLyrics: "[00:01.00]x" }], 0).duration, 5, "no known length: take it")
assert.strictEqual(LM.pickBest([], 10), null)
assert.strictEqual(LM.pickBest(null, 10), null)
assert.strictEqual(LM.trackKey("Band - Topic", "Tune (Official Video)", 200.4), "band|tune|200")
assert.strictEqual(LM.trackKey("Band", "Tune", -1), "band|tune|0")

console.log("lyrics_unit: all checks passed")

// ===== word timing from a karaoke source (yrc) =====
{
    const fs2 = require("fs")
    const src = fs2.readFileSync(require("path").join(__dirname, "../../modules/common/functions/LyricsMath.js"), "utf8")
    const L = new Function(src.replace(/^\.pragma.*$/m, "") + "; return { yrcToLrc, parseLrc, alignShift, sameWords, pickWordSong, spansFor, tokens }")()
    const yrc = [
        '{"t":0,"c":[{"tx":"credits"}]}',
        "[1000,2400](1000,300,0)Hel(1300,500,0)lo (1800,600,0)wor(2400,1000,0)ld",
        "[5000,2000](5000,500,0)Sing (5500,500,0)it (6000,1000,0)loud",
        "[9000,1500](9000,400,0)more (9400,400,0)words (9800,700,0)here",
        "[12000,1500](12000,700,0)and (12700,800,0)more"
    ].join("\n")
    const lrc = L.yrcToLrc(yrc, 0)
    const own = L.parseLrc(lrc)
    assert.strictEqual(own.length, 4, "credit row skipped, four lines")
    assert.strictEqual(own[0].text, "Hello world")
    assert.strictEqual(own[0].end, 3.4, "line end is the last word's end")
    assert.deepStrictEqual(own[0].marks.map(m => m.cs), [0, 3, 5, 8], "a mark where each sung piece starts")
    // the word is placed when it is sung, not by its share of the line
    const sp = L.spansFor(L.tokens(own[0].text), own[0].t, own[0].end - own[0].t, own[0].marks)
    assert.ok(Math.abs(sp[0].from - 1.0) < 1e-6 && Math.abs(sp[1].from - 1.8) < 1e-6, "second word starts at 1.8 s")
    // lined up with another timing of the same song that is 0.8 s later
    const ref = L.parseLrc("[00:01.80]Hello world\n[00:05.80]Sing it loud\n[00:09.80]more words here\n[00:12.80]and more")
    assert.strictEqual(L.alignShift(own, ref), 0.8)
    assert.ok(L.sameWords(ref, own))
    assert.ok(Math.abs(L.parseLrc(L.yrcToLrc(yrc, 0.8))[0].t - 1.8) < 1e-6, "shift moves the stamps")
    // another cut of the song (everything 9 s off) or another song is not used
    const far = L.parseLrc("[00:10.00]Hello world\n[00:14.00]Sing it loud\n[00:18.00]more words here\n[00:21.00]and more")
    assert.strictEqual(L.alignShift(own, far), null)
    assert.ok(!L.sameWords(L.parseLrc("[00:01.00]completely different text here\n[00:05.00]nothing alike at all"), own))
    // picking the song out of a search
    const songs = [
        { id: 1, name: "Hello World (Live)", artists: [{ name: "Someone Else" }], duration: 200000 },
        { id: 2, name: "Hello World", artists: [{ name: "The Band" }], duration: 181000 },
        { id: 3, name: "Hello World", artists: [{ name: "The Band" }], duration: 240000 }
    ]
    assert.strictEqual(L.pickWordSong(songs, "The Band", "Hello World", 180.2), 2)
    assert.strictEqual(L.pickWordSong(songs, "The Band", "Hello World", 100), null, "no song of that length")
    assert.strictEqual(L.pickWordSong(songs, "The Band", "Another Title", 181), null, "title must match")
    assert.strictEqual(L.yrcToLrc("nothing timed here", 0), "")
}
console.log("word timing ok")

// ===== several providers: the best one for each song =====
{
    const fs3 = require("fs")
    const src = fs3.readFileSync(require("path").join(__dirname, "../../modules/common/functions/LyricsMath.js"), "utf8")
    const L = new Function(src.replace(/^\.pragma.*$/m, "") + "; return { parseLrc, yrcToLrc, chooseLyrics, shiftLrc, stripWords, lyricsplusToLrc, unescapeEntities, foldEchoes }")()
    const order = ["lyricsplus", "netease", "lrclib", "qq", "kugou"]
    const syncedText = "[00:01.80]Hello world\n[00:05.80]Sing it loud\n[00:09.80]more words here\n[00:12.80]and more"
    const yrc = "[1000,2400](1000,300,0)Hel(1300,500,0)lo (1800,600,0)wor(2400,1000,0)ld\n[5000,2000](5000,500,0)Sing (5500,500,0)it (6000,1000,0)loud\n[9000,1500](9000,400,0)more (9400,400,0)words (9800,700,0)here\n[12000,1500](12000,700,0)and (12700,800,0)more"
    const mk = (id, kind, text, duration) => ({ id: id, kind: kind, text: text, duration: duration || 0, lines: L.foldEchoes(L.parseLrc(text)) })
    const word = mk("netease", "word", L.yrcToLrc(yrc, 0))
    const lrclib = mk("lrclib", "synced", syncedText, 180)
    const qq = mk("qq", "synced", syncedText, 181)

    // word by word wins, shifted to the synced version the player's cut was given
    let ch = L.chooseLyrics([lrclib, qq, word], order, 180, "auto", true)
    assert.strictEqual(ch.id, "netease")
    assert.strictEqual(ch.kind, "word")
    assert.ok(Math.abs(L.parseLrc(ch.text)[0].t - 1.8) < 1e-6, "shifted by 0.8 s to agree with the synced one")
    // with word timing off it is the line timing of that, or the provider liked best
    ch = L.chooseLyrics([lrclib, qq, word], order, 180, "auto", false)
    assert.strictEqual(ch.kind, "synced")
    assert.ok(ch.text.indexOf("<") < 0 || ch.id !== "netease", "no word tags when off")
    // synced only: the cut to the track's length, then the one liked best
    ch = L.chooseLyrics([mk("kugou", "synced", syncedText, 200), mk("qq", "synced", syncedText, 180.5), lrclib], order, 180, "auto", true)
    assert.strictEqual(ch.id, "lrclib")
    ch = L.chooseLyrics([mk("kugou", "synced", syncedText, 200), qq], order, 180, "auto", true)
    assert.strictEqual(ch.id, "qq", "kugou's 200 s cut is not this track's length")
    // a chosen provider is used when it has something usable
    ch = L.chooseLyrics([lrclib, qq, word], order, 180, "qq", true)
    assert.strictEqual(ch.id, "qq")
    ch = L.chooseLyrics([lrclib], order, 180, "qq", true)
    assert.strictEqual(ch.id, "lrclib", "it falls back when the chosen one has nothing")
    // word timing of another song / another cut is not used
    const other = mk("lyricsplus", "word", L.yrcToLrc("[1000,2000](1000,500,0)totally (1500,500,0)different (2000,1000,0)words\n[5000,2000](5000,500,0)nothing (5500,500,0)alike (6000,1000,0)here\n[9000,1500](9000,400,0)at (9400,400,0)all (9800,700,0)friend\n[12000,1500](12000,700,0)really (12700,800,0)not", 0))
    ch = L.chooseLyrics([lrclib, other], order, 180, "auto", true)
    assert.strictEqual(ch.id, "lrclib")
    // only a word-timed one, length known and agreeing: used as it is
    ch = L.chooseLyrics([word], order, 180, "auto", true)
    assert.strictEqual(ch.id, "netease")
    assert.strictEqual(L.chooseLyrics([], order, 180, "auto", true), null)
    // helpers
    assert.strictEqual(L.stripWords("[00:01.000]<00:01.000>Hel<00:01.300>lo<00:02.000>"), "[00:01.000]Hello")
    assert.strictEqual(L.shiftLrc("[00:01.000]<00:01.000>Hel<00:02.000>", 0.8), "[00:01.800]<00:01.800>Hel<00:02.800>")
    assert.strictEqual(L.unescapeEntities("[00:01.00]it&apos;s&#10;[00:02.00]x"), "[00:01.00]it's\n[00:02.00]x")
    const lp = L.lyricsplusToLrc({ lyrics: [{ time: 1000, duration: 2000, text: "Hello world", syllabus: [{ time: 1000, duration: 500, text: "Hello " }, { time: 1500, duration: 1500, text: "world" }] }, { time: 5000, text: "plain line" }] })
    assert.ok(lp.word)
    assert.strictEqual(lp.text, "[00:01.000]<00:01.000>Hello <00:01.500>world<00:03.000>\n[00:05.000]plain line")
    assert.ok(!L.lyricsplusToLrc({ lyrics: [{ time: 1000, text: "only a line" }] }).word)
}
console.log("providers ok")

// ---------- Boidu (TTML), SimpMusic, YouTube Music ----------
{
    const T = new Function(src.replace(/^\.pragma.*$/m, "") + "; return { ttmlToLrc, ttmlTime, parseLrc, foldEchoes, chooseLyrics, simpmusicPick, simpmusicSongs, richSyncToLrc, videoIdOf, ytmLyricsBrowseId, ytmTimedLyrics, ytmSongs, pickWordSong }")()
    // times in both of the forms the API writes
    assert.strictEqual(T.ttmlTime("00:01:30.500"), 90500)
    assert.strictEqual(T.ttmlTime("1:16.656"), 76656)
    assert.strictEqual(T.ttmlTime("12.5"), 12500)
    assert.strictEqual(T.ttmlTime("12.5s"), 12500)
    assert.strictEqual(T.ttmlTime(""), -1)
    assert.strictEqual(T.ttmlTime("abc"), -1)
    // word timing: the space between two spans is a space, syllables join, the backing voice
    // is folded onto the line it is sung over, a translation is left out
    const ttml = '<?xml version="1.0" encoding="UTF-8"?><tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata"><body><div>'
        + '<p begin="00:00:18.234" end="00:00:21.891" ttm:agent="v1"><span begin="00:00:18.234" end="00:00:18.567">The </span><span begin="00:00:18.567" end="00:00:18.901">club </span><span begin="00:00:18.901" end="00:00:19.234">isn&apos;t</span> <span begin="00:00:19.234" end="00:00:19.568">the </span><span begin="00:00:19.568" end="00:00:21.891">best</span><span ttm:role="x-bg"><span begin="0:20.500" end="0:21.500">(ooh)</span></span></p>'
        + '<p begin="1:16.656" end="1:20.000"><span begin="1:16.656" end="1:17.000">Ev</span><span begin="1:17.000" end="1:17.500">ery </span><span begin="1:17.500" end="1:20.000">day</span><span ttm:role="x-translation">hola</span></p>'
        + '</div></body></tt>'
    const got = T.ttmlToLrc(ttml)
    assert.strictEqual(got.word, true)
    let lines = T.foldEchoes(T.parseLrc(got.text))
    assert.deepStrictEqual(lines.map(l => l.text), ["", "The club isn't the best", "Every day"])
    near(lines[1].t, 18.234); near(lines[1].end, 21.891)
    assert.deepStrictEqual(lines[1].marks.map(m => m.cs), [0, 3, 7, 12, 15], "a mark for each word")
    assert.deepStrictEqual(lines[2].marks.map(m => m.cs), [0, 2, 5], "a word cut into syllables keeps one text")
    assert.strictEqual(lines[2].text.indexOf("hola"), -1, "a translation is not a lyric")
    assert.strictEqual(lines[1].bg.text, "(ooh)"); near(lines[1].bg.t, 20.5)
    // line timing only
    const plain = T.ttmlToLrc('<tt><body><div><p begin="0:05.000" end="0:08.000">Just a line</p><p begin="0:09.000" end="0:12.000">Another &amp; line</p></div></body></tt>')
    assert.strictEqual(plain.word, false)
    assert.deepStrictEqual(T.parseLrc(plain.text).filter(l => l.text).map(l => l.text), ["Just a line", "Another & line"])
    assert.deepStrictEqual(T.ttmlToLrc("not xml at all"), { text: "", word: false })
    assert.deepStrictEqual(T.ttmlToLrc(null), { text: "", word: false })

    // chooseLyrics: Boidu is the first of the order, so it wins a tie; a trusted one is used where
    // a synced text of another song-cut reads differently, an untrusted one is not
    const synced = "[00:01.00]completely different words here\n[00:05.00]nothing alike at all\n[00:09.00]third line of other text\n[00:13.00]and one more"
    const mk = (id, kind, text, extra) => Object.assign({ id, kind, text, lines: T.parseLrc(text), duration: 0 }, extra || {})
    const order = ["boidu", "lyricsplus", "lrclib", "youtubemusic", "simpmusic", "netease", "qq", "kugou"]
    let ch = T.chooseLyrics([mk("lrclib", "synced", synced), mk("boidu", "word", got.text, { trusted: true })], order, 0, "auto", true)
    assert.strictEqual(ch.id, "boidu"); assert.strictEqual(ch.kind, "word", "trusted word timing is kept")
    ch = T.chooseLyrics([mk("lrclib", "synced", synced), mk("boidu", "word", got.text)], order, 0, "auto", true)
    assert.strictEqual(ch.id, "lrclib", "an untrusted word-timed text that disagrees with the synced one is not used")
    ch = T.chooseLyrics([mk("boidu", "word", got.text, { trusted: true }), mk("lyricsplus", "word", got.text)], order, 0, "auto", true)
    assert.strictEqual(ch.id, "boidu", "Boidu first when two are as good")
    // a trusted one is NOT moved onto a synced text that agrees with it but sits 1 s later
    const lateSynced = got.text.replace(/<[^>]*>/g, "").split("\n").filter(l => !/\[bg:/.test(l)).map(l => l.replace(/^\[(\d+):(\d+\.\d+)\]/, (m, a, b) => { const t = Number(a) * 60 + Number(b) + 1; return "[" + String(Math.floor(t / 60)).padStart(2, "0") + ":" + (t % 60).toFixed(3).padStart(6, "0") + "]" })).join("\n")
    ch = T.chooseLyrics([mk("lrclib", "synced", lateSynced), mk("boidu", "word", got.text, { trusted: true })], order, 0, "auto", true)
    assert.strictEqual(ch.id, "boidu"); assert.strictEqual(ch.text, got.text, "trusted timing is used as it came")
    ch = T.chooseLyrics([mk("lrclib", "synced", lateSynced), mk("boidu", "word", got.text)], order, 0, "auto", true)
    assert.notStrictEqual(ch.text, got.text, "an untrusted one is still moved onto the synced text")
    ch = T.chooseLyrics([mk("boidu", "synced", "[00:01.00]aaa bbb ccc ddd\n[00:05.00]eee fff ggg hhh\n[00:09.00]iii jjj kkk lll"), mk("lyricsplus", "word", "[00:01.00]<00:01.00>aaa <00:01.50>bbb<00:02.00>\n[00:05.00]<00:05.00>eee <00:05.50>fff<00:06.00>")], order, 0, "auto", false)
    assert.strictEqual(ch.id, "boidu", "with word timing off, the first of the order wins")

    // SimpMusic: the entry cut closest to the track; rich sync when it has it
    const sm = { type: "success", success: true, data: [
        { videoId: "v1", songTitle: "Shape of You", artistName: "Ed Sheeran", durationSeconds: 300, syncedLyrics: "[00:01.00]long cut" },
        { videoId: "v1", songTitle: "Shape of You", artistName: "Ed Sheeran", durationSeconds: 233, syncedLyrics: "[00:01.00]hi\n[00:05.00]there\n[00:09.00]you" }] }
    let pick = T.simpmusicPick(sm, 233)
    assert.strictEqual(pick.word, false); assert.strictEqual(pick.duration, 233); assert.ok(/hi/.test(pick.text))
    assert.strictEqual(T.simpmusicPick(sm, 100), null, "nothing within 4 s of the track's length")
    assert.strictEqual(T.simpmusicPick({ success: false }, 233), null)
    assert.strictEqual(T.simpmusicPick(null, 233), null)
    const rich = [{ ts: 1.0, te: 3.0, l: [{ c: "Hel", o: 0 }, { c: "lo ", o: 0.4 }, { c: "you", o: 1.2 }] }]
    pick = T.simpmusicPick({ data: [{ durationSeconds: 233, syncedLyrics: "[00:01.00]hello you", richSyncLyrics: JSON.stringify(rich) }] }, 233)
    assert.strictEqual(pick.word, true)
    const rl = T.parseLrc(pick.text)[0]
    assert.strictEqual(rl.text, "Hello you"); assert.deepStrictEqual(rl.marks.map(m => m.cs), [0, 3, 5])
    assert.strictEqual(T.richSyncToLrc("not json"), ""); assert.strictEqual(T.richSyncToLrc([{ nope: 1 }]), "")
    const songs = T.simpmusicSongs(sm)
    assert.strictEqual(songs.length, 2); assert.strictEqual(songs[1].duration, 233000)
    assert.strictEqual(T.pickWordSong(songs, "Ed Sheeran", "Shape of You", 233), "v1")

    // the video id in an address
    assert.strictEqual(T.videoIdOf("https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RDAMVM"), "dQw4w9WgXcQ")
    assert.strictEqual(T.videoIdOf("https://www.youtube.com/watch?feature=share&v=dQw4w9WgXcQ"), "dQw4w9WgXcQ")
    assert.strictEqual(T.videoIdOf("https://youtu.be/dQw4w9WgXcQ?t=3"), "dQw4w9WgXcQ")
    assert.strictEqual(T.videoIdOf("https://www.youtube.com/shorts/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
    assert.strictEqual(T.videoIdOf("file:///home/me/music/a.mp3"), "")
    assert.strictEqual(T.videoIdOf("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT"), "")
    assert.strictEqual(T.videoIdOf(undefined), "")

    // YouTube Music's answers
    const next = { contents: { tabs: [{ tabRenderer: { endpoint: { browseEndpoint: { browseId: "MPLYt_abc", browseEndpointContextSupportedConfigs: { browseEndpointContextMusicConfig: { pageType: "MUSIC_PAGE_TYPE_TRACK_LYRICS" } } } } } },
        { tabRenderer: { endpoint: { browseEndpoint: { browseId: "MPTRt_xyz", browseEndpointContextSupportedConfigs: { browseEndpointContextMusicConfig: { pageType: "MUSIC_PAGE_TYPE_TRACK_RELATED" } } } } } }] } }
    assert.strictEqual(T.ytmLyricsBrowseId(next), "MPLYt_abc")
    assert.strictEqual(T.ytmLyricsBrowseId({ contents: {} }), "", "a video with no lyrics tab")
    const cue = (t, e, l) => ({ lyricLine: l, cueRange: { startTimeMilliseconds: String(t), endTimeMilliseconds: String(e) } })
    const browse = { contents: { elementRenderer: { newElement: { type: { componentType: { model: { timedLyricsModel: { lyricsData: { timedLyricsData: [cue(1000, 3000, "one"), cue(6000, 8000, "two"), cue(8000, 9000, "three")] } } } } } } } } }
    const yl = T.parseLrc(T.ytmTimedLyrics(browse))
    assert.deepStrictEqual(yl.filter(l => l.text).map(l => l.text), ["one", "two", "three"])
    near(yl.find(l => l.text === "one").end, 3, 1e-6)
    assert.strictEqual(T.ytmTimedLyrics({ contents: { plain: "just text" } }), "")
    const run = t => ({ text: t })
    const col = runs => ({ musicResponsiveListItemFlexColumnRenderer: { text: { runs } } })
    const search = { contents: [{ musicResponsiveListItemRenderer: { playlistItemData: { videoId: "abcdefghijk" },
        flexColumns: [col([run("Shape of You")]), col([run("Song"), run(" \u2022 "), run("Ed Sheeran"), run(" \u2022 "), run("\u00f7 (Deluxe)"), run(" \u2022 "), run("3:53")])] } }] }
    const ys = T.ytmSongs(search)
    assert.strictEqual(ys.length, 1); assert.strictEqual(ys[0].id, "abcdefghijk"); assert.strictEqual(ys[0].duration, 233000)
    assert.strictEqual(T.pickWordSong(ys, "Ed Sheeran", "Shape of You", 233), "abcdefghijk")
    assert.strictEqual(T.pickWordSong(ys, "Ed Sheeran", "Perfect", 263), null, "another title is not the song")
    assert.deepStrictEqual(T.ytmSongs(null), [])
    console.log("boidu / simpmusic / youtube music ok")
}

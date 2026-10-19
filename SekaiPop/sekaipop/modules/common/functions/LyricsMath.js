.pragma library

// The maths behind the desktop lyrics widget (LyricsWidget.qml / services/LyricsService.qml).
// Pure functions on plain numbers and strings, so it can be unit-tested with node:
// tests/lyrics-test/lyrics_unit.js.
//
//   parseLrc(text)            "[01:23.45] words" lines -> [{ t, text, end?, marks?, bg?, adlib? }],
//                             sorted, with long gaps as "" (see "LRC" below for what each field is)
//   tokens(text)              a line cut into the things the marker hops over; "(ad libs)" are flagged
//   lineUnits / songRate      how much singing a line holds, and how fast THIS song is sung
//   sungSpan(text, room, rate, known)   how long a line takes to sing
//   spans / spansFor          each token's { from, to }, shared out by syllable, or read off word tags
//   foldEchoes(lines)         an ad-lib line stamped while the line before it is still being sung
//                             becomes that line's "sings along" row instead of taking the stage
//   lineIndexAt / cursor      which line is on, and where the scrolling stack is between lines
//   pose(d)                   where / how big / how faint a line that is `d` lines from the middle is
//   leaveAt / overrun / rushOf / hold / takeover / landing
//                             a line that is still being sung when the stack climbs away from it (a
//                             fast entry, a held last word): how far it runs on, how much of a
//                             takeover that is, how long the line is held above the new one, where
//                             it sits while held, and how the line that took over lands
//   wordAt / hop / hit        the bouncing marker and the squash of the word it lands on
//   mainIndexes               the words the marker hops over (ad libs are skipped)
//   cleanTitle / cleanArtist / candidates / pickBest      asking a lyrics service the right question
//   clockReset / observe / estimate / pollTrust           a play clock that sits between the
//                             player's (coarse, late) position reports without wobbling
// ===== LRC =====
// A parsed line is { t, text } and, only when the file says so:
//   end    when its singing stops: a stamp with no words right after it ("[00:14.20]"), or a
//          closing word tag. It is the one thing a plain lyrics file can say about duration.
//   marks  [{ cs, t }] word timing from an enhanced file ("<00:12.40>want"): `cs` is how many
//          characters (not counting spaces and brackets) came before the word.
//   bg     { t, text } a voice that sings along with the line: a second line stamped at the same
//          moment, or a "[bg: ...]" tag. It starts at `t`.
//   adlib  true when the whole line is "(ooh ooh)".

// A stamp with no words that follows a line by less than this is only the end of that
// line (a breath), not an instrumental part worth three diamonds.
var GAP_MIN = 3.5

function parseTime(m, s, f) {
    var t = Number(m) * 60 + Number(s)
    if (f !== undefined && f !== "")
        t += Number(f) / Math.pow(10, f.length)
    return t
}

function squash(s) {
    return String(s).replace(/\s+/g, " ").trim()
}

// "(oh oh)" or "(oh oh) ..." : bracketed ad libs, ASCII or full-width.
function isAdlibLine(text) {
    var s = String(text)
    var rest = s.replace(/\([^)]*\)|\uff08[^\uff09]*\uff09/g, "")
    if (rest === s)
        return false
    return rest.replace(/[\s\u3000.,!?~\-\u2013\u2014\u2026\u3001\u3002\uff01\uff1f\u266a\u266b]+/g, "") === ""
}

// The text of a row cut at its "<mm:ss.xx>" word tags: the words, where each word starts
// (`marks`), and, when the row ends with a tag, where the line ends.
function readBody(body) {
    var re = /<(\d+):(\d{1,2})(?:[.:](\d{1,3}))?>/g
    var text = ""
    var marks = []
    var end = -1
    var curT = null
    var last = 0
    var m
    function add(chunk) {
        var s = chunk.replace(/\s+/g, " ")
        if (text === "" || text.charAt(text.length - 1) === " ")
            s = s.replace(/^ /, "")
        if (s === "")
            return
        if (curT !== null)
            marks.push({ cs: text.replace(/[\s()\uff08\uff09]/g, "").length, t: curT })
        text += s
    }
    while ((m = re.exec(body)) !== null) {
        add(body.slice(last, m.index))
        curT = parseTime(m[1], m[2], m[3])
        last = m.index + m[0].length
    }
    var tail = body.slice(last)
    if (tail.trim() === "" && curT !== null && marks.length > 0)
        end = curT
    else
        add(tail)
    return { text: text.replace(/ $/, ""), marks: marks, end: end }
}

function parseLrc(text) {
    var out = []
    var offset = 0
    var rows = String(text === undefined || text === null ? "" : text).split(/\r?\n/)
    for (var i = 0; i < rows.length; i++) {
        var head = rows[i].match(/^\s*((?:\[[^\]]*\]\s*)+)(.*)$/)
        if (!head)
            continue
        var tagText = head[1]
        var off = tagText.match(/\[offset:\s*([+-]?\d+)\s*\]/i)
        if (off) {
            offset = Number(off[1])
            continue
        }
        var bgTag = tagText.match(/\[bg:\s*([^\]]*)\]/i)
        var bgText = bgTag ? squash(bgTag[1]) : ""
        var body = head[2]
        // the same tag after the words ("[00:05.00]hold me [bg: (ooh)]")
        var inl = body.match(/\[bg:\s*([^\]]*)\]/i)
        if (inl) {
            if (bgText === "")
                bgText = squash(inl[1])
            body = body.replace(/\[bg:\s*[^\]]*\]/gi, " ")
        }
        var read = readBody(body)
        var re = /\[(\d+):(\d{1,2})(?:[.:](\d{1,3}))?\]/g
        var m
        var base = -1
        var stamped = false
        while ((m = re.exec(tagText)) !== null) {
            stamped = true
            var st = parseTime(m[1], m[2], m[3])
            if (base < 0)
                base = st
            var shift = st - base
            var e = { t: st, text: read.text, n: out.length }
            if (read.text !== "") {
                if (read.marks.length > 0) {
                    e.marks = []
                    for (var q = 0; q < read.marks.length; q++)
                        e.marks.push({ cs: read.marks[q].cs, t: read.marks[q].t + shift })
                }
                if (read.end >= 0)
                    e.end = read.end + shift
                if (bgText !== "")
                    e.bg = { t: st, text: bgText }
            } else if (bgText !== "") {
                // a stamp that carries only a [bg: ...] tag is a line of ad libs
                e.text = bgText
                e.adlib = true
            }
            if (e.text !== "" && e.adlib !== true && isAdlibLine(e.text))
                e.adlib = true
            out.push(e)
        }
        // a "[bg: ...]" row with no stamp of its own sings along with the row before it
        if (!stamped && bgText !== "" && out.length > 0 && read.text === "" && !out[out.length - 1].bg)
            out[out.length - 1].bg = { t: out[out.length - 1].t, text: bgText }
    }
    if (out.length === 0)
        return []
    // The offset tag: positive shows the lyrics earlier.
    for (var j = 0; j < out.length; j++) {
        var o = out[j]
        o.t = Math.max(0, o.t - offset / 1000)
        if (o.end !== undefined)
            o.end = Math.max(0, o.end - offset / 1000)
        if (o.bg)
            o.bg.t = Math.max(0, o.bg.t - offset / 1000)
        if (o.marks)
            for (var w = 0; w < o.marks.length; w++)
                o.marks[w].t = Math.max(0, o.marks[w].t - offset / 1000)
    }
    out.sort(function (a, b) { return a.t - b.t || a.n - b.n })

    // Two lines stamped at the same moment: one is sung over the other (an echo, a backing
    // voice). The one that is not in brackets stays the line; the other sings along with it.
    var merged = []
    for (var k = 0; k < out.length; k++) {
        var cur = out[k]
        var p = merged.length > 0 ? merged[merged.length - 1] : null
        if (p && p.text !== "" && cur.text !== "" && Math.abs(cur.t - p.t) <= 0.15) {
            var main = (p.adlib && !cur.adlib) ? cur : p
            var side = main === p ? cur : p
            var joined = (main.bg ? main.bg.text + " " : "") + side.text
            main.bg = { t: Math.max(main.t, side.t), text: joined }
            merged[merged.length - 1] = main
            continue
        }
        merged.push(cur)
    }

    // A gap is a line with no words. Two in a row are one; one that only marks the end of
    // the line before it (it is followed within GAP_MIN) is not shown, but tells how long
    // that line is sung; a long wait before the first line is one too (the intro).
    var lines = []
    for (var a = 0; a < merged.length; a++) {
        var c = merged[a]
        var prev = lines.length > 0 ? lines[lines.length - 1] : null
        if (c.text === "") {
            if (prev && prev.text === "")
                continue
            if (prev && prev.end === undefined && c.t - prev.t > 0.2 && c.t - prev.t <= 12)
                prev.end = c.t
            var nextT = Infinity
            for (var z = a + 1; z < merged.length; z++) {
                if (merged[z].text !== "") {
                    nextT = merged[z].t
                    break
                }
            }
            if (nextT - c.t < GAP_MIN)
                continue
        }
        var line = { t: c.t, text: c.text }
        if (c.end !== undefined)
            line.end = c.end
        if (c.marks)
            line.marks = c.marks
        if (c.bg)
            line.bg = c.bg
        if (c.adlib)
            line.adlib = true
        lines.push(line)
    }
    if (lines.length === 0)
        return []
    if (lines[0].text !== "" && lines[0].t > 3)
        lines.unshift({ t: 0, text: "" })
    return lines
}

// ===== a line, cut up =====

function isCjk(c) {
    return (c >= 0x3040 && c <= 0x30ff) || (c >= 0x3400 && c <= 0x4dbf) || (c >= 0x4e00 && c <= 0x9fff)
        || (c >= 0xf900 && c <= 0xfaff) || (c >= 0xff66 && c <= 0xff9f) || (c >= 0xac00 && c <= 0xd7af)
}

function isMark(c) {
    // Punctuation sticks to the word before it: CJK and full-width marks, and the ASCII ones.
    return (c >= 0x3000 && c <= 0x303f) || (c >= 0xff01 && c <= 0xff0f) || (c >= 0xff1a && c <= 0xff20)
        || c === 0x2026 || c === 0x2014 || c === 0x2019 || c === 0x2018
}

// Words are the things between spaces. Text with no spaces (Japanese, Chinese, Korean) is
// cut into groups of three, so the marker hops once per beat-ish instead of once per
// character. Returns [{ s, gap, adlib? }]: `gap` is true when a space came before it, and
// `adlib` is true for words inside brackets, "(oh oh)", which are sung over or between the
// words of the line rather than being part of its tune; the brackets themselves are dropped.
function tokens(text) {
    var s = String(text === undefined || text === null ? "" : text)
    var out = []
    var cur = ""
    var curCjk = false
    var gap = false
    var paren = false
    function flush() {
        if (cur !== "") {
            var tok = { s: cur, gap: gap }
            if (paren)
                tok.adlib = true
            out.push(tok)
            gap = false
        }
        cur = ""
        curCjk = false
    }
    for (var i = 0; i < s.length; i++) {
        var ch = s.charAt(i)
        var c = s.charCodeAt(i)
        if (ch === "(" || c === 0xff08) {
            flush()
            paren = true
            continue
        }
        if (ch === ")" || c === 0xff09) {
            flush()
            paren = false
            continue
        }
        if (/\s/.test(ch)) {
            flush()
            if (out.length > 0)
                gap = true
            continue
        }
        if (isMark(c) && cur !== "") {
            cur += ch
            continue
        }
        if (isCjk(c)) {
            if (cur !== "" && !curCjk)
                flush()
            cur += ch
            curCjk = true
            // three at a time, unless a lone character would be left over
            var left = 0
            for (var j = i + 1; j < s.length && isCjk(s.charCodeAt(j)); j++)
                left++
            if (cur.length >= 3 && left !== 1 && left !== 0)
                flush()
            continue
        }
        if (curCjk)
            flush()
        cur += ch
    }
    flush()
    return out
}

// ===== how much singing a line holds =====
// A lyrics file only says when a line STARTS. To guess when each word is sung, the time is
// shared out by how much there is to sing: syllables in Latin text, morae in Japanese (a
// kana is one, a kanji about two, a small ya / yu / yo and the like none: they are said
// with the kana before them), one per Hangul block.

function isKana(c) {
    return (c >= 0x3041 && c <= 0x30ff && c !== 0x30fb) || (c >= 0xff66 && c <= 0xff9f)
}

function isSmallKana(c) {
    return c === 0x3041 || c === 0x3043 || c === 0x3045 || c === 0x3047 || c === 0x3049
        || c === 0x3083 || c === 0x3085 || c === 0x3087 || c === 0x308e
        || c === 0x30a1 || c === 0x30a3 || c === 0x30a5 || c === 0x30a7 || c === 0x30a9
        || c === 0x30e3 || c === 0x30e5 || c === 0x30e7 || c === 0x30ee
        || c === 0x3095 || c === 0x3096 || c === 0x30f5 || c === 0x30f6
}

function hasKana(s) {
    for (var i = 0; i < s.length; i++)
        if (isKana(s.charCodeAt(i)))
            return true
    return false
}

// Syllables of a Latin word, near enough: the groups of vowels, less a silent final e
// ("love", "time") and the "ed" that is not a syllable ("kissed"). Never fewer than one.
function latinSyllables(w) {
    var s = String(w).toLowerCase().replace(/[^a-z0-9\u00e0-\u00ff]/g, "")
    if (s === "")
        return 0
    if (/^[0-9]+$/.test(s))
        return s.length
    var groups = s.match(/[aeiouy\u00e0-\u00e6\u00e8-\u00ef\u00f2-\u00f6\u00f9-\u00fc]+/g)
    var n = groups ? groups.length : 0
    if (n > 1 && /[^aeiouy]e$/.test(s) && !/[^aeiouy]le$/.test(s))
        n--
    else if (n > 1 && /[^aeiouydt]ed$/.test(s))
        n--
    return Math.max(1, n)
}

// How many syllables / morae a word holds. `kanjiW`: what a kanji is worth (2 in a line
// that has kana in it, 1 in Chinese).
function wordUnits(s, kanjiW) {
    var str = String(s)
    var total = 0
    var run = ""
    for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i)
        var cjk = isCjk(c)
        if (!cjk) {
            if (!isMark(c))
                run += str.charAt(i)
            continue
        }
        if (run !== "") {
            total += latinSyllables(run)
            run = ""
        }
        if (isSmallKana(c))
            continue
        if (isKana(c) || (c >= 0xac00 && c <= 0xd7af))
            total += 1
        else
            total += kanjiW
    }
    if (run !== "")
        total += latinSyllables(run)
    return total
}

function kanjiWeight(toks) {
    var all = ""
    for (var i = 0; i < toks.length; i++)
        all += toks[i].s
    return hasKana(all) ? 2 : 1
}

// Ad libs ("(oh oh)") are sung over the line or squeezed between its words, so they take
// less of its time than the same number of words would.
var ADLIB_SHARE = 0.6

// The amount of singing in a line, in syllables (a bracketed word counts for less).
function lineUnits(text) {
    var toks = tokens(text)
    var kw = kanjiWeight(toks)
    var total = 0
    for (var i = 0; i < toks.length; i++)
        total += wordUnits(toks[i].s, kw) * (toks[i].adlib ? ADLIB_SHARE : 1)
    return total
}

// What a song is sung at when nothing says otherwise: about four syllables a second.
var DEFAULT_RATE = 4.2

// How fast THIS song is sung, in syllables a second, learned from the lines that say how
// long they are sung: the ones with an end stamp, and the ones another line follows closely
// (those are sung over most of the room before it). The middle one of them, so one slow
// line or one fast rap does not decide it. With fewer than four such lines, the default.
function songRate(lines) {
    var rates = []
    for (var i = 0; i < (lines ? lines.length : 0); i++) {
        var l = lines[i]
        if (!l || l.text === "")
            continue
        var u = lineUnits(l.text)
        if (u < 3)
            continue
        var dur = -1
        if (l.end !== undefined && l.end > l.t) {
            dur = l.end - l.t
        } else {
            var nx = lines[i + 1]
            if (nx && nx.text !== "" && nx.t - l.t >= 0.8 && nx.t - l.t <= 6.5)
                dur = (nx.t - l.t) * 0.92
        }
        if (dur > 0.5 && dur <= 12)
            rates.push(u / dur)
    }
    if (rates.length < 4)
        return DEFAULT_RATE
    rates.sort(function (a, b) { return a - b })
    return Math.max(2.0, Math.min(9.0, rates[rates.length >> 1]))
}

// The next line is stamped before this one could be sung when the room before it is under
// this share of the line's own length at the song's pace: an echo, a quick answer, voices
// that overlap. (A song with lines that follow at once has a pace that fits them, so they
// are not "fast entries": the room is about what the pace says.)
var OVERLAP_BELOW = 0.65

// How far past the next line's stamp a fast-entry line is let run on (seconds).
var MAX_OVERLAP = 1.5

// How long singing the line takes. `known`: the line says itself (an end stamp), taken as
// it is. Otherwise it is the amount of singing at the song's rate, a fifth longer (the last
// note is held), but never more than most (92 %) of the room before the next line, so a line
// that is followed at once is sung right up to it, and a line with a break after it is not
// stretched over the break. A FAST ENTRY (the next stamp is far sooner than this line could
// be sung) is not squeezed into the room: that made its words rush through and the line
// finish at once, out of step with the voice. It takes nearly its own time and runs on a
// little under the next line (which is when the line before keeps its place, see
// LyricsLine.qml).
function sungSpan(text, room, rate, known) {
    var roomOk = isFinite(room) && room > 0
    if (known !== undefined && known > 0)
        return roomOk ? Math.min(known, room + 2) : known
    var r = rate > 0 ? rate : DEFAULT_RATE
    var raw = lineUnits(text) / r
    var want = (raw + 0.25) * 1.2
    if (!roomOk)
        return want
    var span = Math.min(room * 0.92, want)
    if (room < raw * OVERLAP_BELOW)
        span = Math.max(span, Math.min(raw * 0.9, room + MAX_OVERLAP))
    return Math.max(span, Math.min(room, 0.4))
}

// A line of ad libs, "(about you)", that is stamped while the line before it is still being
// sung (before that line's end stamp, or in the first 60 % of the time it takes at the
// song's pace) is an echo of it, not a line of its own: it becomes that line's "sings along"
// row, starting at its own stamp, so it does not take the stage and cut the line short.
function foldEchoes(lines) {
    if (!lines || lines.length < 2)
        return lines || []
    var rate = songRate(lines)
    var out = []
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        var p = out.length > 0 ? out[out.length - 1] : null
        if (l.adlib && p && p.text !== "" && !p.adlib && l.t - p.t >= 0.15) {
            var overlaps = p.end !== undefined
                ? l.t < p.end - 0.3
                : l.t < p.t + 0.6 * lineUnits(p.text) / rate
            if (overlaps) {
                var np = {}
                for (var key in p)
                    np[key] = p[key]
                np.bg = p.bg ? { t: p.bg.t, text: p.bg.text + " " + l.text } : { t: l.t, text: l.text }
                out[out.length - 1] = np
                continue
            }
        }
        out.push(l)
    }
    return out
}

// The share of a line's time each token gets: its syllables (and a little for the breath
// before it), an ad lib's less, and the last word of the line a bit more (it is the one
// that is held).
function tokenWeights(toks) {
    var kw = kanjiWeight(toks)
    var w = []
    var lastMain = -1
    for (var i = 0; i < toks.length; i++) {
        w.push((wordUnits(toks[i].s, kw) + 0.35) * (toks[i].adlib ? ADLIB_SHARE : 1))
        if (!toks[i].adlib)
            lastMain = i
    }
    if (lastMain > 0)
        w[lastMain] *= 1.3
    return w
}

// Splits `dur` seconds from `t0` over the tokens, by their weights.
function spans(toks, t0, dur) {
    var w = tokenWeights(toks)
    var total = 0
    for (var i = 0; i < w.length; i++)
        total += w[i]
    var out = []
    var acc = 0
    for (var k = 0; k < toks.length; k++) {
        out.push({ from: t0 + dur * acc / total, to: t0 + dur * (acc + w[k]) / total })
        acc += w[k]
    }
    return out
}

// The same, but where the file gave word timing ("<00:12.40>want", `marks`) a word starts
// when its tag says so (a word the tags only reach part of the way in is placed between
// the tags either side of it). Without marks it is spans().
function spansFor(toks, t0, dur, marks) {
    if (!marks || marks.length === 0 || toks.length === 0)
        return spans(toks, t0, dur)
    var t1 = t0 + dur
    var starts = []
    var off = 0
    for (var i = 0; i < toks.length; i++) {
        starts.push(off)
        off += toks[i].s.length
    }
    var total = off
    function timeAt(cs) {
        var j = -1
        for (var m = 0; m < marks.length; m++) {
            if (marks[m].cs <= cs)
                j = m
            else
                break
        }
        if (j < 0) {
            var f = marks[0]
            return f.cs > 0 ? t0 + (f.t - t0) * cs / f.cs : t0
        }
        var a = marks[j]
        var nxt = marks[j + 1]
        var bT = Math.max(a.t, nxt ? nxt.t : t1)
        var bC = nxt ? nxt.cs : total
        if (bC <= a.cs)
            return a.t
        return a.t + (bT - a.t) * (cs - a.cs) / (bC - a.cs)
    }
    var out = []
    var prev = t0
    for (var k = 0; k < toks.length; k++) {
        var from = Math.max(prev, timeAt(starts[k]))
        var to = Math.max(from, k + 1 < toks.length ? timeAt(starts[k + 1]) : t1)
        out.push({ from: from, to: to })
        prev = from
    }
    return out
}

// ===== the stack of lines =====

function lineIndexAt(lines, t) {
    var lo = 0
    var hi = lines.length - 1
    var ans = -1
    while (lo <= hi) {
        var mid = (lo + hi) >> 1
        if (lines[mid].t <= t) {
            ans = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return ans
}

function smooth(u) {
    u = Math.max(0, Math.min(1, u))
    return u * u * (3 - 2 * u)
}

// Where the stack is: the index of the line that is on, plus how far the next one has
// climbed into its place. The climb takes the last `lead` seconds before it starts (less for
// a line that is on only briefly). `rush` (0 .. 1, optional) is how much the next line takes
// over a line that is still being sung when it starts (rushOf of how far the line runs on past
// the next one's start): the move is bigger then (the line that is leaving goes higher and
// stays strong), so it gets a little longer to do it in.
function cursor(lines, t, lead, rush) {
    var i = lineIndexAt(lines, t)
    if (i + 1 < lines.length) {
        var nextT = lines[i + 1].t
        // The climb takes at most the last 40 % of the time the line is on: a line that is
        // only on for half a second does not spend most of it leaving.
        var room = i >= 0 ? nextT - lines[i].t : Infinity
        var ahead = rush > 0 ? lead * (1 + RUSH_LEAD * Math.min(1, rush)) : lead
        var ld = Math.min(ahead, Math.max(0.05, room * 0.4))
        if (t > nextT - ld)
            return i + smooth((t - (nextT - ld)) / ld)
    }
    return i
}

var POSES = [
    { d: -2, y: -118, s: 0.42, o: 0, r: 4.8 },
    { d: -1, y: -62, s: 0.58, o: 0.28, r: 2.4 },
    { d: 0, y: 0, s: 1, o: 1, r: 0 },
    { d: 1, y: 68, s: 0.66, o: 0.55, r: -2.4 },
    { d: 2, y: 122, s: 0.46, o: 0, r: -4.8 }
]

// `d` lines from the middle, in between the poses of a table (smooth between two of them,
// flat beyond the ends).
function blend(table, d) {
    if (d <= table[0].d)
        return { y: table[0].y, scale: table[0].s, opacity: table[0].o, rot: table[0].r }
    var last = table[table.length - 1]
    if (d >= last.d)
        return { y: last.y, scale: last.s, opacity: last.o, rot: last.r }
    for (var i = 0; i < table.length - 1; i++) {
        var a = table[i]
        var b = table[i + 1]
        if (d >= a.d && d <= b.d) {
            var u = smooth((d - a.d) / (b.d - a.d))
            return {
                y: a.y + (b.y - a.y) * u,
                scale: a.s + (b.s - a.s) * u,
                opacity: a.o + (b.o - a.o) * u,
                rot: a.r + (b.r - a.r) * u
            }
        }
    }
    return { y: 0, scale: 1, opacity: 1, rot: 0 }
}

// A line `d` lines from the middle (negative = already sung), in between the poses above.
function pose(d) {
    return blend(POSES, d)
}

// ===== a line that is taken over =====
// Some lines are still being sung when the stack starts to climb away from them, or when the
// next one has begun: voices that overlap, a quick answer, a line stamped close behind a long
// one (a fast entry, see sungSpan), or just a last word that is held. Dropping such a line
// into the faded "already sung" slot cut its singing off in mid-word. Instead it is HELD: it
// sits just above the new line, a little smaller, still strong, and goes on singing there;
// once its last word is done it lets go and settles into the faded slot. How much of that a
// line is held (`rush`) is how long it is still being sung once it has to go (from leaveAt);
// how much of a TAKEOVER the next line makes (the longer climb, the swell as it lands) is how
// long it is still being sung once the next line has begun. All of it is worked out from the
// lyrics clock `t`, so a pause or a seek leaves it in the right place.

// When the stack starts to climb away from line `startT` towards the next one, `nextT`: `lead`
// seconds before the next starts (less for a line that is on only briefly), exactly as
// cursor() does it. A line that is still being sung from here on is leaving mid-word.
function leaveAt(startT, nextT, lead) {
    var room = nextT - startT
    return nextT - Math.min(lead, Math.max(0.05, room * 0.4))
}

// How far a line is still being sung past `from` (a time: when it starts to leave, leaveAt, or
// when the next line starts), in seconds; 0 when it has been sung by then. `end` is when it
// has been sung by (the widget's endOf).
function overrun(end, from) {
    if (!isFinite(end) || !isFinite(from))
        return 0
    return Math.max(0, end - from)
}

// Still being sung for less than this once it has to go is nothing; for this long or more it
// is a full takeover. In between the takeover fades in, so nothing flips at a threshold.
var RUSH_FROM = 0.04
var RUSH_FULL = 0.3

// 0 .. 1: how much of a takeover running on by `over` seconds is.
function rushOf(over) {
    return smooth((over - RUSH_FROM) / (RUSH_FULL - RUSH_FROM))
}

// After its last word the line is held a moment (the note rings), then lets go over RELEASE.
var HOLD_TAIL = 0.12
var RELEASE = 0.6

// How much a line is held (0 .. `rush`): full while it is being sung and a moment after, then
// easing off to 0 as it lets go. 0 for a line that is not taken over at all.
function hold(t, end, rush) {
    if (!(rush > 0))
        return 0
    return Math.min(1, rush) * (1 - smooth((t - end - HOLD_TAIL) / RELEASE))
}

// Where a line sits while it is held: the same stack as POSES, but the line that has gone
// (d = -1) stays high and strong, just above the new line, instead of faded. (Higher than
// the faded slot by a little, so the new line's marker, which hops lower while a line is
// held above it, has room.)
var HELD_POSES = [
    { d: -2, y: -118, s: 0.42, o: 0, r: 4.8 },
    { d: -1, y: -76, s: 0.64, o: 0.78, r: 2.4 },
    { d: 0, y: 0, s: 1, o: 1, r: 0 },
    { d: 1, y: 68, s: 0.66, o: 0.55, r: -2.4 },
    { d: 2, y: 122, s: 0.46, o: 0, r: -4.8 }
]

// The pose of a line `d` lines from the middle that is held by `h` (0 .. 1): in between the
// usual pose and the held one. With h = 0 it is exactly pose(d); at d = 0 the two are the
// same, so a line is not moved by being held until the next one starts to take its place.
function takeover(d, h) {
    var a = pose(d)
    if (!(h > 0))
        return a
    var b = blend(HELD_POSES, d)
    var k = Math.min(1, h)
    return {
        y: a.y + (b.y - a.y) * k,
        scale: a.scale + (b.scale - a.scale) * k,
        opacity: a.opacity + (b.opacity - a.opacity) * k,
        rot: a.rot + (b.rot - a.rot) * k
    }
}

// How much longer than the usual lead a full takeover's climb takes (a share of it).
var RUSH_LEAD = 0.3

// The landing of a line that has taken over (`tau`: seconds since it started, `rush`: how
// much of a takeover its entry was): a soft pulse, 0 .. 1 .. 0 over LANDING seconds, that the
// line uses to swell a little as it lands, like the word the marker lands on squashes. It
// starts and ends with no speed at all, so it adds an impact without making anything move
// faster. 0 for an ordinary entry.
var LANDING = 0.38

function landing(tau, rush) {
    if (!(rush > 0) || !(tau > 0) || tau >= LANDING)
        return 0
    var s = Math.sin(Math.PI * tau / LANDING)
    return Math.min(1, rush) * s * s
}

// A line wider than the room is shrunk to fit it, but not past a point.
function fit(naturalW, maxW) {
    if (naturalW <= 0 || naturalW <= maxW)
        return 1
    return Math.max(0.45, maxW / naturalW)
}

// ===== the marker =====

function wordAt(sp, t) {
    var ans = -1
    for (var i = 0; i < sp.length; i++) {
        // (a line's words and their times are swapped one after the other when a new song's
        // lyrics arrive, so for a moment a time can be missing)
        if (sp[i] === undefined)
            break
        if (sp[i].from <= t)
            ans = i
        else
            break
    }
    return ans
}

// How far the marker is on its hop from word k to word k+1 (0 = just landed on k,
// 1 = landing on k+1). The last word has no hop.
function hop(sp, k, t) {
    if (k < 0 || k >= sp.length - 1 || sp[k] === undefined || sp[k + 1] === undefined)
        return 0
    var a = sp[k].from
    var b = sp[k + 1].from
    if (b <= a)
        return 0
    return Math.max(0, Math.min(1, (t - a) / (b - a)))
}

// The arch of a hop: 0 on the ground, 1 at the top.
function arch(p) {
    return 4 * p * (1 - p)
}

// The squash of a word the marker has just landed on: 1 on landing, 0 a moment later.
function hit(sp, k, t) {
    if (k < 0 || k >= sp.length || sp[k] === undefined || t < sp[k].from)
        return 0
    return Math.max(0, 1 - (t - sp[k].from) / 0.22)
}

// How far a word has been sung (0 .. 1).
function sung(span, t) {
    if (span.to <= span.from)
        return t >= span.to ? 1 : 0
    return Math.max(0, Math.min(1, (t - span.from) / (span.to - span.from)))
}

// The ad libs are not part of the tune: the marker hops over the other words only (a
// line that is nothing but ad libs is hopped over whole).
function mainIndexes(toks) {
    var out = []
    var i
    for (i = 0; i < toks.length; i++)
        if (!toks[i].adlib)
            out.push(i)
    if (out.length === 0)
        for (i = 0; i < toks.length; i++)
            out.push(i)
    return out
}

// ===== a play clock =====
// The player reports its position now and then (four times a second here); the clock runs on
// its own between reports. The state is { pos, at, hist, cand }: the clock says `pos` at the
// wall time `at` (ms) and runs from there. `hist` is the last few readings, as the player's
// position minus the wall time, which is the same number all through a steadily playing
// song, and `cand` a reading far off the clock that is waiting to be believed.
//
// What the readings get wrong, they get wrong in ONE direction: a reading is the position
// when the player last worked it out, so it can only be older than the truth (a player that
// moves its position once a second, a busy bus, a slow reply), never newer. So the right
// clock is not the average of the readings (which sags behind by half the lateness and
// jumps about when the lateness does: the lyrics are early, then late, then early) but the
// best one of the last few, the one that was least late. A reading better than the clock
// moves it at once (and a big one is a seek forward); a reading worse than the clock
// is ignored, unless it keeps saying the same thing (a seek back) or is far off.

// How many readings the clock looks back over (two and a half seconds at four a second:
// longer than a player that moves its position once a second takes between moves).
var CLOCK_WINDOW = 10

function clockReset(pos, nowMs) {
    return { pos: pos, at: nowMs, hist: [], cand: null }
}

function estimate(state, nowMs, playing) {
    if (!playing)
        return state.pos
    return state.pos + (nowMs - state.at) / 1000
}

function observe(state, polled, nowMs, playing) {
    if (!playing)
        return { pos: polled, at: nowMs, hist: [], cand: null }
    var o = polled - nowMs / 1000
    var hist = state.hist || []
    if (hist.length === 0)
        return { pos: polled, at: nowMs, hist: [o], cand: null }
    var d = o - (state.pos - state.at / 1000)
    // a seek, either way, by more than a late reading can be: taken at once
    if (Math.abs(d) >= 1.5)
        return { pos: polled, at: nowMs, hist: [o], cand: null }
    if (d < -0.35) {
        // behind the clock: a late reading (a stale one keeps getting later, so it never
        // repeats; a slow reply is gone the next time) or a seek back (it stays where it is):
        // believed when enough in a row agree. A jump back of under 0.8 s is nearly always a
        // late reading and hardly ever a seek, so it takes two seconds of saying the same
        // thing; a bigger one takes three readings.
        var c = state.cand
        var n = (c && Math.abs(o - c.o) < 0.12) ? c.n + 1 : 1
        if (n >= (d > -0.8 ? 8 : 3))
            return { pos: polled, at: nowMs, hist: [o], cand: null }
        return { pos: state.pos, at: state.at, hist: hist, cand: { o: o, n: n } }
    }
    var next = hist.concat([o])
    if (next.length > CLOCK_WINDOW)
        next = next.slice(next.length - CLOCK_WINDOW)
    var best = next[0]
    for (var i = 1; i < next.length; i++)
        if (next[i] > best)
            best = next[i]
    return { pos: best + nowMs / 1000, at: nowMs, hist: next, cand: null }
}

// How far apart the recent readings were, in milliseconds: how much a plain average of them
// would have wobbled. For the debug line.
function clockSpread(state) {
    var h = state && state.hist ? state.hist : []
    if (h.length < 2)
        return 0
    var lo = h[0]
    var hi = h[0]
    for (var i = 1; i < h.length; i++) {
        lo = Math.min(lo, h[i])
        hi = Math.max(hi, h[i])
    }
    return Math.round((hi - lo) * 1000)
}

// Some players (a browser tab, mostly) report a position that does not move while they play.
// Trusting it would pull the clock back to the same spot at every reading. `prev` is the
// last reading, `stale` how many readings in a row were the same while playing. Returns
// whether to use this reading, and the new count: three equal readings in a row while
// playing mean the player's position is not being kept, and the clock runs on its own
// until the position moves again (a seek or a real update).
function pollTrust(prev, polled, stale, playing) {
    if (!playing)
        return { use: true, stale: 0 }
    if (Math.abs(polled - prev) < 0.001) {
        stale = stale + 1
        return { use: stale < 3, stale: stale }
    }
    return { use: true, stale: 0 }
}

// ===== asking a lyrics service =====

function cleanTitle(s) {
    var t = String(s === undefined || s === null ? "" : s)
    var noise = "official|video|audio|lyric|lyrics|mv|m/v|hd|hq|4k|remaster|remastered|music video|visualizer|full ver|short ver|feat|ft\\."
    t = t.replace(new RegExp("\\s*[\\(\\[\\uff08\\u3010][^\\)\\]\\uff09\\u3011]*(?:" + noise + ")[^\\)\\]\\uff09\\u3011]*[\\)\\]\\uff09\\u3011]", "gi"), "")
    t = t.replace(/\s+[-\u2013|]\s*(?:official|lyrics?|audio|video|mv)\b.*$/i, "")
    return t.replace(/\s+/g, " ").trim()
}

function cleanArtist(s) {
    var a = String(s === undefined || s === null ? "" : s)
    a = a.replace(/\s*-\s*Topic$/i, "").replace(/\s*VEVO$/i, "").replace(/\s*Official$/i, "")
    return a.replace(/\s+/g, " ").trim()
}

function firstArtist(s) {
    return String(s).split(/\s*(?:[,;\u00d7&]|\bfeat\.?\b|\bft\.?\b|\bx\b)\s*/i)[0].trim()
}

// The questions to ask, best first: as the player says it, with only the first artist,
// and the "Artist - Title" a video site puts in the title.
function candidates(artist, title) {
    var a = cleanArtist(artist)
    var t = cleanTitle(title)
    var out = []
    function add(x, y) {
        if (y === "")
            return
        for (var i = 0; i < out.length; i++)
            if (out[i].artist === x && out[i].title === y)
                return
        out.push({ artist: x, title: y })
    }
    add(a, t)
    if (a !== "" && firstArtist(a) !== a)
        add(firstArtist(a), t)
    var dash = t.match(/^(.+?)\s+[-\u2013]\s+(.+)$/)
    if (dash)
        add(cleanArtist(dash[1]), cleanTitle(dash[2]))
    return out
}

// Out of a search's results: the one with synced lyrics whose length is closest to the
// track's (within four seconds when the length is known).
function pickBest(results, duration) {
    var best = null
    var bestDiff = 1e9
    for (var i = 0; i < (results ? results.length : 0); i++) {
        var r = results[i]
        if (!r || typeof r.syncedLyrics !== "string" || r.syncedLyrics.trim() === "")
            continue
        var diff = (duration > 0 && typeof r.duration === "number") ? Math.abs(r.duration - duration) : 0
        if (duration > 0 && typeof r.duration === "number" && diff > 4)
            continue
        if (diff < bestDiff) {
            best = r
            bestDiff = diff
        }
    }
    return best
}

// What a track is called in the cache and in "have I just asked for this".
function trackKey(artist, title, length) {
    return (cleanArtist(artist) + "|" + cleanTitle(title)).toLowerCase() + "|" + Math.round(length > 0 ? length : 0)
}

// ===== word timing from a karaoke source =====
// A source that times every word (NetEase's "yrc") says each line as
//   [start_ms,length_ms](start_ms,length_ms,0)word(start_ms,length_ms,0)word ...
// It is turned into the "<mm:ss.xxx>word" form parseLrc already reads, so the words of the
// line are placed by when they are SUNG (spansFor) rather than by their share of the line.

function stampOf(ms) {
    var t = Math.max(0, Math.round(ms))
    var m = Math.floor(t / 60000)
    var s = Math.floor((t % 60000) / 1000)
    var f = t % 1000
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s + "." + (f < 100 ? (f < 10 ? "00" : "0") : "") + f
}

// `shiftS`: seconds added to every time (see alignShift). "" when there is no timed line.
function yrcToLrc(text, shiftS) {
    var shift = Math.round((Number(shiftS) || 0) * 1000)
    var rows = String(text === undefined || text === null ? "" : text).split(/\r?\n/)
    var out = []
    for (var i = 0; i < rows.length; i++) {
        var head = rows[i].match(/^\s*\[(\d+),(\d+)\](.*)$/)
        if (!head)
            continue
        var re = /\((\d+),(\d+),-?\d+\)/g
        var body = head[3]
        var m
        var tags = []
        while ((m = re.exec(body)) !== null)
            tags.push({ at: m.index, len: m[0].length, t: Number(m[1]), d: Number(m[2]) })
        if (tags.length === 0)
            continue
        var line = ""
        var first = -1
        var endT = -1
        var any = false
        for (var k = 0; k < tags.length; k++) {
            var from = tags[k].at + tags[k].len
            var to = k + 1 < tags.length ? tags[k + 1].at : body.length
            var chunk = body.slice(from, to).replace(/[\r\n]/g, "")
            endT = Math.max(endT, tags[k].t + tags[k].d)
            if (chunk.replace(/\s+/g, "") === "") {
                // a space (or nothing) that has a time of its own: it belongs to the word before
                if (line !== "" && chunk !== "")
                    line += " "
                continue
            }
            if (first < 0)
                first = tags[k].t
            line += "<" + stampOf(tags[k].t + shift) + ">" + chunk
            any = true
        }
        if (!any)
            continue
        out.push("[" + stampOf(first + shift) + "]" + line.replace(/\s+$/, "") + "<" + stampOf(endT + shift) + ">")
    }
    return out.join("\n")
}

function medianOf(v) {
    var s = v.slice().sort(function (a, b) { return a - b })
    return s[s.length >> 1]
}

// How many seconds to add to the word-timed lines so they agree with the lines the player's
// own version of the song was given (`ref`, from parseLrc): the middle of how far apart
// each line and the nearest line of the other are. null when they do not agree on where the
// singing is at all (another cut of the song, another song): then the word timing is not used.
function alignShift(words, ref) {
    var w = []
    var r = []
    var i
    for (i = 0; i < (words ? words.length : 0); i++)
        if (words[i].text !== "")
            w.push(words[i].t)
    for (i = 0; i < (ref ? ref.length : 0); i++)
        if (ref[i].text !== "")
            r.push(ref[i].t)
    if (w.length < 3 || r.length < 3)
        return null
    var diffs = []
    for (i = 0; i < w.length; i++) {
        var best = null
        for (var j = 0; j < r.length; j++)
            if (best === null || Math.abs(r[j] - w[i]) < Math.abs(best - w[i]))
                best = r[j]
        if (best !== null && Math.abs(best - w[i]) <= 5)
            diffs.push(best - w[i])
    }
    if (diffs.length < 3 || diffs.length < w.length * 0.6)
        return null
    var med = medianOf(diffs)
    var close = 0
    for (i = 0; i < diffs.length; i++)
        if (Math.abs(diffs[i] - med) <= 0.7)
            close++
    if (close < diffs.length * 0.7 || Math.abs(med) > 4)
        return null
    return Math.abs(med) < 0.05 ? 0 : Math.round(med * 1000) / 1000
}

function letters(s) {
    return String(s).toLowerCase().replace(/[\s\u3000\-_.,'"!?()\[\]\uff08\uff09\u3010\u3011~\u30fb\u00b7&:;\u2019\u2026\u3001\u3002\uff01\uff1f]/g, "")
}

// The share of the first text's letter pairs the second must have too to be "the same words"
// (two cuts of one song differ in punctuation and a word or two, not in a third of it).
var SAME_WORDS = 0.8

// Whether two sets of lines are the same words (a share of the first one's letter pairs that
// the second one has too): a word-timed text of another song must not replace the lyrics.
function sameWords(a, b) {
    var sa = ""
    var sb = ""
    var i
    for (i = 0; i < (a ? a.length : 0); i++)
        sa += letters(a[i].text)
    for (i = 0; i < (b ? b.length : 0); i++)
        sb += letters(b[i].text)
    if (sa.length < 8 || sb.length < 8)
        return false
    var have = {}
    for (i = 0; i + 1 < sb.length; i++)
        have[sb.substr(i, 2)] = true
    var hit = 0
    var n = 0
    for (i = 0; i + 1 < sa.length; i++) {
        n++
        if (have[sa.substr(i, 2)])
            hit++
    }
    return n > 0 && hit / n >= SAME_WORDS
}

// The song's id out of a NetEase search (`songs`): the title has to match, the artist counts,
// and the length must be within three seconds of the track's when that is known. null if none.
function pickWordSong(songs, artist, title, lengthS) {
    var wantT = letters(cleanTitle(title))
    var wantA = letters(firstArtist(cleanArtist(artist)))
    var best = null
    var bestScore = 0
    for (var i = 0; i < (songs ? songs.length : 0); i++) {
        var s = songs[i]
        if (!s || s.id === undefined)
            continue
        var name = letters(cleanTitle(s.name || ""))
        var score = 0
        if (name !== "" && name === wantT)
            score += 4
        else if (name !== "" && wantT !== "" && (name.indexOf(wantT) >= 0 || wantT.indexOf(name) >= 0))
            score += 2
        if (score === 0)
            continue
        var names = s.artists || s.ar || []
        for (var k = 0; k < names.length; k++) {
            var an = letters(names[k] && names[k].name ? names[k].name : "")
            if (wantA !== "" && an !== "" && (an.indexOf(wantA) >= 0 || wantA.indexOf(an) >= 0)) {
                score += 2
                break
            }
        }
        var dur = Number(s.duration || s.dt || 0) / 1000
        if (lengthS > 0 && dur > 0) {
            var d = Math.abs(dur - lengthS)
            if (d > 3)
                continue
            score += d <= 1.5 ? 2 : 1
        }
        if (score > bestScore) {
            best = s.id
            bestScore = score
        }
    }
    return best
}

// ===== several providers, the best one for each song =====

// "&#10;" and "&apos;" in a lyric a service sent as HTML text.
function unescapeEntities(s) {
    return String(s === undefined || s === null ? "" : s)
        .replace(/&#(\d+);/g, function (m, n) { return String.fromCharCode(Number(n)) })
        .replace(/&apos;/g, "'").replace(/&quot;/g, "\"").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&")
}

// Every "[mm:ss.xx]" and "<mm:ss.xx>" stamp of a text moved by `shiftS` seconds.
function shiftLrc(text, shiftS) {
    var d = Math.round((Number(shiftS) || 0) * 1000)
    if (d === 0)
        return String(text)
    return String(text).replace(/([\[<])(\d+):(\d{1,2})(?:[.:](\d{1,3}))?([\]>])/g, function (all, o, m, s, f, c) {
        return o + stampOf(parseTime(m, s, f) * 1000 + d) + c
    })
}

// The same lyrics with the word tags taken out: line timing only.
function stripWords(text) {
    return String(text).replace(/<\d+:\d{1,2}(?:[.:]\d{1,3})?>/g, "")
}

// One line out of timed pieces ({t, d, text} in ms): "[start]<t>piece<t>piece<end>".
function wordRow(chunks, shiftS) {
    var shift = Math.round((Number(shiftS) || 0) * 1000)
    var line = ""
    var first = -1
    var endT = -1
    for (var k = 0; k < chunks.length; k++) {
        var c = chunks[k]
        var text = String(c.text === undefined || c.text === null ? "" : c.text).replace(/[\r\n]/g, "")
        endT = Math.max(endT, c.t + (c.d > 0 ? c.d : 0))
        if (text.replace(/\s+/g, "") === "") {
            if (line !== "" && text !== "")
                line += " "
            continue
        }
        if (first < 0)
            first = c.t
        line += "<" + stampOf(c.t + shift) + ">" + text
    }
    if (first < 0)
        return ""
    return "[" + stampOf(first + shift) + "]" + line.replace(/\s+$/, "") + "<" + stampOf(Math.max(endT, first) + shift) + ">"
}

// LyricsPlus (a service that has word timing of Apple Music and Musixmatch):
//   { lyrics: [ { time, duration, text, syllabus: [ { time, duration, text } ] } ] }  (ms)
// -> { text, word } ; word is true when any line is timed by its words.
function lyricsplusToLrc(o) {
    var rows = o && o.lyrics
    var out = []
    var word = false
    for (var i = 0; i < (rows ? rows.length : 0); i++) {
        var r = rows[i]
        if (!r || typeof r.time !== "number")
            continue
        var sy = r.syllabus
        if (sy && sy.length > 0) {
            var chunks = []
            for (var k = 0; k < sy.length; k++)
                if (sy[k] && typeof sy[k].time === "number")
                    chunks.push({ t: sy[k].time, d: Number(sy[k].duration) || 0, text: sy[k].text })
            var row = wordRow(chunks, 0)
            if (row !== "") {
                out.push(row)
                word = true
                continue
            }
        }
        var txt = squash(r.text === undefined || r.text === null ? "" : r.text)
        if (txt !== "")
            out.push("[" + stampOf(r.time) + "]" + txt)
    }
    return { text: out.join("\n"), word: word }
}

// ===== Better Lyrics ("Boidu"), SimpMusic and YouTube Music =====

// A time out of a TTML file -- "HH:MM:SS.mmm", "M:SS.mmm", "SS.mmm" or "12.5s" -- in ms;
// -1 when it is none of those.
function ttmlTime(s) {
    var str = String(s === undefined || s === null ? "" : s).trim()
    if (str === "")
        return -1
    var sec = str.match(/^(\d+(?:\.\d+)?)s$/)
    if (sec)
        return Math.round(Number(sec[1]) * 1000)
    var parts = str.split(":")
    var v = 0
    for (var i = 0; i < parts.length; i++) {
        var n = Number(parts[i])
        if (!isFinite(n) || n < 0)
            return -1
        v = v * 60 + n
    }
    return Math.round(v * 1000)
}

// The value of attribute `name` in the inside of a tag ("" when it has none).
function ttmlAttr(tag, name) {
    var m = String(tag).match(new RegExp("(?:^|\\s)" + name + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')"))
    return m ? (m[1] !== undefined ? m[1] : m[2]) : ""
}

// The space between two timed spans (the file has no tag there, only the space itself).
function ttmlGap(list) {
    if (list.length === 0)
        return
    var last = list[list.length - 1]
    list.push({ t: last.t + (last.d > 0 ? last.d : 0), d: 0, text: " " })
}

// Better Lyrics (lyrics-api.boidu.dev / api.betterlyrics.org) answers with TTML, Apple Music's
// format: <p begin end> is a line, a <span begin end> inside it a word or a syllable (the space
// between two spans is a space of the text, so the file must not be pretty-printed),
// <span ttm:role="x-bg"> holds the backing voice. Read with regular expressions: the JS of QML
// has no DOMParser. -> { text, word } in the "[mm:ss.xxx]<mm:ss.xxx>word ..." form parseLrc
// reads; `word` is true when any line is timed by its words. The backing voice becomes a
// "[start][bg: ...]" row, which foldEchoes puts on the line it is sung over. Translations and
// romanizations (other ttm:roles) are left out.
function ttmlToLrc(ttml) {
    var src = String(ttml === undefined || ttml === null ? "" : ttml)
    var out = []
    var word = false
    var pre = /<p\b([^>]*)>([\s\S]*?)<\/p>/g
    var pm
    while ((pm = pre.exec(src)) !== null) {
        var pBegin = ttmlTime(ttmlAttr(pm[1], "begin"))
        var main = []
        var back = []
        var plain = ""
        var stack = []
        var tre = /<(\/?)([A-Za-z][\w:.\-]*)([^>]*?)(\/?)>|([^<]+)/g
        var tm
        var k
        while ((tm = tre.exec(pm[2])) !== null) {
            var top = stack.length > 0 ? stack[stack.length - 1] : null
            if (tm[5] !== undefined) {
                if (top && top.skip)
                    continue
                var txt = unescapeEntities(tm[5])
                var timed = null
                for (var q = stack.length - 1; q >= 0; q--) {
                    if (stack[q].timed) {
                        timed = stack[q]
                        break
                    }
                }
                if (timed)
                    timed.text += txt
                else if (/^\s*$/.test(txt))
                    ttmlGap(top && top.bg ? back : main)
                else if (stack.length === 0)
                    plain += txt
                continue
            }
            var name = tm[2].toLowerCase()
            if (name === "br") {
                ttmlGap(top && top.bg ? back : main)
                continue
            }
            if (name !== "span")
                continue
            if (tm[1] === "/") {
                var done = stack.pop()
                if (done && done.timed && !done.skip)
                    (done.bg ? back : main).push({ t: done.t, d: done.d, text: done.text })
                continue
            }
            if (tm[4] === "/")
                continue
            var role = ttmlAttr(tm[3], "ttm:role")
            var b = ttmlTime(ttmlAttr(tm[3], "begin"))
            var e = ttmlTime(ttmlAttr(tm[3], "end"))
            stack.push({
                timed: b >= 0,
                bg: role === "x-bg" || (top !== null && top.bg),
                skip: (top !== null && top.skip) || (role !== "" && role !== "x-bg"),
                t: b,
                d: (b >= 0 && e >= b) ? e - b : 0,
                text: ""
            })
        }
        var row = ""
        var hasWords = false
        for (k = 0; k < main.length; k++)
            if (main[k].text.replace(/\s+/g, "") !== "")
                hasWords = true
        if (hasWords) {
            row = wordRow(main, 0)
            if (row !== "")
                word = true
        } else if (squash(plain) !== "" && pBegin >= 0) {
            row = "[" + stampOf(pBegin) + "]" + squash(plain)
        }
        if (row !== "")
            out.push(row)
        var bt = ""
        var bFirst = -1
        for (k = 0; k < back.length; k++) {
            if (back[k].text.replace(/\s+/g, "") !== "") {
                if (bFirst < 0)
                    bFirst = back[k].t
                bt += back[k].text
            } else if (bt !== "") {
                bt += " "
            }
        }
        bt = squash(bt.replace(/[\[\]]/g, ""))
        var bStart = bFirst >= 0 ? bFirst : pBegin
        if (bt !== "" && bStart >= 0)
            out.push("[" + stampOf(bStart) + "][bg: " + bt + "]")
    }
    return { text: out.join("\n"), word: word }
}

// A word-timed text in Musixmatch's "rich sync" shape, [ { ts, te, l: [ { c, o } ] } ] (seconds;
// `o` is when the piece `c` starts, after `ts`), as the array or as JSON text -> the same
// "[start]<t>piece<t>piece<end>" rows. "" when it is not that.
function richSyncToLrc(v) {
    var arr = v
    if (typeof v === "string") {
        try {
            arr = JSON.parse(v)
        } catch (e) {
            return ""
        }
    }
    if (!Array.isArray(arr))
        return ""
    var out = []
    for (var i = 0; i < arr.length; i++) {
        var r = arr[i]
        if (!r || typeof r.ts !== "number" || !Array.isArray(r.l))
            continue
        var chunks = []
        for (var k = 0; k < r.l.length; k++) {
            var w = r.l[k]
            if (!w || typeof w.c !== "string")
                continue
            chunks.push({ t: Math.round((r.ts + (Number(w.o) || 0)) * 1000), d: 0, text: w.c })
        }
        for (var n = 0; n < chunks.length; n++) {
            var until = n + 1 < chunks.length ? chunks[n + 1].t : (typeof r.te === "number" ? Math.round(r.te * 1000) : chunks[n].t)
            chunks[n].d = Math.max(0, until - chunks[n].t)
        }
        var row = wordRow(chunks, 0)
        if (row !== "")
            out.push(row)
    }
    return out.join("\n")
}

// SimpMusic (a community database keyed by YouTube video id) answers
//   { success, data: [ { songTitle, artistName, durationSeconds, syncedLyrics, richSyncLyrics, ... } ] }
// -> { text, word, duration } of the entry that has synced lyrics and is cut closest to the
// track's length (within 4 s when both are known); the word-timed text of an entry when it has
// one. null when none.
function simpmusicPick(o, lengthS) {
    var list = o && Array.isArray(o.data) ? o.data : (o && o.data && typeof o.data === "object" ? [o.data] : [])
    var best = null
    var bestDiff = 1e9
    for (var i = 0; i < list.length; i++) {
        var r = list[i]
        if (!r || typeof r !== "object")
            continue
        var dur = Number(r.durationSeconds !== undefined ? r.durationSeconds : r.duration) || 0
        var diff = (lengthS > 0 && dur > 0) ? Math.abs(dur - lengthS) : 0
        if (lengthS > 0 && dur > 0 && diff > 4)
            continue
        var rich = richSyncToLrc(r.richSyncLyrics)
        var text = rich !== "" ? rich : (typeof r.syncedLyrics === "string" ? r.syncedLyrics : "")
        if (parseLrc(text).length === 0)
            continue
        if (diff < bestDiff) {
            best = { text: text, word: rich !== "", duration: dur }
            bestDiff = diff
        }
    }
    return best
}

// The songs of a SimpMusic search, in the shape pickWordSong reads (id = the video id).
function simpmusicSongs(o) {
    var list = o && Array.isArray(o.data) ? o.data : []
    var out = []
    for (var i = 0; i < list.length; i++) {
        var r = list[i]
        if (!r || typeof r.videoId !== "string" || r.videoId === "")
            continue
        out.push({
            id: r.videoId,
            name: r.songTitle || "",
            artists: [{ name: r.artistName || "" }],
            duration: (Number(r.durationSeconds !== undefined ? r.durationSeconds : r.duration) || 0) * 1000
        })
    }
    return out
}

// The YouTube video id in a track's address ("" when it is not a YouTube one).
function videoIdOf(url) {
    var u = String(url === undefined || url === null ? "" : url)
    if (!/youtube\.com|youtu\.be/i.test(u))
        return ""
    var m = u.match(/[?&]v=([A-Za-z0-9_-]{11})(?:[&#]|$)/)
        || u.match(/youtu\.be\/([A-Za-z0-9_-]{11})/)
        || u.match(/\/(?:shorts|embed|live)\/([A-Za-z0-9_-]{11})/)
    return m ? m[1] : ""
}

// Every value of `key` in a parsed JSON, in document order (at most `limit` when it is given):
// YouTube's answers are deep and their layout changes, so what is wanted is looked for by name.
function jsonFind(root, key, limit) {
    var found = []
    var stack = [root]
    var seen = 0
    while (stack.length > 0 && seen < 300000) {
        var o = stack.pop()
        seen++
        if (o === null || typeof o !== "object")
            continue
        var i
        if (Array.isArray(o)) {
            for (i = o.length - 1; i >= 0; i--)
                if (o[i] !== null && typeof o[i] === "object")
                    stack.push(o[i])
            continue
        }
        if (o[key] !== undefined) {
            found.push(o[key])
            if (limit > 0 && found.length >= limit)
                break
        }
        var keys = Object.keys(o)
        for (i = keys.length - 1; i >= 0; i--)
            if (o[keys[i]] !== null && typeof o[keys[i]] === "object")
                stack.push(o[keys[i]])
    }
    return found
}

// YouTube Music's /next answer for a video: the id of its lyrics tab ("" when it has none).
function ytmLyricsBrowseId(j) {
    var eps = jsonFind(j, "browseEndpoint")
    for (var i = 0; i < eps.length; i++) {
        var ep = eps[i]
        var cfg = ep ? ep.browseEndpointContextSupportedConfigs : null
        var pt = cfg && cfg.browseEndpointContextMusicConfig ? cfg.browseEndpointContextMusicConfig.pageType : ""
        if (pt === "MUSIC_PAGE_TYPE_TRACK_LYRICS" && typeof ep.browseId === "string" && ep.browseId !== "")
            return ep.browseId
    }
    return ""
}

// The lyrics tab's /browse answer: its timed lines as "[mm:ss.xxx]words" ("" when it has only
// plain text, or none). A short silence after a line is marked with an empty row, which is how
// parseLrc learns when the line ends.
function ytmTimedLyrics(j) {
    var models = jsonFind(j, "timedLyricsModel", 1)
    var data = models.length > 0 && models[0] && models[0].lyricsData ? models[0].lyricsData.timedLyricsData : null
    if (!Array.isArray(data))
        return ""
    var rows = []
    for (var i = 0; i < data.length; i++) {
        var d = data[i]
        var cue = d && d.cueRange ? d.cueRange : null
        if (!cue)
            continue
        var st = Number(cue.startTimeMilliseconds)
        if (!isFinite(st))
            continue
        var en = Number(cue.endTimeMilliseconds)
        rows.push({ t: st, end: isFinite(en) ? en : -1, text: squash(d.lyricLine === undefined || d.lyricLine === null ? "" : d.lyricLine) })
    }
    var out = []
    for (var k = 0; k < rows.length; k++) {
        out.push("[" + stampOf(rows[k].t) + "]" + rows[k].text)
        var next = k + 1 < rows.length ? rows[k + 1].t : Infinity
        if (rows[k].text !== "" && rows[k].end > rows[k].t + 200 && next - rows[k].end > 500)
            out.push("[" + stampOf(rows[k].end) + "]")
    }
    return out.join("\n")
}

// The text runs of one column of a YouTube Music search row.
function ytmRuns(c) {
    var r = c && c.musicResponsiveListItemFlexColumnRenderer && c.musicResponsiveListItemFlexColumnRenderer.text
        ? c.musicResponsiveListItemFlexColumnRenderer.text.runs : null
    return Array.isArray(r) ? r : []
}

// YouTube Music's search answer as songs for pickWordSong: { id (video id), name, artists, duration }.
function ytmSongs(j) {
    var items = jsonFind(j, "musicResponsiveListItemRenderer")
    var out = []
    for (var i = 0; i < items.length; i++) {
        var it = items[i]
        if (!it || typeof it !== "object")
            continue
        var vid = it.playlistItemData && typeof it.playlistItemData.videoId === "string" ? it.playlistItemData.videoId : ""
        if (vid === "") {
            var w = jsonFind(it, "watchEndpoint", 1)
            if (w.length > 0 && w[0] && typeof w[0].videoId === "string")
                vid = w[0].videoId
        }
        if (vid === "")
            continue
        var cols = Array.isArray(it.flexColumns) ? it.flexColumns : []
        var title = ytmRuns(cols[0]).map(function (r) { return r && r.text ? r.text : "" }).join("")
        var meta = ytmRuns(cols[1])
        var names = []
        var dur = 0
        for (var m = 0; m < meta.length; m++) {
            var tx = meta[m] && typeof meta[m].text === "string" ? meta[m].text : ""
            var tmatch = tx.match(/^(?:(\d+):)?(\d{1,2}):(\d{2})$/)
            if (tmatch)
                dur = (Number(tmatch[1] || 0) * 3600 + Number(tmatch[2]) * 60 + Number(tmatch[3])) * 1000
            else if (tx.replace(/[\s\u2022]/g, "") !== "")
                names.push({ name: tx })
        }
        out.push({ id: vid, name: title, artists: names, duration: dur })
    }
    return out
}

// Out of what the providers found (each { id, kind: "word" | "synced", text, lines, duration })
// the one to show. `order`: the provider ids, best liked first. `lengthS`: the track's length.
//  - a word-timed one wins over a synced one; between the same kind, the one cut to the
//    track's length (within 1.5 s, or no length known), then the one liked best;
//  - a word-timed one is only used when it is the same text as a synced one and agrees with
//    its timing (it is shifted to it), or, with no synced one at all, when it is not of another
//    length than the track's;
//  - `preferred` (not "auto"): that provider's, if it has something usable.
// Returns { id, kind, text } or null.
function chooseLyrics(results, order, lengthS, preferred, wordsOn) {
    var rank = {}
    for (var i = 0; i < order.length; i++)
        rank[order[i]] = i
    var list = []
    for (i = 0; i < (results ? results.length : 0); i++)
        if (results[i] && results[i].lines && results[i].lines.length > 0)
            list.push(results[i])
    function close(r) {
        return !(lengthS > 0 && r.duration > 0 && Math.abs(r.duration - lengthS) > 1.5)
    }
    function better(a, b) {
        var ka = a.kind === "word" ? 0 : 1
        var kb = b.kind === "word" ? 0 : 1
        if (ka !== kb)
            return ka - kb
        var ca = close(a) ? 0 : 1
        var cb = close(b) ? 0 : 1
        if (ca !== cb)
            return ca - cb
        return (rank[a.id] === undefined ? 99 : rank[a.id]) - (rank[b.id] === undefined ? 99 : rank[b.id])
    }
    var synced = list.filter(function (r) { return r.kind !== "word" }).sort(better)
    var ref = synced.length > 0 ? synced[0].lines : null
    var usable = []
    for (i = 0; i < list.length; i++) {
        var r = list[i]
        var u = { id: r.id, kind: "synced", duration: r.duration, text: r.text }
        if (r.kind === "word" && !wordsOn) {
            u.text = stripWords(r.text)
        } else if (r.kind === "word") {
            var shift = 0
            if (r.trusted === true) {
                // a trusted provider (Boidu, when it is sure of its match) keeps its own timing as
                // it is: it is not moved onto the synced text of another provider, whose lines may
                // be off by a little themselves
            } else if (ref) {
                if (!sameWords(ref, r.lines))
                    continue
                shift = alignShift(r.lines, ref)
                if (shift === null)
                    continue
            } else if (!close(r)) {
                continue
            }
            u.kind = "word"
            u.text = shiftLrc(r.text, shift)
        }
        usable.push(u)
    }
    if (usable.length === 0)
        return null
    usable.sort(better)
    var pick = usable[0]
    if (preferred && preferred !== "auto")
        for (i = 0; i < usable.length; i++)
            if (usable[i].id === preferred)
                pick = usable[i]
    return { id: pick.id, kind: pick.kind, text: pick.text }
}

// node tests/calendar-test/events_unit.js   (run from the sekaipop folder)
// The rules of the desktop calendar card's events (EventMath.js): what counts as an
// event, times and dates typed by hand, the "Coming up" order, deadline states, the
// words on the chips, and what a month-grid cell shows. QML can't run here, so the
// last block reads the widget / service sources for the wiring that can't be seen otherwise.
const fs = require("fs"), assert = require("assert")
const locate = require("../lib/locate.js")
const src = fs.readFileSync(locate("modules/common/functions/EventMath.js"), "utf8").replace(".pragma library", "")
const E = new Function(src + "; return { clean, parseAll, parseDate, normalizeTime, timeText, newId, compare, sorted, byDay, diffTo, dueState, countdown, upcoming, monthSummary, dayMarks, changed, keyOf, MAX_EVENTS }")()

const today = new Date(2026, 9, 13)   // Tuesday 13 Oct 2026
const ev = (o) => Object.assign({ id: "x", title: "T", date: "2026-10-13", time: "", note: "", color: 0, kind: "event", done: false }, o)

// 1. dates: real days only
assert.deepStrictEqual(E.parseDate("2026-10-23"), { y: 2026, m: 9, d: 23 })
assert.strictEqual(E.parseDate("2026-02-30"), null)
assert.strictEqual(E.parseDate("2028-02-29").d, 29)       // a leap day
assert.strictEqual(E.parseDate("2027-02-29"), null)
assert.strictEqual(E.parseDate("23/10/2026"), null)
assert.strictEqual(E.parseDate(""), null)
assert.strictEqual(E.keyOf(today), "2026-10-13")
console.log("ok  dates: real days only, leap days, keys agree with CalendarMath.dayKey")

// 2. times typed by hand
const t = E.normalizeTime
assert.strictEqual(t("14:00"), "14:00")
assert.strictEqual(t("9:30"), "09:30")
assert.strictEqual(t("0930"), "09:30")
assert.strictEqual(t("930"), "09:30")
assert.strictEqual(t("9"), "09:00")
assert.strictEqual(t(""), "")
assert.strictEqual(t("   "), "")
assert.strictEqual(t(undefined), "")
assert.strictEqual(t("24:00"), null)
assert.strictEqual(t("12:60"), null)
assert.strictEqual(t("noon"), null)
assert.strictEqual(E.timeText("14:05", true), "14:05")
assert.strictEqual(E.timeText("14:05", false), "2:05 PM")
assert.strictEqual(E.timeText("00:15", false), "12:15 AM")
assert.strictEqual(E.timeText("12:00", false), "12:00 PM")
assert.strictEqual(E.timeText("", true), "All day")
console.log("ok  times: forms accepted, nonsense refused, 12 h / 24 h text")

// 3. what an event is
assert.strictEqual(E.clean(null), null)
assert.strictEqual(E.clean({ title: "  ", date: "2026-10-13" }), null)
assert.strictEqual(E.clean({ title: "a", date: "2026-13-01" }), null)
let c = E.clean({ title: "  Live \n rehearsal  ", date: "2026-10-23", time: "99:99", color: 9, kind: "weird", done: true })
assert.strictEqual(c.title, "Live rehearsal")
assert.strictEqual(c.time, "")            // a bad time is all-day, the event survives
assert.strictEqual(c.color, 0)
assert.strictEqual(c.kind, "event")
assert.strictEqual(c.done, false)         // only a deadline can be done
c = E.clean({ title: "Report", date: "2026-10-30", kind: "deadline", done: true, color: 3 })
assert.strictEqual(c.done, true)
assert.strictEqual(c.color, 3)
assert.strictEqual(E.clean({ title: "x".repeat(200), date: "2026-10-13" }).title.length, 80)
assert.strictEqual(E.clean({ title: "a", date: "2026-10-13", note: "n".repeat(500) }).note.length, 240)
console.log("ok  clean: needs a title and a real day; bad time / colour / kind fall back")

// 4. a saved list
let all = E.parseAll([
    { id: "a", title: "one", date: "2026-10-13" },
    { id: "a", title: "two", date: "2026-10-14" },          // same id: given a new one
    { title: "three", date: "2026-10-15" },                   // no id
    { title: "", date: "2026-10-15" },                        // not an event: dropped
    "junk", null, 5,
    { id: "e1", title: "four", date: "2026-10-16" }
])
assert.strictEqual(all.length, 4)
assert.strictEqual(new Set(all.map(x => x.id)).size, 4)
assert.deepStrictEqual(all.map(x => x.title), ["one", "two", "three", "four"])
assert.deepStrictEqual(E.parseAll("nope"), [])
assert.deepStrictEqual(E.parseAll(undefined), [])
const many = []
for (let i = 0; i < E.MAX_EVENTS + 50; i++) many.push({ title: "e" + i, date: "2026-10-13" })
assert.strictEqual(E.parseAll(many).length, E.MAX_EVENTS)
assert.strictEqual(E.newId([{ id: "e1" }, { id: "e2" }]), "e3")
assert.strictEqual(E.newId([{ id: "e2" }]), "e3")
assert.strictEqual(E.newId([]), "e1")
console.log("ok  parseAll: junk dropped, ids unique, capped; newId never repeats")

// 5. order: date, all-day first, time, title
const order = E.sorted([
    ev({ id: "5", title: "b", date: "2026-10-14", time: "09:00" }),
    ev({ id: "1", title: "z", date: "2026-10-13", time: "18:00" }),
    ev({ id: "2", title: "a", date: "2026-10-13", time: "" }),
    ev({ id: "3", title: "B", date: "2026-10-14", time: "09:00" }),
    ev({ id: "4", title: "a", date: "2026-10-13", time: "08:00" })
]).map(x => x.id)
assert.deepStrictEqual(order, ["2", "4", "1", "3", "5"])
const grouped = E.byDay([ev({ id: "1", date: "2026-10-14" }), ev({ id: "2", date: "2026-10-13" }), ev({ id: "3", date: "2026-10-14", time: "08:00" })])
assert.deepStrictEqual(Object.keys(grouped).sort(), ["2026-10-13", "2026-10-14"])
assert.deepStrictEqual(grouped["2026-10-14"].map(x => x.id), ["1", "3"])
console.log("ok  order and per-day grouping")

// 6. day differences, across a daylight-saving change too
assert.strictEqual(E.diffTo(today, "2026-10-13"), 0)
assert.strictEqual(E.diffTo(today, "2026-10-14"), 1)
assert.strictEqual(E.diffTo(today, "2026-10-12"), -1)
assert.strictEqual(E.diffTo(today, "2026-11-13"), 31)
assert.strictEqual(E.diffTo(new Date(2026, 2, 28), "2026-03-30"), 2)
assert.strictEqual(E.diffTo(new Date(2026, 9, 31), "2026-11-02"), 2)
assert.ok(Number.isNaN(E.diffTo(today, "soon")))
console.log("ok  diffTo: whole days, DST-proof, NaN for junk")

// 7. deadline states and the chip words
const dl = (o) => ev(Object.assign({ kind: "deadline" }, o))
assert.strictEqual(E.dueState(ev({}), 0), "event")
assert.strictEqual(E.dueState(dl({ done: true }), -5), "done")
assert.strictEqual(E.dueState(dl({}), -1), "overdue")
assert.strictEqual(E.dueState(dl({}), 0), "today")
assert.strictEqual(E.dueState(dl({}), 1), "soon")
assert.strictEqual(E.dueState(dl({}), 3), "soon")
assert.strictEqual(E.dueState(dl({}), 4), "later")
assert.strictEqual(E.countdown(ev({}), 0), "Today")
assert.strictEqual(E.countdown(ev({}), 1), "Tomorrow")
assert.strictEqual(E.countdown(ev({}), 5), "in 5 days")
assert.strictEqual(E.countdown(ev({}), -1), "Yesterday")
assert.strictEqual(E.countdown(ev({}), -3), "3 days ago")
assert.strictEqual(E.countdown(dl({}), -1), "1 day late")
assert.strictEqual(E.countdown(dl({}), -4), "4 days late")
assert.strictEqual(E.countdown(dl({ done: true }), -4), "Done")
assert.strictEqual(E.countdown(ev({}), 30), "in 4 weeks")
assert.strictEqual(E.countdown(ev({}), 200), "in 7 months")
console.log("ok  deadline states and countdown words")

// 8. "Coming up": late open deadlines first, then from today, done ones left out
const list = [
    ev({ id: "past", date: "2026-10-01" }),                                   // a past event: not listed
    dl({ id: "late2", date: "2026-10-09" }),
    dl({ id: "late1", date: "2026-10-05" }),
    dl({ id: "lateDone", date: "2026-10-06", done: true }),                   // ticked off: not listed
    ev({ id: "now", date: "2026-10-13", time: "10:00" }),
    dl({ id: "doneToday", date: "2026-10-13", done: true }),
    dl({ id: "next", date: "2026-10-20" }),
    ev({ id: "far", date: "2027-01-01" })
]
assert.deepStrictEqual(E.upcoming(list, today, 0).map(x => x.id), ["late1", "late2", "now", "next", "far"])
assert.deepStrictEqual(E.upcoming(list, today, 3).map(x => x.id), ["late1", "late2", "now"])
assert.deepStrictEqual(E.upcoming([], today, 5), [])
console.log("ok  upcoming: late deadlines pinned first, past events and done deadlines out")

// 9. the month's summary and what a grid cell shows
const s = E.monthSummary(list, 2026, 9, today)
assert.deepStrictEqual(s, { events: 7, open: 3, late: 2 })
assert.deepStrictEqual(E.monthSummary(list, 2026, 10, today), { events: 0, open: 0, late: 0 })
assert.deepStrictEqual(E.monthSummary(list, 2027, 0, today), { events: 1, open: 0, late: 0 })
const entries = [ev({ color: 2 }), ev({ color: 2 }), ev({ color: 4 }), ev({ color: 1 }), ev({ color: 3 })]
const m1 = E.dayMarks(entries, 0, 3)
assert.deepStrictEqual(m1.colors, [2, 4, 1])      // no repeats, capped
assert.strictEqual(m1.count, 5)
assert.strictEqual(m1.deadline, "")
assert.strictEqual(E.dayMarks([ev({}), dl({ color: 3 })], 2, 3).deadline, "soon")
assert.strictEqual(E.dayMarks([dl({}), dl({})], -2, 3).deadline, "overdue")
assert.strictEqual(E.dayMarks([dl({ done: true })], -2, 3).deadline, "")
assert.strictEqual(E.dayMarks([dl({})], 9, 3).deadline, "later")
assert.deepStrictEqual(E.dayMarks(undefined, 0, 3), { colors: [], count: 0, deadline: "" })
console.log("ok  month summary and cell marks")

// 10. editing keeps the id and is refused when the result is not an event
const base = ev({ id: "keep", title: "Old", kind: "deadline" })
let ch = E.changed(base, { title: "New", done: true })
assert.strictEqual(ch.id, "keep")
assert.strictEqual(ch.title, "New")
assert.strictEqual(ch.done, true)
assert.strictEqual(E.changed(base, { title: "   " }), null)
assert.strictEqual(E.changed(base, { date: "2026-02-31" }), null)
assert.strictEqual(E.changed(base, { kind: "event" }).done, false)   // an event cannot stay "done"
console.log("ok  changed: id kept, invalid edits refused")

// 11. wiring (QML can't run here: read the sources)
const read = p => fs.readFileSync(locate(p), "utf8")
const shell = fs.readFileSync(require("path").join(__dirname, "..", "..", "shell.qml"), "utf8")
const widget = read("modules/sekai/desktopWidgets/CalendarCardWidget.qml")
const service = read("services/CalendarCardService.qml")
const editMode = read("services/EditMode.qml")
for (const [name, ok] of [
    ["shell.qml loads the widget behind a gate", /widgetId: "calendarcard"/.test(shell) && /CalendarCardWidget \{\}/.test(shell)],
    ["shell.qml has the ipc target", /target: "calendarcard"/.test(shell)],
    ["Edit Desktop lists it", /id: "calendarcard"/.test(editMode)],
    ["Edit Desktop can add and remove it", (editMode.match(/CalendarCardService/g) || []).length >= 4],
    ["the widget asks the service, not itself, for events", /CalendarCardService\.events/.test(widget)],
    ["the widget has its Edit Desktop parts", /EditStage \{/.test(widget) && /EditChrome \{/.test(widget) && /EditPreview \{/.test(widget)],
    ["the widget only takes the keyboard when it must", /WlrKeyboardFocus\.OnDemand/.test(widget) && /EditMode\.editTarget !== "calendarcard"/.test(widget)],
    ["the service saves through its script", /state\/calendarcard-state\.sh/.test(service)]
]) {
    assert.ok(ok, "wiring: " + name)
}
for (const f of ["calendarcard-state.sh"]) {
    const sh = fs.readFileSync(locate("scripts/state/" + f), "utf8")
    assert.ok(/save\)/.test(sh) && /load\)/.test(sh), f + " has save and load")
}
console.log("ok  wiring: shell, Edit Desktop, widget and service line up")
console.log("\nall calendar checks passed")

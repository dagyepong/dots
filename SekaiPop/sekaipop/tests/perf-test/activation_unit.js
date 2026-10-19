// Node test for the activation registry (services/ComponentActivation.qml, ActivationEntry.qml,
// modules/sekai/overview/OverviewEntry.qml and the wiring in shell.qml). Nothing here needs Quickshell.
//
// Part 1 reads the real QML files as text:
//   - every registry flag exists and defaults to false; `names` and the flags agree
//   - every flag is read by exactly one LazyLoader in shell.qml and written only through an entry
//   - every `name:` an entry is given is a registry name
//   - no `ipc` target is declared twice anywhere (a screen that became lazy must not keep its handler)
//   - the three screens still offer what an entry calls (open, closing, targetScreen, close, openOn / openBoard)
//   - braces / brackets / parentheses balance in every file this change touched
// Part 2 replays the entry's functions (copied statement for statement from ActivationEntry.qml)
// against a simulated screen, over thousands of random sequences of open / toggle / close /
// animation-end / unload, and checks the invariants the QML comments promise.
//   node tests/perf-test/activation_unit.js
"use strict";
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
let checks = 0;
const ok = (cond, msg) => { checks++; assert.ok(cond, msg); };

// ---------- 1. the real files ----------
const reg = read("services/ComponentActivation.qml");
const flags = [...reg.matchAll(/^\s*property bool (\w+Active): (\w+)\s*$/gm)];
ok(flags.length >= 3, "registry has flags");
for (const [, name, value] of flags) ok(value === "false", `${name} must default to false (is ${value})`);
const names = JSON.parse(reg.match(/readonly property var names: (\[[^\]]*\])/)[1]);
ok(names.length === flags.length, "names and flags agree in count");
for (const n of names) ok(flags.some((f) => f[1] === n + "Active"), `flag for ${n}`);
ok(!/Loader\s*\{|Component\s*\{|createObject|Qt\.createComponent/.test(reg), "registry instantiates nothing");

const shell = read("shell.qml");
for (const n of names) {
    const readers = [...shell.matchAll(new RegExp(`LazyLoader\\s*\\{\\s*active: ComponentActivation\\.${n}Active`, "g"))];
    ok(readers.length === 1, `${n}: exactly one LazyLoader reads ComponentActivation.${n}Active (got ${readers.length})`);
    // (the overview's entry is its own type, OverviewEntry.qml, which carries the name itself)
    const entries = [...(shell + read("modules/sekai/overview/OverviewEntry.qml")).matchAll(new RegExp(`name: "${n}"`, "g"))];
    ok(entries.length >= 1, `${n}: an entry carries its name`);
}
ok(!/ComponentActivation\.\w+Active\s*=/.test(shell), "shell.qml never writes a flag directly");
for (const f of ["services/ActivationEntry.qml", "modules/sekai/overview/OverviewEntry.qml"]) {
    ok(!/ComponentActivation\.\w+Active\s*=/.test(read(f)), `${f} writes only through setActive`);
}
for (const m of [...shell.matchAll(/name: "(\w+)"/g)]) ok(names.includes(m[1]), `entry name ${m[1]} is in the registry`);

// every ipc target once
const targets = {};
function walk(dir) {
    for (const e of fs.readdirSync(path.join(root, dir), { withFileTypes: true })) {
        const rel = path.join(dir, e.name);
        if (e.isDirectory()) { if (e.name !== "tests") walk(rel); }
        else if (e.name.endsWith(".qml")) {
            const t = read(rel);
            for (const m of t.matchAll(/IpcHandler\s*\{\s*target:\s*"([^"]+)"/g)) (targets[m[1]] = targets[m[1]] || []).push(rel);
        }
    }
}
walk("."); 
for (const [t, files] of Object.entries(targets)) {
    // QuickPanel.qml declares several targets; one name must still come from one place
    ok(files.length === 1, `ipc target "${t}" declared once (found in ${files.join(", ")})`);
}
for (const t of ["cheatsheet", "palette", "overview"]) ok(targets[t] && targets[t][0] === "shell.qml", `${t} is answered in shell.qml`);

// the screens offer what an entry calls
const screens = {
    "modules/sekai/cheatSheet/CheatSheet.qml": ["openOn"],
    "modules/sekai/palette/PaletteTool.qml": ["openOn"],
    "modules/sekai/overview/Overview.qml": ["openBoard", "openOn"],
};
for (const [f, fns] of Object.entries(screens)) {
    const t = read(f);
    ok(/property bool open: false/.test(t), `${f}: open`);
    ok(/property bool closing: false/.test(t), `${f}: closing`);
    ok(/property var targetScreen/.test(t), `${f}: targetScreen`);
    ok(/function close\(\)/.test(t), `${f}: close()`);
    for (const fn of fns) ok(new RegExp(`function ${fn}\\(`).test(t), `${f}: ${fn}()`);
    ok(!/IpcHandler/.test(t), `${f}: no handler left inside a lazily built screen`);
    ok(!/Component\.onCompleted|Component\.onDestruction/.test(t), `${f}: no own Component handler to clash with the entry's`);
}
// each lazily built screen attaches and detaches itself
for (const id of ["cheatSheetEntry", "paletteToolEntry", "overview"]) {
    ok(new RegExp(`Component\\.onCompleted: ${id}\\.attach\\(`).test(shell), `${id}.attach`);
    ok(new RegExp(`Component\\.onDestruction: ${id}\\.detach\\(`).test(shell), `${id}.detach`);
}
ok(/openFunction: "openBoard"/.test(read("modules/sekai/overview/OverviewEntry.qml")), "overview opens the board itself, not the plugin path twice");

// nothing outside shell.qml still names the old ids
for (const [f, re] of [["shell.qml", /\bcheatSheet\.shown\b/]]) ok(!re.test(read(f)), `${f}: stale reference ${re}`);

// brackets
function balanced(text) {
    // strip strings, comments
    const s = text.replace(/\/\/[^\n]*/g, "").replace(/\/\*[\s\S]*?\*\//g, "").replace(/"(?:\\.|[^"\\])*"/g, '""');
    const stack = [], pair = { ")": "(", "]": "[", "}": "{" };
    for (const c of s) {
        if ("([{".includes(c)) stack.push(c);
        else if (")]}".includes(c)) { if (stack.pop() !== pair[c]) return false; }
    }
    return stack.length === 0;
}
for (const f of ["shell.qml", "services/ComponentActivation.qml", "services/ActivationEntry.qml",
    "modules/sekai/overview/OverviewEntry.qml", "modules/sekai/overview/Overview.qml",
    "modules/sekai/cheatSheet/CheatSheet.qml", "modules/sekai/palette/PaletteTool.qml",
    "services/EditMode.qml", "services/FocusService.qml", "services/SettingsService.qml",
    "modules/sekai/settings/SettingsPageDesktop.qml"]) ok(balanced(read(f)), `${f}: brackets balance`);

// low-end mode: one flag, default off, read where it is documented
ok(/"perf\.lowEnd": false/.test(read("services/SettingsService.qml")), "perf.lowEnd defaults to false");
ok(/perf\.lowEnd/.test(read("services/FocusService.qml")) && /perf\.lowEnd/.test(read("services/EditMode.qml")), "low-end mode is read by FocusService and EditMode");
ok(!/compactWindows\s*=/.test(read("services/EditMode.qml").replace(/\/\/[^\n]*/g, "")), "EditMode.compactWindows is only ever read (a write would break its binding)");

// ---------- 2. the entry's logic ----------
// Statement-for-statement copy of ActivationEntry.qml's functions, on a plain object.
function makeWorld() {
    const world = { flag: false, builds: 0, live: null, deferred: [], log: [] };
    const registry = { setActive(name, on) { world.flag = !!on; syncLoader(); } };
    function syncLoader() {
        if (world.flag && world.live === null) {
            world.builds++;
            world.live = { open: false, closing: false, targetScreen: null,
                openOn(s) { this.open = true; this.closing = false; this.targetScreen = s || this.targetScreen; world.onChange(); },
                openBoard(s) { this.openOn(s); },
                close() { if (this.open) { this.open = false; this.closing = true; world.onChange(); } } };
            entry.attach(world.live);                      // Component.onCompleted
        } else if (!world.flag && world.live !== null) {
            const dead = world.live; world.live = null;
            entry.detach(dead);                            // Component.onDestruction
        }
    }
    const entry = {
        name: "cheatSheet", openFunction: "openOn", item: null, wanted: null,
        attach(it) { entry.item = it; world.deferred.push(() => entry.deliver()); },
        detach(it) { if (entry.item === it) entry.item = null; },
        open(screen) { entry.wanted = { screen }; registry.setActive(entry.name, true); entry.deliver(); },
        toggle(screen) {
            const it = entry.item;
            if (it && it.open && (!screen || screen === it.targetScreen)) { entry.wanted = null; it.close(); return; }
            entry.open(screen);
        },
        close() { entry.wanted = null; if (entry.item) entry.item.close(); },
        deliver() {
            const it = entry.item, w = entry.wanted;
            if (!it || !w) return;
            entry.wanted = null;
            it[entry.openFunction](w.screen);
        },
        settle() {
            const it = entry.item;
            if (it && !it.open && !it.closing && entry.wanted === null) registry.setActive(entry.name, false);
        },
    };
    world.onChange = () => world.deferred.push(() => entry.settle());   // Qt.callLater(settle)
    world.entry = entry;
    return world;
}
function flush(w) { while (w.deferred.length) w.deferred.shift()(); }

let seed = 987654321;
const rnd = (n) => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed % n; };
let runs = 0, requestsSeen = 0;
for (let r = 0; r < 3000; r++) {
    const w = makeWorld();
    let lastWanted = null;      // what the last open request asked for, until it is cancelled
    for (let step = 0; step < 60; step++) {
        const screen = ["A", "B"][rnd(2)];
        switch (rnd(7)) {
            case 0: w.entry.open(screen); lastWanted = screen; break;
            case 1: w.entry.toggle(screen); break;
            case 2: w.entry.close(); lastWanted = null; break;
            case 3: flush(w); break;                                           // an event-loop turn
            case 4: if (w.live && w.live.closing) { w.live.closing = false; w.onChange(); } break;  // exit animation ends
            case 5: if (w.live && w.live.open) { w.live.close(); } break;      // Escape inside the screen
            case 6: w.entry.toggle(null); break;
        }
        // invariants that hold at every instant
        ok(w.live === null || w.flag === true, "an instance exists only while the flag is up");
        ok(w.live === null || w.entry.item === w.live, "the entry holds the live instance");
    }
    // let everything settle: finish the animation, run the deferred calls
    flush(w);
    if (w.live && w.live.closing) { w.live.closing = false; w.onChange(); flush(w); }
    flush(w);
    if (w.live && w.live.open) { w.entry.close(); flush(w); if (w.live && w.live.closing) { w.live.closing = false; w.onChange(); } flush(w); }
    ok(w.live === null && w.flag === false, "after closing and settling nothing stays built");
    ok(w.entry.item === null && w.entry.wanted === null, "no stale reference or request");
    runs++;
}
// a request is never lost: asking while unbuilt opens it on the asked screen
{
    const w = makeWorld();
    w.entry.open("B"); ok(w.flag && w.live !== null, "flag raised and screen built");
    flush(w); ok(w.live.open && w.live.targetScreen === "B", "the request reached the screen");
    ok(w.builds === 1, "built once");
    w.entry.open("A"); flush(w); ok(w.builds === 1 && w.live.targetScreen === "A", "a second request reuses the instance");
    w.entry.toggle("A"); flush(w);
    ok(w.live && w.live.closing && !w.live.open, "toggle on the same screen closes");
    w.entry.open("A"); flush(w);                         // reopen while it is still closing
    ok(w.live && w.live.open && !w.live.closing && w.builds === 1, "reopen during the exit animation reuses it");
    w.entry.close(); w.live.closing = false; w.onChange(); flush(w);
    ok(w.live === null && !w.flag, "released after the exit animation");
    w.entry.open("A"); flush(w); ok(w.builds === 2 && w.live.open, "next open builds a fresh one");
    // hide while nothing is built is harmless
    w.entry.close(); w.live.closing = false; w.onChange(); flush(w);
    w.entry.close(); ok(w.live === null && !w.flag, "close with nothing built does nothing");
}
// the settle() race the QML comment describes: a reopen lands in the same tick as the end of the animation
{
    const w = makeWorld();
    w.entry.open("A"); flush(w);
    w.entry.close();                                      // closing
    w.live.closing = false; w.onChange();                 // the animation ended -> settle is queued
    w.entry.open("A");                                    // ... and a reopen arrives before it runs
    flush(w);
    ok(w.live && w.live.open && w.flag, "a reopen in the same tick is not pulled from under itself");
}

console.log(`activation_unit: ${checks} checks passed (${runs} random runs)`);

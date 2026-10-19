// Rules of Desktop Focus Mode, one by one. Run: node focus_unit.js
const fs = require('fs'), assert = require('assert')
const locate = require('../lib/locate.js')
const src = fs.readFileSync(locate('modules/common/functions/FocusMath.js'), 'utf8').replace('.pragma library', '')
const F = {}
new Function('F', src + ';F.compute=compute;F.census=census;F.kindOf=kindOf;F.hides=hides;F.same=same;F.publish=publish;F.holding=holding;F.slotDelay=slotDelay;F.STAGGER_MS=STAGGER_MS;')(F)

const on = { enabled: true, hideTiled: true, hideFloating: false }
const mon = (name, ws, sp) => ({ name, workspaceId: ws, specialId: sp || 0 })
const win = (ws, mn, extra) => Object.assign({ address: '0x' + Math.random().toString(16).slice(2), workspaceId: ws, monitor: mn, floating: false, mapped: true, hidden: false, pinned: false, fullscreen: 0, cls: 'app', known: true }, extra || {})
const hid = (r, n) => r[n].hidden

// 1. the default rules, one workspace
let M = [mon('DP-1', 1)]
assert.strictEqual(hid(F.compute([], M, on), 'DP-1'), false)
assert.strictEqual(hid(F.compute([win(1, 'DP-1')], M, on), 'DP-1'), true)
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true })], M, on), 'DP-1'), false)
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true }), win(1, 'DP-1')], M, on), 'DP-1'), true)
console.log('ok  empty shows; tiled hides; floating alone keeps; tiled + floating hides')

// 2. hide-with-floating, and hide-with-tiled off
const fl = { enabled: true, hideTiled: true, hideFloating: true }
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true })], M, fl), 'DP-1'), true)
const noTiled = { enabled: true, hideTiled: false, hideFloating: false }
assert.strictEqual(hid(F.compute([win(1, 'DP-1')], M, noTiled), 'DP-1'), false)
assert.strictEqual(hid(F.compute([win(1, 'DP-1'), win(1, 'DP-1', { floating: true })], M, { enabled: true, hideTiled: false, hideFloating: true }), 'DP-1'), true)
console.log('ok  the two hide switches are independent')

// 3. the master switch off: nothing hides, whatever is open
assert.strictEqual(hid(F.compute([win(1, 'DP-1')], M, { enabled: false, hideTiled: true, hideFloating: true }), 'DP-1'), false)
assert.strictEqual(F.compute([win(1, 'DP-1')], M, { enabled: false }) ['DP-1'].busy, true)
console.log('ok  focus mode off never hides (busy is still reported)')

// 4. only the windows on the ACTIVE workspace count; a switch recomputes
const W = [win(2, 'DP-1'), win(3, 'DP-1', { floating: true })]
assert.strictEqual(hid(F.compute(W, [mon('DP-1', 1)], on), 'DP-1'), false)
assert.strictEqual(hid(F.compute(W, [mon('DP-1', 2)], on), 'DP-1'), true)
assert.strictEqual(hid(F.compute(W, [mon('DP-1', 3)], on), 'DP-1'), false)
console.log('ok  other workspaces do not count; switching changes the answer')

// 5. two monitors are independent
M = [mon('DP-1', 1), mon('HDMI-A-1', 5)]
let r = F.compute([win(1, 'DP-1')], M, on)
assert.strictEqual(hid(r, 'DP-1'), true); assert.strictEqual(hid(r, 'HDMI-A-1'), false)
r = F.compute([win(5, 'HDMI-A-1')], M, on)
assert.strictEqual(hid(r, 'DP-1'), false); assert.strictEqual(hid(r, 'HDMI-A-1'), true)
// a window moved to the other monitor's workspace moves the answer with it
r = F.compute([win(5, 'HDMI-A-1')], [mon('DP-1', 5), mon('HDMI-A-1', 1)], on)   // workspaces swapped between monitors
assert.strictEqual(hid(r, 'DP-1'), true); assert.strictEqual(hid(r, 'HDMI-A-1'), false)
console.log('ok  per monitor; follows the workspace, not a fixed monitor-window pairing')

// 6. the same workspace shown on no other monitor; a monitor unknown to us is not in the result
assert.strictEqual(Object.keys(F.compute([win(1, 'DP-1')], [mon('DP-1', 1)], on)).length, 1)
assert.strictEqual(F.compute([win(1, 'DP-1')], [], on)['DP-1'], undefined)
console.log('ok  only known monitors are answered for')

// 7. windows that never count
M = [mon('DP-1', 1)]
for (const [why, w] of [
    ['unmapped', win(1, 'DP-1', { mapped: false })],
    ['hidden', win(1, 'DP-1', { hidden: true })],
    ['the shell\'s own', win(1, 'DP-1', { cls: 'quickshell' })],
    ['the shell\'s own (case)', win(1, 'DP-1', { cls: 'QuickShell' })],
    ['not read yet', win(1, 'DP-1', { known: false, floating: undefined })],
    ['minimised (hidden special workspace, not shown)', win(-99, 'DP-1')]
]) assert.strictEqual(hid(F.compute([w], M, on), 'DP-1'), false, why)
console.log('ok  unmapped, hidden, shell-owned, unknown and minimised windows never hide')

// 8. a special workspace (scratchpad) shown over the monitor counts; shut, it does not
const pad = win(-98, 'DP-1')
assert.strictEqual(hid(F.compute([pad], [mon('DP-1', 1, -98)], on), 'DP-1'), true)
assert.strictEqual(hid(F.compute([pad], [mon('DP-1', 1, 0)], on), 'DP-1'), false)
console.log('ok  a scratchpad over the monitor counts only while it is shown')

// 9. fullscreen counts as tiled, even for a floating window (and 'maximised')
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true, fullscreen: 2 })], M, on), 'DP-1'), true)
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true, fullscreen: 1 })], M, on), 'DP-1'), true)
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true, fullscreen: true })], M, on), 'DP-1'), true)
assert.strictEqual(hid(F.compute([win(1, 'DP-1', { floating: true, fullscreen: 0 })], M, on), 'DP-1'), false)
console.log('ok  fullscreen / maximised floating windows count as tiled')

// 10. a pinned floating window follows the monitor across workspaces
const pin = win(4, 'DP-1', { floating: true, pinned: true })
assert.strictEqual(F.compute([pin], [mon('DP-1', 1)], on)['DP-1'].floating, 1)
assert.strictEqual(hid(F.compute([pin], [mon('DP-1', 1)], on), 'DP-1'), false)
assert.strictEqual(hid(F.compute([pin], [mon('DP-1', 1)], fl), 'DP-1'), true)
assert.strictEqual(F.compute([pin], [mon('HDMI-A-1', 1)], on)['HDMI-A-1'].floating, 0)
console.log('ok  pinned windows count on their own monitor only')

// 11. the last window closing restores; a floating <-> tiled flip recomputes
let ws = [win(1, 'DP-1')]
assert.strictEqual(hid(F.compute(ws, M, on), 'DP-1'), true)
assert.strictEqual(hid(F.compute([], M, on), 'DP-1'), false)
ws[0].floating = true
assert.strictEqual(hid(F.compute(ws, M, on), 'DP-1'), false)
ws[0].floating = false
assert.strictEqual(hid(F.compute(ws, M, on), 'DP-1'), true)
console.log('ok  closing the last window restores; tiled <-> floating flips the answer')

// 12. same(): only hidden / busy matter
const a = F.compute([win(1, 'DP-1')], M, on)
assert.ok(F.same(a, F.compute([win(1, 'DP-1'), win(1, 'DP-1')], M, on)))     // a second tiled window: nothing changes for anyone
assert.ok(!F.same(a, F.compute([], M, on)))
assert.ok(!F.same(a, F.compute([win(1, 'DP-1')], [mon('DP-1', 1), mon('X', 2)], on)))
console.log('ok  same() ignores counts, sees hidden / busy / monitor list')

// 13. hysteresis: hide at once, come back only once settled
let shown = F.compute([win(1, 'DP-1')], M, on)                 // hidden
const gone = F.compute([], M, on)                              // the window closed
assert.ok(F.holding(shown, gone))
assert.strictEqual(hid(F.publish(shown, gone, false), 'DP-1'), true)    // held
assert.strictEqual(hid(F.publish(shown, gone, true), 'DP-1'), false)    // settled: back
// a replacement window opens before the timer: still hidden, nothing flickers
const again = F.compute([win(1, 'DP-1')], M, on)
assert.ok(!F.holding(shown, again))
assert.strictEqual(hid(F.publish(shown, again, false), 'DP-1'), true)
// hiding is never delayed
assert.strictEqual(hid(F.publish(gone, again, false), 'DP-1'), true)
// per monitor: one is held back, the other is not
shown = F.compute([win(1, 'DP-1'), win(5, 'HDMI-A-1')], [mon('DP-1', 1), mon('HDMI-A-1', 5)], on)
const half = F.compute([win(5, 'HDMI-A-1')], [mon('DP-1', 1), mon('HDMI-A-1', 5)], on)
const p = F.publish(shown, half, false)
assert.strictEqual(hid(p, 'DP-1'), true); assert.strictEqual(hid(p, 'HDMI-A-1'), true)
console.log('ok  hide is instant, return waits for the answer to settle, per monitor')

// 14. the wake-up order
assert.strictEqual(F.slotDelay('clock'), 0)
assert.strictEqual(F.slotDelay('visualizer'), 4 * F.STAGGER_MS)
assert.strictEqual(F.slotDelay('nothing'), 0)
console.log('ok  widgets wake one after another')

// 14b. a window whose workspace is not known yet never matches a monitor whose workspace is not known yet
assert.strictEqual(hid(F.compute([win(0, 'DP-1')], [mon('DP-1', 0)], on), 'DP-1'), false)
console.log('ok  two unknown workspaces are not "the same"')

// 15. ten thousand random layouts never throw and always agree with a plain restatement of the rules
function rnd(n) { return Math.floor(Math.random() * n) }
for (let i = 0; i < 10000; i++) {
    const mons = [mon('A', 1 + rnd(4), rnd(3) === 0 ? -98 : 0), mon('B', 5 + rnd(3))]
    const wins = []
    for (let j = rnd(6); j > 0; j--)
        wins.push(win([1, 2, 3, 4, 5, 6, 7, -98, -99][rnd(9)], rnd(2) ? 'A' : 'B', { floating: rnd(2) === 0, mapped: rnd(8) !== 0, hidden: rnd(9) === 0, pinned: rnd(10) === 0, fullscreen: rnd(6) === 0 ? 2 : 0, known: rnd(9) !== 0, cls: rnd(12) === 0 ? 'quickshell' : 'x' }))
    const o = { enabled: rnd(5) !== 0, hideTiled: rnd(4) !== 0, hideFloating: rnd(2) === 0 }
    const res = F.compute(wins, mons, o)
    for (const m of mons) {
        let t = 0, f = 0
        for (const w of wins) {
            if (!w.mapped || w.hidden || w.cls === 'quickshell' || !w.known) continue
            const here = w.workspaceId === m.workspaceId || (m.specialId && w.workspaceId === m.specialId) || (w.pinned && w.monitor === m.name)
            if (!here) continue
            if (w.fullscreen || !w.floating) t++; else f++
        }
        const want = o.enabled && ((o.hideTiled && t > 0) || (o.hideFloating && f > 0))
        assert.strictEqual(res[m.name].hidden, want)
        assert.strictEqual(res[m.name].tiled, t); assert.strictEqual(res[m.name].floating, f)
    }
}
console.log('ok  10000 random layouts agree with the plain rules')
console.log('\nall focus checks passed')

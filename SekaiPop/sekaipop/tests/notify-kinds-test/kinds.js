// Runs under node: loads the real modules/common/functions/NotifyKinds.js and checks the glyph -> attribute
// colour map behind the shell's own notification badges (ShellBadge.qml), then checks that every shell
// notification call site sends a "material:<glyph>" icon whose glyph is one we know. Usage: node tests/notify-kinds-test/kinds.js
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '../..');
const src = fs.readFileSync(path.join(root, 'modules/common/functions/NotifyKinds.js'), 'utf8').replace('.pragma library', '');
const NK = new Function(src + '\nreturn { index, KINDS };')();

let fails = 0;
function ok(c, m) { if (!c) { fails++; console.log('FAIL', m); } else console.log('ok  ', m); }

ok(NK.index('photo_camera') === 0, 'screenshot is Cool (0)');
ok(NK.index('videocam') === 1, 'recording is Cute (1)');
ok(NK.index('alarm') === 2, 'timer / alarm is Happy (2)');
ok(NK.index('terminal') === 3, 'terminal is Mysterious (3)');
ok(NK.index('system_update') === 4, 'updates are Pure (4)');
ok(Object.values(NK.KINDS).every(v => v >= 0 && v <= 4), 'every listed glyph maps to one of the five');
for (const g of ['made_up_glyph', 'x', '', undefined, null, 'constructor', 'toString', '__proto__']) {
  const a = NK.index(g), b = NK.index(g);
  ok(Number.isInteger(a) && a >= 0 && a <= 4 && a === b, 'unlisted glyph ' + JSON.stringify(g) + ' -> stable 0..4 (' + a + ')');
}
const seen = new Set();
for (let i = 0; i < 60; i++) seen.add(NK.index('glyph_' + i));
ok(seen.size === 5, 'unlisted names spread over all five colours');

// call sites: every notify-send the shell makes itself carries a known glyph
const files = ['modules/common/functions/Extras.js', 'modules/sekai/bar/UtilButtons.qml', 'services/QuickSource.qml', 'services/KeyboardService.qml',
  'services/RegionService.qml', 'services/DesktopPresetService.qml', 'services/PackageUpdatesService.qml',
  'services/ScrollOverviewService.qml', 'services/TimerService.qml', 'scripts/system/region-action.sh'];
let calls = 0;
for (const f of files) {
  const t = fs.readFileSync(path.join(root, f), 'utf8');
  const lines = t.split('\n');
  lines.forEach((line, i) => {
    if (!/notify-send|\bnotify (-i|")/.test(line) || /command -v notify-send|have\b.*notify-send|for t in/.test(line)) return;
    if (/^\s*notify\(\)/.test(line) || /^\s*notify\s*\(\)/.test(line)) return;
    // the call may continue on the next line (Quickshell.execDetached([... ,\n "title", ...]))
    const ctx = line + '\n' + (lines[i + 1] || '');
    const m = ctx.match(/material:([a-z_]+)/);
    calls++;
    ok(!!m && Object.prototype.hasOwnProperty.call(NK.KINDS, m[1]), f + ':' + (i + 1) + ' sends a listed material glyph' + (m ? ' (' + m[1] + ')' : ''));
  });
}
ok(calls >= 20, 'found the call sites (' + calls + ')');
console.log(fails ? '\n' + fails + ' failed' : '\nall passed');
process.exit(fails ? 1 : 0);

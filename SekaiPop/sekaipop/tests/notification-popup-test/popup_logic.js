// Runs under node: pulls the real function bodies out of services/NotificationSource.qml (the popup stack:
// push, cap, timing, hover, close, dismiss) and out of NotificationPopup.qml (sync / drop of the cards list)
// and checks them with a fake ListModel. Usage: node tests/notification-popup-test/popup_logic.js
const fs = require('fs');
const src = fs.readFileSync(require('path').join(__dirname,'../../services/NotificationSource.qml'),'utf8');
const win = fs.readFileSync(require('path').join(__dirname,'../../modules/sekai/notificationPopup/NotificationPopup.qml'),'utf8');

function between(s, a, b) { const i = s.indexOf(a); const j = s.indexOf(b, i); if (i<0||j<0) throw new Error('marker '+a); return s.slice(i, j); }

// the real function bodies
const popupJs = between(src, '    // ===== the popups =====', '    // Only ticks while there is something on the stack.');
const readMsJs = between(src, '    function readMs(entry)', '    function hideToast()');

const state = { popups: [], popupMonitor: '', maxPopups: 4, popupLeft: {}, popupHeld: {},
  popupTick: { interval: 200 }, alertStyle: 'popups' };
const Hyprland = { focusedMonitor: { name: 'DP-1' } };
const Quickshell = { screens: [{ name: 'eDP-1' }] };
const body = `with (state) { ${readMsJs}\n${popupJs}\n return { pushPopup, closePopups, closePopup, clearPopups, holdPopup, tickPopups, readMs } }`;
const api = new Function('state','Hyprland','Quickshell', body)(state, Hyprland, Quickshell);

let fails = 0;
function ok(c, m) { if (!c) { fails++; console.log('FAIL', m); } else console.log('ok  ', m); }
const mk = (k, t='hi', b='', u=1) => ({ key: k, app: 'App', title: t, body: b, urgency: u, icon: '' });

// read time
ok(api.readMs(mk('a','x','')) === 4500, 'short one: 4500 ms minimum');
ok(api.readMs(mk('a','x'.repeat(200),'')) === 12000, 'long one capped at 12000');
ok(api.readMs(mk('a','x','',2)) === 8000 || api.readMs(mk('a','x','',2)) >= 7500, 'critical stays longer: '+api.readMs(mk('a','x','',2)));

// push order, monitor, cap
api.pushPopup(mk('n1')); ok(state.popupMonitor === 'DP-1', 'monitor = focused when stack starts');
Hyprland.focusedMonitor = { name: 'HDMI-A-1' };
api.pushPopup(mk('n2')); ok(state.popupMonitor === 'DP-1', 'monitor kept while the stack is not empty');
api.pushPopup(mk('n3')); api.pushPopup(mk('n4'));
ok(state.popups.map(e=>e.key).join() === 'n4,n3,n2,n1', 'newest first');
api.pushPopup(mk('n5'));
ok(state.popups.map(e=>e.key).join() === 'n5,n4,n3,n2', 'cap 4 drops the oldest popup');
ok(state.popupLeft['n1'] === undefined && state.popupHeld['n1'] === undefined, 'dropped one leaves no bookkeeping');

// tick: expiry
function ticks(n){ for(let i=0;i<n;i++) api.tickPopups(); }
ticks(10); ok(state.popups.length === 4, 'still up after 2 s');
ticks(15); // 25 ticks = 5 s > 4500 ms
ok(state.popups.length === 0, 'all expired after > 4.5 s (got '+state.popups.length+')');
ok(Object.keys(state.popupLeft).length === 0, 'bookkeeping empty after expiry');

// hover holds, leaving gives a moment more
state.popupMonitor=''; Hyprland.focusedMonitor = { name: 'eDP-1' };
api.pushPopup(mk('h1')); api.pushPopup(mk('h2'));
api.holdPopup('h1', true);
ticks(40); // 8 s
ok(state.popups.map(e=>e.key).join() === 'h1', 'held popup survives, other expires');
api.holdPopup('h1', false);
ok(state.popupLeft['h1'] === 4500, 'leaving keeps the time it had left ('+state.popupLeft['h1']+')');
ticks(20); ok(state.popups.length === 1, 'still there before its remaining time is up');
ticks(4); ok(state.popups.length === 0, 'gone once it is');
// nearly out of time when the pointer leaves: at least 1.5 s more
state.popupMonitor=''; api.pushPopup(mk('h3')); api.holdPopup('h3', true); state.popupLeft['h3'] = 200; api.holdPopup('h3', false);
ok(state.popupLeft['h3'] === 1500, 'nearly out of time: pointer leaving gives 1.5 s');
ticks(7); ok(state.popups.length === 1, '... still there after 1.4 s');
ticks(1); ok(state.popups.length === 0, '... gone at 1.6 s');

// hold on something not on the stack does not leak
api.holdPopup('ghost', true); api.holdPopup('ghost', false);
ok(state.popupLeft['ghost'] === undefined && state.popupHeld['ghost'] === undefined, 'hold on unknown key leaves nothing');

// close / dismiss many / clear
api.pushPopup(mk('c1')); api.pushPopup(mk('c2')); api.pushPopup(mk('c3'));
api.closePopup('c2'); ok(state.popups.map(e=>e.key).join() === 'c3,c1', 'closePopup removes just that one');
api.closePopups(['c3','nope']); ok(state.popups.map(e=>e.key).join() === 'c1', 'closePopups ignores unknown keys');
api.clearPopups(); ok(state.popups.length === 0 && Object.keys(state.popupLeft).length === 0, 'clearPopups empties everything');
api.closePopup('x'); ok(true, 'closePopup on empty stack is a no-op');

// monitor fallback
state.popupMonitor=''; Hyprland.focusedMonitor = null;
api.pushPopup(mk('f1')); ok(state.popupMonitor === 'eDP-1', 'falls back to the first screen without Hyprland focus');

// ---- window sync() against a fake ListModel
const syncJs = between(win, '        function indexOfKey(key)', '        Connections {');
class Model { constructor(){ this.a=[]; } get count(){ return this.a.length; }
  get(i){ return this.a[i]; } remove(i){ this.a.splice(i,1); } insert(i,o){ this.a.splice(i,0,Object.assign({},o)); }
  setProperty(i,k,v){ this.a[i][k]=v; } }
const notices = new Model();
const root = { source: { popups: [] } };
const w = new Function('notices','root', `const win = {}; ${syncJs.replace(/function (\w+)\(/g,'win.$1 = function(')}; return win;`);
// the extracted text uses "function name(...) {...}" members; rebuild safely:
const wsrc = syncJs.replace(/function (indexOfKey|drop|sync)\(/g, 'win.$1 = function(').replace(/win\.(indexOfKey|drop|sync)\(/g, (m)=>m);
const W = new Function('notices','root', `const win = {}; ${wsrc.replace(/\n\s*\}\n\s*\n\s*\/\/ The card/,'\n}\n// The card')}\n return win;`)(notices, root);
root.source.popups = [mk('a3'), mk('a2'), mk('a1')];
W.sync(); ok(notices.a.map(x=>x.key).join() === 'a3,a2,a1', 'sync: three arrivals, newest on top');
root.source.popups = [mk('a4'), mk('a3'), mk('a2'), mk('a1')];
W.sync(); ok(notices.a.map(x=>x.key).join() === 'a4,a3,a2,a1', 'sync: a new one goes on top');
root.source.popups = [mk('a4'), mk('a2')];
W.sync(); ok(notices.a.filter(x=>x.leaving).map(x=>x.key).join() === 'a3,a1', 'sync: removed ones are marked leaving, not dropped');
ok(notices.count === 4, 'sync: they stay until the card says finished');
W.drop('a3'); W.drop('a1'); W.drop('a3');
ok(notices.a.map(x=>x.key).join() === 'a4,a2', 'drop: removes by key, repeat is harmless');
root.source.popups = [mk('a5'), mk('a4'), mk('a2')];
W.sync(); ok(notices.a.map(x=>x.key).join() === 'a5,a4,a2' && notices.a.every(x=>!x.leaving), 'sync: arrival after a drop');
const fields = Object.keys(notices.a[0]).sort().join();
ok(fields === 'app,body,icon,key,leaving,title,urgency', 'model roles match the card\'s required properties: '+fields);
console.log(fails ? ('\n'+fails+' FAILED') : '\nall passed'); process.exit(fails?1:0);

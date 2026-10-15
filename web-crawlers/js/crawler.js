// Web crawler: a procedural spider whose feet plant on real DOM words/links.
// Every element a foot touches gets a short-lived CSS mutation.
// Body/legs live in page coordinates; the canvas draws them relative to scroll.
//
// Frame discipline (layout on this page is expensive): update() and draw() only
// READ the DOM; every DOM WRITE (mutations, reverts, fx nodes, scrolling) is
// queued and applied in commit() at the very end of the frame, so the browser
// lays the page out once per frame instead of being forced to mid-frame.
(() => {
  const content = document.getElementById('content');
  const fx = document.getElementById('fx');
  const cv = document.getElementById('legs');
  const ctx = cv.getContext('2d');
  const hint = document.getElementById('hint');

  // ---------- tuning ----------
  const SCALE = innerWidth < 640 ? 1.05 : 1.45; // overall spider size (smaller on phones)
  const LW = 1.25 * Math.sqrt(SCALE);    // leg stroke width
  const T = {
    cruise: 200,           // px/s top crawling speed (x sqrt(SCALE)); the reference scrolls ~150-250px/s
    lure: 260,             // px/s when chasing the mouse
    burstFloor: .55,       // gait rhythm never drops below this fraction of top speed
    stopChance: .06,       // chance a new waypoint is a short pause instead
    stopTime: [.35, .9],
    arrive: 60,            // waypoints are passed through at speed, not braked for
    stepY: [160, 480],     // how far down the page each waypoint lies
    stepFrac: .3,          // re-step once a foot drifts this fraction of its reach from its rest spot
    urgentFrac: .5,        // beyond this the step ignores gait coordination
    overFrac: .92,         // hard limit (fraction of full leg length) -> immediate retract
    placeFrac: .85,        // new footholds are never chosen beyond this fraction of full leg length
    lead: .3,              // seconds of velocity lead when placing a foot...
    leadMax: .3,           // ...capped at this fraction of reach
    jump: 14,              // px a gripped word may move in one frame before the foot lets go (reflow)
    ambientEvery: [.03, .09],
    ambientPerTick: 2,
    shinRate: 10,          // per second: text under a random shin gets brushed
    threadEvery: [.16, .5],
    threadMax: 7,
    threadRange: 240,
  };

  // ---------- small math ----------
  const R = Math.random;
  const pick = a => a[(R() * a.length) | 0];
  const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
  const V = (x = 0, y = 0) => ({ x, y });
  const add = (a, b) => V(a.x + b.x, a.y + b.y);
  const sub = (a, b) => V(a.x - b.x, a.y - b.y);
  const mul = (a, s) => V(a.x * s, a.y * s);
  const len = a => Math.hypot(a.x, a.y);
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const lerp = (a, b, t) => V(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  const mix = (a, b, t) => a + (b - a) * t;
  const rot = (v, a) => { const c = Math.cos(a), s = Math.sin(a); return V(v.x * c - v.y * s, v.x * s + v.y * c); };
  const capLen = (v, m) => { const l = len(v); return l > m ? mul(v, m / l) : v; };
  const angLerp = (a, b, t) => { let d = b - a; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return a + d * t; };
  const damp = (k, dt) => 1 - Math.exp(-k * dt);
  const range = ([a, b]) => a + R() * (b - a);

  // ---------- palette (sampled from the reference) ----------
  const C = {
    leg: '#5cc8ff', legHi: '#9be0ff', joint: '#ff4a6e', body: '#cfe8ff', bodyFill: 'rgba(20,40,130,.65)',
    blue: '#3d6dff', red: '#ff3355', purple: '#b44dff', cyan: '#42cfff', magenta: '#ff36d9', pink: '#ff5ca8',
    orange: '#ff7d45', mint: '#6dffb0', green: '#38ff7a', white: '#f2f2f2', yellow: '#ffe14d', sky: '#8fd8ff',
  };
  // threads avoid the leg blues so they never read as legs
  const THREAD_COLORS = [C.purple, C.orange, C.magenta, C.red, C.yellow];

  // ---------- viewport / canvas ----------
  let W = 0, H = 0, DPR = 1, colX = null; // colX: text column's left edge (page coords), set in init
  function resize() {
    DPR = Math.min(2, devicePixelRatio || 1);
    W = innerWidth; H = innerHeight;
    cv.width = W * DPR; cv.height = H * DPR;
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    if (colX == null) return; // spider not built yet
    // the centred column moved sideways: carry the spider (and everything it holds) with the text
    const nx = content.getBoundingClientRect().left + sx(), dx = nx - colX;
    colX = nx;
    if (!dx) return;
    shiftWorld(dx, 0);
    pickTarget(); // re-clamp the goal into the new safeBox()
  }

  // move every page-space point the spider holds (the text moved under it)
  function shiftWorld(dx, dy) {
    const seen = new Set(); // anchors are shared (foot / bar / flash): shift each once
    const sh = p => { if (p && !seen.has(p)) { seen.add(p); p.x += dx; p.y += dy; } };
    sh(S.p); sh(S.abd); sh(S.spin); sh(S.target);
    for (const L of legs) { sh(L.foot); sh(L.next); sh(L.from); sh(L.knee); sh(L.tip); }
    for (const t of threads) sh(t.a);
    for (const b of bars) sh(b.from);
    for (const f of flashes) sh(f.a);
    if (dy) {
      for (const g of ghosts) g.g.style.top = (parseFloat(g.g.style.top) + dy) + 'px';
      camY += dy; viewY += dy; docH += dy;
    }
  }
  addEventListener('resize', resize);
  resize();

  const sx = () => scrollX, sy = () => scrollY;

  // ---------- anchors: a point glued to a DOM element ----------
  // Feet always grip a single word (one line box, so its rect is stable);
  // the element that gets mutated may be the whole surrounding link.
  function grab(el) {
    if (!el || !content.contains(el)) return null;
    const w = el.closest('.w'), a = el.closest('a');
    const at = w || a;
    if (!at) return null;
    return { at, mut: a && (!w || R() < .45) ? a : at };
  }

  function anchorPos(an) {
    if (an.el) {
      if (!an.el.isConnected) an.el = null;
      else {
        const r = an.el.getBoundingClientRect();
        if (r.width || r.height) {
          const x = r.left + an.u * r.width + sx(), y = r.top + an.v * r.height + sy();
          // a reflow (neighbour grew, word wrapped to another line) teleports the word:
          // let go and keep the foot where it was instead of being dragged across the page
          if (Math.abs(x - an.x) + Math.abs(y - an.y) > T.jump) an.el = null;
          else { an.x = x; an.y = y; }
        }
      }
    }
    return V(an.x, an.y);
  }

  // sample around P (page coords) for something grabbable; fall back to bare point
  function findAnchor(P, rad = 16, tries = 5) {
    let best = null, bd = 1e9;
    for (let i = 0; i < tries; i++) {
      const q = V(P.x + (R() * 2 - 1) * rad, P.y + (R() * 2 - 1) * rad);
      const vx = q.x - sx(), vy = q.y - sy();
      if (vx < 1 || vy < 1 || vx >= W - 1 || vy >= H - 1) continue;
      const g = grab(document.elementFromPoint(vx, vy));
      if (!g) continue;
      const r = g.at.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      const u = clamp((vx - r.left) / r.width, .08, .92), v = clamp((vy - r.top) / r.height, .25, .75);
      const d = dist(q, P);
      if (d < bd) { bd = d; best = { el: g.at, mut: g.mut, u, v, x: r.left + u * r.width + sx(), y: r.top + v * r.height + sy() }; }
    }
    return best || { el: null, mut: null, u: .5, v: .5, x: P.x, y: P.y };
  }

  // ---------- mutations ----------
  const active = new Map(); // el -> {until}
  const MCLS = ['mut', 'm-box', 'm-box2', 'm-hl', 'm-ink', 'm-mono', 'm-serif', 'm-big', 'm-tiny', 'm-wide',
    'm-upper', 'm-rot', 'm-skew', 'm-under', 'm-strike', 'm-dash', 'm-blink', 'm-pad'];
  const short = el => el.textContent.length < 36;

  function revert(el) {
    el.classList.remove(...MCLS);
    el.style.removeProperty('--mc'); el.style.removeProperty('--mt');
    el.style.removeProperty('--ms'); el.style.removeProperty('--mr');
    active.delete(el);
  }

  // recipes: [weight, el -> {cls, c, t?, s?, life?} | null]
  const RECIPES = [
    [24, () => ({ cls: ['m-box'], c: pick([C.blue, C.blue, C.blue, C.red, C.purple, C.white, C.cyan]) })],
    [6, () => ({ cls: ['m-box2'], c: pick([C.red, C.blue, C.mint]) })],
    [13, () => ({ cls: ['m-hl'], c: pick([C.cyan, C.cyan, C.sky, C.mint, C.orange]), t: '#06061e' })],
    [7, () => ({ cls: ['m-hl'], c: pick([C.blue, '#4f7dff', C.sky]), t: 'transparent' })], // solid bar
    [9, el => short(el) ? ({ cls: ['m-hl', 'm-mono', 'm-big', 'm-pad'], c: pick([C.pink, C.magenta, C.mint, C.cyan]), t: pick(['#fff', '#1a0420', '#04140a']), s: pick(['1.5em', '1.8em', '2.1em']), life: 1.8 }) : null],
    [9, () => ({ cls: ['m-ink', 'm-mono'], c: pick([C.cyan, C.sky, C.white, C.red, C.purple]) })],
    [5, el => short(el) ? ({ cls: ['m-ink', 'm-serif', 'm-big', 'm-wide'], c: pick([C.sky, '#b8c8ff', C.white]), s: pick(['1.7em', '2.2em']), life: 1.6 }) : null],
    [6, el => short(el) ? ({ cls: ['m-ink', 'm-big'], c: pick([C.blue, '#6d8bff', C.cyan]), s: pick(['1.6em', '2em']), life: 1.6 }) : null],
    [5, () => ({ cls: ['m-tiny', 'm-mono', 'm-ink'], c: pick(['#9aa4b8', C.sky, C.white]) })],
    [6, () => ({ cls: ['m-box', 'm-ink'], c: pick([C.red, C.blue, C.purple, C.magenta]) })],
    [4, () => ({ cls: ['m-ink', 'm-under'], c: pick([C.red, C.orange, C.magenta]) })],
    [3, () => ({ cls: ['m-strike'], c: pick([C.red, C.cyan]) })],
    [3, () => ({ cls: ['m-dash', 'm-ink'], c: pick([C.mint, C.yellow]) })],
    [3, () => ({ cls: ['m-skew', 'm-mono', 'm-ink'], c: pick([C.sky, C.white]) })],
    [3, () => ({ cls: ['m-blink', 'm-hl'], c: pick([C.red, C.magenta]), t: '#fff', life: .9 })],
    [2, () => ({ cls: ['m-upper', 'm-mono', 'm-box'], c: C.white })],
  ];
  const RW = RECIPES.reduce((s, r) => s + r[0], 0);

  // ---------- write queues (applied in commit) ----------
  const Q = { mut: [], revert: [], ghost: [], add: [], remove: [], append: false, prune: null };
  const mutate = (el, opts = {}) => { if (el) Q.mut.push([el, opts]); };

  function applyMutation(el, opts) {
    if (!el.isConnected) return;
    if (active.has(el)) revert(el);
    let m = opts.recipe || null;
    if (!m && opts.rot != null && short(el)) {
      m = { cls: ['m-rot', 'm-mono', 'm-ink'], c: pick([C.sky, C.cyan, C.white]), r: opts.rot, life: 1.4 };
    }
    for (let k = 0; k < 6 && !m; k++) {
      let x = R() * RW;
      for (const r of RECIPES) { if ((x -= r[0]) <= 0) { m = r[1](el); break; } }
    }
    if (!m) m = { cls: ['m-box'], c: C.blue };
    el.classList.add('mut', ...m.cls);
    el.style.setProperty('--mc', m.c);
    if (m.t) el.style.setProperty('--mt', m.t);
    if (m.s) el.style.setProperty('--ms', m.s);
    if (m.r != null) el.style.setProperty('--mr', m.r + 'rad');
    const life = (m.life || 1.4 + R() * 3.4) * (opts.lifeMul || 1);
    active.set(el, { until: now + life });
  }

  // ghost: an enlarged monospace echo of an element, drifting off to the side
  const ghosts = [];
  const ghost = el => { if (el) Q.ghost.push(el); };
  function makeGhost(el) { // read phase: measure now, build the node, attach in commit
    if (!el.isConnected) return;
    const r = el.getBoundingClientRect();
    const g = document.createElement('div');
    g.className = 'ghost';
    g.textContent = el.textContent.trim().slice(0, 34);
    g.style.color = pick([C.red, C.sky, C.white, C.blue, C.cyan, '#c9a4ff']);
    g.style.fontSize = (20 + R() * 22) + 'px';
    g.style.opacity = .55 + R() * .4;
    if (R() < .3) g.style.letterSpacing = '.25em';
    g.style.left = (r.left + sx() + (R() * 2 - 1) * 140) + 'px';
    g.style.top = (r.top + sy() + (R() * 2 - 1) * 22) + 'px';
    Q.add.push(g);
    ghosts.push({ g, until: now + .8 + R() * 1.8 });
  }

  // silk bar: element text stretched along a line (anchor -> moving end)
  const bars = [];
  function bar(el, fromAnchor, toFn, color) {
    const b = document.createElement('div');
    b.className = 'bar';
    b.textContent = el ? el.textContent.trim().slice(0, 60) : '';
    b.style.background = color;
    b.style.color = pick(['#fff', '#0a0a2a', 'rgba(255,255,255,.75)']);
    const h = (12 + R() * 14 * SCALE) | 0;
    b.style.height = b.style.lineHeight = h + 'px';
    Q.add.push(b);
    const o = { b, h, from: fromAnchor, to: toFn, until: now + .9 + R() * 1.6, geo: null };
    bars.push(o);
    return o;
  }

  // ---------- spider ----------
  // leg rest angles (rad, relative to heading; +right), reach (px), hip offset along body
  const LEG_DEF = [
    [0.55, 118, 7], [1.15, 106, 3], [1.95, 106, -1], [2.55, 126, -5],
    [0.22, 38, 10], // pedipalp
  ];
  const legs = [];
  for (const side of [1, -1]) {
    LEG_DEF.forEach(([a, reach, hip], i) => {
      const r = reach * SCALE;
      legs.push({
        side, idx: i, ang: a * side, reach: r, hip: hip * SCALE,
        L1: r * .56, L2: r * .64,
        palp: i === 4,
        foot: null, next: null, from: null, t: 0, dur: .15, stepping: false,
        // fixed knee side per leg (front three bend forward, rear leg and palp outward);
        // choosing it per frame made knees flip ~140px mid-stride
        bend: (i === 3 || i === 4 ? 1 : -1) * side,
        tint: null, tintUntil: 0, bar: null,
        knee: V(), tip: V(),
      });
    });
  }
  const LEG_MAX = Math.max(...legs.map(L => L.L1 + L.L2));

  const S = {
    p: V(), v: V(), heading: Math.PI / 2, stopUntil: 0, brake: false,
    target: V(), tUntil: 0, phase: R() * 10,
    abd: V(), spin: V(),
  };

  let now = 0, paused = false, follow = true, followHold = 0;
  let camY = 0, viewY = 0;          // viewY: scroll offset this frame is drawn for (applied in commit)
  let lastY = 0;                    // scroll offset as left by the previous commit()
  let docH = 0, docHAt = -99;       // cached document height (reading it forces layout)

  // The page grows forever, and per-frame rendering cost grows with the DOM (8fps after
  // ~70 min / 120k nodes). Articles the spider has finished reading are swapped for one
  // spacer of identical height, so nothing below moves and the DOM stays small.
  const spacer = document.createElement('div');
  spacer.style.cssText = 'height:0;display:flow-root';
  content.prepend(spacer);
  let spacerH = 0;
  const REBASE = 1e6; // px: then pull the whole world back up (layout units overflow ~33M px)
  const mouse = { x: 0, y: 0, t: -99 };

  const fwd = () => V(Math.cos(S.heading), Math.sin(S.heading));
  const hipPos = L => add(S.p, rot(V(L.hip, L.side * 3 * SCALE), S.heading));
  // where the foot naturally rests relative to the body (no velocity lead)
  const restPos = L => {
    const k = L.palp ? 1 : .8;
    return add(hipPos(L), rot(V(Math.cos(L.ang) * L.reach * k, Math.sin(L.ang) * L.reach * k), S.heading));
  };
  // where a new step should land: rest + capped lead, never beyond the leg's comfortable length
  const stepTarget = L => {
    const h = hipPos(L);
    const p = add(restPos(L), capLen(mul(S.v, T.lead), L.reach * T.leadMax));
    return add(h, capLen(sub(p, h), (L.L1 + L.L2) * T.placeFrac));
  };

  function contentBounds() {
    const r = content.getBoundingClientRect();
    return { l: r.left + sx() + 30, r: r.right + sx() - 30, t: r.top + sy() + 60, b: r.bottom + sy() - 60 };
  }

  // where the body may go: inside the text column AND far enough from the
  // viewport sides that the whole spider stays on screen
  function safeBox() {
    const b = contentBounds();
    const m = Math.min(LEG_MAX * .7, W * .3);
    let l = Math.max(b.l, sx() + m), r = Math.min(b.r, sx() + W - m);
    if (r < l) l = r = (l + r) / 2;
    return { l, r, t: b.t, b: b.b };
  }
  const cameraLocked = () => follow && now > followHold;

  function pickTarget() {
    const s = safeBox();
    // autonomous browsing only ever reads on down the page: every target lies below the body
    if (R() < T.stopChance) { // brief stop, legs idle and twitching
      // aim where momentum coasts to, so the body settles without turning round
      const c = add(S.p, mul(S.v, .3));
      S.target = V(clamp(c.x + (R() * 2 - 1) * 4, s.l, s.r), Math.max(c.y, S.p.y) + R() * 4);
      S.tUntil = S.stopUntil = now + range(T.stopTime); // held for its full duration, not "arrived" at once
      S.brake = true;
      return;
    }
    S.brake = false;
    // centre-weighted lateral wander (sum of 3 uniforms ~ bell curve), kept modest so
    // most of the travel goes down the page rather than across it
    const cx = (s.l + s.r) / 2, half = (s.r - s.l) / 2;
    const g = (R() + R() + R() - 1.5) / 1.5;
    const x = clamp(mix(cx + g * half * .8, S.p.x, .45), s.l, s.r);
    let y = Math.min(S.p.y + range(T.stepY), Math.max(s.b, S.p.y));
    if (!cameraLocked()) { // user took the camera (F / manual scroll): stay inside their view instead
      const gy = (R() + R() + R() - 1.5) / 1.5;
      y = clamp(mix(sy() + H * .5 + gy * H * .25, S.p.y, .25), sy() + H * .25, sy() + H * .75);
    }
    S.target = V(x, y);
    S.tUntil = now + 2 + R() * 3;
  }

  function lureTarget(px, py) {
    const s = safeBox();
    return V(clamp(px, s.l, s.r), clamp(py, sy() + H * .15, sy() + H * .85));
  }

  function stepping() { let n = 0; for (const L of legs) if (L.stepping) n++; return n; }

  function neighbourStepping(L) {
    for (const o of legs) if (o.stepping && o.side === L.side && Math.abs(o.idx - L.idx) === 1 && !o.palp && !L.palp) return true;
    return false;
  }

  function startStep(L, quick) {
    const h = hipPos(L), full = L.L1 + L.L2;
    let from = L.foot ? anchorPos(L.foot) : restPos(L);
    const d = sub(from, h), dl = len(d);
    if (dl > full) from = add(h, mul(d, full / dl)); // never animate a leg from beyond its own length
    L.from = from;
    L.next = findAnchor(stepTarget(L), L.palp ? 8 : 18 * Math.sqrt(SCALE));
    L.t = 0;
    L.dur = quick ? .07 + R() * .04 : (L.palp ? .08 : .1) + R() * .07;
    L.stepping = true;
    if (L.bar) { L.bar.until = Math.min(L.bar.until, now + .15); L.bar = null; }
  }

  function neighbours(el) {
    const out = [];
    for (const n of [el.previousElementSibling, el.nextElementSibling]) {
      if (n && (n.classList.contains('w') || n.tagName === 'A')) out.push(n);
    }
    return out;
  }

  function plant(L) {
    L.stepping = false;
    L.foot = L.next;
    L.next = null;
    flashes.push({ a: L.foot, t: now });
    if (R() < .22) { L.tint = pick([C.green, C.mint]); L.tintUntil = now + 1 + R() * 2; }
    const el = L.foot.mut, word = L.foot.el;
    if (!el) return;
    const fp = anchorPos(L.foot); // may let go of the word (foot.el -> null) after a reflow
    const roll = R();
    if (roll < .1 && !L.palp) {
      L.bar = bar(el, L.foot, () => S.p, pick(['rgba(255,60,200,.78)', 'rgba(70,110,255,.72)', 'rgba(66,207,255,.6)', 'rgba(255,125,69,.7)']));
    } else if (roll < .19) {
      ghost(el);
      mutate(el);
    } else if (roll < .26) {
      const d = sub(fp, S.p);
      mutate(el, { rot: Math.atan2(d.y, d.x) });
    } else {
      mutate(el);
    }
    // infection spreads to the words next to the foot
    if (word && R() < .4) for (const n of neighbours(word)) if (R() < .6) mutate(n, { lifeMul: .7 });
  }

  // ---------- threads: thin silk lines shot at nearby elements ----------
  const threads = [];
  let nextThread = 0, nextAmbient = 0;
  function shootThread() {
    if (threads.length >= T.threadMax) return;
    const a = findAnchor(add(S.p, V((R() * 2 - 1) * T.threadRange, (R() * 2 - 1) * T.threadRange * .8)), 30, 4);
    if (!a.el) return;
    const color = pick(THREAD_COLORS);
    const life = .5 + R() * .9;
    mutate(a.mut, { recipe: { cls: ['m-box'], c: color, life: life + .6 } });
    const t = { a, color, born: now, until: now + life, from: R() < .5 ? 'spin' : 'body', bar: null };
    threads.push(t);
    if (R() < .2) t.bar = bar(a.mut, a, () => S.spin, pick(['rgba(255,60,200,.7)', 'rgba(70,110,255,.65)']));
  }

  const flashes = [];

  // ---------- init ----------
  function init() {
    // start at the top of the first article and read our way down
    const s = safeBox();
    S.p = V((s.l + s.r) / 2, Math.max(s.t + 80, H * .5));
    S.abd = add(S.p, V(0, -17 * SCALE)); S.spin = add(S.p, V(0, -30 * SCALE));
    colX = content.getBoundingClientRect().left + sx();
    camY = S.p.y - H * .5;
    scrollTo(0, camY);
    viewY = lastY = scrollY;
    pickTarget();
    for (const L of legs) { L.foot = findAnchor(restPos(L), 18); }
    setTimeout(() => hint.classList.add('off'), 6000);
  }

  // ---------- update (reads only) ----------
  function update(dt) {
    if (now - docHAt > 1) {
      docH = document.documentElement.scrollHeight; docHAt = now;
      const arts = content.getElementsByClassName('article');
      if (arts.length > 2 && !Q.prune) {
        const top = spacer.getBoundingClientRect().bottom, r0 = arts[0].getBoundingClientRect();
        // well above the view (and not being used by any foot/thread: those stay near the body)
        if (r0.bottom < -2 * H) Q.prune = { el: arts[0], h: arts[1].getBoundingClientRect().top - top };
      }
    }

    // target selection: mouse lure > wander
    const mouseActive = now - mouse.t < 1.6;
    if (mouseActive) {
      S.target = lureTarget(mouse.x + sx(), mouse.y + sy());
    } else if (now > S.tUntil || (now > S.stopUntil && dist(S.p, S.target) < (S.brake ? 26 : T.arrive))) {
      pickTarget();
    }

    // spider-like rhythm: surge / ease, but never a crawl
    S.phase += dt;
    const pulse = Math.pow(Math.max(0, Math.sin(S.phase * 3.1) * .6 + Math.sin(S.phase * 1.27) * .5 + .35), .7);
    const burst = T.burstFloor + (1.15 - T.burstFloor) * Math.min(1, pulse);
    const to = sub(S.target, S.p), d = len(to);
    const maxSpd = (mouseActive ? T.lure : T.cruise) * Math.sqrt(SCALE) * burst;
    // waypoints are flown through at speed; only real destinations (stop, click, mouse) brake
    const brake = mouseActive || S.brake;
    const want = d > 2 ? mul(to, (brake ? Math.min(maxSpd, d * 2.2) : maxSpd) / d) : V();
    S.v = lerp(S.v, want, damp(5, dt));
    S.p = add(S.p, mul(S.v, dt));

    const sp = len(S.v);
    if (sp > 6) S.heading = angLerp(S.heading, Math.atan2(S.v.y, S.v.x), damp(4 + sp * .02, dt));
    S.heading += (R() - .5) * .02;

    // abdomen chain trails the body
    const abdT = add(S.p, mul(fwd(), -17 * SCALE));
    S.abd = lerp(S.abd, abdT, damp(12, dt));
    const sd = sub(S.spin, S.abd), sl = len(sd) || 1;
    S.spin = lerp(S.spin, add(S.abd, mul(sd, 13 * SCALE / sl)), damp(14, dt));

    // legs
    const maxStepping = sp > 70 ? 6 : 4;
    for (const L of legs) {
      if (L.stepping) {
        L.t += dt / L.dur;
        if (L.t >= 1) plant(L);
        continue;
      }
      const fp = L.foot ? anchorPos(L.foot) : restPos(L);
      const off = dist(fp, restPos(L));
      const over = dist(fp, hipPos(L)) > (L.L1 + L.L2) * T.overFrac;
      const urgent = off > L.reach * T.urgentFrac;
      const thresh = L.reach * (L.palp ? .25 : T.stepFrac);
      if (over || urgent) startStep(L, true);
      else if (off > thresh && stepping() < maxStepping && !neighbourStepping(L)) startStep(L, false);
      else if (sp < 4 && R() < dt * .3) startStep(L, false); // idle twitch
    }

    // threads
    if (now > nextThread) { shootThread(); nextThread = now + range(T.threadEvery); }
    for (const t of threads) {
      const o = t.from === 'spin' ? S.spin : S.p;
      const end = anchorPos(t.a); // may let go after a reflow, but keeps the last point
      // body walked away, or the word jumped: reel the thread in now instead of stretching/popping it
      if (t.until > now + .15 && (!t.a.el || dist(o, end) > T.threadRange * 1.25)) t.until = now + .15;
      if (t.bar) t.bar.until = Math.min(t.bar.until, t.until); // its silk bar goes with it
    }

    // ambient infection around the body
    if (now > nextAmbient) {
      for (let i = 0; i < T.ambientPerTick; i++) {
        const a = findAnchor(add(S.p, V((R() * 2 - 1) * LEG_MAX * .85, (R() * 2 - 1) * LEG_MAX * .65)), 10, 1);
        if (a.el) { mutate(a.mut, { lifeMul: .7 }); if (R() < .03) ghost(a.mut); }
      }
      nextAmbient = now + range(T.ambientEvery);
    }
    // ...and along the legs: shins brush the words they pass over
    if (R() < dt * T.shinRate) {
      const L = pick(legs);
      if (!L.palp) {
        const a = findAnchor(lerp(L.knee, L.tip, R() * .7), 4, 1);
        if (a.el) mutate(a.mut, { lifeMul: .5 });
      }
    }

    // expire (queued; the actual DOM work happens in commit)
    for (const [el, m] of active) if (now > m.until) { active.delete(el); Q.revert.push(el); }
    for (let i = threads.length - 1; i >= 0; i--) if (now > threads[i].until) threads.splice(i, 1);
    for (let i = ghosts.length - 1; i >= 0; i--) if (now > ghosts[i].until) { Q.remove.push(ghosts[i].g); ghosts.splice(i, 1); }
    for (let i = bars.length - 1; i >= 0; i--) if (now > bars[i].until) { Q.remove.push(bars[i].b); bars.splice(i, 1); }
    for (let i = flashes.length - 1; i >= 0; i--) if (now - flashes[i].t > .3) flashes.splice(i, 1);

    // endless page: grow when heading toward the bottom
    if (S.p.y > docH - H * 2.5) Q.append = true;

    // camera (with a little look-ahead so the spider sits centred while moving)
    if (cameraLocked()) {
      let ty = S.p.y + Math.max(0, S.v.y) * .35 - H * .5;
      if (!mouseActive && ty < camY) ty = camY; // autonomous: the page only ever scrolls forward
      camY += (ty - camY) * damp(3.2, dt);
      viewY = clamp(Math.round(camY), 0, Math.max(0, docH - H));
    } else {
      camY = viewY = scrollY;
    }
  }

  // ---------- draw (reads + canvas only) ----------
  function line(a, b, color, w = LW) {
    ctx.strokeStyle = color; ctx.lineWidth = w;
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
  }
  const DR = Math.pow(SCALE, .6);
  function dot(p, color, r = 2.4) {
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(p.x, p.y, r * DR, 0, Math.PI * 2); ctx.fill();
  }

  function ik(h, f, L) {
    const d = dist(h, f), base = Math.atan2(f.y - h.y, f.x - h.x);
    if (d >= L.L1 + L.L2 - .01) return add(h, mul(V(Math.cos(base), Math.sin(base)), L.L1));
    const c = clamp((L.L1 * L.L1 + d * d - L.L2 * L.L2) / (2 * L.L1 * d), -1, 1);
    const b = base + L.bend * Math.acos(c);
    return add(h, V(Math.cos(b) * L.L1, Math.sin(b) * L.L1));
  }

  function draw() {
    // reads that commit() will need
    for (const el of Q.ghost) makeGhost(el);
    Q.ghost.length = 0;
    for (const b of bars) {
      const a = anchorPos(b.from), d = sub(b.to(), a);
      b.geo = [a, len(d), Math.atan2(d.y, d.x)];
      if (b.geo[1] > LEG_MAX * 1.3) b.until = Math.min(b.until, now + .1); // never an over-long feeler
    }

    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, W, H);
    const o = V(-sx(), -viewY); // drawn for the scroll position commit() is about to set
    const P = p => add(p, o);

    // threads shoot out, hold, then reel back in
    for (const t of threads) {
      const org = t.from === 'spin' ? S.spin : S.p;
      const end = anchorPos(t.a);
      const e = Math.min(clamp((now - t.born) / .12, 0, 1), clamp((t.until - now) / .15, 0, 1));
      const tip = lerp(org, end, e);
      line(P(org), P(tip), t.color, 1);
      dot(P(tip), t.color, 1.4);
    }

    // legs
    for (const L of legs) {
      const h = hipPos(L);
      let f;
      if (L.stepping) {
        const e = L.t * L.t * (3 - 2 * L.t);
        f = lerp(L.from, anchorPos(L.next), e);
        f = lerp(f, h, Math.sin(Math.PI * L.t) * .18); // lift = pull in slightly
      } else f = L.foot ? anchorPos(L.foot) : restPos(L);
      const k = ik(h, f, L);
      L.knee = k; L.tip = f;
      const tint = L.tint && now < L.tintUntil ? L.tint : null;
      const w = L.palp ? LW * .75 : LW;
      line(P(h), P(k), tint || C.leg, w);
      line(P(k), P(f), tint || (L.idx === 3 ? C.legHi : C.leg), w);
      dot(P(k), C.joint, L.palp ? 1.6 : 2.3);
      dot(P(f), tint || C.joint, L.palp ? 1.4 : 2.1);
    }

    // plant flashes
    for (const fl of flashes) {
      const t = (now - fl.t) / .3, p = P(anchorPos(fl.a));
      ctx.strokeStyle = `rgba(255,74,110,${1 - t})`; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(p.x, p.y, (3 + t * 9) * DR, 0, Math.PI * 2); ctx.stroke();
    }

    // body: cephalothorax box + abdomen chain
    const head = add(S.p, mul(fwd(), 12 * SCALE));
    line(P(head), P(S.p), C.body);
    line(P(S.p), P(S.abd), C.leg, LW * 1.15);
    line(P(S.abd), P(S.spin), C.leg);
    for (const L of legs) if (!L.palp && L.idx % 2 === 0) line(P(S.abd), P(hipPos(L)), 'rgba(92,200,255,.45)', 1);

    const c = P(S.p);
    ctx.save();
    ctx.translate(c.x, c.y); ctx.rotate(S.heading); ctx.scale(SCALE, SCALE);
    ctx.fillStyle = C.bodyFill; ctx.strokeStyle = C.body; ctx.lineWidth = 1.2 / SCALE;
    ctx.fillRect(-8, -5.5, 18, 11); ctx.strokeRect(-8, -5.5, 18, 11);
    ctx.restore();
    dot(P(head), C.joint, 2.2);
    dot(P(S.abd), C.joint, 2.8);
    dot(P(S.spin), C.joint, 2);
  }

  // ---------- commit (all DOM writes, once per frame) ----------
  function commit() {
    for (const el of Q.revert) if (!active.has(el)) revert(el);
    for (const [el, o] of Q.mut) applyMutation(el, o);
    for (const n of Q.remove) n.remove();
    for (const n of Q.add) fx.appendChild(n);
    for (const b of bars) {
      if (!b.geo) continue;
      const [a, l, ang] = b.geo;
      b.b.style.left = a.x + 'px';
      b.b.style.top = (a.y - b.h / 2) + 'px';
      b.b.style.width = l + 'px';
      b.b.style.transform = `rotate(${ang}rad)`;
    }
    Q.revert.length = Q.mut.length = Q.remove.length = Q.add.length = 0;
    if (Q.append) { Q.append = false; window.Arachno.append(); docHAt = -99; }
    if (Q.prune) { // same height in, article out: nothing below moves
      spacerH += Q.prune.h;
      spacer.style.height = spacerH + 'px';
      Q.prune.el.remove();
      Q.prune = null; docHAt = -99;
    }
    if (viewY !== scrollY) scrollTo(scrollX, viewY);
    lastY = scrollY; // read back: the browser may have clamped it
  }

  // spacer got huge: drop it and move the world (and the view) up by the same amount
  function rebase() {
    const dy = -spacerH;
    spacerH = 0;
    spacer.style.height = '0px';
    shiftWorld(0, dy);
    scrollTo(scrollX, viewY);
    lastY = scrollY; docHAt = -99;
  }

  // ---------- loop ----------
  let last = performance.now();
  function frame(t) {
    requestAnimationFrame(frame); // schedule first: one bad frame must not freeze the piece
    const dt = Math.min(.05, (t - last) / 1000);
    last = t;
    // anyone else moved the page (scrollbar, keys, touch, wheel): let them, the camera eases back later
    if (Math.abs(scrollY - lastY) > 1) followHold = now + 2.5;
    if (spacerH > REBASE && cameraLocked()) rebase();
    if (!paused) { now += dt; update(dt); } else viewY = scrollY;
    draw();
    commit();
  }

  // ---------- input ----------
  addEventListener('mousemove', e => {
    if (Math.hypot(e.movementX, e.movementY) > 1.5) mouse.t = now;
    mouse.x = e.clientX; mouse.y = e.clientY;
  });
  addEventListener('mouseout', e => { if (!e.relatedTarget) mouse.t = -99; }); // pointer left the window
  addEventListener('click', e => {
    S.target = lureTarget(e.clientX + sx(), e.clientY + sy());
    S.tUntil = now + 4;
    S.stopUntil = 0;
    S.brake = true; // a destination: slow down and land on it
    mouse.t = -99;
  });
  addEventListener('wheel', () => { followHold = now + 2.5; }, { passive: true });
  addEventListener('keydown', e => {
    if (e.code === 'Space') { paused = !paused; e.preventDefault(); }
    if (e.code === 'KeyF') { follow = !follow; }
  });

  // ?debug exposes internals for measuring (leg extension, speed, pruning)
  if (/[?&]debug\b/.test(location.search)) {
    window.__crawler = { S, legs, threads, hipPos, get now() { return now; }, get spacerH() { return spacerH; }, rebase };
  }

  // let fonts/layout settle before grabbing the first footholds
  requestAnimationFrame(() => requestAnimationFrame(() => { init(); requestAnimationFrame(frame); }));
})();

// Web Crawlers — content script, injected on demand (activeTab) into the current tab.
//
// A procedural spider walks over the page's real words: feet grab words found with
// caretRangeFromPoint + Intl.Segmenter, and each word it touches briefly "glitches".
// The page is NEVER modified: the spider, the glitches, ghosts, silk bars and threads
// are all drawn in one overlay (closed shadow root, pointer-events: none, contain:
// strict) that re-reads the words' positions every frame. Removing the overlay
// leaves the page exactly as it was.
//
// API (isolated world): window.__webCrawler.start(opts) / .stop() / .set(opts) / .running
//   opts = { autoRead: bool, size: 'S'|'M'|'L', density: 'calm'|'normal'|'wild' }
(() => {
  if (window.__webCrawler) return;

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
  const sx = () => window.scrollX, sy = () => window.scrollY;

  const C = {
    leg: '#5cc8ff', legHi: '#9be0ff', joint: '#ff4a6e', body: '#cfe8ff', bodyFill: 'rgba(20,40,130,.75)',
    blue: '#3d6dff', red: '#ff3355', purple: '#b44dff', cyan: '#42cfff', magenta: '#ff36d9', pink: '#ff5ca8',
    orange: '#ff7d45', mint: '#6dffb0', green: '#38ff7a', white: '#f2f2f2', yellow: '#ffe14d', sky: '#8fd8ff',
  };
  const THREAD_COLORS = [C.purple, C.orange, C.magenta, C.red, C.yellow];
  const MONO = '"Courier New", Courier, monospace';
  const SERIF = 'Georgia, "Times New Roman", serif';

  const DENSITY = {
    calm: { ambientEvery: [.14, .32], ambientPerTick: 1, shinRate: 3, threadEvery: [.7, 1.8], threadMax: 3, maxPatches: 50 },
    normal: { ambientEvery: [.06, .15], ambientPerTick: 1, shinRate: 6, threadEvery: [.3, .9], threadMax: 5, maxPatches: 90 },
    wild: { ambientEvery: [.03, .09], ambientPerTick: 2, shinRate: 10, threadEvery: [.16, .5], threadMax: 7, maxPatches: 140 },
  };
  const SIZE = { S: .75, M: 1, L: 1.3 };

  let opts = { autoRead: false, size: 'M', density: 'normal' };
  let D = DENSITY.normal;

  // ---------- overlay ----------
  let host, shadow, cv, ctx, fx;
  const CSS = `
    :host { all: initial; }
    canvas, #fx { position: fixed; left: 0; top: 0; pointer-events: none; }
    #fx { width: 100vw; height: 100vh; overflow: hidden; }
    .p { position: absolute; left: 0; top: 0; white-space: pre; pointer-events: none; transform-origin: 0 0; will-change: transform; }
    .box { box-sizing: border-box; border: 1px solid var(--c); }
    .box2 { box-sizing: border-box; border: 1.5px solid var(--c); }
    .fill { background: var(--c); }
    .txt { line-height: 1; }
    .bar { height: 16px; overflow: hidden; font: 11px/16px ${MONO}; padding-left: 4px; box-sizing: border-box; transform-origin: 0 50%; }
  `;

  function mountOverlay() {
    host = document.createElement('web-crawlers-overlay');
    host.style.cssText = 'all: initial; position: fixed; inset: 0; z-index: 2147483647; pointer-events: none; contain: strict; display: block;';
    shadow = host.attachShadow({ mode: 'closed' });
    const sheet = new CSSStyleSheet();
    sheet.replaceSync(CSS); // constructable sheet: unaffected by the page's CSP style-src
    shadow.adoptedStyleSheets = [sheet];
    fx = document.createElement('div'); fx.id = 'fx';
    cv = document.createElement('canvas');
    shadow.append(fx, cv);
    ctx = cv.getContext('2d');
    document.documentElement.appendChild(host);
  }

  let W = 0, H = 0, DPR = 1;
  function resize() {
    DPR = Math.min(2, devicePixelRatio || 1);
    W = innerWidth; H = innerHeight;
    cv.width = W * DPR; cv.height = H * DPR;
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
  }

  // ---------- reading the page (never writing it) ----------
  const segmenter = 'Segmenter' in Intl ? new Intl.Segmenter(undefined, { granularity: 'word' }) : null;
  const SKIP = 'input, textarea, select, option, script, style, noscript, [contenteditable=""], [contenteditable="true"]';

  // the word under a viewport point, as a live Range (or null)
  function wordAt(vx, vy) {
    const cr = document.caretRangeFromPoint ? document.caretRangeFromPoint(vx, vy) : null;
    if (!cr) return null;
    const node = cr.startContainer;
    if (!node || node.nodeType !== 3 || node.getRootNode() !== document) return null;
    const par = node.parentElement;
    if (!par || par.closest(SKIP)) return null;
    const text = node.data;
    let s, e;
    if (segmenter) {
      const segs = segmenter.segment(text);
      const g = segs.containing(cr.startOffset) || (cr.startOffset > 0 ? segs.containing(cr.startOffset - 1) : null);
      if (!g || !g.isWordLike) return null;
      s = g.index; e = g.index + g.segment.length;
    } else {
      s = e = cr.startOffset;
      while (s > 0 && /[\p{L}\p{N}_]/u.test(text[s - 1])) s--;
      while (e < text.length && /[\p{L}\p{N}_]/u.test(text[e])) e++;
      if (e <= s) return null;
    }
    const rg = document.createRange();
    rg.setStart(node, s); rg.setEnd(node, e);
    const r = rg.getBoundingClientRect();
    if (!r.width || !r.height || r.height > 200) return null;
    // caretRangeFromPoint snaps to the nearest caret: make sure the point is really on the word
    const dx = vx < r.left ? r.left - vx : vx > r.right ? vx - r.right : 0;
    const dy = vy < r.top ? r.top - vy : vy > r.bottom ? vy - r.bottom : 0;
    if (dx + dy > 6) return null;
    return { range: rg, par, text: text.slice(s, e), r };
  }

  // a small non-text thing worth standing on (image, icon, button) under a viewport point.
  // Never a text container: framing a whole paragraph / table looks nothing like the piece.
  const ATOMIC = 'img, svg, picture, video, canvas, button, [role="button"], input, select, kbd, code';
  function elementAt(vx, vy) {
    const hit = document.elementFromPoint(vx, vy);
    const el = hit && hit.closest(ATOMIC);
    if (!el || el === host) return null;
    const r = el.getBoundingClientRect();
    if (!r.width || !r.height || r.width * r.height > W * H * .06) return null;
    return { el, r };
  }

  // anchor = a page-space point glued to a word (range) or an element
  function anchorFrom(P, rad, tries) {
    let best = null, bd = 1e9;
    for (let i = 0; i < tries; i++) {
      const q = V(P.x + (R() * 2 - 1) * rad, P.y + (R() * 2 - 1) * rad);
      const vx = q.x - sx(), vy = q.y - sy();
      if (vx < 1 || vy < 1 || vx >= W - 1 || vy >= H - 1) continue;
      const w = wordAt(vx, vy);
      let a = null;
      if (w) {
        const u = clamp((vx - w.r.left) / w.r.width, .1, .9), v = clamp((vy - w.r.top) / w.r.height, .3, .7);
        const link = w.par.closest('a');
        a = { kind: 'word', range: w.range, par: w.par, text: w.text, link, u, v, x: w.r.left + u * w.r.width + sx(), y: w.r.top + v * w.r.height + sy() };
      } else if (i === tries - 1 || R() < .3) {
        const e = elementAt(vx, vy);
        if (e) {
          const u = clamp((vx - e.r.left) / e.r.width, .1, .9), v = clamp((vy - e.r.top) / e.r.height, .1, .9);
          a = { kind: 'el', el: e.el, u, v, x: e.r.left + u * e.r.width + sx(), y: e.r.top + v * e.r.height + sy() };
        }
      }
      if (!a) continue;
      const d = dist(q, P);
      if (d < bd) { bd = d; best = a; }
    }
    return best || { kind: 'none', x: P.x, y: P.y };
  }

  function targetRect(a) {
    if (a.kind === 'word') {
      if (!a.range.startContainer.isConnected) return null;
      const r = a.range.getBoundingClientRect();
      return r.width || r.height ? r : null;
    }
    if (a.kind === 'el' || a.kind === 'link') {
      if (!a.el.isConnected) return null;
      const r = a.el.getBoundingClientRect();
      return r.width || r.height ? r : null;
    }
    return null;
  }

  const JUMP = 14;
  function anchorPos(a) {
    if (a.kind !== 'none') {
      const r = targetRect(a);
      if (!r) a.kind = 'none';
      else {
        const x = r.left + a.u * r.width + sx(), y = r.top + a.v * r.height + sy();
        // the word moved (reflow, the page changed): let go, keep the foot where it was
        if (Math.abs(x - a.x) + Math.abs(y - a.y) > JUMP) a.kind = 'none';
        else { a.x = x; a.y = y; }
      }
    }
    return V(a.x, a.y);
  }

  // ---------- glitches (overlay patches) ----------
  const bgCache = new WeakMap();
  function bgBehind(el) {
    if (bgCache.has(el)) return bgCache.get(el);
    let out = null;
    for (let e = el; e; e = e.parentElement) {
      const cs = getComputedStyle(e);
      if (cs.backgroundImage !== 'none') break;                      // gradient / image: can't match it
      const m = cs.backgroundColor.match(/rgba?\(([^)]+)\)/);
      if (m) {
        const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
        if (p.length < 4 || p[3] >= .95) { out = cs.backgroundColor; break; }
        if (p[3] > .05) break;                                        // translucent: can't match it
      }
      if (e === document.documentElement) out = matchMedia('(prefers-color-scheme: dark)').matches &&
        /dark/.test(getComputedStyle(e).colorScheme) ? '#121212' : '#ffffff';
    }
    bgCache.set(el, out);
    return out;
  }

  // recipes return a patch spec; cover = paint the page background over the original word first
  const RECIPES = [
    [26, () => ({ k: 'box', c: pick([C.blue, C.blue, C.red, C.purple, C.cyan, C.magenta]) })],
    [6, () => ({ k: 'box2', c: pick([C.red, C.blue, C.mint]) })],
    [13, () => ({ k: 'hl', c: pick([C.cyan, C.sky, C.mint, C.orange, C.yellow]), t: '#06061e' })],
    [6, () => ({ k: 'bar', c: pick([C.blue, '#4f7dff', C.sky]) })],
    [9, () => ({ k: 'hl', c: pick([C.pink, C.magenta, C.mint, C.cyan]), t: pick(['#fff', '#1a0420']), font: MONO, scale: pick([1.5, 1.8, 2.1]), pad: 4 })],
    [9, () => ({ k: 'text', cover: true, t: pick([C.cyan, C.blue, C.red, C.purple, C.magenta]), font: MONO })],
    [5, () => ({ k: 'text', cover: true, t: pick([C.blue, '#6d8bff', C.cyan]), font: SERIF, scale: pick([1.7, 2.2]), spacing: '.35em' })],
    [5, () => ({ k: 'text', cover: true, t: pick([C.blue, C.magenta, C.cyan]), scale: pick([1.6, 2]) })],
    [4, () => ({ k: 'text', cover: true, t: '#8a93a6', font: MONO, scale: .62 })],
    [4, () => ({ k: 'text', cover: true, t: pick([C.red, C.orange, C.magenta]), deco: 'underline wavy' })],
    [3, () => ({ k: 'text', cover: true, t: pick([C.red, C.cyan]), deco: 'line-through' })],
    [3, () => ({ k: 'text', cover: true, t: pick([C.sky, C.blue]), font: MONO, skew: true })],
    [3, () => ({ k: 'hl', c: pick([C.red, C.magenta]), t: '#fff', blink: true, life: .9 })],
    [2, () => ({ k: 'text', cover: true, t: C.blue, font: MONO, upper: true, box: true })],
  ];
  const RW = RECIPES.reduce((s, r) => s + r[0], 0);

  const patches = [];        // { a, nodes, until, born, spec, pending }
  const Q = { add: [], remove: [] };
  let viewY = 0, lastY = 0;

  function glitch(a, o = {}) {
    if (!a || a.kind === 'none') return;
    let spec = o.spec;
    // whole links sometimes, like the art piece
    const target = a.kind === 'word' && a.link && R() < .35 ? { kind: 'link', el: a.link, u: .5, v: .5, x: a.x, y: a.y } : a;
    if (!spec) {
      if (o.rot != null && target.kind === 'word') spec = { k: 'text', cover: true, t: pick([C.blue, C.cyan, C.purple]), font: MONO, rot: o.rot, life: 1.4 };
      else {
        let x = R() * RW;
        for (const r of RECIPES) if ((x -= r[0]) <= 0) { spec = r[1](); break; }
      }
    }
    if (target.kind !== 'word' && (spec.k === 'text' || spec.k === 'hl')) spec = { k: R() < .7 ? 'box' : 'box2', c: spec.c || pick([C.blue, C.red, C.purple]) };
    let bg = null;
    if (spec.cover) {
      bg = bgBehind(target.par);
      if (!bg) spec = { k: 'hl', c: pick([C.cyan, C.mint, C.yellow]), t: '#06061e' }; // can't hide the original: highlight instead
    }
    const nodes = [];
    const mk = cls => { const n = document.createElement('div'); n.className = 'p ' + cls; nodes.push(n); return n; };
    if (spec.k === 'box' || spec.k === 'box2') { const n = mk(spec.k); n.style.setProperty('--c', spec.c); }
    else if (spec.k === 'bar') { const n = mk('fill'); n.style.setProperty('--c', spec.c); }
    else {
      const cs = getComputedStyle(target.par);
      if (spec.cover) { const n = mk('fill'); n.style.setProperty('--c', bg); }
      const t = mk('txt');
      t.textContent = spec.upper ? target.text.toUpperCase() : target.text;
      const size = parseFloat(cs.fontSize) * (spec.scale || 1);
      t.style.font = `${cs.fontStyle} ${cs.fontWeight} ${size}px ${spec.font || cs.fontFamily}`;
      t.style.color = spec.t || cs.color;
      if (spec.k === 'hl') { t.style.background = spec.c; t.style.padding = `0 ${spec.pad || 1}px`; }
      if (spec.spacing) t.style.letterSpacing = spec.spacing;
      if (spec.deco) t.style.textDecoration = `${spec.deco} ${spec.t}`;
      if (spec.box) t.style.outline = `1px solid ${spec.t}`;
      t.dataset.scale = spec.scale || 1;
    }
    const life = (spec.life || 1.4 + R() * 3.2) * (o.lifeMul || 1);
    const p = { a: target, nodes, spec, born: now, until: now + life, blink: !!spec.blink };
    patches.push(p);
    Q.add.push(...nodes);
    while (patches.length > D.maxPatches) Q.remove.push(...patches.shift().nodes);
  }

  // big monospace echo drifting next to a word
  const ghosts = [];
  function ghost(a) {
    if (!a || a.kind !== 'word') return;
    const g = document.createElement('div');
    g.className = 'p txt';
    g.textContent = a.text.slice(0, 34);
    g.style.font = `${20 + R() * 20}px ${MONO}`;
    g.style.color = pick([C.red, C.sky, C.blue, C.cyan, C.purple]);
    g.style.opacity = .5 + R() * .4;
    if (R() < .3) g.style.letterSpacing = '.25em';
    Q.add.push(g);
    ghosts.push({ g, x: a.x + (R() * 2 - 1) * 140, y: a.y + (R() * 2 - 1) * 22, until: now + .8 + R() * 1.8 });
  }

  // silk bar: a word's text stretched from an anchor to a moving point
  const bars = [];
  function bar(a, toFn, color) {
    const b = document.createElement('div');
    b.className = 'p bar';
    b.textContent = a.text || '';
    b.style.background = color;
    b.style.color = pick(['#fff', '#0a0a2a']);
    const h = (12 + R() * 12 * SCALE) | 0;
    b.style.height = b.style.lineHeight = h + 'px';
    Q.add.push(b);
    const o = { b, h, a, to: toFn, until: now + .9 + R() * 1.4, geo: null };
    bars.push(o);
    return o;
  }

  // ---------- spider ----------
  let SCALE = 1, LW = 1.25, LEG_MAX = 200;
  const LEG_DEF = [[0.55, 118, 7], [1.15, 106, 3], [1.95, 106, -1], [2.55, 126, -5], [0.22, 38, 10]];
  let legs = [];
  function buildLegs() {
    SCALE = SIZE[opts.size] * (innerWidth < 640 ? .8 : 1);
    LW = 1.25 * Math.sqrt(SCALE);
    legs = [];
    for (const side of [1, -1]) {
      LEG_DEF.forEach(([a, reach, hip], i) => {
        const r = reach * SCALE;
        legs.push({
          side, idx: i, ang: a * side, reach: r, hip: hip * SCALE, L1: r * .56, L2: r * .64, palp: i === 4,
          bend: (i === 3 || i === 4 ? 1 : -1) * side,
          foot: null, next: null, from: null, t: 0, dur: .15, stepping: false,
          tint: null, tintUntil: 0, bar: null, knee: V(), tip: V(),
        });
      });
    }
    LEG_MAX = Math.max(...legs.map(L => L.L1 + L.L2));
  }

  const T = {
    cruise: 170, lure: 240, burstFloor: .55, stopChance: .08, stopTime: [.35, .9], arrive: 50,
    stepFrac: .3, urgentFrac: .5, overFrac: .92, placeFrac: .85, lead: .3, leadMax: .3, stepY: [140, 420],
  };

  const S = { p: V(), v: V(), heading: Math.PI / 2, target: V(), tUntil: 0, stopUntil: 0, brake: false, phase: 0, abd: V(), spin: V() };
  let now = 0, raf = 0, last = 0, camY = 0, followHold = 0, docH = 0, docHAt = -99, ownScroll = false;
  const mouse = { x: 0, y: 0, t: -99 };
  const threads = [], flashes = [];
  let nextThread = 0, nextAmbient = 0;

  const fwd = () => V(Math.cos(S.heading), Math.sin(S.heading));
  const hipPos = L => add(S.p, rot(V(L.hip, L.side * 3 * SCALE), S.heading));
  const restPos = L => { const k = L.palp ? 1 : .8; return add(hipPos(L), rot(V(Math.cos(L.ang) * L.reach * k, Math.sin(L.ang) * L.reach * k), S.heading)); };
  const stepTarget = L => {
    const h = hipPos(L);
    const p = add(restPos(L), capLen(mul(S.v, T.lead), L.reach * T.leadMax));
    return add(h, capLen(sub(p, h), (L.L1 + L.L2) * T.placeFrac));
  };

  const reading = () => opts.autoRead && now > followHold;
  function viewBox() {
    const m = Math.min(LEG_MAX * .6, W * .3), mv = Math.min(LEG_MAX * .6, H * .3);
    return { l: sx() + m, r: sx() + W - m, t: sy() + mv, b: sy() + H - mv };
  }

  function pickTarget() {
    const s = viewBox();
    if (R() < T.stopChance) {
      const c = add(S.p, mul(S.v, .3));
      S.target = V(clamp(c.x, s.l, s.r), c.y);
      S.tUntil = S.stopUntil = now + range(T.stopTime);
      S.brake = true;
      return;
    }
    S.brake = false;
    const g = (R() + R() + R() - 1.5) / 1.5;
    const x = clamp(mix((s.l + s.r) / 2 + g * (s.r - s.l) / 2 * .8, S.p.x, .4), s.l, s.r);
    let y;
    const atBottom = sy() + H >= docH - 4;
    if (reading() && !atBottom) {
      y = S.p.y + range(T.stepY);                                     // read on down the page
    } else {                                                         // stay in the visible band
      const gy = (R() + R() + R() - 1.5) / 1.5;
      y = clamp(mix((s.t + s.b) / 2 + gy * (s.b - s.t) / 2, S.p.y, .25), s.t, s.b);
    }
    S.target = V(x, y);
    S.tUntil = now + 2 + R() * 3;
  }

  function stepping() { let n = 0; for (const L of legs) if (L.stepping) n++; return n; }
  function neighbourStepping(L) {
    for (const o of legs) if (o.stepping && o.side === L.side && Math.abs(o.idx - L.idx) === 1 && !o.palp && !L.palp) return true;
    return false;
  }

  // a foothold near the step target that is really within reach: the word search
  // around the target can drift ~25 px, which is a lot for a 150 px leg
  function foothold(L) {
    const h = hipPos(L), tgt = stepTarget(L), lim = (L.L1 + L.L2) * T.placeFrac + 6;
    const rad = L.palp ? 8 : 18 * Math.sqrt(SCALE);
    let a = anchorFrom(tgt, rad, 4);
    if (dist(V(a.x, a.y), h) > lim) a = anchorFrom(tgt, rad * .35, 3);   // too far: look closer
    if (dist(V(a.x, a.y), h) > lim) a = { kind: 'none', x: tgt.x, y: tgt.y }; // still too far: bare ground
    return a;
  }

  function startStep(L, quick) {
    const h = hipPos(L), full = L.L1 + L.L2;
    let from = L.foot ? anchorPos(L.foot) : restPos(L);
    const d = sub(from, h), dl = len(d);
    if (dl > full) from = add(h, mul(d, full / dl));
    L.from = from;
    L.next = foothold(L);
    L.t = 0;
    L.dur = quick ? .07 + R() * .04 : (L.palp ? .08 : .1) + R() * .07;
    L.stepping = true;
    L.retarget = false;
    if (L.bar) { L.bar.until = Math.min(L.bar.until, now + .15); L.bar = null; }
  }

  function plant(L) {
    L.stepping = false;
    L.foot = L.next; L.next = null;
    flashes.push({ a: L.foot, t: now });
    if (R() < .22) { L.tint = pick([C.green, C.mint]); L.tintUntil = now + 1 + R() * 2; }
    if (L.foot.kind === 'none') return;
    const fp = anchorPos(L.foot);
    const roll = R();
    if (roll < .08 && !L.palp && L.foot.kind === 'word') {
      L.bar = bar(L.foot, () => S.p, pick(['rgba(255,60,200,.78)', 'rgba(70,110,255,.72)', 'rgba(66,207,255,.6)', 'rgba(255,125,69,.7)']));
    } else if (roll < .16) {
      ghost(L.foot); glitch(L.foot);
    } else if (roll < .22) {
      const d = sub(fp, S.p); glitch(L.foot, { rot: Math.atan2(d.y, d.x) });
    } else glitch(L.foot);
  }

  function shootThread() {
    if (threads.length >= D.threadMax) return;
    const a = anchorFrom(add(S.p, V((R() * 2 - 1) * 240, (R() * 2 - 1) * 190)), 30, 3);
    if (a.kind === 'none') return;
    const color = pick(THREAD_COLORS), life = .5 + R() * .9;
    glitch(a, { spec: { k: 'box', c: color, life: life + .6 } });
    const t = { a, color, born: now, until: now + life, from: R() < .5 ? 'spin' : 'body', bar: null };
    threads.push(t);
    if (R() < .2 && a.kind === 'word') t.bar = bar(a, () => S.spin, pick(['rgba(255,60,200,.7)', 'rgba(70,110,255,.65)']));
  }

  // the user scrolled the spider out of view: bring it back from the nearest edge
  function recover() {
    const vy = S.p.y - sy(), vx = S.p.x - sx();
    if (vy > -H * .6 && vy < H * 1.6 && vx > -W * .5 && vx < W * 1.5) return;
    const p = V(clamp(vx, W * .25, W * .75) + sx(), (vy < 0 ? -LEG_MAX * .5 : H + LEG_MAX * .5) + sy());
    const d = sub(p, S.p);
    S.p = p; S.abd = add(S.abd, d); S.spin = add(S.spin, d);
    for (const L of legs) { L.stepping = false; L.foot = { kind: 'none', x: restPos(L).x, y: restPos(L).y }; }
    pickTarget();
  }

  // ---------- update (reads only) ----------
  function update(dt) {
    if (now - docHAt > 1) { docH = Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0); docHAt = now; }
    recover();

    const mouseActive = now - mouse.t < 1.2;
    if (mouseActive) {
      const s = viewBox();
      S.target = V(clamp(mouse.x + sx(), s.l, s.r), clamp(mouse.y + sy(), s.t, s.b));
    } else if (now > S.tUntil || (now > S.stopUntil && dist(S.p, S.target) < (S.brake ? 26 : T.arrive))) pickTarget();

    S.phase += dt;
    const pulse = Math.pow(Math.max(0, Math.sin(S.phase * 3.1) * .6 + Math.sin(S.phase * 1.27) * .5 + .35), .7);
    const burst = T.burstFloor + (1.15 - T.burstFloor) * Math.min(1, pulse);
    const to = sub(S.target, S.p), d = len(to);
    const maxSpd = (mouseActive ? T.lure : T.cruise) * Math.sqrt(SCALE) * burst;
    const brake = mouseActive || S.brake || !reading();
    const want = d > 2 ? mul(to, (brake ? Math.min(maxSpd, d * 2.2) : maxSpd) / d) : V();
    S.v = lerp(S.v, want, damp(5, dt));
    S.p = add(S.p, mul(S.v, dt));
    const sp = len(S.v);
    if (sp > 6) S.heading = angLerp(S.heading, Math.atan2(S.v.y, S.v.x), damp(4 + sp * .02, dt));
    S.heading += (R() - .5) * .02;
    S.abd = lerp(S.abd, add(S.p, mul(fwd(), -17 * SCALE)), damp(12, dt));
    const sd = sub(S.spin, S.abd), sl = len(sd) || 1;
    S.spin = lerp(S.spin, add(S.abd, mul(sd, 13 * SCALE / sl)), damp(14, dt));

    const maxStepping = sp > 70 ? 6 : 4;
    for (const L of legs) {
      if (L.stepping) {
        L.t += dt / L.dur;
        // the body kept moving during the step: if the chosen foothold is now out of reach, pick a closer one (once)
        if (!L.retarget && dist(anchorPos(L.next), hipPos(L)) > (L.L1 + L.L2) * T.overFrac) {
          L.next = foothold(L);
          L.retarget = true;
        }
        if (L.t >= 1) {
          plant(L);
          // landed out of reach anyway (the body kept going): lift it again right away
          if (dist(anchorPos(L.foot), hipPos(L)) > (L.L1 + L.L2) * T.overFrac) startStep(L, true);
        }
        continue;
      }
      const fp = L.foot ? anchorPos(L.foot) : restPos(L);
      const off = dist(fp, restPos(L));
      const over = dist(fp, hipPos(L)) > (L.L1 + L.L2) * T.overFrac;
      const urgent = off > L.reach * T.urgentFrac;
      if (over || urgent) startStep(L, true);
      else if (off > L.reach * (L.palp ? .25 : T.stepFrac) && stepping() < maxStepping && !neighbourStepping(L)) startStep(L, false);
      else if (sp < 4 && R() < dt * .3) startStep(L, false);
    }

    if (now > nextThread) { shootThread(); nextThread = now + range(D.threadEvery); }
    for (const t of threads) {
      const o = t.from === 'spin' ? S.spin : S.p, end = anchorPos(t.a);
      if (t.until > now + .15 && (t.a.kind === 'none' || dist(o, end) > 300)) t.until = now + .15;
      if (t.bar) t.bar.until = Math.min(t.bar.until, t.until);
    }
    if (now > nextAmbient) {
      for (let i = 0; i < D.ambientPerTick; i++) {
        const a = anchorFrom(add(S.p, V((R() * 2 - 1) * LEG_MAX * .85, (R() * 2 - 1) * LEG_MAX * .65)), 10, 1);
        if (a.kind !== 'none') { glitch(a, { lifeMul: .7 }); if (R() < .03) ghost(a); }
      }
      nextAmbient = now + range(D.ambientEvery);
    }
    if (R() < dt * D.shinRate) {
      const L = pick(legs);
      if (!L.palp) { const a = anchorFrom(lerp(L.knee, L.tip, R() * .7), 4, 1); if (a.kind !== 'none') glitch(a, { lifeMul: .5 }); }
    }

    for (let i = patches.length - 1; i >= 0; i--) if (now > patches[i].until) { Q.remove.push(...patches[i].nodes); patches.splice(i, 1); }
    for (let i = threads.length - 1; i >= 0; i--) if (now > threads[i].until) threads.splice(i, 1);
    for (let i = ghosts.length - 1; i >= 0; i--) if (now > ghosts[i].until) { Q.remove.push(ghosts[i].g); ghosts.splice(i, 1); }
    for (let i = bars.length - 1; i >= 0; i--) if (now > bars[i].until) { Q.remove.push(bars[i].b); bars.splice(i, 1); }
    for (let i = flashes.length - 1; i >= 0; i--) if (now - flashes[i].t > .3) flashes.splice(i, 1);

    // camera: only in auto-read mode, only forward, and never against the user
    ownScroll = reading() && !mouseActive;
    if (ownScroll) {
      let ty = S.p.y + Math.max(0, S.v.y) * .35 - H * .5;
      if (ty < camY) ty = camY;
      camY += (ty - camY) * damp(3.2, dt);
      viewY = clamp(Math.round(camY), 0, Math.max(0, docH - H));
    } else {
      camY = viewY = sy();
    }
  }

  // ---------- draw (reads + canvas) ----------
  function line(a, b, color, w = LW) { ctx.strokeStyle = color; ctx.lineWidth = w; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke(); }
  function dot(p, color, r) { ctx.fillStyle = color; ctx.beginPath(); ctx.arc(p.x, p.y, r * Math.pow(SCALE, .6), 0, Math.PI * 2); ctx.fill(); }
  function ik(h, f, L) {
    const d = dist(h, f), base = Math.atan2(f.y - h.y, f.x - h.x);
    if (d >= L.L1 + L.L2 - .01) return add(h, mul(V(Math.cos(base), Math.sin(base)), L.L1));
    const c = clamp((L.L1 * L.L1 + d * d - L.L2 * L.L2) / (2 * L.L1 * d), -1, 1);
    const b = base + L.bend * Math.acos(c);
    return add(h, V(Math.cos(b) * L.L1, Math.sin(b) * L.L1));
  }

  const layout = [];   // [node, transform, extra] computed here, written in commit()
  function draw() {
    const ox = -sx(), oy = -viewY, shift = sy() - viewY;   // drawn for the scroll position commit() sets
    const P = p => V(p.x + ox, p.y + oy);
    layout.length = 0;

    for (const p of patches) {
      const r = targetRect(p.a);
      if (!r) { p.until = Math.min(p.until, now); continue; }
      const x = r.left, y = r.top + shift, s = p.spec;
      const vis = p.blink ? ((now * 1000 / 70) | 0) % 2 === 0 : true;
      let i = 0;
      if (s.k === 'box' || s.k === 'box2') {
        const o = s.k === 'box' ? 1 : 3;
        layout.push([p.nodes[0], `translate(${x - o}px,${y - o}px)`, { width: r.width + 2 * o, height: r.height + 2 * o }]);
        continue;
      }
      if (s.k === 'bar') { layout.push([p.nodes[0], `translate(${x}px,${y}px)`, { width: r.width, height: r.height }]); continue; }
      if (s.cover) layout.push([p.nodes[i++], `translate(${x - 1}px,${y - 1}px)`, { width: r.width + 2, height: r.height + 2 }]);
      const t = p.nodes[i], sc = +t.dataset.scale || 1;
      const h = r.height * sc;
      let tf = `translate(${x - (s.k === 'hl' ? (s.pad || 1) : 0)}px,${y + r.height / 2 - h / 2}px)`;
      if (s.rot != null) tf += ` translate(${r.width / 2}px,${h / 2}px) rotate(${s.rot}rad) translate(${-r.width / 2}px,${-h / 2}px)`;
      if (s.skew) tf += ' skewX(-20deg)';
      layout.push([t, tf, { opacity: vis ? 1 : .15 }]);
    }
    for (const g of ghosts) layout.push([g.g, `translate(${g.x + ox}px,${g.y + oy}px)`, null]);
    for (const b of bars) {
      const a = anchorPos(b.a), d = sub(b.to(), a);
      layout.push([b.b, `translate(${a.x + ox}px,${a.y + oy - b.h / 2}px) rotate(${Math.atan2(d.y, d.x)}rad)`, { width: len(d) }]);
    }

    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, W, H);
    for (const t of threads) {
      const org = t.from === 'spin' ? S.spin : S.p, end = anchorPos(t.a);
      const e = Math.min(clamp((now - t.born) / .12, 0, 1), clamp((t.until - now) / .15, 0, 1));
      const tip = lerp(org, end, e);
      line(P(org), P(tip), t.color, 1); dot(P(tip), t.color, 1.4);
    }
    for (const L of legs) {
      const h = hipPos(L);
      let f;
      if (L.stepping) {
        const e = L.t * L.t * (3 - 2 * L.t);
        f = lerp(lerp(L.from, anchorPos(L.next), e), h, Math.sin(Math.PI * L.t) * .18);
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
    for (const fl of flashes) {
      const t = (now - fl.t) / .3, p = P(anchorPos(fl.a));
      ctx.strokeStyle = `rgba(255,74,110,${1 - t})`; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(p.x, p.y, (3 + t * 9) * Math.pow(SCALE, .6), 0, Math.PI * 2); ctx.stroke();
    }
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
    dot(P(head), C.joint, 2.2); dot(P(S.abd), C.joint, 2.8); dot(P(S.spin), C.joint, 2);
  }

  // ---------- commit (writes: overlay nodes, and the scroll in auto-read mode) ----------
  function commit() {
    for (const n of Q.remove) n.remove();
    for (const n of Q.add) fx.appendChild(n);
    Q.remove.length = Q.add.length = 0;
    for (const [n, tf, extra] of layout) {
      n.style.transform = tf;
      if (extra) {
        if (extra.width != null) n.style.width = extra.width + 'px';
        if (extra.height != null) n.style.height = extra.height + 'px';
        if (extra.opacity != null) n.style.opacity = extra.opacity;
      }
    }
    if (ownScroll && Math.abs(viewY - sy()) >= 1) window.scrollTo({ left: sx(), top: viewY, behavior: 'instant' });
    lastY = sy();
    if (!host.isConnected) document.documentElement.appendChild(host); // a page script removed it
  }

  function frame(t) {
    raf = requestAnimationFrame(frame);
    const dt = Math.min(.05, (t - last) / 1000);
    last = t;
    if (Math.abs(sy() - lastY) > 1) followHold = now + 2.5;   // the user scrolled: let them
    now += dt;
    update(dt);
    draw();
    commit();
  }

  // ---------- lifecycle ----------
  const onMove = e => { if (Math.hypot(e.movementX, e.movementY) > 1.5) mouse.t = now; mouse.x = e.clientX; mouse.y = e.clientY; };
  const onOut = e => { if (!e.relatedTarget) mouse.t = -99; };

  function set(o) {
    const sizeChanged = o && o.size && o.size !== opts.size;
    opts = { ...opts, ...(o || {}) };
    D = DENSITY[opts.density] || DENSITY.normal;
    if (sizeChanged && api.running) {
      buildLegs();
      for (const L of legs) L.foot = anchorFrom(restPos(L), 18, 4);
    }
  }

  function start(o) {
    if (api.running) { set(o); return true; }
    set(o);
    mountOverlay();
    resize();
    buildLegs();
    // enter from the top of the current view, near the middle
    S.p = V(sx() + W * (.4 + R() * .2), sy() + Math.min(H * .35, 260));
    S.v = V(); S.heading = Math.PI / 2;
    S.abd = add(S.p, V(0, -17 * SCALE)); S.spin = add(S.p, V(0, -30 * SCALE));
    camY = viewY = lastY = sy();
    docHAt = -99;
    for (const L of legs) L.foot = anchorFrom(restPos(L), 18, 4);
    pickTarget();
    addEventListener('resize', resize);
    addEventListener('mousemove', onMove, { passive: true, capture: true });
    addEventListener('mouseout', onOut, { passive: true, capture: true });
    last = performance.now();
    raf = requestAnimationFrame(frame);
    api.running = true;
    return true;
  }

  function stop() {
    if (!api.running) return false;
    cancelAnimationFrame(raf);
    removeEventListener('resize', resize);
    removeEventListener('mousemove', onMove, { capture: true });
    removeEventListener('mouseout', onOut, { capture: true });
    host.remove();
    patches.length = threads.length = ghosts.length = bars.length = flashes.length = 0;
    Q.add.length = Q.remove.length = 0;
    api.running = false;
    return true;
  }

  // read-only numbers for testing / curiosity
  function stats() {
    const ext = legs.filter(L => !L.stepping && L.foot).map(L => dist(V(L.foot.x, L.foot.y), hipPos(L)) / (L.L1 + L.L2));
    return {
      running: api.running, t: +now.toFixed(2),
      spider: { vx: +((S.p.x - sx()) / W).toFixed(3), vy: +((S.p.y - sy()) / H).toFixed(3), speed: Math.round(len(S.v)) },
      feet: legs.length, feetOnWords: legs.filter(L => L.foot && L.foot.kind === 'word').length,
      maxLegExt: +Math.max(0, ...ext).toFixed(3),
      patches: patches.length, threads: threads.length, ghosts: ghosts.length, bars: bars.length,
      overlayNodes: fx ? fx.childElementCount : 0,
    };
  }

  const api = window.__webCrawler = { running: false, start, stop, set, stats, get options() { return { ...opts }; } };
})();

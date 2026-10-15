// Deterministic frame-by-frame capture of the crawler page into a video.
//
//   node render.mjs                 full 22 s, 60 fps, 1080x1080 -> out/web-crawlers.mp4
//   node render.mjs --seconds 6     quick preview of the first 6 s
//   node render.mjs --from 20 --seconds 8   (still simulates 0..20 s, only encodes 20..28 s)
//   node render.mjs --mux           only re-mux build/video.mp4 + build/music.wav (new music, no re-render)
//
// The page runs on a virtual clock (rAF / performance.now / setTimeout are
// replaced before any page script runs) and a seeded Math.random, so every
// frame is exact no matter how long a screenshot takes, and every render of
// the same seed is identical. Title card, a scripted cursor and the
// end card are drawn by an overlay injected into the page (pointer-events:
// none, so the spider never steps on it). If build/music.wav exists it is
// muxed in.
import puppeteer from 'puppeteer-core';
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const arg = (name, def) => {
  const i = process.argv.indexOf('--' + name);
  return i > 0 ? process.argv[i + 1] : def;
};

const FPS = +arg('fps', 60);
const FROM = +arg('from', 0);
const TOTAL = 22;                                  // must match music.py (11 bars @ 120 BPM)
const SECONDS = +arg('seconds', TOTAL - FROM);
const SEED = +arg('seed', 20261002);
const VIEW = 720, DSF = 1.5;                       // 720 css px * 1.5 = 1080 px video
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const BUILD = path.join(HERE, 'build'), OUT = path.join(HERE, 'out');
const silent = path.join(BUILD, FROM || SECONDS < TOTAL ? 'preview.mp4' : 'video.mp4');
const music = path.join(BUILD, 'music.wav');
const final = path.join(OUT, FROM || SECONDS < TOTAL ? 'preview.mp4' : 'web-crawlers.mp4');
mkdirSync(BUILD, { recursive: true }); mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------------------
// runs inside the page before its own scripts
function inject(SEED) {
  // seeded RNG (mulberry32): page content and spider behaviour become reproducible
  let s = SEED >>> 0;
  Math.random = () => {
    s = (s + 0x6D2B79F5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  // virtual clock
  let vt = 0, rid = 0;
  const rafs = new Map();
  let timers = [];
  performance.now = () => vt;
  window.requestAnimationFrame = cb => (rafs.set(++rid, cb), rid);
  window.cancelAnimationFrame = id => rafs.delete(id);
  window.setTimeout = (fn, ms = 0, ...a) => (timers.push({ at: vt + ms, fn: () => fn(...a) }), timers.length);

  const listeners = [];
  window.__onTick = fn => listeners.push(fn);
  window.__tick = ms => {
    vt += ms;
    const due = timers.filter(t => t.at <= vt);
    timers = timers.filter(t => t.at > vt);
    due.forEach(t => t.fn());
    const cbs = [...rafs.values()];
    rafs.clear();
    cbs.forEach(cb => cb(vt));
    listeners.forEach(fn => fn(vt / 1000));
  };

  document.addEventListener('DOMContentLoaded', () => window.__stage && window.__stage());
}

// overlay: title, cursor, end card (by cyohei9907, inspired by @rybinfx) — all driven by virtual time
function stage() {
  const css = `
    #hint { display: none !important; }
    html.blink-off .m-blink { opacity: .15 !important; }
    .m-blink { animation: none !important; }
    #stage { position: fixed; inset: 0; z-index: 50; pointer-events: none; font-family: "Segoe UI", Arial, sans-serif; }
    #stage * { pointer-events: none; }
    .card { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center;
            background: radial-gradient(ellipse at center, rgba(0,0,0,.8) 0%, rgba(0,0,0,.93) 70%); opacity: 0; }
    .card .t { font: 700 64px/1 "Courier New", monospace; color: #f2f2f2; letter-spacing: .02em; white-space: nowrap; }
    .card .t span { display: inline-block; padding: 0 .02em; }
    .card .g { font: 400 34px/1 "Courier New", monospace; color: #5cc8ff; margin-top: 18px; letter-spacing: .1em; }
    .card .s { font-size: 19px; color: #a2a9b1; margin-top: 26px; letter-spacing: .04em; text-align: center; line-height: 1.6; }
    .card .s b { color: #e8e9eb; font-weight: 600; }
    .cursor { position: absolute; width: 26px; height: 26px; opacity: 0; transform-origin: 0 0; }
    .ripple { position: absolute; width: 10px; height: 10px; margin: -5px 0 0 -5px; border: 2px solid #ffe14d; border-radius: 50%; opacity: 0; }
    .fade { position: absolute; inset: 0; background: #000; opacity: 0; }
  `;
  const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
  const root = document.createElement('div'); root.id = 'stage'; document.body.appendChild(root);

  const TITLE = 'Web crawlers';
  const mkCard = (sub) => {
    const c = document.createElement('div'); c.className = 'card';
    c.innerHTML = `<div class="t">${[...TITLE].map(ch => `<span class="tl">${ch === ' ' ? '&nbsp;' : ch}</span>`).join('')}</div>
      <div class="g">/[•]\\</div><div class="s">${sub}</div>`;
    root.appendChild(c);
    return c;
  };
  const intro = mkCard('');
  const outro = mkCard('<b>by cyohei9907</b><br>inspired by @rybinfx');

  const cursor = document.createElement('div'); cursor.className = 'cursor';
  cursor.innerHTML = `<svg viewBox="0 0 26 26" width="26" height="26"><path d="M3 2 L3 21 L8.5 16 L12.5 24.5 L16 23 L12 14.8 L19.5 14.8 Z" fill="#fff" stroke="#000" stroke-width="1.6" stroke-linejoin="round"/></svg>`;
  root.appendChild(cursor);
  const ripple = document.createElement('div'); ripple.className = 'ripple'; root.appendChild(ripple);
  const fade = document.createElement('div'); fade.className = 'fade'; root.appendChild(fade);

  const ease = t => t < 0 ? 0 : t > 1 ? 1 : t * t * (3 - 2 * t);
  const hash = (i, k) => { let x = (i * 374761393 + k * 668265263) | 0; x = Math.imul(x ^ (x >>> 13), 1274126177); return ((x ^ (x >>> 16)) >>> 0) / 4294967296; };
  const COLORS = ['#3d6dff', '#ff3355', '#42cfff', '#ff36d9', '#6dffb0', '#ffe14d', '#b44dff'];

  // title letters glitch in with the page's own mutation classes
  function glitchTitle(card, t, frame) {
    card.querySelectorAll('.tl').forEach((s, i) => {
      const on = t > .06 * i;                                   // letters arrive one by one
      s.style.visibility = on ? 'visible' : 'hidden';
      const settle = t - .06 * i;
      const flick = settle < .35 || hash(frame >> 2, i) < .05;  // settling, then rare flickers
      s.className = 'tl';
      s.style.removeProperty('--mc'); s.style.removeProperty('--mt');
      if (on && flick) {
        const k = hash(frame >> 1, i + 31);
        s.classList.add('mut', k < .4 ? 'm-box' : k < .75 ? 'm-hl' : 'm-ink');
        s.style.setProperty('--mc', COLORS[(hash(frame >> 2, i + 7) * COLORS.length) | 0]);
        s.style.setProperty('--mt', '#05051a');
      }
    });
  }

  // scripted pointer: lure (10-12.8 s), then a click (13 s), then leave
  // timeline (s), on the music's bar lines: title 0-2 | crawl 2-10 | cursor 10-14 | crawl 14-20 | end card 20-22
  const INTRO_OUT = 1.5, OUTRO_IN = 20, FADE_OUT = 21.3, LURE_END = 12.8;
  const P = [[690, 640, 10.0], [520, 470, 10.8], [250, 300, 11.6], [470, 220, 12.2], [430, 560, 12.8], [430, 560, 13.3], [760, 620, 14.0]];
  const CLICK_AT = 13.0;
  function pointerAt(t) {
    for (let i = 0; i < P.length - 1; i++) {
      const [x0, y0, t0] = P[i], [x1, y1, t1] = P[i + 1];
      if (t >= t0 && t <= t1) { const e = ease((t - t0) / (t1 - t0)); return [x0 + (x1 - x0) * e, y0 + (y1 - y0) * e]; }
    }
    return null;
  }
  let prev = null, clicked = false, frame = 0;

  window.__onTick(t => {
    frame++;
    document.documentElement.classList.toggle('blink-off', ((t * 1000 / 70) | 0) % 2 === 1);

    // intro card: 0 - 2 s (fades out over the last 0.5 s)
    intro.style.opacity = t < INTRO_OUT ? 1 : 1 - ease((t - INTRO_OUT) / .5);
    if (t < INTRO_OUT + .5) glitchTitle(intro, t, frame);
    // outro card: 20 s on, then fade to black
    outro.style.opacity = ease((t - OUTRO_IN) / .4);
    if (t >= OUTRO_IN) glitchTitle(outro, t - OUTRO_IN, frame);
    fade.style.opacity = ease((t - FADE_OUT) / .7);

    // pointer
    const p = pointerAt(t);
    if (p) {
      const [x, y] = p;
      cursor.style.opacity = 1;
      cursor.style.left = x + 'px'; cursor.style.top = y + 'px';
      const mx = prev ? x - prev[0] : 0, my = prev ? y - prev[1] : 0;
      if (t < LURE_END && (mx || my)) window.dispatchEvent(new MouseEvent('mousemove', { clientX: x, clientY: y, movementX: mx, movementY: my }));
      if (!clicked && t >= CLICK_AT) {
        clicked = true;
        window.dispatchEvent(new MouseEvent('click', { clientX: x, clientY: y }));
      }
      prev = [x, y];
    } else {
      cursor.style.opacity = 0; prev = null;
    }
    const r = t - CLICK_AT;
    if (r >= 0 && r < .6) {
      const [x, y] = pointerAt(CLICK_AT);
      ripple.style.left = x + 'px'; ripple.style.top = y + 'px';
      ripple.style.opacity = 1 - r / .6;
      ripple.style.transform = `scale(${1 + r * 9})`;
    } else ripple.style.opacity = 0;
    cursor.style.transform = r >= 0 && r < .15 ? 'scale(.85)' : 'none';
  });
}

// ---------------------------------------------------------------------------
const run = (cmd, args, opts = {}) => new Promise((res, rej) => {
  const p = spawn(cmd, args, { stdio: ['ignore', 'inherit', 'inherit'], ...opts });
  p.on('exit', code => code === 0 ? res() : rej(new Error(`${cmd} exited ${code}`)));
});

async function capture() {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: ['--hide-scrollbars', '--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none'],
    defaultViewport: { width: VIEW, height: VIEW, deviceScaleFactor: DSF },
  });
  const page = await browser.newPage();
  page.on('pageerror', e => console.error('[page error]', e.message));
  await page.evaluateOnNewDocument(`(${inject})(${SEED}); window.__stage = ${stage};`);
  await page.goto(pathToFileURL(path.join(ROOT, 'index.html')).href, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);

  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', silent],
    { stdio: ['pipe', 'inherit', 'inherit'] });
  const ffDone = new Promise((res, rej) => ff.on('exit', c => c === 0 ? res() : rej(new Error('ffmpeg exited ' + c))));

  const dt = 1000 / FPS;
  const skip = Math.round(FROM * FPS), total = Math.round(SECONDS * FPS);
  const t0 = Date.now();
  for (let f = 0; f < skip + total; f++) {
    await page.evaluate(ms => window.__tick(ms), dt);
    if (f < skip) continue;
    const buf = await page.screenshot({ type: 'jpeg', quality: 95, optimizeForSpeed: true });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    const n = f - skip + 1;
    if (n % FPS === 0 || n === total) {
      const el = (Date.now() - t0) / 1000;
      process.stdout.write(`\r  frame ${n}/${total}  ${(n / el).toFixed(1)} fps  eta ${Math.round((total - n) / (n / el))} s   `);
    }
  }
  ff.stdin.end();
  await ffDone;
  await browser.close();
  console.log(`\n  video -> ${path.relative(HERE, silent)}`);
}

if (!process.argv.includes('--mux')) await capture();

if (existsSync(music)) {
  const off = FROM.toFixed(3);
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', silent, '-ss', off, '-i', music,
    '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', final]);
  console.log(`  with music -> ${path.relative(HERE, final)}`);
} else {
  console.log('  (no build/music.wav yet — run `npm run music`, then re-mux or re-render)');
}

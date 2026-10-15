// End-to-end test of the extension in a real Chromium (see harness.mjs).
//
//   node e2e.mjs            (needs network for the live sites)
//
// On each page: starts the spider through the service worker exactly like the popup
// does, samples its stats, measures fps, records every DOM mutation of the page (the
// page must stay untouched), screenshots, recalls the spider and checks no trace remains.
// Screenshots of third-party sites go to tools/out/ (git-ignored) and are for checking only.
import path from 'node:path';
import { launch, sleep, out, HERE } from './harness.mjs';

const OUT = out(path.join(HERE, 'out'));
const H = await launch();

const PAGES = [
  { name: 'sample', url: H.sampleUrl },
  { name: 'wikipedia-en', url: 'https://en.wikipedia.org/wiki/Spider', autoRead: true },
  { name: 'wikipedia-ja', url: 'https://ja.wikipedia.org/wiki/%E3%82%AF%E3%83%A2' },
  { name: 'github-csp', url: 'https://github.com/cyohei9907/web-crawlers' },
];

const results = [];
for (const P of PAGES) {
  const r = { page: P.name };
  const page = await H.browser.newPage();
  const errors = [];
  page.on('pageerror', e => { if (/chrome-extension:/.test(e.stack || '')) errors.push(e.message); });
  page.on('console', m => { if (m.type() === 'error' && /chrome-extension:/.test(m.location()?.url || '')) errors.push(m.text()); });
  try {
    await page.goto(P.url, { waitUntil: 'networkidle2', timeout: 45000 });
    await page.bringToFront();
    await sleep(800);
    const tabId = await H.tabIdOf(page);

    // the page's own mutations without the spider (baseline), then with it
    const watch = () => page.evaluate(() => {
      window.__muts = new Set();
      window.__mo?.disconnect();
      window.__mo = new MutationObserver(rs => {
        for (const m of rs) {
          const nodes = [...m.addedNodes, ...m.removedNodes];
          if (m.type === 'childList' && nodes.length && nodes.every(n => n.nodeName === 'WEB-CRAWLERS-OVERLAY')) continue;
          window.__muts.add(`${m.type}:${m.target.nodeName}${m.attributeName ? '@' + m.attributeName : ''}`);
        }
      });
      window.__mo.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true });
    });
    const muts = () => page.evaluate(() => [...window.__muts]);
    await watch(); await sleep(4000);
    const baseline = new Set(await muts());
    await watch();

    const started = await H.toggle(tabId);
    r.started = started.ok && started.running;
    const fpsP = page.evaluate(() => new Promise(res => { let n = 0; const t0 = performance.now(); (function f() { n++; performance.now() - t0 < 6000 ? requestAnimationFrame(f) : res(n / 6); })(); }));
    let maxExt = 0, wordFeet = 0, samples = 0, maxPatches = 0, last = null;
    for (let i = 0; i < 14; i++) {
      await sleep(450);
      const s = await H.inTab(tabId, '() => window.__webCrawler.stats()');
      if (!s) continue;
      samples++; last = s;
      maxExt = Math.max(maxExt, s.maxLegExt); wordFeet += s.feetOnWords; maxPatches = Math.max(maxPatches, s.patches);
    }
    r.fps = +(await fpsP).toFixed(1);
    r.maxLegExt = maxExt; r.avgFeetOnWords = +(wordFeet / Math.max(1, samples)).toFixed(1) + '/10';
    r.maxPatches = maxPatches; r.spiderInView = !!last && last.spider.vx > 0 && last.spider.vx < 1 && last.spider.vy > 0 && last.spider.vy < 1;
    await page.screenshot({ path: path.join(OUT, `${P.name}.png`) });
    r.newPageMutations = (await muts()).filter(m => !baseline.has(m));

    if (P.autoRead) {
      await H.apply(tabId, { autoRead: true, size: 'M', density: 'normal' });
      const ys = [];
      for (let i = 0; i < 12; i++) { await sleep(400); ys.push(await page.evaluate(() => scrollY)); }
      r.autoRead = { scrolledPx: Math.round(ys.at(-1) - ys[0]), monotonic: ys.every((y, i) => !i || y >= ys[i - 1] - 1) };
      await page.screenshot({ path: path.join(OUT, `${P.name}-autoread.png`) });
      await H.apply(tabId, { autoRead: false });
    }

    const stopped = await H.toggle(tabId);
    await sleep(200);
    r.stopped = stopped.ok && !stopped.running;
    r.overlayGone = await page.evaluate(() => !document.querySelector('web-crawlers-overlay'));
  } catch (e) {
    r.failure = String(e.message || e).slice(0, 200);
  }
  r.extensionErrors = errors;
  results.push(r);
  await page.close();
}

// restricted page: must fail gracefully, not throw
try {
  // extensions can't see chrome:// URLs even with <all_urls>: find the tab as "the new one"
  const before = await H.sw.evaluate(async () => (await chrome.tabs.query({})).map(t => t.id));
  const page = await H.browser.newPage();
  await page.goto('chrome://version');
  const tabId = await H.sw.evaluate(async ids => (await chrome.tabs.query({})).find(t => !ids.includes(t.id))?.id, before);
  const s = await H.toggle(tabId);
  results.push({ page: 'chrome://version', refusedGracefully: !!s && s.ok === false, error: s && s.error });
  await page.close();
} catch (e) {
  results.push({ page: 'chrome://version', failure: String(e.message || e).slice(0, 200) });
}

// popup UI
{
  const page = await H.browser.newPage();
  await page.setViewport({ width: 280, height: 300, deviceScaleFactor: 2 });
  await page.goto(`chrome-extension://${H.extId}/popup.html`);
  await sleep(600);
  await page.screenshot({ path: path.join(OUT, 'popup.png') });
  results.push({ page: 'popup', title: await page.$eval('h1', e => e.textContent), button: await page.$eval('#toggle', e => e.textContent) });
  await page.close();
}

await H.close();
console.log(JSON.stringify(results, null, 1));

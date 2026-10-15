// Chrome Web Store screenshots (1280x800 JPEG, no alpha) of the extension running on
// store-sample.html: a neutral blog-style page with original text (no third-party
// sites, layouts, names or marks).
//
//   node shots.mjs   -> ../store/screenshot-1..4.jpg
import path from 'node:path';
import { readFileSync } from 'node:fs';
import { launch, sleep, out, HERE } from './harness.mjs';

const STORE = out(path.resolve(HERE, '../store'));
const H = await launch({ width: 1280, height: 800 });

async function shot(name, url, settings, heading, wait) {
  const page = await H.browser.newPage();
  await page.goto(url, { waitUntil: 'load' });
  await page.bringToFront();
  const tabId = await H.tabIdOf(page);
  const y = heading ? await page.evaluate(h => {
    const el = [...document.querySelectorAll('h2')].find(e => e.textContent === h);
    return el.getBoundingClientRect().top + scrollY - 60;
  }, heading) : 0;
  await page.evaluate(y => window.scrollTo({ top: y, behavior: 'instant' }), y);
  await H.setSettings(settings);
  await sleep(300);
  await H.toggle(tabId);
  await sleep(wait);
  const file = path.join(STORE, name);
  await page.screenshot({ path: file, type: 'jpeg', quality: 92 });
  await H.toggle(tabId);
  await page.close();
  return file;
}

const light = H.storeUrl, dark = H.storeUrl + '?dark';
await shot('screenshot-1.jpg', light, { size: 'L', density: 'wild', autoRead: false }, null, 5200);
const second = await shot('screenshot-2.jpg', light, { size: 'M', density: 'normal', autoRead: false }, 'Silk', 6000);
await shot('screenshot-4.jpg', dark, { size: 'M', density: 'normal', autoRead: false }, 'Terrain', 6000);

// 3: the popup, composited where Chrome shows it (top-right, under the toolbar)
{
  await H.setSettings({ size: 'M', density: 'normal', autoRead: false }); // same settings as the shot behind it
  const pop = await H.browser.newPage();
  await pop.setViewport({ width: 280, height: 268, deviceScaleFactor: 1 });
  await pop.goto(`chrome-extension://${H.extId}/popup.html`);
  await sleep(500);
  // show it in its "running" state
  await pop.evaluate(() => { const b = document.querySelector('#toggle'); b.disabled = false; b.classList.add('on'); b.textContent = chrome.i18n.getMessage('recall'); document.querySelector('#note').hidden = true; });
  const popPng = await pop.screenshot({ type: 'png', clip: { x: 0, y: 0, width: 280, height: await pop.evaluate(() => document.body.scrollHeight) } });
  await pop.close();
  const bg = readFileSync(second).toString('base64');
  const comp = await H.browser.newPage();
  await comp.setViewport({ width: 1280, height: 800 });
  await comp.setContent(`<body style="margin:0;background:#000">
    <img src="data:image/jpeg;base64,${bg}" style="position:absolute;left:0;top:0;width:1280px;height:800px">
    <img src="data:image/png;base64,${popPng.toString('base64')}" style="position:absolute;right:22px;top:10px;width:280px;
      border:1px solid #2a3040;box-shadow:0 10px 40px rgba(0,0,0,.45),0 0 0 1px rgba(92,200,255,.25)">
  </body>`);
  await comp.screenshot({ path: path.join(STORE, 'screenshot-3.jpg'), type: 'jpeg', quality: 92 });
  await comp.close();
}

await H.close();
console.log('screenshots ->', STORE);

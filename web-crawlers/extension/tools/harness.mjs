// Shared test harness: a Chromium with a TEST COPY of the extension loaded.
// The copy adds host_permissions <all_urls> because activeTab needs a real user
// gesture (toolbar click / shortcut), which automation can't produce. The shipped
// manifest in ../src is never modified.
import puppeteer from 'puppeteer-core';
import http from 'node:http';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync, createReadStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO = path.resolve(HERE, '../..');
const SRC = path.resolve(HERE, '../src');
const TEST_EXT = path.join(HERE, '.e2e-ext');
const CHROMIUM = process.env.CHROMIUM ||
  path.join(process.env.LOCALAPPDATA || '', 'ms-playwright/chromium-1217/chrome-win64/chrome.exe');
export const sleep = ms => new Promise(r => setTimeout(r, ms));

export async function launch({ width = 1280, height = 800 } = {}) {
  rmSync(TEST_EXT, { recursive: true, force: true });
  cpSync(SRC, TEST_EXT, { recursive: true });
  const man = JSON.parse(readFileSync(path.join(TEST_EXT, 'manifest.json'), 'utf8'));
  man.host_permissions = ['<all_urls>'];
  if (!existsSync(path.join(TEST_EXT, 'icons/icon16.png'))) { delete man.icons; delete man.action.default_icon; }
  writeFileSync(path.join(TEST_EXT, 'manifest.json'), JSON.stringify(man, null, 2));

  // static server for the local sample page
  const server = http.createServer((req, res) => {
    const f = path.join(REPO, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (!f.startsWith(REPO) || !existsSync(f)) { res.writeHead(404); return res.end(); }
    const type = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' }[path.extname(f)] || 'application/octet-stream';
    res.writeHead(200, { 'content-type': type + '; charset=utf-8' });
    createReadStream(f).pipe(res);
  }).listen(0);
  const port = server.address().port;

  const browser = await puppeteer.launch({
    executablePath: CHROMIUM,
    headless: true,
    args: [`--disable-extensions-except=${TEST_EXT}`, `--load-extension=${TEST_EXT}`, '--hide-scrollbars', '--lang=en-US'],
    defaultViewport: { width, height },
  });
  const swTarget = await browser.waitForTarget(t => t.type() === 'service_worker' && t.url().endsWith('/background.js'), { timeout: 15000 });
  const sw = await swTarget.worker();
  const extId = new URL(swTarget.url()).host;

  return {
    browser, sw, extId, port,
    sampleUrl: `http://localhost:${port}/extension/tools/demo.html`,
    storeUrl: `http://localhost:${port}/extension/tools/store-sample.html`,
    tabIdOf: async page => sw.evaluate(async u => (await chrome.tabs.query({})).find(t => t.url === u)?.id, page.url()),
    inTab: (tabId, fn) => sw.evaluate(`exec(${tabId}, ${fn})`),
    toggle: tabId => sw.evaluate(id => toggle(id), tabId),
    apply: (tabId, o) => sw.evaluate((id, o) => apply(id, o), tabId, o),
    setSettings: o => sw.evaluate(o => chrome.storage.sync.set(o), o),
    async close() { await browser.close(); server.close(); },
  };
}

export const out = dir => { mkdirSync(dir, { recursive: true }); return dir; };

// Web Crawlers — service worker. Injects / controls the spider in the active tab.
// Uses only activeTab + scripting: the spider runs on a tab only after the user
// opened the popup or pressed the shortcut on that tab.
const DEFAULTS = { autoRead: false, size: 'M', density: 'normal' };

const settings = async () => ({ ...DEFAULTS, ...(await chrome.storage.sync.get(DEFAULTS)) });

async function exec(tabId, func, args = []) {
  const [r] = await chrome.scripting.executeScript({ target: { tabId }, func, args });
  return r && r.result;
}

function badge(tabId, on) {
  chrome.action.setBadgeText({ tabId, text: on ? 'ON' : '' });
}

async function status(tabId) {
  try {
    const running = await exec(tabId, () => !!(window.__webCrawler && window.__webCrawler.running));
    return { ok: true, running: !!running };
  } catch (e) {
    // chrome://, the Web Store, PDF viewer, other extensions' pages...: browsers block all extensions there
    return { ok: false, error: String((e && e.message) || e) };
  }
}

async function start(tabId) {
  await chrome.scripting.executeScript({ target: { tabId }, files: ['spider.js'] });
  await exec(tabId, o => window.__webCrawler.start(o), [await settings()]);
  badge(tabId, true);
}

async function stop(tabId) {
  await exec(tabId, () => window.__webCrawler && window.__webCrawler.stop());
  badge(tabId, false);
}

async function toggle(tabId) {
  const s = await status(tabId);
  if (!s.ok) return s;
  try {
    if (s.running) await stop(tabId); else await start(tabId);
    return { ok: true, running: !s.running };
  } catch (e) {
    return { ok: false, error: String((e && e.message) || e) };
  }
}

async function apply(tabId, opts) {
  const s = await status(tabId);
  if (s.ok && s.running) await exec(tabId, o => window.__webCrawler.set(o), [opts]);
  return s;
}

chrome.action.setBadgeBackgroundColor({ color: '#ff4a6e' });
if (chrome.action.setBadgeTextColor) chrome.action.setBadgeTextColor({ color: '#ffffff' });

// a navigation / reload wipes the page (and the spider with it)
chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (info.status === 'loading') badge(tabId, false);
});

chrome.commands.onCommand.addListener((command, tab) => {
  if (command === 'toggle-spider' && tab && tab.id != null) toggle(tab.id);
});

chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  const run = {
    status: () => status(msg.tabId),
    toggle: () => toggle(msg.tabId),
    apply: () => apply(msg.tabId, msg.opts),
  }[msg && msg.type];
  if (!run) return false;
  run().then(reply, e => reply({ ok: false, error: String((e && e.message) || e) }));
  return true; // async reply
});

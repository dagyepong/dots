// Popup: release / recall the spider on this tab and tune it. Settings live in chrome.storage.sync.
const DEFAULTS = { autoRead: false, size: 'M', density: 'normal' };
const $ = s => document.querySelector(s);
const t = k => chrome.i18n.getMessage(k) || k;

document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });

let tabId = null, running = false, opts = { ...DEFAULTS };
const send = msg => chrome.runtime.sendMessage({ ...msg, tabId });

function paint() {
  const btn = $('#toggle');
  btn.textContent = running ? t('recall') : t('release');
  btn.classList.toggle('on', running);
  $('#autoRead').checked = !!opts.autoRead;
  document.querySelectorAll('.seg').forEach(seg => {
    seg.querySelectorAll('button').forEach(b => b.classList.toggle('sel', b.dataset.v === opts[seg.dataset.key]));
  });
}

async function save(patch) {
  opts = { ...opts, ...patch };
  paint();
  await chrome.storage.sync.set(opts);
  if (tabId != null) await send({ type: 'apply', opts });
}

$('#toggle').addEventListener('click', async () => {
  const btn = $('#toggle');
  btn.disabled = true;
  const r = await send({ type: 'toggle' });
  if (r && r.ok) running = r.running;
  else showNote();
  btn.disabled = false;
  paint();
});
$('#autoRead').addEventListener('change', e => save({ autoRead: e.target.checked }));
document.querySelectorAll('.seg').forEach(seg => {
  seg.addEventListener('click', e => {
    const b = e.target.closest('button');
    if (b) save({ [seg.dataset.key]: b.dataset.v });
  });
});

function showNote() {
  const n = $('#note');
  n.textContent = t('cantRun');
  n.hidden = false;
  $('#toggle').disabled = true;
}

(async () => {
  opts = { ...DEFAULTS, ...(await chrome.storage.sync.get(DEFAULTS)) };
  const cmds = await chrome.commands.getAll();
  const c = cmds.find(x => x.name === 'toggle-spider');
  $('#kbd').textContent = (c && c.shortcut) || t('notSet');
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  tabId = tab ? tab.id : null;
  paint();
  const s = tabId != null ? await send({ type: 'status' }) : { ok: false };
  if (s && s.ok) {
    running = s.running;
    $('#toggle').disabled = false;
    paint();
  } else showNote();
})();

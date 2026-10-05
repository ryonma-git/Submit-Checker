import { STORAGE_KEY, DEFAULT_ASSIGNMENTS, localDay, identity, createRecord, toggleRecord, csv, loadArchive, saveArchive, validateArchive } from './core.js';
const $ = id => document.getElementById(id);
let archive = { schemaVersion: 1, records: [] }, activeID = null, undo = null, missingOnly = false, blocked = false, toastTimer;
const current = () => archive.records.find(r => r.id === activeID);
const sorted = () => [...archive.records].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
const filtered = () => sorted().filter(r => `${r.grade}年${r.classNumber}組 ${r.assignment} ${r.date}`.includes($('search').value.trim()));
function error(message) { $('error').textContent = message; $('error').hidden = false; }
function toast(message) { $('toast').textContent = message; $('toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => { $('toast').hidden = true; }, 3500); }
function clearError() { $('error').hidden = true; }
function read() {
  try { archive = loadArchive(localStorage); blocked = false; }
  catch { blocked = true; error('保存データを読み込めません。上書きを防ぐためチェックを停止しました。バックアップを書き出して保管し、正常なバックアップを読み込んでください。'); }
}
async function mutate(change) {
  const run = () => {
    if (blocked) { error('保存データを復旧するまで変更できません。'); return false; }
    try {
      const next = structuredClone(loadArchive(localStorage));
      change(next); saveArchive(localStorage, next); archive = next; clearError(); updateLists(); return true;
    } catch (e) { error(`保存できませんでした。変更は反映していません。ブラウザの保存設定・空き容量を確認してください。 ${e.message}`); return false; }
  };
  return navigator.locks ? navigator.locks.request(STORAGE_KEY, run) : run();
}
function option(value, label) { const node = document.createElement('option'); node.value = value; node.textContent = label; return node; }
for (let n = 1; n <= 6; n++) $('grade').append(option(n, `${n}年`));
for (let n = 1; n <= 20; n++) $('class-number').append(option(n, `${n}組`));
for (let n = 1; n <= 40; n++) $('count').append(option(n, `${n}人`));
$('count').value = '30'; $('date').value = localDay();
$('count').addEventListener('change', () => { $('count-label').textContent = $('count').value; });
$('today').onclick = () => { $('date').value = localDay(); };
function show(view) {
  document.body.classList.toggle('checking', view === 'check');
  for (const name of ['home', 'check', 'history']) $(name + '-view').hidden = name !== view;
  $('nav-home').classList.toggle('active', view !== 'history'); $('nav-history').classList.toggle('active', view === 'history');
  $('breadcrumb').textContent = view === 'history' ? 'ホーム / 保存した記録' : view === 'check' ? '提出チェック / チェック中' : 'ホーム / 提出チェック';
  updateLists(); window.scrollTo({ top: 0 });
}
$('nav-home').onclick = $('back').onclick = () => show('home');
$('nav-history').onclick = $('see-all').onclick = () => show('history');
$('setup-form').onsubmit = async event => {
  event.preventDefault();
  const start = $('setup-form').querySelector('[type=submit]'); start.disabled = true;
  try {
    const candidate = createRecord({ grade: Number($('grade').value), classNumber: Number($('class-number').value), date: $('date').value, assignment: $('assignment').value, count: Number($('count').value) });
    let record, existed = false;
    if (await mutate(next => {
      record = next.records.find(r => identity(r) === identity(candidate)); existed = !!record;
      if (!record) { record = candidate; next.records.push(record); }
    })) {
      openRecord(record.id);
      if (existed) toast(`保存した記録（${record.students.length}人）を再開しました。`);
    }
  } catch (e) { error(e.message); }
  finally { start.disabled = false; }
};
function openRecord(id) { activeID = id; undo = null; missingOnly = false; renderBoard(); show('check'); }
function renderBoard(focusNumber) {
  const r = current(); if (!r) { activeID = null; show('home'); return; }
  const done = Object.keys(r.submitted).length, total = r.students.length;
  layoutSeats();
  $('check-meta').textContent = `${r.grade}年${r.classNumber}組 · ${r.date.replaceAll('-', '.')} · ${total}人`;
  $('check-title').textContent = r.assignment; $('submitted-count').textContent = done; $('total-count').textContent = total;
  $('remaining').textContent = `未提出 ${total - done}人`; $('progress-bar').style.width = `${done / total * 100}%`;
  $('completion').hidden = done !== total; $('undo').disabled = !undo;
  $('saved-state').textContent = '✓ 保存済み';
  $('show-all').classList.toggle('selected', !missingOnly); $('show-missing').classList.toggle('selected', missingOnly);
  $('show-all').setAttribute('aria-pressed', String(!missingOnly)); $('show-missing').setAttribute('aria-pressed', String(missingOnly));
  $('seats').replaceChildren();
  for (const s of [...r.students].sort((a, b) => a.number - b.number)) {
    const submitted = !!r.submitted[s.number], button = document.createElement('button');
    button.className = `seat${submitted ? ' done' : ''}${missingOnly && submitted ? ' dimmed' : ''}`;
    button.dataset.number = s.number; button.disabled = blocked || (missingOnly && submitted);
    button.setAttribute('aria-pressed', String(submitted)); button.setAttribute('aria-label', `${s.number}番${s.name ? ' ' + s.name : ''} ${submitted ? '提出済み' : '未提出'}`);
    const add = (cls, text) => { const span = document.createElement('span'); span.className = cls; span.textContent = text; button.append(span); };
    add('seat-mark', submitted ? '✓' : ''); add('seat-number', String(s.number).padStart(2, '0'));
    if (s.reading) add('seat-reading', s.reading); if (s.name) add('seat-name', s.name);
    add('seat-status', submitted ? '提出済み' : '未提出');
    button.onclick = async () => {
      const recordID = r.id; let previous, after;
      button.disabled = true;
      const ok = await mutate(next => {
        const i = next.records.findIndex(item => item.id === recordID);
        if (i < 0) throw new Error('記録が見つかりません。');
        previous = next.records[i].submitted[s.number]; next.records[i] = toggleRecord(next.records[i], s.number); after = next.records[i].submitted[s.number];
      });
      if (ok) { undo = { recordID, number: s.number, previous, after }; renderBoard(s.number); }
      else button.disabled = false;
    };
    $('seats').append(button);
  }
  if (focusNumber) $('seats').querySelector(`[data-number="${focusNumber}"]`)?.focus({ preventScroll: true });
}
$('show-all').onclick = () => { missingOnly = false; renderBoard(); };
$('show-missing').onclick = () => { missingOnly = true; renderBoard(); };
function layoutSeats() {
  const r = current(); if (!r) return;
  const landscape = innerWidth > innerHeight && innerWidth >= 900;
  let columns = $('columns').value === 'auto' ? (landscape ? (r.students.length > 30 ? 8 : 6) : 5) : Number($('columns').value);
  if (innerWidth < 600) columns = Math.min(columns, 5);
  $('seats').style.setProperty('--columns', columns);
  $('seats').style.setProperty('--rows', Math.ceil(r.students.length / columns));
}
$('columns').onchange = layoutSeats;
window.addEventListener('resize', layoutSeats);
$('undo').onclick = async () => {
  if (!undo) return; const action = undo;
  if (await mutate(next => {
    const r = next.records.find(item => item.id === action.recordID);
    if (!r || r.submitted[action.number] !== action.after) throw new Error('別の画面で変更されています。記録を確認してください。');
    if (action.previous) r.submitted[action.number] = action.previous; else delete r.submitted[action.number];
    r.updatedAt = new Date().toISOString();
  })) { undo = null; renderBoard(); toast(`${action.number}番の操作を戻しました。`); }
};
function recordList(target, records, message) {
  target.replaceChildren();
  if (!records.length) { const empty = document.createElement('div'); empty.className = 'empty'; empty.textContent = message; target.append(empty); return; }
  for (const r of records) {
    const button = document.createElement('button'); button.className = 'record-card'; button.onclick = () => openRecord(r.id);
    const icon = document.createElement('span'); icon.className = 'record-icon'; icon.textContent = '▤';
    const text = document.createElement('span'); text.className = 'record-text';
    const title = document.createElement('strong'); title.textContent = r.assignment;
    const sub = document.createElement('small'); sub.textContent = `${r.grade}年${r.classNumber}組　·　${r.date}`;
    text.append(title, sub);
    const count = document.createElement('span'); count.className = 'record-progress'; count.textContent = `${Object.keys(r.submitted).length} / ${r.students.length}人 提出済み`;
    const arrow = document.createElement('span'); arrow.className = 'record-arrow'; arrow.textContent = '→'; button.append(icon, text, count, arrow); target.append(button);
  }
}
function updateLists() {
  $('record-badge').textContent = archive.records.length;
  recordList($('recent-list'), sorted().slice(0, 3), 'まだ記録はありません。最初の提出チェックを始めましょう。');
  recordList($('history-list'), filtered(), '該当する記録はありません。');
  $('export-all').disabled = !filtered().length;
  $('assignments').replaceChildren(...[...new Set([...DEFAULT_ASSIGNMENTS, ...sorted().map(r => r.assignment)])].map(name => option(name, name)));
}
$('search').oninput = updateLists;
function download(content, name, type) {
  const blob = new Blob([content], { type }); const url = URL.createObjectURL(blob); const a = document.createElement('a');
  a.href = url; a.download = name; document.body.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 60000);
  toast('書き出しました。ダウンロードしたファイルを確認してください。');
}
const filename = r => `${r.date}_${r.grade}年${r.classNumber}組_${r.assignment.replace(/[\\/:*?"<>|\n\r]/g, '_')}.csv`;
$('export-current').onclick = () => { const r = current(); if (r) download(csv([r]), filename(r), 'text/csv;charset=utf-8'); };
$('export-all').onclick = () => { const records = filtered(); if (records.length) download(csv(records), `提出記録_${localDay()}.csv`, 'text/csv;charset=utf-8'); };
$('backup').onclick = () => {
  try { const raw = localStorage.getItem(STORAGE_KEY); download(raw ?? JSON.stringify(archive), `提出チェッカー_backup_${localDay()}.json`, 'application/json'); }
  catch { error('保存領域を読み出せません。ブラウザの保存設定を確認してください。'); }
};
$('restore').onclick = () => $('restore-file').click();
$('restore-file').onchange = async event => {
  const file = event.target.files[0]; if (!file) return;
  try {
    if (file.size > 20 * 1024 * 1024) throw new Error('20MB以下のバックアップを選んでください。');
    const restored = validateArchive(JSON.parse(await file.text()));
    if (!confirm(`${restored.records.length}件のバックアップで、この端末の記録を置き換えます。現在の記録は先にバックアップしてください。読み込みますか？`)) return;
    const restore = () => { saveArchive(localStorage, restored); archive = restored; blocked = false; activeID = null; undo = null; clearError(); show('history'); toast('バックアップを読み込みました。'); };
    if (navigator.locks) await navigator.locks.request(STORAGE_KEY, restore); else restore();
  } catch (e) { error(`読み込めませんでした。${e.message}`); }
  finally { event.target.value = ''; }
};
window.addEventListener('storage', event => { if (event.key === STORAGE_KEY || event.key === null) { read(); undo = null; updateLists(); if (activeID) renderBoard(); } });
read(); updateLists();
if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(() => {});

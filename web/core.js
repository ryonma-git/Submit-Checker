export const STORAGE_KEY = 'submit-checker.archive.v1';
export const DEFAULT_ASSIGNMENTS = ['漢字ノート', '計算ドリル', '音読カード', '自主学習', 'プリント'];
export function localDay(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}
export function identity(r) { return JSON.stringify([r.grade, r.classNumber, r.date, r.assignment]); }
export function validateArchive(archive) {
  if (!archive || archive.schemaVersion !== 1 || !Array.isArray(archive.records)) throw new Error('保存データの形式・バージョンが正しくありません。');
  const ids = new Set(), identities = new Set();
  for (const r of archive.records) {
    if (!r || typeof r.id !== 'string' || !r.id || ids.has(r.id) || identities.has(identity(r)) ||
      !Number.isInteger(r.grade) || r.grade < 1 || r.grade > 6 || !Number.isInteger(r.classNumber) || r.classNumber < 1 || r.classNumber > 20 ||
      typeof r.assignment !== 'string' || !r.assignment.trim() || r.assignment !== r.assignment.trim() || [...r.assignment].length > 100 ||
      typeof r.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(r.date) || !Number.isFinite(Date.parse(r.date)) || new Date(r.date).toISOString().slice(0, 10) !== r.date ||
      !Array.isArray(r.students) || r.students.length < 1 || r.students.length > 40 ||
      !r.students.every(s => s && Number.isInteger(s.number) && ['name', 'reading', 'photoAssetID'].every(k => s[k] == null || typeof s[k] === 'string')) ||
      r.students.map(s => s.number).sort((a, b) => a - b).some((n, i) => n !== i + 1) ||
      !r.submitted || typeof r.submitted !== 'object' || Array.isArray(r.submitted) ||
      !Object.entries(r.submitted).every(([n, time]) => r.students.some(s => String(s.number) === n) && typeof time === 'string' && Number.isFinite(Date.parse(time))) ||
      ![r.createdAt, r.updatedAt].every(t => typeof t === 'string' && Number.isFinite(Date.parse(t)))) throw new Error('提出記録の形式が正しくありません。元のデータは上書きしていません。');
    ids.add(r.id); identities.add(identity(r));
  }
  return archive;
}
export function createRecord({ grade, classNumber, date, assignment, count }, now = new Date()) {
  if (!Number.isInteger(count) || count < 1 || count > 40) throw new Error('人数は1〜40人で指定してください。');
  const r = { id: crypto.randomUUID(), grade, classNumber, date, assignment: assignment.trim(), students: Array.from({ length: count }, (_, i) => ({ number: i + 1 })), submitted: {}, createdAt: now.toISOString(), updatedAt: now.toISOString() };
  validateArchive({ schemaVersion: 1, records: [r] }); return r;
}
export function toggleRecord(record, number, now = new Date()) {
  if (!record.students.some(s => s.number === number)) throw new Error('出席番号が範囲外です。');
  const copy = structuredClone(record), key = String(number);
  if (copy.submitted[key]) delete copy.submitted[key]; else copy.submitted[key] = now.toISOString();
  copy.updatedAt = now.toISOString(); return copy;
}
export function csv(records) {
  const cell = value => { let s = String(value ?? ''); if (/^[\s]*[=+@-]/.test(s) || /^[\t\r]/.test(s)) s = "'" + s; return '"' + s.replaceAll('"', '""') + '"'; };
  const rows = [['クラス', '提出日', '課題名', '出席番号', '名前', '読み仮名', '提出状況', '提出確認日時']];
  for (const r of records) for (const s of [...r.students].sort((a, b) => a.number - b.number)) rows.push([`${r.grade}年${r.classNumber}組`, r.date, r.assignment, s.number, s.name, s.reading, r.submitted[s.number] ? '提出済み' : '未提出', r.submitted[s.number]]);
  return '\uFEFF' + rows.map(row => row.map(cell).join(',')).join('\r\n') + '\r\n';
}
export function loadArchive(storage) {
  const raw = storage.getItem(STORAGE_KEY);
  return raw === null ? { schemaVersion: 1, records: [] } : validateArchive(JSON.parse(raw));
}
export function saveArchive(storage, archive) {
  validateArchive(archive); storage.setItem(STORAGE_KEY, JSON.stringify(archive));
}

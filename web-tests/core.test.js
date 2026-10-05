import test from 'node:test';
import assert from 'node:assert/strict';
import { createRecord, toggleRecord, csv, validateArchive, loadArchive, saveArchive, localDay } from '../web/core.js';
const sample = (options = {}) => createRecord({ grade: 3, classNumber: 2, date: '2026-10-06', assignment: '漢字ノート', count: 30, ...options });
test('人数・日付・入力の境界', () => {
  assert.equal(sample().students.length, 30); assert.equal(sample({ count: 40 }).students.at(-1).number, 40);
  for (const count of [0, 41, 1.5, NaN]) assert.throws(() => sample({ count }));
  assert.throws(() => sample({ date: '2026-02-30' })); assert.throws(() => sample({ assignment: ' ' }));
  assert.equal(localDay(new Date(2026, 9, 6, 0, 1)), '2026-10-06');
});
test('番号の切り替えは元のデータを変えず、範囲外を拒否', () => {
  const first = sample({ count: 40 }), next = toggleRecord(first, 40);
  assert.equal(Object.keys(first.submitted).length, 0); assert.ok(next.submitted['40']);
  assert.equal(Object.keys(toggleRecord(next, 40).submitted).length, 0); assert.throws(() => toggleRecord(first, 41));
});
test('記録分離・重複防止・破損を拒否', () => {
  const first = toggleRecord(sample(), 1), second = sample({ assignment: '計算' });
  const archive = { schemaVersion: 1, records: [first, second] }; validateArchive(archive);
  assert.equal(Object.keys(second.submitted).length, 0);
  assert.throws(() => validateArchive({ ...archive, records: [first, first] }));
  assert.throws(() => validateArchive({ ...archive, schemaVersion: 2 }));
  assert.throws(() => validateArchive({ ...archive, records: [{ ...first, submitted: { 31: new Date().toISOString() } }] }));
});
test('保存・復元・保存失敗の通知', () => {
  let value = null; const storage = { getItem: () => value, setItem: (k, v) => { value = v; } };
  assert.equal(loadArchive(storage).records.length, 0);
  const archive = { schemaVersion: 1, records: [toggleRecord(sample(), 1)] }; saveArchive(storage, archive); assert.deepEqual(loadArchive(storage), archive);
  assert.throws(() => saveArchive({ setItem: () => { throw Error('quota'); } }, archive));
  value = '{broken'; assert.throws(() => loadArchive(storage)); assert.equal(value, '{broken');
});
test('CSVは全番号・BOM・引用符・式対策に対応', () => {
  const r = toggleRecord(sample({ count: 2, assignment: '=SUM(1,2)"課題' }), 2), output = csv([r]);
  assert.ok(output.startsWith('\uFEFF')); assert.ok(output.includes('"\'=SUM(1,2)""課題"'));
  assert.ok(output.includes('"未提出"')); assert.ok(output.includes('"提出済み"')); assert.equal(output.split('\r\n').length, 4);
});

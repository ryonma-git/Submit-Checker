import { test, expect } from '@playwright/test';
const start = async (page, name = '漢字ノート', count = '30') => {
  await page.locator('#assignment').fill(name); await page.locator('#count').selectOption(count);
  await page.getByRole('button', { name: '提出チェックを始める' }).click();
  await expect(page.locator('#check-view')).toBeVisible();
};
test.beforeEach(async ({ page }) => { await page.goto('/'); });
test('30人で開始・保存・再開・取り消し・40人・記録の分離', async ({ page }) => {
  await expect(page.locator('#count')).toHaveValue('30'); await start(page);
  await expect(page.locator('.seat')).toHaveCount(30);
  await page.getByRole('button', { name: '1番 未提出', exact: true }).click();
  await expect(page.locator('#submitted-count')).toHaveText('1');
  await page.reload(); await page.locator('.record-card').first().click();
  await expect(page.getByRole('button', { name: '1番 提出済み', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await page.getByRole('button', { name: '1番 提出済み', exact: true }).click();
  await expect(page.locator('#submitted-count')).toHaveText('0'); await page.locator('#undo').click(); await expect(page.locator('#submitted-count')).toHaveText('1');
  await page.locator('#back').click(); await start(page, '計算ドリル', '40'); await expect(page.locator('.seat')).toHaveCount(40); await expect(page.locator('#submitted-count')).toHaveText('0');
  await page.getByRole('button', { name: '40番 未提出', exact: true }).click(); await expect(page.locator('#submitted-count')).toHaveText('1');
  await page.locator('#back').click(); await start(page, '漢字ノート', '40'); await expect(page.locator('.seat')).toHaveCount(30); await expect(page.locator('#submitted-count')).toHaveText('1');
});
test('CSV・バックアップ・復元', async ({ page }) => {
  await start(page, '国語,"確認"', '2'); await page.getByRole('button', { name: '2番 未提出' }).click();
  const downloadPromise = page.waitForEvent('download'); await page.locator('#export-current').click(); const download = await downloadPromise;
  const stream = await download.createReadStream(); const chunks = []; for await (const chunk of stream) chunks.push(chunk);
  const text = Buffer.concat(chunks).toString('utf8'); expect(text.charCodeAt(0)).toBe(0xfeff); expect(text).toContain('国語,""確認""'); expect(text).toContain('提出済み'); expect(text).toContain('未提出');
  const data = await page.evaluate(() => localStorage.getItem('submit-checker.archive.v1'));
  await page.locator('#back').click(); await start(page, '別の課題', '1');
  page.once('dialog', dialog => dialog.accept()); await page.locator('#restore-file').setInputFiles({ name: 'backup.json', mimeType: 'application/json', buffer: Buffer.from(data) });
  await expect(page.locator('#history-list .record-card')).toHaveCount(1); await page.locator('#history-list .record-card').click(); await expect(page.locator('#submitted-count')).toHaveText('1');
});
test('保存できない場合は変更を表示せず警告', async ({ page }) => {
  await start(page);
  await page.evaluate(() => { Storage.prototype.setItem = () => { throw new DOMException('full', 'QuotaExceededError'); }; });
  await page.getByRole('button', { name: '1番 未提出', exact: true }).click();
  await expect(page.locator('#error')).toContainText('保存できませんでした'); await expect(page.locator('#submitted-count')).toHaveText('0');
});
test('破損データは上書きしない', async ({ page }) => {
  await page.evaluate(() => localStorage.setItem('submit-checker.archive.v1', '{broken')); await page.reload();
  await expect(page.locator('#error')).toContainText('上書きを防ぐ');
  await page.locator('#assignment').fill('テスト'); await page.locator('.start-button').click();
  expect(await page.evaluate(() => localStorage.getItem('submit-checker.archive.v1'))).toBe('{broken');
});
test('iPad縦横・携帯で横にはみ出さず押せる', async ({ page }) => {
  for (const viewport of [{ width: 820, height: 1180 }, { width: 1194, height: 834 }, { width: 390, height: 844 }]) {
    await page.setViewportSize(viewport); await expect(page.locator('#setup-form')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
  await start(page, 'テスト', '40');
  for (const viewport of [{ width: 820, height: 1180 }, { width: 1194, height: 834 }, { width: 390, height: 844 }]) {
    await page.setViewportSize(viewport); expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    const box = await page.locator('.seat').first().boundingBox(); expect(box.width).toBeGreaterThanOrEqual(44); expect(box.height).toBeGreaterThanOrEqual(44);
  }
});
test('未提出表示と全員完了', async ({ page }) => {
  await start(page, 'テスト', '2'); await page.getByRole('button', { name: '1番 未提出', exact: true }).click();
  await page.locator('#show-missing').click(); await expect(page.getByRole('button', { name: '1番 提出済み', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: '2番 未提出', exact: true }).click(); await expect(page.locator('#completion')).toBeVisible();
});
test('別タブの変更を反映しチェックを失わない', async ({ page, context }) => {
  await start(page); const other = await context.newPage(); await other.goto('/'); await other.locator('.record-card').first().click();
  await page.getByRole('button', { name: '1番 未提出', exact: true }).click();
  await expect(other.getByRole('button', { name: '1番 提出済み', exact: true })).toBeVisible();
  await other.getByRole('button', { name: '2番 未提出', exact: true }).click(); await expect(page.locator('#submitted-count')).toHaveText('2');
});
test('iPadは40人の番号が画面内に収まる', async ({ page }) => {
  await start(page, '40人の課題', '40');
  for (const viewport of [{ width: 1194, height: 834 }, { width: 820, height: 1180 }]) {
    await page.setViewportSize(viewport); await page.evaluate(() => window.scrollTo(0, 0));
    const last = await page.locator('.seat').last().boundingBox(); expect(last.y + last.height).toBeLessThanOrEqual(viewport.height);
    const first = await page.locator('.seat').first().boundingBox(); expect(first.width).toBeGreaterThanOrEqual(44);
  }
});
test('オフラインで開き直して保存できる', async ({ page, context }) => {
  await page.evaluate(async () => { await navigator.serviceWorker.ready; });
  await start(page); await page.getByRole('button', { name: '1番 未提出', exact: true }).click();
  await expect(page.locator('#submitted-count')).toHaveText('1');
  await page.reload(); await page.waitForFunction(() => !!navigator.serviceWorker.controller);
  await context.setOffline(true); await page.reload();
  await page.locator('.record-card').first().click(); await expect(page.locator('#submitted-count')).toHaveText('1');
  await page.getByRole('button', { name: '2番 未提出', exact: true }).click(); await expect(page.locator('#submitted-count')).toHaveText('2');
});

import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './web-tests', testMatch: 'app.spec.js', fullyParallel: true, workers: 2,
  use: { baseURL: 'http://127.0.0.1:4173', viewport: { width: 1194, height: 834 }, screenshot: 'only-on-failure' },
  projects: [{ name: 'chromium', use: { browserName: 'chromium', channel: 'chrome' } }, { name: 'webkit', use: { browserName: 'webkit' } }],
  webServer: { command: 'npm run serve', url: 'http://127.0.0.1:4173', reuseExistingServer: true }
});

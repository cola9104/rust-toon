// Browser component regression against a running Vite development server.
// The API module is mocked; no application records or paid generation are touched.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { chromium } from '../apps/web/node_modules/playwright/index.mjs';

const base = process.env.ALIGNMENT_UI_URL || 'http://127.0.0.1:5668';
const componentPath = '/src/views/toonflow/projects/ProductionAssetStrip.vue';
const compiled = await (await fetch(`${base}${componentPath}`)).text();
const vuePath = compiled.match(/from "([^"]*\/vue\.js[^\"]*)"/)?.[1];
const antPath = compiled.match(/from "([^"]*\/ant-design-vue\.js[^\"]*)"/)?.[1];
assert.ok(vuePath, 'Vite must serve the real Vue component');
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
page.on('pageerror', error => errors.push(error.message));
try {
  await page.route('**/api/**', route => route.abort());
  await page.route('**/src/api/toonflow/index.ts*', route => route.fulfill({
    contentType: 'text/javascript',
    body: `export async function executeAgentTool(value) {
      if (value.toolName === 'generate_deriveAsset') window.generationInput = structuredClone(value);
      return {result: {id: 99}};
    }
    export async function polishAssetPrompt(value) { return {assetsId: value.assetsId, prompt: 'AI prompt'}; }
    export async function saveAsset(value) {
      window.savedAsset = structuredClone(value);
      return value;
    }`,
  }));
  await page.route('**/__alignment.html', route => route.fulfill({
    contentType: 'text/html',
    body: `<!doctype html><meta charset="UTF-8"><style>body{margin:32px;font-family:sans-serif}#app{max-width:1100px;margin:auto}</style><div id="app"></div>
      <script type="module">
        import { createApp, h, reactive } from ${JSON.stringify(vuePath)};
        import { ConfigProvider } from ${JSON.stringify(antPath)};
        import Component from ${JSON.stringify(componentPath)};
        const assets = reactive([{
          id: 1, projectId: 100, name: '角色身份', type: 'role',
          derive: [{id: 2, projectId: 100, parentAssetId: 1, type: 'role',
            name: '现代日常造型', description: '原始服装描述', prompt: '灰色卫衣与运动鞋'}]
        }]);
        window.refreshCount = 0;
        createApp({render: () => h(ConfigProvider, {theme:{cssVar:true}}, () => h(Component, {assets,
          onRefresh: () => {window.refreshCount++; Object.assign(assets[0].derive[0], window.savedAsset);},
        }))}).mount('#app');
      </script>`,
  }));
  await page.goto(`${base}/__alignment.html`);
  await page.getByRole('button', { name: '编辑', exact: true }).click();
  const description = page.locator('.ant-modal textarea').nth(0);
  const textarea = page.locator('.ant-modal textarea').nth(1);
  assert.equal(await description.inputValue(), '原始服装描述');
  assert.equal(await textarea.inputValue(), '灰色卫衣与运动鞋');
  await description.fill('现代通勤造型');
  const edited = '现代灰色卫衣、黑色长裤、白色运动鞋；保留左脸旧伤，不改成古装。';
  await textarea.fill(edited);
  await page.locator('.ant-modal .ant-btn-primary').click();
  await page.waitForFunction(() => window.refreshCount === 1);
  await textarea.waitFor({ state: 'hidden' });
  await page.getByRole('button', { name: '编辑', exact: true }).click();
  await textarea.waitFor({ state: 'visible' });
  assert.equal(await textarea.inputValue(), edited, 'reopened editor reads the saved prompt');
  await page.waitForFunction(() => {
    const modal = document.querySelector('.ant-modal');
    return modal && getComputedStyle(modal).opacity === '1' &&
      ![...modal.classList].some(name => name.includes('enter') || name.includes('leave'));
  });
  await fs.mkdir('.codex/audit/toonflow-alignment', { recursive: true });
  await page.screenshot({ path: '.codex/audit/toonflow-alignment/prompt-editor.png', fullPage: true, animations: 'disabled' });
  await page.locator('.ant-modal-close').click();
  await page.getByRole('button', { name: '生成图片', exact: true }).click();
  const generated = await page.evaluate(() => window.generationInput);
  assert.equal(generated.projectId, 100);
  assert.deepEqual(generated.arguments.ids, [2]);
  assert.deepEqual(errors, []);
  console.log('PASS: browser edit → save → refresh → reopen → generation input; APIs mocked');
} finally {
  await browser.close();
}

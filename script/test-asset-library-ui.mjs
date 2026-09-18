// Run against local Vite. All asset APIs are mocked; no real data is deleted.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { chromium } from '../apps/web/node_modules/playwright/index.mjs';

const base = process.env.ASSET_UI_URL || 'http://127.0.0.1:5666';
const componentPath = '/src/views/toonflow/assets/index.vue';
const compiled = await (await fetch(`${base}${componentPath}`)).text();
const vuePath = compiled.match(/from "([^"]*\/vue\.js[^\"]*)"/)?.[1];
const antPath = compiled.match(/from "([^"]*\/ant-design-vue\.js[^\"]*)"/)?.[1];
assert.ok(vuePath);
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
page.on('pageerror', error => { errors.push(error.message); console.error(error.message); });
page.on('console', msg => { if (msg.type() === 'error' || msg.type() === 'warning') console.error(msg.text()); });
try {
  await page.route('**/api/**', route => route.abort());
  await page.route('**/src/api/toonflow/index.ts*', route => route.fulfill({ contentType: 'text/javascript', body: `
    let assets = [
      {id:1,name:'李晨 · 基础形象',type:'role',description:'统一真人影视基底，青年面部与体态参考',prompt:'青年，干净自然光'},
      {id:2,name:'张曼成 · 生成失败',type:'role',description:'失败资产也可以删除',imageState:'生成失败'},
      {id:3,name:'周仓 · 正在生成',type:'role',description:'任务正在运行'},
      {id:4,name:'蜀郡医馆',type:'scene',description:'木制门窗与药柜'},
      {id:5,name:'同行老者',type:'role',description:'布衣行医者'},
    ];
    window.deletedBatches=[];
    export async function getProjects(){return [{id:100,name:'历史国战 · 测试项目'}]}
    export async function getProject(){return {id:100,name:'历史国战 · 测试项目',imageQuality:'2K'}}
    export async function getAssetLibrary(){return assets}
    export async function deleteAssets(ids){window.deletedBatches.push(ids); assets=assets.filter(a=>!ids.includes(a.id));}
    export async function batchBindAudio(){}
    export async function generateAssetDubbing(){}
    export async function saveAsset(){}
    export async function uploadMaterial(){}
  ` }));
  await page.route('**/useAssetGeneration.ts*', route => route.fulfill({ contentType:'text/javascript', body:`
    import {ref,reactive} from ${JSON.stringify(vuePath)};
    export function useAssetGeneration(){return {
      generationFailedIds:ref(new Set([2])), generatingAssetIds:ref(new Set([3])), polishingAssetIds:reactive(new Set()),
      batchRunning:ref(''),batchProgress:ref({current:0,total:0}),batchProjectName:ref(''),submitting:ref(false),
      cancelling:ref(false),statusError:ref(''),start(){},stop(){},async refreshStatuses(){},
      cancelBatchImages(){},polish(){},generate(){}
    }}
  ` }));
  // Substitute only layout/router imports; mount the real page and Ant components.
  await page.route(`**${componentPath}`, route => route.fulfill({contentType:'text/javascript', body:compiled
    .replace(/import \{ Page \} from [^;]+;/, `import {h as testH} from ${JSON.stringify(vuePath)}; const Page = {setup:(_, {slots})=>()=>testH('div',{style:'height:100vh'},slots.default?.())};`)
    .replace(/import \{ useRoute, useRouter \} from [^;]+;/, `const useRoute=()=>({query:{}}); const useRouter=()=>({replace:async()=>{}});`)
  }));
  await page.route('**/__asset-library.html', route => route.fulfill({contentType:'text/html',body:`
    <!doctype html><meta charset="UTF-8"><style>body{margin:0;font-family:sans-serif}.hidden{display:none}#app{padding:20px;box-sizing:border-box}</style><div id="app"></div>
    <script type="module">
    import {createApp,h} from ${JSON.stringify(vuePath)};
    import {ConfigProvider} from ${JSON.stringify(antPath)};
    import Component from ${JSON.stringify(componentPath)};
    createApp({render:()=>h(ConfigProvider,{},()=>h(Component))}).mount('#app');
    </script>`}));
  await page.goto(`${base}/__asset-library.html`);
  await page.getByRole('heading',{name:'李晨 · 基础形象'}).waitFor();
  await page.getByRole('checkbox',{name:'全选',exact:true}).check();
  await page.getByRole('button',{name:/批量删除/}).click();
  await page.getByText('所选资产中有正在执行的任务，请先取消任务或取消勾选这些资产').waitFor();
  assert.deepEqual(await page.evaluate(()=>window.deletedBatches),[]);
  await page.getByRole('checkbox',{name:'选择周仓 · 正在生成',exact:true}).uncheck();
  await page.getByRole('tab',{name:/场景/}).click();
  assert.ok(await page.getByRole('button',{name:'批量删除',exact:true}).isDisabled(), 'category change clears hidden selection');
  await page.getByRole('tab',{name:/角色/}).click();
  await page.getByRole('checkbox',{name:'选择张曼成 · 生成失败',exact:true}).check();
  await page.getByRole('checkbox',{name:'选择李晨 · 基础形象',exact:true}).check();
  await page.getByRole('button',{name:/批量删除/}).click();
  await page.locator('.ant-modal-confirm .ant-btn').filter({hasText:/取\s*消/}).click();
  assert.deepEqual(await page.evaluate(()=>window.deletedBatches),[],'cancel leaves assets intact');
  await page.getByRole('button',{name:/批量删除/}).click();
  await page.locator('.ant-modal-confirm .ant-btn-dangerous').click();
  await page.getByRole('heading',{name:'张曼成 · 生成失败'}).waitFor({state:'hidden'});
  assert.deepEqual(await page.evaluate(()=>window.deletedBatches),[[1,2]],'bulk deletion includes failed assets');
  await page.getByRole('checkbox',{name:'选择同行老者',exact:true}).check();
  await page.getByPlaceholder('搜索名称或描述').fill('周仓');
  assert.ok(await page.getByRole('button',{name:'批量删除',exact:true}).isDisabled(),'search clears hidden selection');
  await page.getByPlaceholder('搜索名称或描述').fill('');
  await page.waitForFunction(()=>document.querySelectorAll('.ant-message-notice').length===0);
  await fs.mkdir('.codex/audit/asset-library',{recursive:true});
  await page.screenshot({path:'.codex/audit/asset-library/desktop.png',fullPage:true});
  await page.setViewportSize({width:390,height:844});
  await page.screenshot({path:'.codex/audit/asset-library/mobile.png',fullPage:true});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'mobile has no horizontal overflow');
  assert.deepEqual(errors,[]);
  console.log('PASS: selection, hidden selection reset, busy-task guard, cancel, failed-asset deletion, mobile layout; APIs mocked');
} catch (error) {
  console.error((await page.locator('body').innerText()).slice(0, 3000));
  throw error;
} finally { await browser.close(); }

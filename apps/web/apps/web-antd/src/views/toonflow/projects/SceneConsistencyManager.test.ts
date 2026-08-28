import { createApp, defineComponent, h, nextTick, ref } from 'vue';

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const sceneConsistencyApi = vi.hoisted(() => ({
  autoConfigure: vi.fn(),
  getCatalog: vi.fn(),
  saveMaster: vi.fn(),
  saveState: vi.fn(),
}));

vi.mock('#/api/toonflow', () => ({
  autoConfigureSceneConsistency: sceneConsistencyApi.autoConfigure,
  getSceneConsistencyCatalog: sceneConsistencyApi.getCatalog,
  saveSceneMaster: sceneConsistencyApi.saveMaster,
  saveSceneState: sceneConsistencyApi.saveState,
}));

import SceneConsistencyManager from './SceneConsistencyManager.vue';

async function flushUi() {
  await Promise.resolve();
  await nextTick();
  await Promise.resolve();
  await nextTick();
}

describe('SceneConsistencyManager', () => {
  let unmount: (() => void) | undefined;

  beforeEach(() => {
    sceneConsistencyApi.autoConfigure.mockResolvedValue({
      sceneCount: 3,
      statesCreated: 0,
      storyboardsBound: 22,
      warnings: [],
    });
    sceneConsistencyApi.getCatalog.mockResolvedValue({
      scenes: [
        {
          id: 1,
          layoutSpec: {},
          name: '老宅客厅 · 夜',
          projectId: 12,
          revision: 1,
          sceneKey: 'sc1',
          scriptId: 34,
          source: 'manual',
          spatialPrompt: '',
          states: [],
          status: 'ready',
        },
      ],
    });
  });

  afterEach(() => {
    unmount?.();
    unmount = undefined;
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  it('explains the AI-first master flow without a manual scene entry', async () => {
    const open = ref(false);
    const host = document.createElement('div');
    document.body.append(host);
    const app = createApp(
      defineComponent({
        setup: () => () =>
          h(SceneConsistencyManager, {
            assets: [],
            open: open.value,
            projectId: 12,
            sceneKeys: ['sc1'],
            scriptId: 34,
          }),
      }),
    );
    app.mount(host);
    unmount = () => app.unmount();

    open.value = true;
    await flushUi();

    expect(document.body.textContent).toContain('SC1 · 老宅客厅 · 夜');
    expect(document.body.textContent).toContain(
      '选择现有场景图片只会把它锁定为空间参考，不会重新生成图片',
    );
    expect(document.body.textContent).toContain(
      '空间布局约束（可选，AI 可自动识别）',
    );
    expect(document.body.textContent).toContain(
      '持续性的破坏识别为同一场景的后续状态',
    );
    expect(document.body.textContent).toContain('AI 自动识别并配置');
    expect(
      document.querySelector('[data-testid="new-scene-key-input"]'),
    ).toBeNull();
    expect(document.querySelector('[data-testid="add-scene-key"]')).toBeNull();
  });

  it('runs automatic scene planning for the selected script', async () => {
    const host = document.createElement('div');
    document.body.append(host);
    const app = createApp(SceneConsistencyManager, {
      assets: [],
      open: true,
      projectId: 12,
      sceneKeys: [],
      scriptId: 34,
    });
    app.mount(host);
    unmount = () => app.unmount();

    await Promise.resolve();
    await nextTick();
    document
      .querySelector<HTMLButtonElement>(
        '[data-testid="auto-configure-scenes"]',
      )
      ?.click();
    await Promise.resolve();
    await nextTick();

    expect(sceneConsistencyApi.autoConfigure).toHaveBeenCalledWith(12, 34);
  });

  it('previews and preserves the pinned master image when metadata is saved', async () => {
    sceneConsistencyApi.getCatalog.mockResolvedValue({
      scenes: [
        {
          id: 1,
          layoutSpec: {},
          name: '老宅客厅 · 夜',
          pinnedImageId: 89,
          projectId: 12,
          referenceUrl: '/toonflow/assets/files/pinned-old.png',
          revision: 1,
          sceneAssetId: 90,
          sceneKey: 'sc1',
          scriptId: 34,
          source: 'manual',
          spatialPrompt: '门在北墙',
          states: [],
          status: 'ready',
        },
      ],
    });
    sceneConsistencyApi.saveMaster.mockResolvedValue({ id: 1 });
    const open = ref(false);
    const host = document.createElement('div');
    document.body.append(host);
    const app = createApp(
      defineComponent({
        setup: () => () =>
          h(SceneConsistencyManager, {
            assets: [
              {
                description: '',
                id: 90,
                imageFilePath: '/toonflow/assets/files/asset-current.png',
                name: '老宅客厅',
                projectId: 12,
                prompt: '',
                type: 'scene',
              },
            ],
            open: open.value,
            projectId: 12,
            sceneKeys: ['sc1'],
            scriptId: 34,
          }),
      }),
    );
    app.mount(host);
    unmount = () => app.unmount();
    open.value = true;
    await flushUi();

    expect(
      document
        .querySelector('[data-testid="scene-master-preview"] img')
        ?.getAttribute('src'),
    ).toBe('/api/toonflow/assets/files/pinned-old.png');

    const nameInput = document.querySelector<HTMLInputElement>(
      '[data-testid="scene-master-name"]',
    );
    nameInput!.value = '老宅客厅 · 雨夜';
    nameInput!.dispatchEvent(new Event('input', { bubbles: true }));
    await nextTick();
    document
      .querySelector<HTMLButtonElement>('[data-testid="save-scene-master"]')
      ?.click();
    await flushUi();

    expect(sceneConsistencyApi.saveMaster).toHaveBeenCalledWith(
      expect.objectContaining({
        name: '老宅客厅 · 雨夜',
        pinnedImageId: 89,
        sceneAssetId: 90,
      }),
    );
  });

  it('disables manual scene editing while automatic configuration is running', async () => {
    let resolveAutoConfigure: ((value: unknown) => void) | undefined;
    sceneConsistencyApi.autoConfigure.mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveAutoConfigure = resolve;
        }),
    );
    const host = document.createElement('div');
    document.body.append(host);
    const app = createApp(SceneConsistencyManager, {
      assets: [],
      open: true,
      projectId: 12,
      sceneKeys: ['sc1'],
      scriptId: 34,
    });
    app.mount(host);
    unmount = () => app.unmount();
    await flushUi();

    document
      .querySelector<HTMLButtonElement>(
        '[data-testid="auto-configure-scenes"]',
      )
      ?.click();
    await nextTick();

    expect(
      document.querySelector<HTMLInputElement>('[data-testid="scene-master-name"]')
        ?.disabled,
    ).toBe(true);
    const newStateButton = [...document.querySelectorAll('button')].find(
      (button) => button.textContent?.includes('新建状态'),
    );
    expect(newStateButton?.disabled).toBe(true);

    resolveAutoConfigure?.({
      sceneCount: 3,
      statesCreated: 0,
      storyboardsBound: 22,
      warnings: [],
    });
    await flushUi();
  });

  it('loads the correct scene catalog when switching scripts', async () => {
    const scriptId = ref(34);
    sceneConsistencyApi.getCatalog.mockImplementation(
      (_projectId: number, currentScriptId: number) =>
        Promise.resolve({
          scenes: [
            {
              id: currentScriptId,
              layoutSpec: {},
              name: currentScriptId === 34 ? '旧剧本客厅' : '新剧本病房',
              projectId: 12,
              revision: 1,
              sceneKey: 'sc1',
              scriptId: currentScriptId,
              source: 'manual',
              spatialPrompt: '',
              states: [],
              status: 'ready',
            },
          ],
        }),
    );
    const host = document.createElement('div');
    document.body.append(host);
    const app = createApp(
      defineComponent({
        setup: () => () =>
          h(SceneConsistencyManager, {
            assets: [],
            open: true,
            projectId: 12,
            sceneKeys: ['sc1'],
            scriptId: scriptId.value,
          }),
      }),
    );
    app.mount(host);
    unmount = () => app.unmount();
    await flushUi();

    scriptId.value = 35;
    await flushUi();

    expect(
      document.querySelector<HTMLInputElement>('[data-testid="scene-master-name"]')
        ?.value,
    ).toBe('新剧本病房');
  });
});

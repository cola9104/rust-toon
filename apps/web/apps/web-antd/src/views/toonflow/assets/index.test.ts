import { createApp, defineComponent, h, nextTick, reactive, ref } from 'vue';
import { afterEach, describe, expect, it, vi } from 'vitest';
import AssetPage from './index.vue';

const api = vi.hoisted(() => ({ getProjects: vi.fn(), getProject: vi.fn(), getAssetLibrary: vi.fn(), pollAssetImages: vi.fn(),
  cancelAssetImage: vi.fn(), polishAssetPrompt: vi.fn(), queueAssetImages: vi.fn(), retryAssetImages: vi.fn(),
  batchBindAudio: vi.fn(), deleteAssets: vi.fn(), generateAssetDubbing: vi.fn(), saveAsset: vi.fn(), uploadMaterial: vi.fn() }));
vi.mock('#/api/toonflow', () => api);
vi.mock('vue-router', () => ({ useRoute: () => reactive({ query: { projectId: '1' } }), useRouter: () => ({ replace: vi.fn().mockResolvedValue(undefined) }) }));
vi.mock('@vben/common-ui', () => ({ Page: defineComponent({ setup: (_, { slots }) => () => h('div', slots.default?.()) }) }));
vi.mock('./asset-types', () => ({ ASSET_CATEGORY_OPTIONS: [{ value: 'role', label: '角色' }], assetFileUrl: (path: string) => path, assetTypeLabel: () => '角色', isAssetInCategory: () => true }));
vi.mock('ant-design-vue', () => {
  const box = defineComponent({ setup: (_, { slots, attrs }) => () => h('div', [String(attrs.title ?? ''), slots.default?.(), slots.cover?.()]) });
  return { Alert: box, Button: box, Card: Object.assign({ ...box }, { Meta: box }), Checkbox: box, Col: box, Empty: box,
    Form: Object.assign({ ...box }, { Item: box }), Image: box, Input: Object.assign({ ...box }, { Search: box, TextArea: box }),
    Modal: defineComponent({ setup: () => () => null }), Row: box, Space: box, Tag: box,
    Tabs: Object.assign({ ...box }, { TabPane: box }), Typography: { Text: box, Paragraph: box }, theme: { useToken: () => ({ token: ref({}) }) },
    message: { success: vi.fn(), warning: vi.fn(), error: vi.fn() },
    Select: defineComponent({ props: ['options', 'value'], emits: ['change'], setup: (props, { emit }) => () => h('select', {
      value: props.value, onChange: (event: Event) => emit('change', (event.target as HTMLSelectElement).value),
    }, props.options?.map((option: { value: number; label: string }) => h('option', { value: option.value }, option.label))) }),
  };
});
let app: ReturnType<typeof createApp>;
let host: HTMLDivElement;
afterEach(() => { app?.unmount(); host?.remove(); });
async function flush() { for (let i = 0; i < 12; i++) await nextTick(); }
describe('asset library project switch', () => {
  it('keeps the new project assets when the old project request finishes last', async () => {
    let resolveOld!: (value: unknown[]) => void;
    api.getProjects.mockResolvedValue([{ id: 1, name: 'A' }, { id: 2, name: 'B' }]);
    api.getProject.mockImplementation((id) => Promise.resolve({ id, name: String(id), imageModel: 1 }));
    api.pollAssetImages.mockResolvedValue([]);
    api.getAssetLibrary.mockImplementation((id) => id === 1 ? new Promise((resolve) => { resolveOld = resolve; }) : Promise.resolve([{ id: 20, projectId: 2, name: 'B 的角色', type: 'role' }]));
    host = document.createElement('div'); document.body.append(host); app = createApp(AssetPage); app.mount(host); await flush();
    const select = host.querySelector('select')!; select.value = '2'; select.dispatchEvent(new Event('change')); await flush();
    expect(host.textContent).toContain('B 的角色');
    resolveOld([{ id: 10, projectId: 1, name: 'A 的角色', type: 'role' }]); await flush();
    expect(host.textContent).toContain('B 的角色'); expect(host.textContent).not.toContain('A 的角色');
    expect(api.pollAssetImages).toHaveBeenLastCalledWith([20]);
  });
});

import type { ToonflowApi } from '#/api/toonflow';
import { effectScope, ref } from 'vue';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useAssetGeneration } from './useAssetGeneration';

const api = vi.hoisted(() => ({ pollAssetImages: vi.fn(), polishAssetPrompt: vi.fn(), queueAssetImages: vi.fn(), retryAssetImages: vi.fn(), cancelAssetImage: vi.fn() }));
const toast = vi.hoisted(() => ({ success: vi.fn(), warning: vi.fn(), error: vi.fn() }));
vi.mock('#/api/toonflow', () => api);
vi.mock('ant-design-vue', () => ({ message: toast }));
function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>((done) => { resolve = done; }); return { promise, resolve }; }
const scopes: ReturnType<typeof effectScope>[] = [];
function setup() {
  const scope = effectScope(); scopes.push(scope);
  const projectId = ref<number | undefined>(1);
  const project = ref({ id: 1, name: '项目 A', imageModel: '11' } as unknown as ToonflowApi.Project);
  const assets = ref([{ id: 10, projectId: 1, name: '角色', type: 'role', prompt: 'prompt', imageFilePath: 'old.png' }] as ToonflowApi.LibraryAsset[]);
  const ready = vi.fn();
  const generation = scope.run(() => useAssetGeneration(projectId, project, assets, ready))!;
  return { projectId, project, assets, ready, generation };
}
beforeEach(() => { vi.useFakeTimers(); vi.resetAllMocks(); api.pollAssetImages.mockResolvedValue([]); api.queueAssetImages.mockResolvedValue({}); api.cancelAssetImage.mockResolvedValue({}); });
afterEach(() => { scopes.splice(0).forEach((scope) => scope.stop()); vi.clearAllTimers(); vi.useRealTimers(); });

describe('asset generation recovery and isolation', () => {
  it('restores failed attempts on refresh and retains the last usable image', async () => {
    api.pollAssetImages.mockResolvedValue([{ id: 10, imageId: 90, state: '生成失败', errorReason: 'quota' }]);
    const { generation, assets } = setup();
    await generation.refreshStatuses(); await generation.refreshStatuses();
    expect(generation.generationFailedIds.value.has(10)).toBe(true);
    expect(assets.value[0]).toMatchObject({ imageFilePath: 'old.png', imageErrorReason: 'quota' });
  });
  it('does not submit a prepared batch after the project changes', async () => {
    const pending = deferred<{ prompt: string }>(); api.polishAssetPrompt.mockReturnValue(pending.promise);
    const { generation, projectId, assets } = setup(); assets.value[0]!.prompt = '';
    const work = generation.generate(assets.value, '4K');
    projectId.value = 2;
    pending.resolve({ prompt: 'prepared for A' }); await work;
    expect(api.polishAssetPrompt).toHaveBeenCalledWith(expect.objectContaining({ projectId: 1, assetsId: 10 }));
    expect(api.queueAssetImages).not.toHaveBeenCalled();
    expect(generation.batchRunning.value).toBeUndefined();
  });
  it('ignores old status responses after switching projects', async () => {
    const pending = deferred<any[]>(); api.pollAssetImages.mockReturnValue(pending.promise);
    const { generation, projectId, assets, ready } = setup();
    const work = generation.refreshStatuses(); projectId.value = 2; assets.value = [];
    pending.resolve([{ id: 10, imageId: 90, state: '已完成', filePath: 'new.png' }]); await work;
    expect(generation.statuses.size).toBe(0); expect(ready).not.toHaveBeenCalled();
  });
  it('uses image IDs for cancellation and reports failures without a false completion', async () => {
    api.pollAssetImages.mockResolvedValue([{ id: 10, imageId: 90, state: '生成中' }]);
    const { generation, assets } = setup(); await generation.generate(assets.value, '4K');
    expect(api.queueAssetImages).toHaveBeenCalledWith(expect.objectContaining({ projectId: 1, model: '11', resolution: '4K' }));
    await generation.cancelBatchImages(); expect(api.cancelAssetImage).toHaveBeenCalledWith(90);
    expect(generation.batchRunning.value).toBe('image');
    api.pollAssetImages.mockRejectedValueOnce(new Error('offline')); await generation.refreshStatuses();
    expect(generation.batchRunning.value).toBe('image'); expect(generation.statusError.value).toBe('offline');
    api.pollAssetImages.mockResolvedValue([{ id: 10, imageId: 90, state: '生成失败' }]); await generation.refreshStatuses();
    expect(generation.batchRunning.value).toBeUndefined();
    expect(toast.warning).toHaveBeenCalledWith(expect.stringContaining('0 项图片生成成功，1 项失败或取消'));
  });
  it('retries backend failures using the original project and accepted IDs', async () => {
    const { generation, assets } = setup();
    api.retryAssetImages.mockResolvedValue({ ids: [10] });
    api.pollAssetImages.mockResolvedValue([{ id: 10, imageId: 91, state: '生成中' }]);
    await generation.generate(assets.value, '2K', true);
    expect(api.retryAssetImages).toHaveBeenCalledWith({ projectId: 1, ids: [10], concurrentCount: 5 });
    expect(generation.generatingAssetIds.value.has(10)).toBe(true);
    generation.stop(); await vi.advanceTimersByTimeAsync(10000);
    expect(api.pollAssetImages).toHaveBeenCalledTimes(1);
  });
});

import type { ToonflowApi } from '#/api/toonflow';
import { effectScope } from 'vue';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useTaskCenter } from './useTaskCenter';
const api = vi.hoisted(() => ({ getTaskPage: vi.fn(), getTaskDetails: vi.fn(), getTaskCategories: vi.fn(), getTaskProjects: vi.fn() }));
vi.mock('#/api/toonflow', () => api);
const stats = { total: 100, running: 20, success: 70, failed: 10 };
const task = (id: number, state = 'running') => ({ id, state, description: `task ${id}` }) as ToonflowApi.Task;
const response = (id: number) => ({ data: [task(id)], total: 100, stats });
function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>((done) => { resolve = done; }); return { promise, resolve }; }
let scope: ReturnType<typeof effectScope>;
let center: ReturnType<typeof useTaskCenter>;
beforeEach(() => {
  vi.useFakeTimers(); vi.resetAllMocks();
  api.getTaskPage.mockResolvedValue(response(1)); api.getTaskCategories.mockResolvedValue([]); api.getTaskProjects.mockResolvedValue([]);
  scope = effectScope(); center = scope.run(useTaskCenter)!;
});
afterEach(() => { center.stop(); scope.stop(); vi.useRealTimers(); });
describe('task center paging and polling', () => {
  it('applies valid dashboard filters on first load', async () => {
    const filtered = scope.run(() => useTaskCenter({ projectId: 7, state: 'failed' }))!;
    filtered.start();
    await vi.advanceTimersByTimeAsync(0);
    expect(api.getTaskPage).toHaveBeenLastCalledWith(expect.objectContaining({ projectId: 7, state: 'failed' }));
    filtered.stop();
  });
  it('preserves large task IDs when loading details', async () => {
    const record = { ...task(1), id: '1789003357277804801' };
    api.getTaskDetails.mockResolvedValue(record);
    center.openDetail(record);
    await vi.advanceTimersByTimeAsync(0);
    expect(api.getTaskDetails).toHaveBeenCalledWith('1789003357277804801');
    expect(center.detail.value?.id).toBe(record.id);
    expect(center.detailError.value).toBe('');
  });
  it('requests server pages and resets the page when project/state changes', async () => {
    center.start(); await vi.advanceTimersByTimeAsync(0);
    center.changePage(3, 20); await vi.advanceTimersByTimeAsync(0);
    expect(api.getTaskPage).toHaveBeenLastCalledWith(expect.objectContaining({ page: 3, limit: 20 }));
    center.projectId.value = 7; center.state.value = 'failed'; await vi.advanceTimersByTimeAsync(0);
    expect(api.getTaskPage).toHaveBeenLastCalledWith(expect.objectContaining({ page: 1, projectId: 7, state: 'failed' }));
    expect(center.taskStats.value).toEqual(stats);
  });
  it('ignores a late response for a previous filter', async () => {
    const pending = deferred<ReturnType<typeof response>>(); api.getTaskPage.mockReturnValueOnce(pending.promise);
    center.start(); center.projectId.value = 7; await vi.advanceTimersByTimeAsync(0);
    pending.resolve(response(99)); await vi.advanceTimersByTimeAsync(0);
    expect(center.tasks.value[0]!.id).toBe(1);
  });
  it('refreshes an open task outside the current page and ignores a closed drawer response', async () => {
    api.getTaskDetails.mockResolvedValue(task(99, 'completed'));
    center.openDetail(task(99)); await center.load();
    expect(center.detail.value?.state).toBe('completed'); expect(center.tasks.value[0]!.id).toBe(1);
    const pending = deferred<ToonflowApi.Task>(); api.getTaskDetails.mockReturnValueOnce(pending.promise);
    center.openDetail(task(88)); center.closeDetail(); pending.resolve(task(88)); await vi.advanceTimersByTimeAsync(0);
    expect(center.detail.value).toBeUndefined();
  });
  it('waits for a request before scheduling the next poll and stops on leave', async () => {
    const pending = deferred<ReturnType<typeof response>>(); api.getTaskPage.mockReturnValueOnce(pending.promise);
    center.start(); await vi.advanceTimersByTimeAsync(15000); expect(api.getTaskPage).toHaveBeenCalledTimes(1);
    pending.resolve(response(1)); await vi.advanceTimersByTimeAsync(5000); expect(api.getTaskPage).toHaveBeenCalledTimes(2);
    center.stop(); await vi.advanceTimersByTimeAsync(15000); expect(api.getTaskPage).toHaveBeenCalledTimes(2);
  });
  it('preserves displayed tasks when a refresh fails', async () => {
    await center.load(); api.getTaskPage.mockRejectedValueOnce(new Error('offline')); await center.load();
    expect(center.tasks.value[0]!.id).toBe(1); expect(center.loadError.value).toBe('offline');
  });
});

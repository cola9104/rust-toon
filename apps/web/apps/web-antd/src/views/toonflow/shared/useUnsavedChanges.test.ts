import { createApp, defineComponent, ref } from 'vue';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useUnsavedChanges } from './useUnsavedChanges';
const mocks = vi.hoisted(() => ({ confirm: vi.fn(), info: vi.fn(), leave: vi.fn(), update: vi.fn() }));
vi.mock('ant-design-vue', () => ({ Modal: { confirm: mocks.confirm }, message: { info: mocks.info } }));
vi.mock('vue-router', () => ({ onBeforeRouteLeave: mocks.leave, onBeforeRouteUpdate: mocks.update }));
let app: ReturnType<typeof createApp>;
let host: HTMLElement;
beforeEach(() => vi.clearAllMocks());
afterEach(() => { app.unmount(); host.remove(); });
function setup() {
  const count = ref(2); const saving = ref(false); const discard = vi.fn();
  let guard!: ReturnType<typeof useUnsavedChanges>;
  host = document.createElement('div'); app = createApp(defineComponent({ setup() { guard = useUnsavedChanges(count, saving, discard); return () => null; } })); app.mount(host);
  return { count, saving, discard, guard };
}
describe('unsaved edit protection', () => {
  it('cancels refresh without losing edits and accepts explicit discard on navigation', async () => {
    const { guard, discard } = setup(); const refresh = guard.confirmDiscard('刷新配置');
    mocks.confirm.mock.calls[0]![0].onCancel(); expect(await refresh).toBe(false); expect(discard).not.toHaveBeenCalled();
    const leave = mocks.leave.mock.calls[0]![0](); mocks.confirm.mock.calls[1]![0].onOk();
    expect(await leave).toBe(true); expect(discard).toHaveBeenCalledTimes(1);
  });
  it('warns on browser close only when there are unsaved edits', () => {
    const { count } = setup(); const dirty = new Event('beforeunload', { cancelable: true }); window.dispatchEvent(dirty); expect(dirty.defaultPrevented).toBe(true);
    count.value = 0; const clean = new Event('beforeunload', { cancelable: true }); window.dispatchEvent(clean); expect(clean.defaultPrevented).toBe(false);
  });
  it('blocks leaving during save and removes the browser listener on unmount', async () => {
    const { saving, guard } = setup(); saving.value = true; expect(await guard.confirmDiscard('离开')).toBe(false); expect(mocks.confirm).not.toHaveBeenCalled();
    app.unmount(); const event = new Event('beforeunload', { cancelable: true }); window.dispatchEvent(event); expect(event.defaultPrevented).toBe(false);
  });
});

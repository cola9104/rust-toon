import type { Ref } from 'vue';
import { onActivated, onBeforeUnmount, onDeactivated } from 'vue';
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router';
import { Modal, message } from 'ant-design-vue';

export function useUnsavedChanges(count: Ref<number>, saving: Ref<boolean>, discard?: () => void) {
  let active = true;
  let pending: Promise<boolean> | undefined;
  function confirmDiscard(action: string): Promise<boolean> {
    if (saving.value) { message.info('正在保存，请稍候'); return Promise.resolve(false); }
    if (!count.value) return Promise.resolve(true);
    if (pending) return pending;
    pending = new Promise<boolean>((resolve) => {
      Modal.confirm({ title: `有 ${count.value} 项配置尚未保存`,
        content: `${action}将丢弃未保存的修改。可以取消并先保存，或丢弃后继续。`,
        okText: '丢弃并继续', okType: 'danger', cancelText: '继续编辑',
        onOk: () => resolve(true), onCancel: () => resolve(false), afterClose: () => resolve(false),
      });
    }).finally(() => { pending = undefined; });
    return pending;
  }
  function beforeUnload(event: BeforeUnloadEvent) {
    if (active && (count.value || saving.value)) { event.preventDefault(); event.returnValue = ''; }
  }
  window.addEventListener('beforeunload', beforeUnload);
  async function leave() {
    const allowed = await confirmDiscard('离开页面');
    if (allowed) discard?.();
    return allowed;
  }
  onBeforeRouteLeave(leave);
  onBeforeRouteUpdate(leave);
  onActivated(() => { active = true; });
  onDeactivated(() => { active = false; });
  onBeforeUnmount(() => window.removeEventListener('beforeunload', beforeUnload));
  return { confirmDiscard };
}

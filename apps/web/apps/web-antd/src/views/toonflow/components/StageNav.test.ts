import { createApp } from 'vue';

import { afterEach, describe, expect, it, vi } from 'vitest';

import StageNav from './StageNav.vue';

const stages = [
  { key: 'novel', label: '原文', hint: '导入与事件提取', icon: '文' },
  {
    key: 'production',
    label: '分镜制作',
    hint: '画布与视频工作台',
    icon: '制',
  },
] as const;

let unmount: (() => void) | undefined;

afterEach(() => {
  unmount?.();
  unmount = undefined;
});

describe('StageNav', () => {
  it('uses menu-compatible active state semantics and emits stage changes', () => {
    const host = document.createElement('div');
    const onChange = vi.fn();
    const app = createApp(StageNav, {
      modelValue: 'novel',
      stages,
      'onUpdate:modelValue': onChange,
    });
    app.mount(host);
    unmount = () => app.unmount();

    const buttons = host.querySelectorAll<HTMLButtonElement>(
      '.stage-nav__item',
    );

    expect(buttons).toHaveLength(2);
    expect(buttons[0]?.classList.contains('is-active')).toBe(true);
    expect(buttons[0]?.getAttribute('aria-current')).toBe('step');
    expect(buttons[1]?.classList.contains('is-active')).toBe(false);
    expect(buttons[1]?.hasAttribute('aria-current')).toBe(false);

    buttons[1]?.click();
    expect(onChange).toHaveBeenCalledOnce();
    expect(onChange).toHaveBeenCalledWith('production');
  });
});

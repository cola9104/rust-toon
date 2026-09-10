import { createApp, defineComponent, h, nextTick, ref } from 'vue';

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import DictPage from './index.vue';

const { getSimpleDictTypeList, showError } = vi.hoisted(() => ({
  getSimpleDictTypeList: vi.fn(),
  showError: vi.fn(),
}));
const dictionaries = [
  { name: 'AI 平台', type: 'ai_platform' },
  { name: '用户性别', type: 'system_user_sex' },
  ...Array.from({ length: 5 }, (_, i) => ({ name: `字典 ${i}`, type: `dict_${i}` })),
];
vi.mock('#/api/system/dict/type', () => ({ getSimpleDictTypeList }));
beforeEach(() => {
  getSimpleDictTypeList.mockReset().mockResolvedValue(dictionaries);
  showError.mockClear();
});

vi.mock('@vben/common-ui', () => ({
  Page: defineComponent({ setup: (_, { slots }) => () => h('div', slots.default?.()) }),
}));
vi.mock('ant-design-vue', () => ({
  Button: defineComponent({ setup: (_, { slots }) => () => h('button', slots.default?.()) }),
  message: { error: showError },
  Select: defineComponent({
    props: {
      value: String,
      options: { type: Array<{ label: string; value: string }>, default: () => [] },
      showSearch: Boolean,
      optionFilterProp: String,
    },
    emits: ['change', 'dropdownVisibleChange'],
    setup: (props, { emit }) => () => h('select', {
      value: props.value,
      'data-searchable': String(props.showSearch),
      'data-filter-by': props.optionFilterProp,
      onFocus: () => emit('dropdownVisibleChange', true),
      onChange: (event: Event) => emit('change', (event.target as HTMLSelectElement).value),
    }, props.options.map((option: { label: string; value: string }) => h('option', { value: option.value }, option.label))),
  }),
}));
vi.mock('./modules/type-grid.vue', () => ({
  default: defineComponent({
    emits: ['select'],
    setup(_, { emit }) {
      const search = ref('');
      const page = ref(1);
      return () => h('div', { 'data-testid': 'types' }, [
        h('input', {
          value: search.value,
          onInput: (event: Event) => { search.value = (event.target as HTMLInputElement).value; },
        }),
        h('button', { 'data-testid': 'next', onClick: () => { page.value += 1; } }, `第 ${page.value} 页`),
        ...['AI 平台', '用户性别'].map((name, index) => h('button', {
          'data-testid': `open-${index}`,
          onClick: () => emit('select', { name, type: index ? 'system_user_sex' : 'ai_platform' }),
        }, name)),
      ]);
    },
  }),
}));
vi.mock('./modules/data-grid.vue', () => ({
  default: defineComponent({
    props: { dictType: String },
    setup(props) {
      const search = ref('');
      const page = ref(1);
      return () => h('div', { 'data-testid': 'items' }, [
        h('span', { 'data-testid': 'current-type' }, props.dictType),
        h('input', {
          value: search.value,
          onInput: (event: Event) => { search.value = (event.target as HTMLInputElement).value; },
        }),
        h('button', { 'data-testid': 'item-next', onClick: () => { page.value += 1; } }, `第 ${page.value} 页`),
      ]);
    },
  }),
}));

let cleanup: (() => void) | undefined;
afterEach(() => { cleanup?.(); });

describe('dictionary navigation', () => {
  it('opens one dictionary at a time and preserves the list state when returning', async () => {
    const host = document.createElement('div');
    const app = createApp(DictPage);
    app.mount(host);
    cleanup = () => app.unmount();

    expect(host.querySelector('[data-testid="items"]')).toBeNull();
    const types = host.querySelector<HTMLElement>('[data-testid="types"]')!;
    const search = types.querySelector('input')!;
    search.value = 'AI';
    search.dispatchEvent(new Event('input'));
    types.querySelector<HTMLButtonElement>('[data-testid="next"]')!.click();
    types.querySelector<HTMLButtonElement>('[data-testid="open-0"]')!.click();
    await nextTick();

    expect(types.parentElement?.style.display).toBe('none');
    expect(host.querySelector('[data-testid="current-type"]')?.textContent).toBe('ai_platform');
    expect(host.querySelector('h1')?.textContent).toBe('AI 平台');
    [...host.querySelectorAll('button')].find((button) => button.textContent === '返回全部字典')!.click();
    await nextTick();

    expect(host.querySelector('[data-testid="items"]')).toBeNull();
    expect(types.parentElement?.style.display).not.toBe('none');
    expect(host.querySelector('[data-testid="types"]')).toBe(types);
    expect(search.value).toBe('AI');
    expect(types.querySelector('[data-testid="next"]')?.textContent).toBe('第 2 页');

    types.querySelector<HTMLButtonElement>('[data-testid="open-1"]')!.click();
    await nextTick();
    expect(host.querySelector('[data-testid="current-type"]')?.textContent).toBe('system_user_sex');
    [...host.querySelectorAll('button')].find((button) => button.textContent === '返回全部字典')!.click();
    await nextTick();
    expect(host.querySelector('[data-testid="items"]')).toBeNull();
  });

  it('switches directly and restores each dictionary search and page through recent shortcuts', async () => {
    const host = document.createElement('div');
    const app = createApp(DictPage);
    app.mount(host);
    cleanup = () => app.unmount();
    await nextTick();
    host.querySelector<HTMLButtonElement>('[data-testid="open-0"]')!.click();
    await nextTick();
    const firstItems = host.querySelector('[data-testid="items"]')!;
    const search = firstItems.querySelector('input')!;
    search.value = '火山';
    search.dispatchEvent(new Event('input'));
    firstItems.querySelector<HTMLButtonElement>('[data-testid="item-next"]')!.click();

    const select = host.querySelector('select')!;
    expect(select.dataset.searchable).toBe('true');
    expect(select.dataset.filterBy).toBe('label');
    expect([...select.options].map((option) => option.textContent)).toContain('AI 平台 · ai_platform');
    select.value = 'system_user_sex';
    select.dispatchEvent(new Event('change'));
    await nextTick();
    expect(host.querySelector('[data-testid="current-type"]')?.textContent).toBe('system_user_sex');
    const secondItems = host.querySelector('[data-testid="items"]')!;
    expect(secondItems.querySelector('input')!.value).toBe('');
    expect(secondItems.querySelector('[data-testid="item-next"]')?.textContent).toBe('第 1 页');

    host.querySelector<HTMLButtonElement>('nav button[title="ai_platform"]')!.click();
    await nextTick();
    expect(host.querySelector('[data-testid="items"]')).toBe(firstItems);
    expect(search.value).toBe('火山');
    expect(firstItems.querySelector('[data-testid="item-next"]')?.textContent).toBe('第 2 页');
    expect(host.querySelectorAll('nav button[title="ai_platform"]')).toHaveLength(1);
    expect(host.querySelector('nav button[title="ai_platform"]')?.getAttribute('aria-pressed')).toBe('true');

    for (const dict of dictionaries.slice(2)) {
      select.value = dict.type;
      select.dispatchEvent(new Event('change'));
      await nextTick();
    }
    expect(host.querySelectorAll('nav button')).toHaveLength(5);
    expect(host.querySelector('nav button')?.getAttribute('title')).toBe('dict_4');
  });

  it('keeps the list usable after a load failure and retries when the switcher opens', async () => {
    getSimpleDictTypeList.mockRejectedValueOnce(new Error('offline'));
    const host = document.createElement('div');
    const app = createApp(DictPage);
    app.mount(host);
    cleanup = () => app.unmount();
    await nextTick();
    expect(showError).toHaveBeenCalledOnce();
    host.querySelector<HTMLButtonElement>('[data-testid="open-0"]')!.click();
    await nextTick();
    host.querySelector('select')!.dispatchEvent(new Event('focus'));
    await nextTick();
    await nextTick();
    expect(getSimpleDictTypeList).toHaveBeenCalledTimes(2);
    expect(host.querySelector('select')!.options).toHaveLength(dictionaries.length);
    expect(host.querySelector('[data-testid="current-type"]')?.textContent).toBe('ai_platform');
  });
});

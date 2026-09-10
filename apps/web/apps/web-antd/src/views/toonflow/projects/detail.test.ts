// @vitest-environment happy-dom

import { createApp, defineComponent, h, KeepAlive, nextTick, onMounted } from 'vue';
import { createMemoryHistory, createRouter, RouterView } from 'vue-router';
import { afterEach, expect, it, vi } from 'vitest';
import Detail from './detail.vue';

const mountedIds = vi.hoisted(() => [] as number[]);
vi.mock('./detail/ProjectDetailWorkspace.vue', () => ({
  default: defineComponent({
    props: { projectId: { type: Number, required: true } },
    setup(props) {
      onMounted(() => mountedIds.push(props.projectId));
      return () => h('div', `project:${props.projectId}`);
    },
  }),
}));

let app: ReturnType<typeof createApp>;
let host: HTMLDivElement;
afterEach(() => { app?.unmount(); host?.remove(); mountedIds.length = 0; });

it.each([false, true])('returns to a valid workspace with keepAlive=%s', async (cached) => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/toonflow/projects/:id', name: 'ToonflowProjectDetail', component: Detail },
      { path: '/other/:id?', component: defineComponent({ render: () => h('div', 'other') }) },
    ],
  });
  app = createApp({
    render: () => h(RouterView, {}, {
      default: ({ Component }: any) => cached
        ? h(KeepAlive, {}, { default: () => Component }) : Component,
    }),
  });
  app.use(router);
  await router.push('/toonflow/projects/1789001546712');
  await router.isReady();
  host = document.createElement('div');
  document.body.append(host);
  app.mount(host);
  for (const target of ['/other', '/other/42']) {
    await router.push(target);
    await nextTick();
    await router.push('/toonflow/projects/1789001546712');
    await nextTick();
    expect(host.textContent).toContain('project:1789001546712');
  }
  await router.push('/toonflow/projects/1789001546713');
  await nextTick();
  expect(host.textContent).toContain('project:1789001546713');
  expect(mountedIds.every((id) => [1789001546712, 1789001546713].includes(id))).toBe(true);
});

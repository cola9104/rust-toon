import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/toonflow',
    name: 'Toonflow',
    meta: {
      title: '短剧工厂',
      icon: 'lucide:clapperboard',
      order: 20,
    },
    children: [
      {
        path: '/toonflow/projects',
        component: () => import('#/views/toonflow/projects/index.vue'),
        name: 'ToonflowProjects',
        meta: {
          title: '项目工作台',
          icon: 'lucide:layout-dashboard',
        },
      },
      {
        path: '/toonflow/projects/:id',
        component: () => import('#/views/toonflow/projects/detail.vue'),
        name: 'ToonflowProjectDetail',
        meta: {
          title: '项目详情',
          icon: 'lucide:file-stack',
          activePath: '/toonflow/projects',
          hideInMenu: true,
          noCache: true,
        },
      },
      {
        path: '/toonflow/manuals',
        component: () => import('#/views/toonflow/manuals/index.vue'),
        name: 'ToonflowManuals',
        meta: { title: '创作手册', icon: 'lucide:notebook-tabs' },
      },
      {
        path: '/toonflow/styles',
        component: () => import('#/views/toonflow/styles/index.vue'),
        name: 'ToonflowStyles',
        meta: { title: '风格库', icon: 'lucide:palette' },
      },
      {
        path: '/toonflow/tasks',
        component: () => import('#/views/toonflow/tasks/index.vue'),
        name: 'ToonflowTasks',
        meta: { title: '任务中心', icon: 'lucide:list-checks' },
      },
      {
        path: '/toonflow/prompts',
        component: () => import('#/views/toonflow/prompts/index.vue'),
        name: 'ToonflowPrompts',
        meta: { title: '提示词与 Skill', icon: 'lucide:wand-sparkles' },
      },
      {
        path: '/toonflow/settings',
        component: () => import('#/views/toonflow/settings/index.vue'),
        name: 'ToonflowSettings',
        meta: {
          title: '模型与 Agent',
          icon: 'lucide:bot',
        },
      },
      {
        path: '/toonflow/settings/model-map',
        component: () => import('#/views/toonflow/settings/model-map.vue'),
        name: 'ToonflowModelPromptMap',
        meta: { title: '模型 Prompt 映射', icon: 'lucide:link-2' },
      },
    ],
  },
];

export default routes;

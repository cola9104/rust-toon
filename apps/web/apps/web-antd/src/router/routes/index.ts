import type { RouteRecordRaw } from 'vue-router';

import { traverseTreeValues } from '@vben/utils';

import { coreRoutes, fallbackNotFoundRoute } from './core';

// 有需要可以自行打开注释，并创建文件夹
// const externalRouteFiles = import.meta.glob('./external/**/*.ts', { eager: true });
// const staticRouteFiles = import.meta.glob('./static/**/*.ts', { eager: true });

/** 外部路由列表，访问这些页面可以不需要Layout，可能用于内嵌在别的系统(不会显示在菜单中) */
// const externalRoutes: RouteRecordRaw[] = mergeRouteModules(externalRouteFiles);
// const staticRoutes: RouteRecordRaw[] = mergeRouteModules(staticRouteFiles);
const staticRoutes: RouteRecordRaw[] = [
  {
    path: '/toonflow/projects/:id/workbench',
    component: () => import('#/views/toonflow/projects/workbench.vue'),
    name: 'ToonflowVideoWorkbench',
    meta: {
      title: '视频工作台',
      icon: 'lucide:clapperboard',
      activePath: '/toonflow/projects',
      hideInMenu: true,
      fullPathKey: false,
    },
  },
];
const externalRoutes: RouteRecordRaw[] = [];

/** 路由列表，由基本路由、外部路由和404兜底路由组成
 *  无需走权限验证（会一直显示在菜单中） */
const routes: RouteRecordRaw[] = [
  // Keep the hidden workbench route under the existing Root/BasicLayout
  // record. A top-level route would bypass the app shell and render fullscreen.
  ...coreRoutes.map((route) =>
    route.name === 'Root'
      ? { ...route, children: [...(route.children ?? []), ...staticRoutes] }
      : route,
  ),
  ...externalRoutes,
  fallbackNotFoundRoute,
];

/** 基本路由列表，这些路由不需要进入权限拦截 */
const coreRouteNames = traverseTreeValues(coreRoutes, (route) => route.name);

/**
 * 业务路由以 system_menu 为唯一来源。本地只保留核心、静态和外部路由，
 * 避免与后端菜单生成同名或同路径的第二套路由。
 */
const accessRoutes = [...staticRoutes];

// add by 芋艿：from https://github.com/vbenjs/vue-vben-admin/blob/main/playground/src/router/routes/index.ts#L38-L45
const componentKeys: string[] = Object.keys(
  import.meta.glob('../../views/**/*.vue'),
)
  .filter((item) => !item.includes('/modules/'))
  .map((v) => {
    const path = v.replace('../../views/', '/');
    return path.endsWith('.vue') ? path.slice(0, -4) : path;
  });
export { accessRoutes, componentKeys, coreRouteNames, routes };

import type {
  AppRouteRecordRaw,
  ComponentRecordType,
  GenerateMenuAndRoutesOptions,
} from '@vben/types';

import type { Router } from 'vue-router';

import { generateAccessible } from '@vben/access';
import { preferences } from '@vben/preferences';
import { useAccessStore } from '@vben/stores';
import { convertServerMenuToRouteRecordStringComponent } from '@vben/utils';

import { BasicLayout, IFrameView } from '#/layouts';
import { accessRoutes } from '#/router/routes';

const forbiddenComponent = () => import('#/views/_core/fallback/forbidden.vue');

async function generateAccess(options: GenerateMenuAndRoutesOptions) {
  const pageMap: ComponentRecordType = import.meta.glob('../views/**/*.vue');
  const accessStore = useAccessStore();

  const layoutMap: ComponentRecordType = {
    BasicLayout,
    IFrameView,
  };

  const result = await generateAccessible(preferences.app.accessMode, {
    ...options,
    fetchMenuListAsync: async () => {
      // 由于 yudao 通过 accessStore 读取，所以不在进行 message.loading 提示
      return convertServerMenuToRouteRecordStringComponent(
        accessStore.backendAccessMenus as AppRouteRecordRaw[],
      );
    },
    // 可以指定没有权限跳转403页面
    forbiddenComponent,
    // 如果 route.meta.menuVisibleWithForbidden = true
    layoutMap,
    pageMap,
  });

  normalizeToonflowTabRoutes(options.router);
  registerProjectWorkbenchRoute(options.router);
  return result;
}

function normalizeToonflowTabRoutes(router: Router) {
  const tabRoutes = new Map([
    ['ToonflowProjects', '/toonflow/projects'],
    ['ToonflowProjectDetail', '/toonflow/projects/:id'],
    ['ToonflowTasks', '/toonflow/tasks'],
  ]);
  for (const [name, path] of tabRoutes) {
    const route = router
      .getRoutes()
      .find((item) => item.name === name || item.path === path);
    if (route) {
      route.meta.fullPathKey = false;
    }
  }
}

function registerProjectWorkbenchRoute(router: Router) {
  const workbenchRoute = accessRoutes.find(
    (route) => route.name === 'ToonflowVideoWorkbench',
  );
  if (!workbenchRoute || !router.hasRoute('Toonflow')) return;

  // The server owns the Toonflow menu tree. Reparent this hidden project route
  // under that tree after it has been generated so it uses the same layout and
  // route hierarchy as /toonflow/projects/:id.
  if (router.hasRoute('ToonflowVideoWorkbench')) {
    router.removeRoute('ToonflowVideoWorkbench');
  }
  router.addRoute('Toonflow', {
    ...workbenchRoute,
    meta: workbenchRoute.meta,
  });
}

export { generateAccess };

import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/infra',
    name: 'Infra',
    meta: {
      title: '基础功能',
      icon: 'lucide:blocks',
      order: 20,
    },
    children: [
      {
        path: '/infra/job',
        component: () => import('#/views/infra/job/index.vue'),
        name: 'InfraJob',
        meta: {
          title: '定时任务',
          icon: 'lucide:timer',
        },
      },
      {
        path: '/infra/api-access-log',
        component: () => import('#/views/infra/apiAccessLog/index.vue'),
        name: 'InfraApiAccessLog',
        meta: {
          title: '访问日志',
          icon: 'lucide:scroll-text',
        },
      },
      {
        path: '/infra/api-error-log',
        component: () => import('#/views/infra/apiErrorLog/index.vue'),
        name: 'InfraApiErrorLog',
        meta: {
          title: '错误日志',
          icon: 'lucide:triangle-alert',
        },
      },
      {
        path: '/infra/config',
        component: () => import('#/views/infra/config/index.vue'),
        name: 'InfraConfig',
        meta: {
          title: '参数配置',
          icon: 'lucide:settings-2',
        },
      },
      {
        path: '/infra/file',
        component: () => import('#/views/infra/file/index.vue'),
        name: 'InfraFile',
        meta: {
          title: '文件管理',
          icon: 'lucide:file',
        },
      },
      {
        path: '/infra/file-config',
        component: () => import('#/views/infra/fileConfig/index.vue'),
        name: 'InfraFileConfig',
        meta: {
          title: '文件配置',
          icon: 'lucide:file-cog',
        },
      },
      {
        path: '/infra/data-source-config',
        component: () => import('#/views/infra/dataSourceConfig/index.vue'),
        name: 'InfraDataSourceConfig',
        meta: {
          title: '数据源配置',
          icon: 'lucide:database-zap',
        },
      },
      {
        path: '/infra/codegen',
        component: () => import('#/views/infra/codegen/index.vue'),
        name: 'InfraCodegen',
        meta: {
          title: '代码生成',
          icon: 'lucide:code-2',
        },
      },
      {
        path: '/infra/build',
        component: () => import('#/views/infra/build/index.vue'),
        name: 'InfraBuild',
        meta: {
          title: '表单构建',
          icon: 'lucide:panel-top',
        },
      },
      {
        path: '/infra/demo01',
        component: () => import('#/views/infra/demo/demo01/index.vue'),
        name: 'InfraDemo01',
        meta: {
          title: '示例一',
          icon: 'lucide:flask-conical',
        },
      },
      {
        path: '/infra/demo02',
        component: () => import('#/views/infra/demo/demo02/index.vue'),
        name: 'InfraDemo02',
        meta: {
          title: '示例二',
          icon: 'lucide:flask-round',
        },
      },
    ],
  },
  {
    path: '/infra/monitor',
    name: 'InfraMonitor',
    meta: {
      title: '基础设施',
      icon: 'lucide:server-cog',
      order: 21,
    },
    children: [
      {
        path: '/infra/redis',
        component: () => import('#/views/infra/redis/index.vue'),
        name: 'InfraRedis',
        meta: {
          title: 'Redis 监控',
          icon: 'lucide:database',
        },
      },
      {
        path: '/infra/server',
        component: () => import('#/views/infra/server/index.vue'),
        name: 'InfraServer',
        meta: {
          title: '服务监控',
          icon: 'lucide:server',
        },
      },
      {
        path: '/infra/druid',
        component: () => import('#/views/infra/druid/index.vue'),
        name: 'InfraDruid',
        meta: {
          title: '数据监控',
          icon: 'lucide:database-backup',
        },
      },
      {
        path: '/infra/skywalking',
        component: () => import('#/views/infra/skywalking/index.vue'),
        name: 'InfraSkywalking',
        meta: {
          title: '链路追踪',
          icon: 'lucide:route',
        },
      },
      {
        path: '/infra/swagger',
        component: () => import('#/views/infra/swagger/index.vue'),
        name: 'InfraSwagger',
        meta: {
          title: '接口文档',
          icon: 'lucide:book-marked',
        },
      },
      {
        path: '/infra/websocket',
        component: () => import('#/views/infra/webSocket/index.vue'),
        name: 'InfraWebSocket',
        meta: {
          title: 'WebSocket',
          icon: 'lucide:radio-tower',
        },
      },
    ],
  },
  {
    path: '/infra/job/log',
    component: () => import('#/views/infra/job/logger/index.vue'),
    name: 'InfraJobLog',
    meta: {
      title: '调度日志',
      icon: 'ant-design:history-outlined',
      activePath: '/infra/job',
      keepAlive: false,
      hideInMenu: true,
    },
  },
  {
    path: '/infra/codegen/edit',
    component: () => import('#/views/infra/codegen/edit/index.vue'),
    name: 'InfraCodegenEdit',
    meta: {
      title: '生成配置修改',
      icon: 'ic:baseline-view-in-ar',
      activePath: '/infra/codegen',
      keepAlive: true,
      hideInMenu: true,
    },
  },
];

export default routes;

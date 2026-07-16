import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/bpm',
    name: 'bpm',
    meta: {
      title: '工作流',
      icon: 'lucide:workflow',
      order: 50,
    },
    children: [
      {
        path: 'manager/model',
        component: () => import('#/views/bpm/model/index.vue'),
        name: 'BpmModel',
        meta: {
          title: '流程模型',
          icon: 'lucide:workflow',
        },
      },
      {
        path: 'manager/form',
        component: () => import('#/views/bpm/form/index.vue'),
        name: 'BpmForm',
        meta: {
          title: '流程表单',
          icon: 'lucide:panel-top',
        },
      },
      {
        path: 'manager/category',
        component: () => import('#/views/bpm/category/index.vue'),
        name: 'BpmCategory',
        meta: {
          title: '流程分类',
          icon: 'lucide:folder-tree',
        },
      },
      {
        path: 'manager/group',
        component: () => import('#/views/bpm/group/index.vue'),
        name: 'BpmGroup',
        meta: {
          title: '用户组',
          icon: 'lucide:users-round',
        },
      },
      {
        path: 'manager/listener',
        component: () => import('#/views/bpm/processListener/index.vue'),
        name: 'BpmProcessListener',
        meta: {
          title: '流程监听器',
          icon: 'lucide:radio',
        },
      },
      {
        path: 'manager/expression',
        component: () => import('#/views/bpm/processExpression/index.vue'),
        name: 'BpmProcessExpression',
        meta: {
          title: '流程表达式',
          icon: 'lucide:function-square',
        },
      },
      {
        path: 'process-instance/my',
        component: () => import('#/views/bpm/processInstance/index.vue'),
        name: 'BpmProcessInstance',
        meta: {
          title: '我的流程',
          icon: 'lucide:file-play',
        },
      },
      {
        path: 'process-instance/manager',
        component: () => import('#/views/bpm/processInstance/manager/index.vue'),
        name: 'BpmProcessInstanceManager',
        meta: {
          title: '流程实例',
          icon: 'lucide:files',
        },
      },
      {
        path: 'task/todo',
        component: () => import('#/views/bpm/task/todo/index.vue'),
        name: 'BpmTaskTodo',
        meta: {
          title: '待办任务',
          icon: 'lucide:list-todo',
        },
      },
      {
        path: 'task/done',
        component: () => import('#/views/bpm/task/done/index.vue'),
        name: 'BpmTaskDone',
        meta: {
          title: '已办任务',
          icon: 'lucide:list-checks',
        },
      },
      {
        path: 'task/copy',
        component: () => import('#/views/bpm/task/copy/index.vue'),
        name: 'BpmTaskCopy',
        meta: {
          title: '抄送任务',
          icon: 'lucide:copy-check',
        },
      },
      {
        path: 'task/manager',
        component: () => import('#/views/bpm/task/manager/index.vue'),
        name: 'BpmTaskManager',
        meta: {
          title: '任务管理',
          icon: 'lucide:list-tree',
        },
      },
      {
        path: 'process-instance/detail',
        component: () => import('#/views/bpm/processInstance/detail/index.vue'),
        name: 'BpmProcessInstanceDetail',
        meta: {
          title: '流程详情',
          activePath: '/bpm/task/my',
          icon: 'ant-design:history-outlined',
          keepAlive: false,
          hideInMenu: true,
        },
        props: (route) => {
          return {
            id: route.query.id,
            taskId: route.query.taskId,
            activityId: route.query.activityId,
          };
        },
      },
      {
        path: '/bpm/manager/form/edit',
        name: 'BpmFormEditor',
        component: () => import('#/views/bpm/form/designer/index.vue'),
        meta: {
          title: '设计流程表单',
          activePath: '/bpm/manager/form',
        },
        props: (route) => {
          return {
            id: route.query.id,
            type: route.query.type,
            copyId: route.query.copyId,
          };
        },
      },
      {
        path: 'manager/model/create',
        component: () => import('#/views/bpm/model/form/index.vue'),
        name: 'BpmModelCreate',
        meta: {
          title: '创建流程',
          activePath: '/bpm/manager/model',
          icon: 'carbon:flow-connection',
          hideInMenu: true,
          keepAlive: true,
        },
      },
      {
        path: 'manager/model/:type/:id',
        component: () => import('#/views/bpm/model/form/index.vue'),
        name: 'BpmModelUpdate',
        meta: {
          title: '修改流程',
          activePath: '/bpm/manager/model',
          icon: 'carbon:flow-connection',
          hideInMenu: true,
          keepAlive: true,
        },
      },
      {
        path: 'manager/definition',
        component: () => import('#/views/bpm/model/definition/index.vue'),
        name: 'BpmProcessDefinition',
        meta: {
          title: '流程定义',
          activePath: '/bpm/manager/model',
          icon: 'carbon:flow-modeler',
          hideInMenu: true,
          keepAlive: true,
        },
      },
      {
        path: 'process-instance/report',
        component: () => import('#/views/bpm/processInstance/report/index.vue'),
        name: 'BpmProcessInstanceReport',
        meta: {
          title: '数据报表',
          activePath: '/bpm/manager/model',
          icon: 'carbon:data-2',
          hideInMenu: true,
          keepAlive: true,
        },
      },
    ],
  },
];

export default routes;

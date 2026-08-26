import type { Component } from 'vue';

import { defineAsyncComponent } from 'vue';

export const projectDetailStages = [
  { key: 'novel', label: '原文', hint: '导入与事件提取', icon: '文' },
  {
    key: 'script-agent',
    label: '剧本创作',
    hint: '与编剧 Agent 协作',
    icon: '写',
  },
  { key: 'script', label: '剧本与资产', hint: '管理剧本和角色', icon: '库' },
  {
    key: 'production',
    label: '分镜制作',
    hint: '画布与视频工作台',
    icon: '制',
  },
  { key: 'archive', label: '剧集成果', hint: '成片与历史版本', icon: '片' },
] as const;

export const projectDetailPanelComponents: Record<string, Component> = {
  archive: defineAsyncComponent(() => import('./VideoArchivePanel.vue')),
  novel: defineAsyncComponent(() => import('./NovelPanel.vue')),
  production: defineAsyncComponent(() => import('./ProductionPanel.vue')),
  script: defineAsyncComponent(() => import('./ScriptLibraryPanel.vue')),
  'script-agent': defineAsyncComponent(() => import('./ScriptChatPanel.vue')),
};

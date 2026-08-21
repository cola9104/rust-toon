<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { Page } from '@vben/common-ui';
import { Button, Card, Drawer, Empty, Select, Space, Table, Tag } from 'ant-design-vue';
import { getTasks } from '#/api/toonflow';
import '../shared/page-card.css';
import '../styles/toon-theme.css';

const loading = ref(false);
const tasks = ref<ToonflowApi.Task[]>([]);
const category = ref('all');
const state = ref('all');
const detail = ref<ToonflowApi.Task>();
let pollTimer: number | undefined;

const typeLabel = (type: string) => ({ novelEvent: '章节事件提取', scriptAssetExtraction: '剧本资产提取', videoExport: '成片导出', '工作流图片生成': '工作流图片生成' }[type] ?? type);
const modelLabel = (model?: string) => ({ universalAi: '通用 AI' }[model ?? ''] ?? model ?? '—');
const stateLabel = (value: string) => ({ success: '成功', completed: '已完成', running: '处理中', failed: '失败', error: '失败' }[value?.toLowerCase()] ?? value ?? '未知');
const color = (value: string) => ({ success: 'green', completed: 'green', running: 'blue', failed: 'red', error: 'red' }[value?.toLowerCase()] ?? 'default');
const progress = (task: ToonflowApi.Task) => task.progressTotal && task.progressTotal > 0 ? Math.min(100, Math.round(((task.progressCurrent ?? 0) / task.progressTotal) * 100)) : undefined;
const categoryOptions = computed(() => [{ label: '全部类型', value: 'all' }, ...Array.from(new Set(tasks.value.map((item) => item.taskClass))).filter(Boolean).map((value) => ({ label: typeLabel(value), value }))]);
const visibleTasks = computed(() => tasks.value.filter((item) => (category.value === 'all' || item.taskClass === category.value) && (state.value === 'all' || item.state?.toLowerCase() === state.value)));
const taskStats = computed(() => ({ total: tasks.value.length, running: tasks.value.filter((item) => item.state?.toLowerCase() === 'running').length, success: tasks.value.filter((item) => ['success', 'completed'].includes(item.state?.toLowerCase())).length, failed: tasks.value.filter((item) => ['failed', 'error'].includes(item.state?.toLowerCase())).length }));
const columns = [
  { title: '任务', dataIndex: 'description', width: 260 }, { title: '项目', dataIndex: 'projectName', width: 180 },
  { title: '类型', dataIndex: 'taskClass', width: 150 }, { title: '进度', key: 'progress', width: 150 }, { title: '模型', dataIndex: 'model', width: 200 },
  { title: '关联对象', dataIndex: 'relatedObjects' }, { title: '开始时间', key: 'startTime', width: 180 },
  { title: '状态', dataIndex: 'state', width: 110 }, { title: '操作', key: 'action', width: 90 },
];

async function load(silent = false) {
  if (!silent) loading.value = true;
  try { tasks.value = await getTasks(); } finally { loading.value = false; }
}
function schedule() {
  window.clearInterval(pollTimer);
  if (!document.hidden) pollTimer = window.setInterval(() => void load(true), 5000);
}
function onVisibilityChange() { schedule(); if (!document.hidden) void load(true); }
function openDetail(record: Record<string, any>) { detail.value = record as ToonflowApi.Task; }

onMounted(() => { void load(); schedule(); document.addEventListener('visibilitychange', onVisibilityChange); });
onBeforeUnmount(() => { window.clearInterval(pollTimer); document.removeEventListener('visibilitychange', onVisibilityChange); });
</script>

<template>
  <Page auto-content-height class="toon-page">
    <Card :bordered="false" class="toonflow-page-card h-full toon-surface">
      <div class="toon-header"><div><h1 class="toon-title">任务中心</h1><p class="toon-subtitle">每 5 秒自动更新，切换到后台时暂停轮询。</p></div><Space><Select v-model:value="category" :options="categoryOptions" style="width: 170px" /><Select v-model:value="state" :options="[{label:'全部状态',value:'all'},{label:'处理中',value:'running'},{label:'已完成',value:'completed'},{label:'失败',value:'failed'}]" style="width: 130px" /><Button @click="load()">刷新</Button></Space></div>
      <div class="task-stats"><div class="stat-card total"><span class="stat-label">全部任务</span><strong>{{ taskStats.total }}</strong><small>累计记录</small></div><div class="stat-card running"><span class="stat-label">处理中</span><strong>{{ taskStats.running }}</strong><small>正在执行</small></div><div class="stat-card success"><span class="stat-label">已完成</span><strong>{{ taskStats.success }}</strong><small>执行成功</small></div><div class="stat-card failed"><span class="stat-label">失败</span><strong>{{ taskStats.failed }}</strong><small>需要处理</small></div></div>
      <Empty v-if="!loading && visibleTasks.length === 0" description="暂无匹配任务" />
      <Table v-else :columns="columns" :data-source="visibleTasks" :loading="loading" :pagination="{ pageSize: 20, showSizeChanger: true, pageSizeOptions: ['20','50','100'], showTotal: (total: number) => `共 ${total} 个任务` }" row-key="id">
        <template #bodyCell="{column,record}"><Tag v-if="column.dataIndex === 'taskClass'">{{ typeLabel(record.taskClass) }}</Tag><template v-else-if="column.dataIndex === 'model'">{{ modelLabel(record.model) }}</template><template v-else-if="column.key === 'progress'"><span v-if="progress(record as ToonflowApi.Task) !== undefined">{{ progress(record as ToonflowApi.Task) }}% <small class="progress-count">({{ record.progressCurrent ?? 0 }}/{{ record.progressTotal }})</small></span><span v-else>—</span></template><Tag v-else-if="column.dataIndex === 'state'" :color="color(record.state)">{{ stateLabel(record.state) }}</Tag><template v-else-if="column.key === 'startTime'">{{ record.startTime ? new Date(record.startTime).toLocaleString() : '—' }}</template><Button v-else-if="column.key === 'action'" type="link" @click="openDetail(record)">详情</Button></template>
      </Table>
    </Card>
    <Drawer :open="!!detail" title="任务详情" width="480" @close="detail = undefined">
      <template v-if="detail"><div class="task-detail"><label>任务</label><p>{{ detail.description || '—' }}</p><label>项目</label><p>{{ detail.projectName || '—' }}</p><label>类型 / 模型</label><p>{{ typeLabel(detail.taskClass) }} · {{ modelLabel(detail.model) }}</p><label>关联对象</label><p>{{ detail.relatedObjects || '—' }}</p><label>状态 / 进度</label><p><Tag :color="color(detail.state)">{{ stateLabel(detail.state) }}</Tag><span v-if="progress(detail) !== undefined" class="detail-progress">{{ progress(detail) }}%（{{ detail.progressCurrent ?? 0 }}/{{ detail.progressTotal }}）</span></p><label v-if="detail.retryOfId">重试来源</label><p v-if="detail.retryOfId">任务 #{{ detail.retryOfId }}</p><label>失败原因</label><pre :class="{ error: detail.reason }">{{ detail.reason || '无' }}</pre><label>原始输入</label><pre>{{ detail.input && Object.keys(detail.input).length ? JSON.stringify(detail.input, null, 2) : '暂无记录（旧任务）' }}</pre></div></template>
    </Drawer>
  </Page>
</template>

<style scoped>.task-stats{display:grid;margin-bottom:20px;gap:14px;grid-template-columns:repeat(4,minmax(0,1fr))}.stat-card{position:relative;display:flex;min-height:104px;flex-direction:column;justify-content:center;overflow:hidden;padding:16px 18px;border:1px solid var(--ant-color-border-secondary);border-radius:14px;background:var(--ant-color-bg-container);box-shadow:0 3px 12px rgb(15 23 42 / 4%)}.stat-card::before{position:absolute;inset:0 auto 0 0;width:4px;content:"";background:var(--stat-color,#bfbfbf)}.stat-card.total{--stat-color:#8c8c8c}.stat-card.running{--stat-color:#1677ff}.stat-card.success{--stat-color:#52c41a}.stat-card.failed{--stat-color:#ff4d4f}.stat-label{color:var(--ant-color-text-secondary);font-size:13px}.stat-card strong{margin-top:5px;color:var(--ant-color-text);font-size:28px;font-weight:650;line-height:1.1}.stat-card small{margin-top:5px;color:var(--ant-color-text-tertiary);font-size:11px}@media (max-width:720px){.task-stats{grid-template-columns:repeat(2,minmax(0,1fr))}}@media (max-width:420px){.task-stats{grid-template-columns:1fr}}.task-detail { display: grid; gap: 5px; }.task-detail label { margin-top: 12px; color: #8c8c8c; font-size: 12px; }.task-detail p { margin: 0; }.task-detail pre { padding: 12px; border-radius: 10px; white-space: pre-wrap; background: #f5f5f5; }.task-detail pre.error { color: #a8071a; background: #fff1f0; }</style>

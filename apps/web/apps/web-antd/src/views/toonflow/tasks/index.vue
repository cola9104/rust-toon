<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onActivated, onBeforeUnmount, onDeactivated, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { Page } from '@vben/common-ui';
import { Alert, Button, Card, Drawer, Progress, Select, Space, Table, Tag, message } from 'ant-design-vue';
import { getTaskDetails } from '#/api/toonflow';
import { useTaskCenter } from './useTaskCenter';
import { assetFileUrl } from '../assets/asset-types';
import '../shared/page-card.css';
import '../styles/toon-theme.css';

const route = useRoute();
const routeProjectId = Number(route.query.projectId);
const center = useTaskCenter({
  state: typeof route.query.state === 'string' ? route.query.state : undefined,
  projectId: Number.isSafeInteger(routeProjectId) && routeProjectId > 0 ? routeProjectId : undefined,
});
const { loading, tasks, loadError, category, state, detail, detailError, projectId,
  page, pageSize, total, taskStats, load, closeDetail } = center;
watch(() => route.fullPath, async (_, __, onCleanup) => {
  let cancelled = false;
  onCleanup(() => { cancelled = true; });
  if (route.path !== '/toonflow/tasks') return;
  const nextState = typeof route.query.state === 'string' ? route.query.state : 'all';
  state.value = ['all', 'running', 'completed', 'failed'].includes(nextState) ? nextState : 'all';
  const nextProject = Number(route.query.projectId);
  projectId.value = Number.isSafeInteger(nextProject) && nextProject > 0 ? nextProject : undefined;
  category.value = 'all';
  closeDetail();
  const id = route.query.taskId;
  if (typeof id !== 'string' || !/^\d+$/.test(id)) return;
  try {
    const result = await getTaskDetails(id);
    if (cancelled) return;
    if (result) center.openDetail(result);
    else message.info('该任务已不存在');
  } catch (error) {
    if (!cancelled) message.error(error instanceof Error ? error.message : '任务详情加载失败');
  }
}, { immediate: true });
const projectOptions = computed(() => center.projects.value.map((project) => ({ label: project.name, value: project.id })));
const tablePagination = computed(() => ({ current: page.value, pageSize: pageSize.value, total: total.value,
  showSizeChanger: true, pageSizeOptions: ['20', '50', '100'], showTotal: (count: number) => `共 ${count} 个任务` }));

const taskKind = (type: string) => ({
  video: 'video',
  videoExport: 'video',
  image: 'image',
  '工作流图片生成': 'image',
}[type] ?? 'default');
const typeLabel = (type: string) => ({
  novelEvent: '章节事件提取',
  scriptAssetExtraction: '剧本资产提取',
  video: '视频生成',
  videoExport: '视频合成',
  image: '图片生成',
  '工作流图片生成': '图片生成',
}[type] ?? type);
const modelLabel = (model?: string) => ({ universalAi: '通用 AI' }[model ?? ''] ?? model ?? '—');
const stateLabel = (value: string) => ({ success: '成功', completed: '已完成', running: '处理中', failed: '失败', error: '失败' }[value?.toLowerCase()] ?? value ?? '未知');
const color = (value: string) => ({ success: 'green', completed: 'green', running: 'blue', failed: 'red', error: 'red' }[value?.toLowerCase()] ?? 'default');
const progress = (task: ToonflowApi.Task) => task.progressTotal && task.progressTotal > 0 ? Math.min(100, Math.round(((task.progressCurrent ?? 0) / task.progressTotal) * 100)) : undefined;
const categoryOptions = computed(() => [{ label: '全部类型', value: 'all' }, ...center.categories.value.map(({ taskClass }) => ({ label: typeLabel(taskClass), value: taskClass }))]);
const stateOptions = [{ label: '全部状态', value: 'all' }, { label: '处理中', value: 'running' }, { label: '已完成', value: 'completed' }, { label: '失败', value: 'failed' }];
const columns = [
  { title: '任务', dataIndex: 'description', width: 260 }, { title: '项目', dataIndex: 'projectName', width: 180 },
  { title: '类型', dataIndex: 'taskClass', width: 150 }, { title: '进度', key: 'progress', width: 150 }, { title: '模型', dataIndex: 'model', width: 200 },
  { title: '关联对象', dataIndex: 'relatedObjects' }, { title: '开始时间', key: 'startTime', width: 180 },
  { title: '状态', dataIndex: 'state', width: 110 }, { title: '操作', key: 'action', width: 90 },
];

let pageActive = true;
function onVisibilityChange() {
  if (pageActive && !document.hidden) center.start();
  else center.stop();
}
function openDetail(record: Record<string, any>) { center.openDetail(record as ToonflowApi.Task); }
function filterByState(next: string) { state.value = state.value === next ? 'all' : next; }
function taskResultUrl(task?: ToonflowApi.Task) {
  if (!task || !['success', 'completed'].includes(task.state?.toLowerCase() ?? '')) return '';
  const candidates = [task.relatedObjects, task.input ? JSON.stringify(task.input) : ''];
  for (const candidate of candidates) {
    try {
      const payload = JSON.parse(candidate || '{}') as { filePath?: unknown; imageUrl?: unknown; path?: unknown; url?: unknown };
      const raw = payload.url ?? payload.imageUrl ?? payload.filePath ?? payload.path;
      if (typeof raw === 'string' && raw.trim()) return assetFileUrl(raw);
    } catch {
      // Older task rows contain plain text in relatedObjects.
    }
  }
  return '';
}
function downloadVideo(task: ToonflowApi.Task) {
  const url = taskResultUrl(task);
  if (!url) return;
  const link = document.createElement('a');
  link.href = url;
  link.download = `toonflow-export-${task.id}.mp4`;
  link.click();
}

onMounted(() => { onVisibilityChange(); document.addEventListener('visibilitychange', onVisibilityChange); });
onActivated(() => { pageActive = true; onVisibilityChange(); });
onDeactivated(() => { pageActive = false; center.stop(); });
onBeforeUnmount(() => { center.stop(); document.removeEventListener('visibilitychange', onVisibilityChange); });
</script>

<template>
  <Page auto-content-height class="toon-page">
    <Card :bordered="false" class="toonflow-page-card h-full toon-surface">
      <div class="toon-header">
        <div>
          <div class="page-kicker"><span class="live-dot" />实时任务</div>
          <h1 class="toon-title">任务中心</h1>
          <p class="toon-subtitle">自动追踪图片、分镜和导出任务，页面每 5 秒同步一次。</p>
        </div>
        <Space class="task-toolbar" wrap>
          <Select v-model:value="projectId" :options="projectOptions" allow-clear show-search option-filter-prop="label" placeholder="全部项目" class="task-filter task-filter--type" />
          <Select v-model:value="category" :options="categoryOptions" class="task-filter task-filter--type" />
          <Select v-model:value="state" :options="stateOptions" class="task-filter" />
          <Button :loading="loading" @click="load()">刷新任务</Button>
        </Space>
      </div>
      <div class="task-stats">
        <button class="stat-card total" :class="{ active: state === 'all' }" type="button" @click="state = 'all'"><span class="stat-label">全部任务</span><strong>{{ taskStats.total }}</strong><small>当前项目与类型范围</small></button>
        <button class="stat-card running" :class="{ active: state === 'running' }" type="button" @click="filterByState('running')"><span class="stat-label">处理中</span><strong>{{ taskStats.running }}</strong><small>正在执行</small></button>
        <button class="stat-card success" :class="{ active: state === 'completed' }" type="button" @click="filterByState('completed')"><span class="stat-label">已完成</span><strong>{{ taskStats.success }}</strong><small>执行成功</small></button>
        <button class="stat-card failed" :class="{ active: state === 'failed' }" type="button" @click="filterByState('failed')"><span class="stat-label">失败</span><strong>{{ taskStats.failed }}</strong><small>需要处理</small></button>
      </div>
      <Alert v-if="loadError" class="task-load-error" type="error" show-icon :message="loadError" />
      <Table class="task-table" :columns="columns" :data-source="tasks" :loading="loading" :pagination="tablePagination" :scroll="{ x: 1280 }" row-key="id" size="middle" @change="(pagination) => center.changePage(pagination.current ?? 1, pagination.pageSize ?? 20)">
        <template #bodyCell="{column,record}">
          <div v-if="column.dataIndex === 'description'" class="task-name"><span class="task-name__icon" :class="`task-name__icon--${taskKind(record.taskClass)}`">{{ taskKind(record.taskClass) === 'video' ? '▶' : taskKind(record.taskClass) === 'image' ? '▧' : '✦' }}</span><div><strong>{{ record.description || '未命名任务' }}</strong><small>#{{ record.id }}</small></div></div>
          <div v-else-if="column.dataIndex === 'projectName'" class="project-name"><span class="project-mark">P</span><span>{{ record.projectName || '未关联项目' }}</span></div>
          <Tag v-else-if="column.dataIndex === 'taskClass'" class="type-tag" :class="`type-tag--${taskKind(record.taskClass)}`">{{ typeLabel(record.taskClass) }}</Tag>
          <template v-else-if="column.dataIndex === 'model'"><span class="model-name">{{ modelLabel(record.model) }}</span></template>
          <div v-else-if="column.key === 'progress'" class="progress-cell"><template v-if="progress(record as ToonflowApi.Task) !== undefined"><Progress :percent="progress(record as ToonflowApi.Task)" :status="record.state?.toLowerCase() === 'failed' ? 'exception' : undefined" :show-info="false" size="small" /><small>{{ record.progressCurrent ?? 0 }}/{{ record.progressTotal }}</small></template><span v-else class="muted">未提供</span></div>
          <span v-else-if="column.dataIndex === 'relatedObjects'" class="related-object">{{ record.relatedObjects || '—' }}</span>
          <template v-else-if="column.key === 'startTime'"><span class="time-text">{{ record.startTime ? new Date(record.startTime).toLocaleString() : '—' }}</span></template>
          <Tag v-else-if="column.dataIndex === 'state'" :color="color(record.state)" class="state-tag"><span class="state-dot" />{{ stateLabel(record.state) }}</Tag>
          <Button v-else-if="column.key === 'action'" type="link" @click="openDetail(record)">{{ taskResultUrl(record as ToonflowApi.Task) ? (taskKind(record.taskClass) === 'image' ? '查看图片' : '查看视频') : '查看详情' }}</Button>
        </template>
      </Table>
    </Card>
    <Drawer root-class-name="toon-overlay" :open="!!detail" title="任务详情" width="480" @close="closeDetail">
      <Alert v-if="detailError" type="warning" show-icon :message="detailError" />
      <template v-if="detail"><div class="task-detail"><label>任务</label><p>{{ detail.description || '—' }}</p><label>项目</label><p>{{ detail.projectName || '—' }}</p><label>类型 / 模型</label><p>{{ typeLabel(detail.taskClass) }} · {{ modelLabel(detail.model) }}</p><label>关联对象</label><p>{{ detail.relatedObjects || '—' }}</p><section v-if="taskResultUrl(detail) && taskKind(detail.taskClass) === 'video'" class="export-result"><div class="export-result-heading"><b>视频结果</b><Button size="small" type="primary" @click="downloadVideo(detail)">下载 MP4</Button></div><video :key="detail.id" :src="taskResultUrl(detail)" controls playsinline preload="metadata" /></section><section v-else-if="taskResultUrl(detail) && taskKind(detail.taskClass) === 'image'" class="image-result"><b>图片结果</b><img :src="taskResultUrl(detail)" alt="生成结果" /></section><label>状态 / 进度</label><p><Tag :color="color(detail.state)">{{ stateLabel(detail.state) }}</Tag><span v-if="progress(detail) !== undefined" class="detail-progress">{{ progress(detail) }}%（{{ detail.progressCurrent ?? 0 }}/{{ detail.progressTotal }}）</span></p><label v-if="detail.retryOfId">重试来源</label><p v-if="detail.retryOfId">任务 #{{ detail.retryOfId }}</p><label>失败原因</label><pre :class="{ error: detail.reason }">{{ detail.reason || '无' }}</pre><label>原始输入</label><pre>{{ detail.input && Object.keys(detail.input).length ? JSON.stringify(detail.input, null, 2) : '暂无记录（旧任务）' }}</pre></div></template>
    </Drawer>
  </Page>
</template>

<style scoped>
.toon-header > div:first-child { min-width: 0; flex: 1 1 280px; }
.page-kicker { display: inline-flex; align-items: center; gap: 7px; margin-bottom: 7px; padding: 4px 9px; border: 1px solid var(--ant-color-success-border); border-radius: 999px; color: var(--ant-color-success-text); background: var(--ant-color-success-bg); font-size: 11px; font-weight: 700; letter-spacing: .04em; white-space: nowrap; }
.live-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--ant-color-success); box-shadow: 0 0 0 4px var(--ant-color-success-bg); }
.toonflow-page-card { width: 100%; min-width: 0; overflow: hidden; }
.toonflow-page-card :deep(.ant-card-body) { box-sizing: border-box; min-width: 0; max-width: 100%; min-height: 0; padding: 20px; overflow-x: hidden; overflow-y: auto; scrollbar-gutter: stable; }
.toon-header { min-width: 0; flex-wrap: wrap; }
.task-toolbar { min-width: 0; flex: 0 1 auto; justify-content: flex-end; flex-wrap: wrap; }
.task-filter { width: 130px; }
.task-filter--type { width: 180px; }
.task-stats { display: grid; width: 100%; min-width: 0; margin-bottom: 20px; gap: 14px; grid-template-columns: repeat(4, minmax(0, 1fr)); }
.stat-card { position: relative; display: flex; min-width: 0; min-height: 104px; box-sizing: border-box; flex-direction: column; justify-content: center; overflow: hidden; padding: 16px 18px; border: 1px solid var(--ant-color-border-secondary); border-radius: 14px; color: inherit; background: var(--ant-color-bg-container); box-shadow: 0 3px 12px rgb(15 23 42 / 4%); cursor: pointer; text-align: left; transition: border-color .2s, box-shadow .2s, transform .2s; }
.stat-card:hover, .stat-card.active { border-color: var(--stat-color); box-shadow: 0 8px 20px rgb(15 23 42 / 9%); transform: translateY(-2px); }
.stat-card::before { position: absolute; inset: 0 auto 0 0; width: 4px; content: ''; background: var(--stat-color, var(--toon-line)); }
.stat-card.total { --stat-color: var(--ant-color-text-tertiary); }.stat-card.running { --stat-color: var(--ant-color-primary); }.stat-card.success { --stat-color: var(--ant-color-success); }.stat-card.failed { --stat-color: var(--ant-color-error); }
.stat-label { color: var(--ant-color-text-secondary); font-size: 13px; }.stat-card strong { margin-top: 5px; color: var(--ant-color-text); font-size: 28px; font-weight: 650; line-height: 1.1; }.stat-card small { margin-top: 5px; color: var(--ant-color-text-tertiary); font-size: 11px; }
.task-table { width: 100%; max-width: 100%; overflow: hidden; border: 1px solid var(--toon-line); border-radius: 14px; }.task-table :deep(.ant-table-container) { max-width: 100%; overflow-x: auto; }.task-table :deep(.ant-table-thead > tr > th) { color: var(--ant-color-text-secondary); background: var(--toon-canvas); font-size: 12px; font-weight: 650; }.task-table :deep(.ant-table-tbody > tr > td) { padding-top: 14px; padding-bottom: 14px; }
.task-name, .project-name { display: flex; align-items: center; gap: 9px; min-width: 0; }.task-name__icon, .project-mark { display: grid; flex: 0 0 auto; width: 28px; height: 28px; place-items: center; border-radius: 8px; color: var(--ant-color-primary); background: var(--ant-color-primary-bg); font-size: 13px; }.task-name__icon--video { color: var(--ant-color-primary); background: var(--ant-color-primary-bg); }.task-name__icon--image { color: var(--ant-color-warning-text); background: var(--ant-color-warning-bg); }.task-name strong { display: block; overflow: hidden; max-width: 210px; text-overflow: ellipsis; white-space: nowrap; }.task-name small { display: block; margin-top: 3px; color: var(--ant-color-text-tertiary); font-size: 10px; }.project-mark { width: 24px; height: 24px; color: var(--ant-color-primary); background: var(--ant-color-primary-bg); font-size: 11px; font-weight: 700; }.project-name span:last-child, .related-object { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }.model-name, .time-text, .muted { color: var(--ant-color-text-secondary); font-size: 12px; }.related-object { display: block; max-width: 180px; color: var(--ant-color-text-secondary); font-size: 12px; }.type-tag, .state-tag { margin-inline-end: 0; }.type-tag--video { color: var(--ant-color-primary-text); border-color: var(--ant-color-primary-border); background: var(--ant-color-primary-bg); }.type-tag--image { color: var(--ant-color-warning-text); border-color: var(--ant-color-warning-border); background: var(--ant-color-warning-bg); }.state-dot { display: inline-block; width: 5px; height: 5px; margin-right: 5px; border-radius: 50%; background: currentcolor; vertical-align: middle; }.progress-cell { display: grid; width: 120px; align-items: center; grid-template-columns: 1fr auto; gap: 8px; }.progress-cell :deep(.ant-progress) { margin: 0; }.progress-cell small { color: var(--ant-color-text-secondary); font-size: 11px; white-space: nowrap; }
.task-detail { display: grid; min-width: 0; max-width: 100%; gap: 5px; overflow-x: hidden; }.task-detail label { margin-top: 12px; color: var(--ant-color-text-tertiary); font-size: 12px; }.task-detail p { margin: 0; overflow-wrap: anywhere; word-break: break-word; }.task-detail pre { max-width: 100%; box-sizing: border-box; padding: 12px; overflow-x: auto; border-radius: 10px; white-space: pre-wrap; background: var(--toon-canvas); }.task-detail pre.error { color: var(--ant-color-error-text); background: var(--ant-color-error-bg); }.export-result { display: grid; min-width: 0; max-width: 100%; gap: 10px; margin-top: 12px; padding: 12px; overflow: hidden; box-sizing: border-box; border: 1px solid var(--ant-color-border-secondary); border-radius: 10px; background: var(--ant-color-fill-quaternary); }.export-result-heading { display: flex; min-width: 0; align-items: center; justify-content: space-between; gap: 8px; flex-wrap: wrap; }.export-result video { display: block; width: min(420px, 100%); max-width: 100%; height: min(250px, 42vh); min-width: 0; margin: 0; justify-self: start; box-sizing: border-box; border-radius: 7px; background: #000; object-fit: contain; }
.image-result { display: grid; min-width: 0; max-width: 100%; gap: 10px; margin-top: 12px; padding: 12px; overflow: hidden; box-sizing: border-box; border: 1px solid var(--ant-color-border-secondary); border-radius: 10px; background: var(--ant-color-fill-quaternary); }.image-result img { display: block; width: min(420px, 100%); max-width: 100%; max-height: 360px; object-fit: contain; border-radius: 8px; background: var(--toon-canvas); }
.task-load-error { margin-bottom: 16px; }
@media (max-width: 720px) { .toonflow-page-card :deep(.ant-card-body) { padding: 14px; } .task-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } .task-toolbar { justify-content: flex-start; width: 100%; } .task-filter, .task-filter--type { width: min(100%, 220px); } }
@media (max-width: 420px) { .task-stats { grid-template-columns: 1fr; } }
</style>

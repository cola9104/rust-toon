<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { Page } from '@vben/common-ui';
import { Alert, Button, Empty, Progress, Select, Skeleton, Tag } from 'ant-design-vue';
import { formatDashboardTime, useToonflowDashboard } from '../toonflow-dashboard';

defineOptions({ name: 'Analytics' });
const router = useRouter();
const { load, loading, loadError, projects, visibleProjects, tasks, taskStats, totals, taskTypes, failures, selectedProjectId, updatedAt } = useToonflowDashboard();
const projectOptions = computed(() => projects.value.map((project) => ({ value: project.id, label: project.name })));
const resolvedCount = computed(() => taskStats.value ? taskStats.value.success + taskStats.value.failed : 0);
const successRate = computed(() => resolvedCount.value ? Math.round(taskStats.value!.success / resolvedCount.value * 100) : undefined);
const states = computed(() => [
  { label: '已完成', value: taskStats.value?.success ?? 0, color: 'var(--ant-color-success)', filter: 'completed' },
  { label: '失败', value: taskStats.value?.failed ?? 0, color: 'var(--ant-color-error)', filter: 'failed' },
  { label: '处理中', value: taskStats.value?.running ?? 0, color: 'var(--ant-color-info)', filter: 'running' },
  { label: '其他', value: Math.max(0, (taskStats.value?.total ?? 0) - resolvedCount.value - (taskStats.value?.running ?? 0)), color: 'var(--ant-color-text-quaternary)', filter: 'all' },
]);
function openTasks(state = 'all', taskId?: string | number) {
  void router.push({ name: 'ToonflowTasks', query: { state, projectId: selectedProjectId.value ? String(selectedProjectId.value) : undefined, taskId: taskId === undefined ? undefined : String(taskId) } });
}
</script>

<template>
  <Page class="toon-page studio-dashboard">
    <div class="studio-shell">
      <header class="studio-header"><div><span class="studio-eyebrow">TOONFLOW / ANALYTICS</span><h1>制作分析</h1><p>看清产量与生成结果，找到影响创作的问题。</p></div><div class="studio-actions"><Select v-model:value="selectedProjectId" allow-clear show-search option-filter-prop="label" :options="projectOptions" placeholder="全部项目" aria-label="统计项目" class="project-filter" :disabled="loading" @change="load" /><Button :loading="loading" @click="load">刷新数据</Button></div></header>
      <Alert v-if="loadError" :message="loadError" type="warning" show-icon />
      <div class="scope-line"><span><i />{{ selectedProjectId ? '所选项目' : '全部项目' }} · 累计内容与任务记录</span><span>{{ updatedAt ? `更新于 ${formatDashboardTime(updatedAt)}` : '正在加载' }}</span></div>
      <Skeleton v-if="loading && !updatedAt" active :paragraph="{ rows: 8 }" />
      <template v-else>
        <section class="production-metrics" aria-label="内容产量"><article><span>原文章节</span><strong>{{ totals.chapters ?? '—' }}<small>章</small></strong><p>已导入项目的故事原文</p></article><article><span>已保存剧本</span><strong>{{ totals.scripts ?? '—' }}<small>集</small></strong><p>已经写入的剧本记录</p></article><article><span>分镜记录</span><strong>{{ totals.storyboards ?? '—' }}<small>个</small></strong><p>包含待生成和已生成的分镜</p></article><article class="highlight-metric"><span>已导出成片</span><strong>{{ totals.renders ?? '—' }}<small>集</small></strong><p>同一剧集的多个版本只计一集</p></article></section>

        <div class="analytics-layout">
          <section class="studio-panel task-results"><div class="studio-section-head"><div><h2>生成任务结果</h2><p>累计 {{ taskStats?.total ?? '—' }} 次任务尝试，包含重试</p></div><Button type="link" @click="openTasks()">查看任务 →</Button></div>
            <div class="success-heading"><strong>{{ successRate === undefined ? '—' : `${successRate}%` }}</strong><div><b>已结束任务成功率</b><p>成功 ÷（成功＋失败），不计运行中与其他状态</p></div></div>
            <div class="result-strip" aria-label="累计任务状态分布"><span v-for="item in states.filter((row) => row.value)" :key="item.label" :style="{ flex: item.value, background: item.color }" :title="`${item.label} ${item.value} 次`" /></div>
            <div class="result-legend"><button v-for="item in states" :key="item.label" type="button" @click="openTasks(item.filter)"><i :style="{ background: item.color }" /><span>{{ item.label }}</span><b>{{ taskStats ? item.value : '—' }}</b></button></div>
            <p class="studio-note">历史失败可能已通过重试解决；这里反映任务执行记录，不作为当前待办数量。</p>
          </section>
          <section class="studio-panel"><div class="studio-section-head"><div><h2>近期任务构成</h2><p>最近 {{ tasks.length }} 条记录，最多取 100 条</p></div><Tag>样本</Tag></div><Empty v-if="!tasks.length" :description="taskStats ? '暂无生成任务' : '任务数据暂不可用'" /><div v-else class="task-type-list"><div v-for="item in taskTypes" :key="item.type"><div><b>{{ item.label }}</b><span>{{ item.count }} 次 <small>· {{ Math.round(item.count / tasks.length * 100) }}%</small></span></div><Progress :percent="Math.round(item.count / tasks.length * 100)" :show-info="false" :stroke-width="7" /></div></div></section>
        </div>

        <section class="studio-panel"><div class="studio-section-head"><div><h2>近期失败原因</h2><p>合并最近 {{ tasks.length }} 条任务中的相同原因，点击查看具体记录</p></div><Button type="link" @click="openTasks('failed')">全部失败记录 →</Button></div><Empty v-if="!failures.length" :description="taskStats ? '当前样本中没有失败记录' : '任务数据暂不可用'" /><div v-else class="failure-groups"><button v-for="group in failures.slice(0, 5)" :key="group.message" type="button" @click="openTasks('failed', group.task.id)"><span class="failure-count"><b>{{ group.count }}</b><small>次</small></span><span class="failure-copy"><b>{{ group.message }}</b><small>最近一次：{{ group.task.projectName || '未关联项目' }} · {{ formatDashboardTime(group.task.startTime) }}</small></span><span class="failure-link">查看详情 →</span></button></div></section>

        <section class="studio-panel"><div class="studio-section-head"><div><h2>项目内容明细</h2><p>按已保存内容展示，不估算完成百分比</p></div><span class="subtle">{{ visibleProjects.length }} 个项目</span></div><Empty v-if="!visibleProjects.length" description="暂无项目数据" /><div v-else class="project-table-scroll"><table class="project-table"><thead><tr><th>项目</th><th>原文 / 章</th><th>剧本 / 集</th><th>分镜 / 个</th><th>视频记录 / 条</th><th>成片 / 集</th><th>操作</th></tr></thead><tbody><tr v-for="project in visibleProjects" :key="project.id"><td><b>{{ project.name }}</b><small>{{ project.stageLabel }}</small></td><td>{{ project.chapters ?? '—' }}</td><td>{{ project.statistics?.scriptCount ?? '—' }}</td><td>{{ project.statistics?.storyboardCount ?? '—' }}</td><td>{{ project.statistics?.videoCount ?? '—' }}</td><td>{{ project.renders ?? '—' }}</td><td><Button type="link" @click="router.push({ name: 'ToonflowProjectDetail', params: { id: String(project.id) } })">打开项目 →</Button></td></tr></tbody></table></div><p class="studio-note">视频记录包含各次生成尝试；成片仅统计具有成功导出版本的剧集。</p></section>
      </template>
    </div>
  </Page>
</template>

<style scoped src="../dashboard.css" />

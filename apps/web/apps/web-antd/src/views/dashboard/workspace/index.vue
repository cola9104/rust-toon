<script setup lang="ts">
import type { DashboardProject } from '../toonflow-dashboard';
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { Page } from '@vben/common-ui';
import { IconifyIcon } from '@vben/icons';
import { Alert, Button, Empty, Skeleton, Tag } from 'ant-design-vue';
import { formatDashboardTime, taskState, taskTypeLabel, useToonflowDashboard } from '../toonflow-dashboard';

defineOptions({ name: 'Workspace' });
const router = useRouter();
const { load, loading, loadError, projects, tasks, taskStats, totals, failures, updatedAt } = useToonflowDashboard();
const recentProjects = computed(() => projects.value.slice(0, 4));
const featured = computed(() => recentProjects.value[0]);
const missing = computed(() => projects.value.filter((project) => project.missingModels.length));
const shortcuts = [
  { icon: 'lucide:folders', label: '全部项目', path: '/toonflow/projects' },
  { icon: 'lucide:images', label: '资产中心', path: '/toonflow/assets' },
  { icon: 'lucide:bot', label: '模型与 Agent', path: '/toonflow/settings' },
  { icon: 'lucide:notebook-tabs', label: '创作手册', path: '/toonflow/manuals' },
];
function continueProject(project: DashboardProject) {
  // Omit stage so the existing per-user project location restores the last visit.
  void router.push({ name: 'ToonflowProjectDetail', params: { id: String(project.id) } });
}
function nextStep(project: DashboardProject) {
  void router.push({ name: 'ToonflowProjectDetail', params: { id: String(project.id) }, query: project.nextStage ? { stage: project.nextStage } : undefined });
}
</script>

<template>
  <Page class="toon-page studio-dashboard">
    <div class="studio-shell">
      <header class="studio-header">
        <div><span class="studio-eyebrow">TOONFLOW / WORKSPACE</span><h1>创作工作台</h1><p>继续手上的故事，让下一步更清楚。</p></div>
        <div class="studio-actions"><span class="studio-sync">{{ updatedAt ? `更新于 ${formatDashboardTime(updatedAt)}` : '读取创作数据' }}</span><Button :loading="loading" @click="load">刷新</Button><Button type="primary" @click="router.push({ name: 'ToonflowProjects', query: { create: '1' } })">＋ 新建项目</Button></div>
      </header>
      <Alert v-if="loadError" :message="loadError" show-icon type="warning" />
      <Skeleton v-if="loading && !updatedAt" active :paragraph="{ rows: 8 }" />
      <template v-else>
        <div class="workspace-layout">
          <main class="studio-column">
            <section v-if="featured" class="studio-panel feature-project">
              <div class="feature-top"><span class="studio-eyebrow">最近更新的项目</span><Tag color="processing">{{ featured.stageLabel }}</Tag></div>
              <h2>{{ featured.name }}</h2>
              <p class="feature-intro">{{ featured.intro || '从原文、剧本到分镜，让故事逐步成为画面。' }}</p>
              <div class="project-milestones" aria-label="项目现有内容">
                <span :class="{ present: featured.chapters }"><i />原文<b>{{ featured.chapters ?? '—' }}</b></span>
                <span :class="{ present: featured.statistics?.scriptCount }"><i />剧本<b>{{ featured.statistics?.scriptCount ?? '—' }}</b></span>
                <span :class="{ present: featured.statistics?.storyboardCount }"><i />分镜<b>{{ featured.statistics?.storyboardCount ?? '—' }}</b></span>
                <span :class="{ present: featured.renders }"><i />成片剧集<b>{{ featured.renders ?? '—' }}</b></span>
              </div>
              <div class="next-step"><IconifyIcon icon="lucide:arrow-right" /><div><b>建议下一步 · {{ featured.nextAction }}</b><p>{{ featured.nextHint }}</p></div></div>
              <div class="feature-footer"><Button type="primary" size="large" @click="continueProject(featured)">继续创作 <span aria-hidden="true">→</span></Button><Button type="text" @click="nextStep(featured)">{{ featured.nextAction }}</Button><span>自动恢复上次创作位置</span></div>
            </section>
            <section v-else class="studio-panel"><Empty description="第一部作品，从一个故事开始"><Button type="primary" @click="router.push({ name: 'ToonflowProjects', query: { create: '1' } })">创建项目</Button></Empty></section>

            <section class="studio-panel">
              <div class="studio-section-head"><div><h2>最近生成活动</h2><p>最近 6 条记录，点击查看任务详情</p></div><Button type="link" @click="router.push({ name: 'ToonflowTasks' })">全部任务 →</Button></div>
              <Empty v-if="!tasks.length" :description="taskStats ? '还没有生成任务' : '任务数据暂不可用'" />
              <div v-else class="activity-list"><button v-for="task in tasks.slice(0, 6)" :key="task.id" type="button" @click="router.push({ name: 'ToonflowTasks', query: { taskId: String(task.id) } })"><span class="studio-icon"><IconifyIcon :icon="task.taskClass === 'novelEvent' ? 'lucide:book-open' : task.taskClass.toLowerCase().includes('video') ? 'lucide:film' : 'lucide:image'" /></span><span class="activity-copy"><b>{{ task.description || taskTypeLabel(task.taskClass) }}</b><small>{{ task.projectName || '未关联项目' }} · {{ taskTypeLabel(task.taskClass) }}</small></span><span class="activity-meta"><Tag :color="taskState(task.state).color">{{ taskState(task.state).label }}</Tag><time>{{ formatDashboardTime(task.startTime) }}</time></span></button></div>
            </section>

            <section v-if="recentProjects.length > 1" class="studio-panel"><div class="studio-section-head"><h2>其他最近项目</h2><Button type="link" @click="router.push('/toonflow/projects')">全部项目 →</Button></div><div class="other-projects"><button v-for="project in recentProjects.slice(1)" :key="project.id" type="button" @click="continueProject(project)"><span class="project-letter">{{ project.name.slice(0, 1) }}</span><span><b>{{ project.name }}</b><small>{{ project.stageLabel }}</small></span><IconifyIcon icon="lucide:arrow-up-right" /></button></div></section>
          </main>

          <aside class="studio-column">
            <section class="studio-panel">
              <div class="studio-section-head"><h2>任务与配置</h2><span class="subtle">当前状态</span></div>
              <div class="task-mini-stats"><button type="button" @click="router.push({ name: 'ToonflowTasks', query: { state: 'running' } })"><strong>{{ taskStats?.running ?? '—' }}</strong><span>正在处理</span></button><button type="button" @click="router.push({ name: 'ToonflowTasks', query: { state: 'failed' } })"><strong>{{ taskStats?.failed ?? '—' }}</strong><span>历史失败记录</span></button></div>
              <p class="studio-note">失败次数包含历史尝试，不代表同等数量的未解决问题。</p>
              <div v-if="failures.length" class="attention-box"><span class="attention-label"><IconifyIcon icon="lucide:circle-alert" />近期常见异常</span><p>{{ failures[0]!.message }}</p><small>最近 {{ tasks.length }} 条任务中出现 {{ failures[0]!.count }} 次</small><Button type="link" @click="router.push({ name: 'ToonflowTasks', query: { taskId: String(failures[0]!.task.id), state: 'failed' } })">查看原因与处理入口 →</Button></div>
              <div v-for="project in missing.slice(0, 3)" :key="project.id" class="configuration-row"><b>{{ project.name }}</b><p>尚未选择{{ project.missingModels.join('、') }}模型</p><Button size="small" @click="router.push({ name: 'ToonflowProjects', query: { edit: String(project.id) } })">配置项目模型</Button></div>
              <p v-if="!missing.length && projects.length" class="configuration-ok"><IconifyIcon icon="lucide:check" />所有项目均已选择三类模型</p>
            </section>
            <section class="studio-panel"><div class="studio-section-head"><h2>创作入口</h2></div><div class="studio-shortcuts"><button v-for="item in shortcuts" :key="item.path" type="button" @click="router.push(item.path)"><IconifyIcon :icon="item.icon" /><span>{{ item.label }}</span><IconifyIcon icon="lucide:chevron-right" /></button></div></section>
            <section class="studio-panel library-summary"><div class="studio-section-head"><h2>作品概览</h2><Button type="link" @click="router.push('/analytics')">制作分析 →</Button></div><dl><div><dt>创作项目</dt><dd>{{ projects.length }}</dd></div><div><dt>已保存剧本</dt><dd>{{ totals.scripts ?? '—' }} <small>集</small></dd></div><div><dt>已导出成片</dt><dd>{{ totals.renders ?? '—' }} <small>集</small></dd></div></dl></section>
          </aside>
        </div>
      </template>
    </div>
  </Page>
</template>

<style scoped src="../dashboard.css" />

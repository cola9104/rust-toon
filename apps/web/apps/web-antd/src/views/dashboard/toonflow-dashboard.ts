import type { ToonflowApi, TaskStats } from '#/api/toonflow';
import { computed, onActivated, onBeforeUnmount, onMounted, ref } from 'vue';
import { getNovelPage, getProjectStatistics, getProjects, getProjectVideoArchive, getTaskPage } from '#/api/toonflow';

export interface DashboardProject extends ToonflowApi.Project {
  statistics?: ToonflowApi.ProjectStatistics;
  chapters?: number;
  renders?: number;
  stageLabel: string;
  nextAction: string;
  nextHint: string;
  nextStage?: string;
  missingModels: string[];
}

export function countFinishedEpisodes(archive: ToonflowApi.ProjectVideoArchive) {
  return archive.episodes.filter((episode) => episode.renders.some((render) =>
    ['completed', 'ready', 'success', '生成成功'].includes(render.state.toLowerCase()) && Boolean(render.url),
  )).length;
}

export function buildProjectSummary(project: ToonflowApi.Project, statistics?: ToonflowApi.ProjectStatistics, chapters?: number, renders?: number): DashboardProject {
  const missingModels = [[project.chatModel, '对话'], [project.imageModel, '图片'], [project.videoModel, '视频']]
    .filter(([id]) => !id).map(([, label]) => String(label));
  const base = { ...project, statistics, chapters, renders, missingModels };
  if (!statistics) return { ...base, stageLabel: '数据暂不可用', nextAction: '打开项目', nextHint: '项目统计加载失败，可打开项目查看详情。' };
  if (renders) return { ...base, stageLabel: '已有剧集成果', nextAction: '查看剧集成果', nextStage: 'archive', nextHint: `${renders} 集已有成功导出的版本，可继续制作其他剧集。` };
  if (statistics.storyboardCount || statistics.videoCount) return { ...base, stageLabel: '分镜制作', nextAction: '继续分镜制作', nextStage: 'production', nextHint: `${statistics.storyboardCount} 个分镜，${statistics.videoCount} 条视频记录。检查生成结果后合成成片。` };
  if (statistics.scriptCount) return { ...base, stageLabel: '剧本与资产', nextAction: '检查剧本与资产', nextStage: 'script', nextHint: `${statistics.scriptCount} 集剧本已保存，确认内容与角色后进入分镜制作。` };
  if (chapters) return { ...base, stageLabel: '原文准备', nextAction: '处理原文章节', nextStage: 'novel', nextHint: `${chapters} 章原文已导入，可选择需要的章节提取事件，再开始剧本创作。` };
  if (chapters === 0) return { ...base, stageLabel: '等待创作', nextAction: '导入原文', nextStage: 'novel', nextHint: '还没有原文和剧本，先导入故事开始创作。' };
  return { ...base, stageLabel: '原文状态待确认', nextAction: '查看原文', nextStage: 'novel', nextHint: '原文数量暂时无法读取，打开项目查看。' };
}

export function taskTypeLabel(type: string) {
  return ({ image: '图片生成', novelEvent: '章节事件提取', scriptAssetExtraction: '剧本资产提取', video: '视频生成', videoExport: '视频合成', '工作流图片生成': '工作流图片' } as Record<string, string>)[type] ?? (type || '其他任务');
}

export function taskState(state: string) {
  const value = state?.toLowerCase();
  if (['completed', 'success'].includes(value)) return { label: '已完成', color: 'success', key: 'success' };
  if (['failed', 'error'].includes(value)) return { label: '失败', color: 'error', key: 'failed' };
  if (value === 'running') return { label: '处理中', color: 'processing', key: 'running' };
  return { label: ({ queued: '排队中', pending: '等待中', cancelled: '已取消', canceled: '已取消' } as Record<string, string>)[value] ?? (state || '未知'), color: 'default', key: 'other' };
}

export function failureMessage(reason?: string) {
  if (!reason?.trim()) return '未记录具体原因';
  try {
    const parsed: unknown = JSON.parse(reason);
    if (typeof parsed === 'object' && parsed !== null && 'message' in parsed && typeof parsed.message === 'string') return parsed.message;
  } catch { /* Older tasks store plain text. */ }
  return reason;
}

export function summarizeFailures(tasks: ToonflowApi.Task[]) {
  const groups = new Map<string, { message: string; count: number; task: ToonflowApi.Task }>();
  for (const task of tasks.filter((item) => taskState(item.state).key === 'failed')) {
    const message = failureMessage(task.reason);
    const existing = groups.get(message);
    if (existing) existing.count += 1;
    else groups.set(message, { message, count: 1, task });
  }
  return [...groups.values()].sort((a, b) => b.count - a.count);
}

export function formatDashboardTime(value?: number) {
  if (!value) return '—';
  return new Date(value).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
}

export function useToonflowDashboard() {
  const loading = ref(false);
  const loadError = ref('');
  const projects = ref<DashboardProject[]>([]);
  const tasks = ref<ToonflowApi.Task[]>([]);
  const taskStats = ref<TaskStats>();
  const selectedProjectId = ref<number>();
  const updatedAt = ref<number>();
  let version = 0;
  let lastLoad = 0;
  const visibleProjects = computed(() => projects.value.filter((project) => !selectedProjectId.value || project.id === selectedProjectId.value));
  const totals = computed(() => {
    const rows = visibleProjects.value;
    const known = rows.every((row) => row.statistics);
    return {
      scripts: known ? rows.reduce((sum, row) => sum + row.statistics!.scriptCount, 0) : undefined,
      storyboards: known ? rows.reduce((sum, row) => sum + row.statistics!.storyboardCount, 0) : undefined,
      videos: known ? rows.reduce((sum, row) => sum + row.statistics!.videoCount, 0) : undefined,
      chapters: rows.every((row) => row.chapters !== undefined) ? rows.reduce((sum, row) => sum + row.chapters!, 0) : undefined,
      renders: rows.every((row) => row.renders !== undefined) ? rows.reduce((sum, row) => sum + row.renders!, 0) : undefined,
    };
  });
  const failures = computed(() => summarizeFailures(tasks.value));
  const taskTypes = computed(() => {
    const counts = new Map<string, number>();
    for (const task of tasks.value) counts.set(task.taskClass, (counts.get(task.taskClass) ?? 0) + 1);
    return [...counts].map(([type, count]) => ({ type, label: taskTypeLabel(type), count })).sort((a, b) => b.count - a.count);
  });

  async function load() {
    const current = ++version;
    loading.value = true;
    loadError.value = '';
    const projectId = selectedProjectId.value;
    const [projectResult, taskResult] = await Promise.allSettled([getProjects(), getTaskPage({ page: 1, limit: 100, projectId })]);
    if (current !== version) return;
    const errors: string[] = [];
    if (taskResult.status === 'fulfilled') {
      tasks.value = taskResult.value.data;
      taskStats.value = taskResult.value.stats;
    } else {
      tasks.value = [];
      taskStats.value = undefined;
      errors.push('任务数据加载失败');
    }
    if (projectResult.status === 'fulfilled') {
      const rows = [...projectResult.value].sort((a, b) => b.updateTime - a.updateTime);
      const summaries: DashboardProject[] = [];
      // Bound fan-out: at most three projects (nine requests) at a time.
      for (let i = 0; i < rows.length; i += 3) {
        if (current !== version) return;
        const chunk = await Promise.all(rows.slice(i, i + 3).map(async (project) => {
          const [statistics, chapters, archive] = await Promise.allSettled([
            getProjectStatistics(project.id), getNovelPage(project.id, 1, 1), getProjectVideoArchive(project.id),
          ]);
          if ([statistics, chapters, archive].some((result) => result.status === 'rejected')) errors.push('部分项目数据暂不可用');
          return buildProjectSummary(project,
            statistics.status === 'fulfilled' ? statistics.value : undefined,
            chapters.status === 'fulfilled' ? chapters.value.total : undefined,
            archive.status === 'fulfilled' ? countFinishedEpisodes(archive.value) : undefined);
        }));
        summaries.push(...chunk);
      }
      if (current !== version) return;
      projects.value = summaries;
    } else errors.push('项目列表加载失败，暂保留上次结果');
    loadError.value = [...new Set(errors)].join('；');
    updatedAt.value = Date.now();
    lastLoad = Date.now();
    loading.value = false;
  }
  function refreshOnEnter() { if (!loading.value && Date.now() - lastLoad > 15_000) void load(); }
  onMounted(refreshOnEnter);
  onActivated(refreshOnEnter);
  onBeforeUnmount(() => { version += 1; });
  return { load, loading, loadError, projects, visibleProjects, tasks, taskStats, taskTypes, totals, failures, selectedProjectId, updatedAt };
}

import type { TaskStats, ToonflowApi } from '#/api/toonflow';

import { ref, watch } from 'vue';

import { getTaskCategories, getTaskDetails, getTaskPage, getTaskProjects } from '#/api/toonflow';

export function useTaskCenter(initial: { projectId?: number; state?: string } = {}) {
  const tasks = ref<ToonflowApi.Task[]>([]);
  const detail = ref<ToonflowApi.Task>();
  const category = ref('all');
  const state = ref(['all', 'running', 'completed', 'failed'].includes(initial.state ?? '') ? initial.state! : 'all');
  const projectId = ref<number | undefined>(initial.projectId);
  const page = ref(1);
  const pageSize = ref(20);
  const total = ref(0);
  const loading = ref(false);
  const loadError = ref('');
  const detailError = ref('');
  const categories = ref<Array<{ taskClass: string }>>([]);
  const projects = ref<Array<{ id: number; name: string }>>([]);
  const taskStats = ref<TaskStats>({ total: 0, running: 0, success: 0, failed: 0 });
  let active = false;
  let version = 0;
  let detailVersion = 0;
  let metadataVersion = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;

  async function refreshDetail() {
    const id = detail.value?.id;
    if (id === undefined) return;
    const current = ++detailVersion;
    try {
      const result = await getTaskDetails(id);
      if (current !== detailVersion || detail.value?.id !== id) return;
      detailError.value = result ? '' : '该任务已不存在';
      if (result) detail.value = result;
    } catch (error) {
      if (current === detailVersion) detailError.value = error instanceof Error ? error.message : '任务详情更新失败';
    }
  }

  async function load(silent = false): Promise<void> {
    clearTimeout(timer);
    const current = ++version;
    if (!silent) loading.value = true;
    const query = {
      page: page.value,
      limit: pageSize.value,
      taskClass: category.value === 'all' ? undefined : category.value,
      state: state.value === 'all' ? undefined : state.value,
      projectId: projectId.value,
    };
    // The drawer may refer to a task outside this page or filter.
    const detailUpdate = refreshDetail();
    try {
      const result = await getTaskPage(query);
      if (current !== version) return;
      const lastPage = Math.max(1, Math.ceil(result.total / query.limit));
      if (query.page > lastPage) {
        page.value = lastPage;
        await load(silent);
        return;
      }
      tasks.value = result.data;
      total.value = result.total;
      taskStats.value = result.stats;
      loadError.value = '';
    } catch (error) {
      if (current === version) loadError.value = error instanceof Error ? error.message : '任务中心暂时无法加载，请稍后重试';
    } finally {
      await detailUpdate;
      if (current === version) {
        loading.value = false;
        if (active) timer = setTimeout(() => void load(true), 5000);
      }
    }
  }

  async function loadMetadata() {
    const current = ++metadataVersion;
    const results = await Promise.allSettled([getTaskCategories(), getTaskProjects()]);
    if (current !== metadataVersion) return;
    if (results[0].status === 'fulfilled') categories.value = results[0].value;
    if (results[1].status === 'fulfilled') projects.value = results[1].value;
  }

  function openDetail(task: ToonflowApi.Task) {
    detail.value = task;
    detailError.value = '';
    void refreshDetail();
  }
  function closeDetail() {
    detailVersion += 1;
    detail.value = undefined;
    detailError.value = '';
  }
  function changePage(nextPage: number, nextSize: number) {
    page.value = nextSize === pageSize.value ? nextPage : 1;
    pageSize.value = nextSize;
    void load();
  }
  function start() {
    if (active) return;
    active = true;
    void loadMetadata();
    void load();
  }
  function stop() {
    active = false;
    version += 1;
    detailVersion += 1;
    metadataVersion += 1;
    clearTimeout(timer);
    loading.value = false;
  }
  watch([category, state, projectId], () => {
    page.value = 1;
    if (active) void load();
  }, { flush: 'sync' });

  return { tasks, detail, category, state, projectId, page, pageSize, total, loading,
    loadError, detailError, categories, projects, taskStats, load, openDetail,
    closeDetail, changePage, start, stop };
}

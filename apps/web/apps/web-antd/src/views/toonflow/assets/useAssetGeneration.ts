import type { Ref } from 'vue';
import type { ToonflowApi } from '#/api/toonflow';

import { computed, reactive, ref, watch } from 'vue';
import { message } from 'ant-design-vue';
import { cancelAssetImage, pollAssetImages, polishAssetPrompt, queueAssetImages, retryAssetImages } from '#/api/toonflow';

type ImageStatus = Awaited<ReturnType<typeof pollAssetImages>>[number];
const isFailure = (state: string) => ['生成失败', '已取消'].includes(state);
const isTerminal = (state: string) => state === '已完成' || isFailure(state);

// Wait for all preparations, including failures, before allowing another batch.
async function prepareAll<T>(items: T[], run: (item: T) => Promise<void>) {
  let cursor = 0;
  const errors: unknown[] = [];
  await Promise.all(Array.from({ length: Math.min(5, items.length) }, async () => {
    while (cursor < items.length) {
      const item = items[cursor++]!;
      try { await run(item); } catch (error) { errors.push(error); }
    }
  }));
  return errors;
}

export function useAssetGeneration(
  projectId: Ref<number | undefined>,
  project: Ref<ToonflowApi.Project | undefined>,
  assets: Ref<ToonflowApi.LibraryAsset[]>,
  imageReady: (id: number) => void,
) {
  const statuses = reactive(new Map<number, ImageStatus>());
  const preparingIds = reactive(new Set<number>());
  const polishingAssetIds = reactive(new Set<number>());
  const generationFailedIds = computed(() => new Set([...statuses.values()].filter((item) => isFailure(item.state)).map((item) => item.id)));
  const generatingAssetIds = computed(() => new Set([...preparingIds, ...[...statuses.values()].filter((item) => item.state === '生成中').map((item) => item.id)]));
  const batchRunning = ref<'image' | 'prompt'>();
  const batchProgress = ref({ current: 0, total: 0 });
  const batchProjectName = ref('');
  const submitting = ref(false);
  const cancelling = ref(false);
  const statusError = ref('');
  let epoch = 0;
  let statusVersion = 0;
  let active = true;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let batch: { epoch: number; ids: number[]; name: string } | undefined;

  function current(scope: number) { return active && scope === epoch; }
  function snapshot(targets: ToonflowApi.Asset[]) {
    if (!projectId.value || project.value?.id !== projectId.value || targets.some((asset) => asset.projectId !== projectId.value)) {
      message.warning('请等待当前项目加载完成');
      return;
    }
    return { epoch, id: projectId.value, name: project.value.name, model: project.value.imageModel };
  }
  function finishBatch() {
    if (!batch || !current(batch.epoch)) return;
    const results = batch.ids.map((id) => statuses.get(id));
    const done = results.filter((item) => item && isTerminal(item.state));
    batchProgress.value = { current: done.length, total: results.length };
    if (done.length !== results.length) return;
    const failed = done.filter((item) => item && isFailure(item.state)).length;
    const text = `项目“${batch.name}”：${results.length - failed} 项图片生成成功，${failed} 项失败或取消`;
    if (failed) message.warning(text); else message.success(text);
    batch = undefined;
    batchRunning.value = undefined;
  }
  function schedule() {
    clearTimeout(timer);
    if (active && (batch || generatingAssetIds.value.size)) {
      timer = setTimeout(() => void refreshStatuses(), 2000);
    }
  }
  async function refreshStatuses() {
    if (!active || !projectId.value) return;
    clearTimeout(timer);
    const scope = epoch;
    const version = ++statusVersion;
    const ids = assets.value.map((asset) => asset.id);
    try {
      const results: ImageStatus[] = [];
      for (let offset = 0; offset < ids.length; offset += 100) {
        results.push(...await pollAssetImages(ids.slice(offset, offset + 100)));
        if (!current(scope) || version !== statusVersion) return;
      }
      if (!current(scope) || version !== statusVersion) return;
      const visible = new Set(ids);
      for (const id of statuses.keys()) if (!visible.has(id)) statuses.delete(id);
      for (const result of results) {
        statuses.set(result.id, result);
        const asset = assets.value.find((item) => item.id === result.id);
        if (!asset) continue;
        asset.imageState = result.state;
        asset.imageErrorReason = result.errorReason;
        if (result.state === '已完成' && result.filePath) {
          if (asset.imageId !== result.imageId || asset.imageFilePath !== result.filePath) imageReady(asset.id);
          asset.imageId = result.imageId;
          asset.imageFilePath = result.filePath;
        }
      }
      statusError.value = '';
      finishBatch();
    } catch (error) {
      if (current(scope) && version === statusVersion) statusError.value = error instanceof Error ? error.message : '生成状态同步失败，请重试';
    } finally {
      if (current(scope) && version === statusVersion) schedule();
    }
  }

  async function polish(targets: ToonflowApi.Asset[], batchMode = false) {
    if (!targets.length || batchRunning.value || targets.some((item) => polishingAssetIds.has(item.id))) return;
    const scope = snapshot(targets);
    if (!scope) return;
    if (batchMode) batchRunning.value = 'prompt';
    batchProjectName.value = scope.name;
    batchProgress.value = { current: 0, total: targets.length };
    targets.forEach((item) => polishingAssetIds.add(item.id));
    const errors = await prepareAll(targets, async (asset) => {
      if (!current(scope.epoch)) return;
      try {
        const result = await polishAssetPrompt({ assetsId: asset.id, projectId: scope.id, type: asset.type, name: asset.name, describe: asset.description || '' });
        if (current(scope.epoch)) {
          asset.prompt = result.prompt;
          const visibleAsset = assets.value.find((item) => item.id === asset.id);
          if (visibleAsset) visibleAsset.prompt = result.prompt;
        }
      } finally {
        if (current(scope.epoch)) {
          polishingAssetIds.delete(asset.id);
          batchProgress.value.current += 1;
        }
      }
    });
    if (!current(scope.epoch)) return;
    if (batchMode) batchRunning.value = undefined;
    const summary = `项目“${scope.name}”：${targets.length - errors.length} 条提示词润色完成`;
    if (errors.length) message.warning(`${summary}，${errors.length} 条失败`); else message.success(summary);
  }

  async function generate(targets: ToonflowApi.Asset[], resolution: string, retry = false) {
    if (!targets.length || batchRunning.value || targets.some((item) => generatingAssetIds.value.has(item.id) || polishingAssetIds.has(item.id))) return;
    const scope = snapshot(targets);
    if (!scope) return;
    if (!retry && !scope.model) return message.warning('请先为当前项目配置图片模型');
    const copies = targets.map((item) => ({ ...item }));
    submitting.value = true;
    batchRunning.value = 'image';
    batchProjectName.value = scope.name;
    batchProgress.value = { current: 0, total: copies.length };
    copies.forEach((item) => preparingIds.add(item.id));
    try {
      let ids = copies.map((item) => item.id);
      if (retry) {
        const result = await retryAssetImages({ projectId: scope.id, ids, concurrentCount: 5 });
        ids = result.ids;
      } else {
        const errors = await prepareAll(copies, async (asset) => {
          if (asset.prompt || !current(scope.epoch)) return;
          const result = await polishAssetPrompt({ assetsId: asset.id, projectId: scope.id, type: asset.type, name: asset.name, describe: asset.description || '' });
          asset.prompt = result.prompt;
          if (current(scope.epoch)) {
            const visibleAsset = assets.value.find((item) => item.id === asset.id);
            if (visibleAsset) visibleAsset.prompt = result.prompt;
          }
        });
        if (!current(scope.epoch)) return;
        if (errors.length) throw new Error(`${errors.length} 条提示词准备失败，本批图片尚未提交，请重试`);
        await queueAssetImages({ projectId: scope.id, model: String(scope.model), resolution, concurrentCount: 5,
          items: copies.map((asset) => ({ id: asset.id, type: asset.type, name: asset.name, prompt: asset.prompt })) });
      }
      if (!current(scope.epoch)) return;
      // Invalidate status reads started before submission; they may describe the old attempt.
      statusVersion += 1;
      if (ids.length) batch = { epoch: scope.epoch, ids, name: scope.name };
      for (const id of ids) statuses.set(id, { id, state: '生成中', imageId: 0 });
      message.success(`已向项目“${scope.name}”提交 ${ids.length} 项图片任务，切换页面后仍会在后台执行`);
    } catch (error) {
      if (current(scope.epoch)) message.error(error instanceof Error ? error.message : '图片任务提交失败');
    } finally {
      if (current(scope.epoch)) {
        copies.forEach((item) => preparingIds.delete(item.id));
        submitting.value = false;
        if (!batch) batchRunning.value = undefined;
        await refreshStatuses();
      }
    }
  }

  async function cancelBatchImages() {
    if (!batch || submitting.value || cancelling.value) return;
    const run = batch;
    cancelling.value = true;
    try {
      // cancelGenerate accepts image IDs, not asset IDs.
      const images = await pollAssetImages(run.ids);
      if (!current(run.epoch)) return;
      const results = await Promise.allSettled(images.filter((item) => item.state === '生成中').map((item) => cancelAssetImage(item.imageId)));
      if (!current(run.epoch)) return;
      if (results.some((result) => result.status === 'rejected')) message.warning('部分取消请求失败，正在同步实际任务状态');
      else message.success(`项目“${run.name}”的取消请求已处理`);
    } catch (error) {
      if (current(run.epoch)) message.error(error instanceof Error ? error.message : '取消失败');
    } finally {
      if (current(run.epoch)) { cancelling.value = false; await refreshStatuses(); }
    }
  }

  function reset() {
    epoch += 1;
    statusVersion += 1;
    clearTimeout(timer);
    statuses.clear(); preparingIds.clear(); polishingAssetIds.clear();
    batch = undefined; batchRunning.value = undefined;
    batchProgress.value = { current: 0, total: 0 };
    submitting.value = false; cancelling.value = false; statusError.value = '';
  }
  watch(projectId, reset, { flush: 'sync' });
  function stop() { active = false; reset(); }
  function start() { if (!active) { active = true; void refreshStatuses(); } }
  return { statuses, generationFailedIds, generatingAssetIds, polishingAssetIds, batchRunning, batchProgress,
    batchProjectName, submitting, cancelling, statusError, refreshStatuses, polish, generate, cancelBatchImages, start, stop };
}

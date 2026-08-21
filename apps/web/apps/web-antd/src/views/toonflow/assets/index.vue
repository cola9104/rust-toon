<script lang="ts" setup>
import type { AssetCategory } from './asset-types';

import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';

import {
  Button,
  Checkbox,
  Col,
  Empty,
  Form,
  Image,
  Input,
  message,
  Modal,
  Row,
  Select,
  Space,
  Tabs,
  Tag,
  Typography,
} from 'ant-design-vue';

import {
  batchBindAudio,
  cancelAssetImage,
  deleteAssets,
  generateAssetDubbing,
  getAssetLibrary,
  getProject,
  getProjects,
  pollAssetImages,
  polishAssetPrompt,
  queueAssetImages,
  retryAssetImages,
  saveAsset,
  uploadMaterial,
} from '#/api/toonflow';

import {
  ASSET_CATEGORY_OPTIONS,
  assetFileUrl,
  assetTypeLabel,
  isAssetInCategory,
} from './asset-types';

import '../shared/page-card.css';
import '../styles/toon-theme.css';

const route = useRoute();
const router = useRouter();
const projects = ref<ToonflowApi.Project[]>([]);
const assets = ref<ToonflowApi.LibraryAsset[]>([]);
const selectedProjectId = ref<number>();
const project = ref<ToonflowApi.Project>();
const loading = ref(false);
const materialInput = ref<HTMLInputElement>();
const assetModalOpen = ref(false);
const dubbingModalOpen = ref(false);
const dubbingResult = ref('');
const failedImageIds = reactive(new Set<number>());
const generatingAssetIds = reactive(new Set<number>());
const polishingAssetIds = reactive(new Set<number>());
const activeCategory = ref<AssetCategory>('role');
const assetSearch = ref('');
const selectedAssetIds = reactive(new Set<number>());
const batchResolution = ref('2K');
const batchRunning = ref<'image' | 'prompt'>();
const batchProgress = ref({ current: 0, total: 0 });

const projectOptions = computed(() =>
  projects.value.map((item) => ({ label: item.name, value: item.id })),
);
const imageQuality = computed(() =>
  ['1K', '2K', '4K'].includes(project.value?.imageQuality ?? '')
    ? project.value!.imageQuality
    : '2K',
);
const filteredAssets = computed(() =>
  assets.value.filter((asset) => {
    if (!isAssetInCategory(asset.type, activeCategory.value)) return false;
    const keyword = assetSearch.value.trim().toLocaleLowerCase();
    if (!keyword) return true;
    return [asset.name, asset.description, asset.prompt]
      .some((value) => value?.toLocaleLowerCase().includes(keyword));
  }),
);
const categoryCounts = computed(() =>
  Object.fromEntries(
    ASSET_CATEGORY_OPTIONS.map(({ value }) => [
      value,
      assets.value.filter((asset) => isAssetInCategory(asset.type, value)).length,
    ]),
  ) as Record<AssetCategory, number>,
);
const selectedAssets = computed(() => assets.value.filter((asset) => selectedAssetIds.has(asset.id)));
const failedSelectedAssets = computed(() => selectedAssets.value.filter((asset) => failedImageIds.has(asset.id)));
const selectedVisibleCount = computed(() => filteredAssets.value.filter((asset) => selectedAssetIds.has(asset.id)).length);
const allVisibleSelected = computed(() => filteredAssets.value.length > 0 && selectedVisibleCount.value === filteredAssets.value.length);
const someVisibleSelected = computed(() => selectedVisibleCount.value > 0 && !allVisibleSelected.value);
function imagePath(asset: ToonflowApi.LibraryAsset) {
  return asset.imageFilePath || asset.imageUrl || (asset as ToonflowApi.Asset & { filePath?: string }).filePath || '';
}

const assetForm = reactive({
  id: undefined as number | undefined,
  name: '',
  type: 'role',
  description: '',
  prompt: '',
  remark: '',
});
const dubbingForm = reactive({
  assetsId: 0,
  assetName: '',
  text: '',
  voice: 'alloy',
});

async function loadAssets() {
  if (!selectedProjectId.value) {
    assets.value = [];
    project.value = undefined;
    return;
  }
  loading.value = true;
  try {
    failedImageIds.clear();
    [assets.value, project.value] = await Promise.all([
      getAssetLibrary(selectedProjectId.value),
      getProject(selectedProjectId.value),
    ]);
  } finally {
    loading.value = false;
  }
}

async function selectProject(projectId?: number) {
  selectedProjectId.value = projectId;
  await router.replace({ query: projectId ? { projectId } : {} });
  await loadAssets();
}

function handleProjectChange(value: unknown) {
  const projectId = Number(value);
  void selectProject(Number.isFinite(projectId) ? projectId : undefined);
}

function openAsset(asset?: ToonflowApi.LibraryAsset) {
  if (!selectedProjectId.value) {
    message.warning('请先选择项目');
    return;
  }
  Object.assign(assetForm, {
    id: asset?.id,
    name: asset?.name ?? '',
    type: asset?.type ?? 'role',
    description: asset?.description ?? '',
    prompt: asset?.prompt ?? '',
    remark: asset?.remark ?? '',
  });
  assetModalOpen.value = true;
}

async function saveAssetForm() {
  if (!selectedProjectId.value || !assetForm.name.trim()) {
    message.warning('请选择项目并填写资产名称');
    return;
  }
  await saveAsset({ ...assetForm, projectId: selectedProjectId.value });
  assetModalOpen.value = false;
  message.success('资产已保存');
  await loadAssets();
}

async function uploadMaterialFile(event: Event) {
  if (!selectedProjectId.value) {
    message.warning('请先选择项目');
    return;
  }
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  const base64Data = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
  await uploadMaterial({
    projectId: selectedProjectId.value,
    base64Data,
    type: 'clip',
    name: file.name,
  });
  message.success('素材上传成功');
  await loadAssets();
}

async function polishAsset(asset: ToonflowApi.Asset) {
  if (!selectedProjectId.value) return;
  if (polishingAssetIds.has(asset.id)) return;
  const messageKey = `polish-asset-${asset.id}`;
  polishingAssetIds.add(asset.id);
  message.loading({
    content: `正在润色“${asset.name}”的提示词…`,
    duration: 0,
    key: messageKey,
  });
  try {
    const result = await polishAssetPrompt({
      assetsId: asset.id,
      projectId: selectedProjectId.value,
      type: asset.type,
      name: asset.name,
      describe: asset.description || '',
    });
    asset.prompt = result.prompt;
    message.success({
      content: `“${asset.name}”提示词润色完成`,
      duration: 3,
      key: messageKey,
    });
  } catch (error) {
    message.error({
      content: error instanceof Error ? error.message : `“${asset.name}”提示词润色失败`,
      duration: 5,
      key: messageKey,
    });
  } finally {
    polishingAssetIds.delete(asset.id);
  }
}

async function generateAssetPicture(asset: ToonflowApi.Asset) {
  if (!selectedProjectId.value || !project.value?.imageModel) {
    message.warning('请先选择项目并配置图片模型');
    return;
  }
  if (generatingAssetIds.has(asset.id)) return;
  const messageKey = `generate-asset-${asset.id}`;
  generatingAssetIds.add(asset.id);
  message.loading({
    content: `正在生成“${asset.name}”的图片，请稍候…`,
    duration: 0,
    key: messageKey,
  });
  try {
    let visualPrompt = asset.prompt;
    if (!visualPrompt) {
      const polished = await polishAssetPrompt({
        assetsId: asset.id,
        projectId: selectedProjectId.value,
        type: asset.type,
        name: asset.name,
        describe: asset.description || '',
      });
      visualPrompt = polished.prompt;
    }
    const [current] = await pollAssetImages([asset.id]);
    if (current?.state !== '生成中') {
      await queueAssetImages({
        projectId: selectedProjectId.value,
        model: String(project.value.imageModel),
        resolution: imageQuality.value,
        concurrentCount: 1,
        items: [{
          id: asset.id,
          type: asset.type,
          name: asset.name,
          prompt: visualPrompt,
        }],
      });
    }
    let completed = false;
    for (let attempt = 0; attempt < 180; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 2000));
      const [result] = await pollAssetImages([asset.id]);
      if (!result || result.state === '生成中') continue;
      if (result.state !== '已完成') {
        throw new Error(result.errorReason || `“${asset.name}”图片生成失败`);
      }
      completed = true;
      break;
    }
    if (!completed) {
      message.info({
        content: `“${asset.name}”仍在后台生成，可稍后刷新查看`,
        duration: 5,
        key: messageKey,
      });
      return;
    }
    failedImageIds.delete(asset.id);
    await loadAssets();
    message.success({
      content: `“${asset.name}”图片生成完成`,
      duration: 3,
      key: messageKey,
    });
  } catch (error) {
    message.error({
      content: error instanceof Error ? error.message : `“${asset.name}”图片生成失败`,
      duration: 5,
      key: messageKey,
    });
  } finally {
    generatingAssetIds.delete(asset.id);
  }
}

function selectVisible(mode: 'all' | 'empty' | 'invert' | 'missing') {
  for (const asset of filteredAssets.value) {
    if (mode === 'invert') selectedAssetIds.has(asset.id) ? selectedAssetIds.delete(asset.id) : selectedAssetIds.add(asset.id);
    else if (mode === 'all' || (mode === 'empty' && !asset.prompt) || (mode === 'missing' && !asset.imageFilePath)) selectedAssetIds.add(asset.id);
  }
}

function toggleVisible(checked: boolean) {
  for (const asset of filteredAssets.value) {
    if (checked) selectedAssetIds.add(asset.id);
    else selectedAssetIds.delete(asset.id);
  }
}

function clearSelection() {
  selectedAssetIds.clear();
}

function toggleAsset(id: number, checked: boolean) {
  checked ? selectedAssetIds.add(id) : selectedAssetIds.delete(id);
}

async function batchPolish() {
  if (!selectedProjectId.value || !selectedAssets.value.length) return message.warning('请先选择资产');
  batchRunning.value = 'prompt';
  batchProgress.value = { current: 0, total: selectedAssets.value.length };
  try {
    await Promise.all(selectedAssets.value.map(async (asset) => {
      polishingAssetIds.add(asset.id);
      try {
        const result = await polishAssetPrompt({ assetsId: asset.id, projectId: selectedProjectId.value!, type: asset.type, name: asset.name, describe: asset.description || '' });
        asset.prompt = result.prompt;
      } finally { polishingAssetIds.delete(asset.id); batchProgress.value.current += 1; }
    }));
    message.success(`已生成 ${selectedAssets.value.length} 条提示词`);
  } finally { batchRunning.value = undefined; batchProgress.value = { current: 0, total: 0 }; }
}

async function batchGenerateImages() {
  if (!selectedProjectId.value || !project.value?.imageModel || !selectedAssets.value.length) return message.warning('请选择资产并配置图片模型');
  batchRunning.value = 'image';
  const targets = [...selectedAssets.value];
  batchProgress.value = { current: 0, total: targets.length };
  targets.forEach((asset) => generatingAssetIds.add(asset.id));
  try {
    const items = await Promise.all(targets.map(async (asset) => {
      let prompt = asset.prompt;
      if (!prompt) {
        const result = await polishAssetPrompt({ assetsId: asset.id, projectId: selectedProjectId.value!, type: asset.type, name: asset.name, describe: asset.description || '' });
        prompt = result.prompt;
        asset.prompt = prompt;
      }
      return { id: asset.id, type: asset.type, name: asset.name, prompt };
    }));
    await queueAssetImages({ projectId: selectedProjectId.value, model: String(project.value.imageModel), resolution: batchResolution.value, concurrentCount: 5, items });
    const pending = new Set(targets.map((asset) => asset.id));
    for (let attempt = 0; attempt < 180 && pending.size; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 2000));
      const results = await pollAssetImages([...pending]);
      for (const result of results) {
        if (result.state === '生成中') continue;
        pending.delete(result.id);
        batchProgress.value.current += 1;
        generatingAssetIds.delete(result.id);
        if (result.state !== '已完成') failedImageIds.add(result.id);
      }
    }
    // 超过轮询窗口仍未返回终态时，按失败处理，保证用户可以显式重试。
    for (const id of pending) {
      failedImageIds.add(id);
      generatingAssetIds.delete(id);
    }
    await loadAssets();
    const failedCount = targets.filter((asset) => failedImageIds.has(asset.id)).length;
    if (failedCount) {
      message.warning(`批量图片任务完成，${failedCount} 项失败，可在左侧重试`);
    } else {
      message.success('批量图片任务已完成');
    }
  } finally {
    targets.forEach((asset) => generatingAssetIds.delete(asset.id));
    batchRunning.value = undefined;
    batchProgress.value = { current: 0, total: 0 };
  }
}

async function cancelBatchImages() {
  if (batchRunning.value !== 'image') return;
  const ids = [...generatingAssetIds];
  if (!ids.length) return;
  try {
    await Promise.all(ids.map((id) => cancelAssetImage(id)));
    ids.forEach((id) => {
      generatingAssetIds.delete(id);
      failedImageIds.add(id);
    });
    message.success(`已取消 ${ids.length} 项图片任务，可稍后重试`);
  } catch (error) {
    message.error(error instanceof Error ? error.message : '批量取消失败');
  } finally {
    batchRunning.value = undefined;
    batchProgress.value = { current: 0, total: 0 };
  }
}

async function retryFailedImages() {
  const failedTargets = [...failedSelectedAssets.value];
  if (!failedTargets.length) return message.info('当前没有失败的批量图片任务');
  const previousSelection = new Set(selectedAssetIds);
  selectedAssetIds.clear();
  failedTargets.forEach((asset) => selectedAssetIds.add(asset.id));
  failedTargets.forEach((asset) => failedImageIds.delete(asset.id));
  batchRunning.value = 'image';
  batchProgress.value = { current: 0, total: failedTargets.length };
  failedTargets.forEach((asset) => generatingAssetIds.add(asset.id));
  try {
    await retryAssetImages({ projectId: selectedProjectId.value!, ids: failedTargets.map((asset) => asset.id), concurrentCount: 5 });
    const pending = new Set(failedTargets.map((asset) => asset.id));
    for (let attempt = 0; attempt < 180 && pending.size; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 2000));
      const results = await pollAssetImages([...pending]);
      for (const result of results) {
        if (result.state === '生成中') continue;
        pending.delete(result.id);
        batchProgress.value.current += 1;
        generatingAssetIds.delete(result.id);
        if (result.state !== '已完成') failedImageIds.add(result.id);
      }
    }
    for (const id of pending) {
      failedImageIds.add(id);
      generatingAssetIds.delete(id);
    }
    await loadAssets();
    const failedCount = failedTargets.filter((asset) => failedImageIds.has(asset.id)).length;
    if (failedCount) message.warning(`${failedCount} 项图片重试失败，请稍后再次尝试`);
    else message.success(`已重试 ${failedTargets.length} 项失败图片`);
  } catch (error) {
    failedTargets.forEach((asset) => failedImageIds.add(asset.id));
    message.error(error instanceof Error ? error.message : '失败图片重试未提交');
  } finally {
    failedTargets.forEach((asset) => generatingAssetIds.delete(asset.id));
    batchRunning.value = undefined;
    batchProgress.value = { current: 0, total: 0 };
    selectedAssetIds.clear();
    previousSelection.forEach((id) => selectedAssetIds.add(id));
  }
}

async function matchAssetVoice(asset: ToonflowApi.Asset) {
  if (!selectedProjectId.value) return;
  await batchBindAudio(selectedProjectId.value, [asset.id]);
  message.success('已匹配项目中的音色资产');
  await loadAssets();
}

function removeAsset(asset: ToonflowApi.Asset) {
  Modal.confirm({
    title: `确认删除“${asset.name}”？`,
    content: '关联的图片、剧本绑定和人物形态也会一并删除，且无法恢复。',
    okText: '删除',
    okType: 'danger',
    cancelText: '取消',
    async onOk() {
      await deleteAssets([asset.id]);
      failedImageIds.delete(asset.id);
      await loadAssets();
      message.success(`“${asset.name}”已删除`);
    },
  });
}

function openDubbing(asset: ToonflowApi.Asset) {
  Object.assign(dubbingForm, {
    assetsId: asset.id,
    assetName: asset.name,
    text: asset.description || asset.prompt || '',
    voice: 'alloy',
  });
  dubbingResult.value = '';
  dubbingModalOpen.value = true;
}

async function createDubbing() {
  if (!selectedProjectId.value || !dubbingForm.text.trim()) {
    message.warning('请输入配音文本');
    return;
  }
  const result = await generateAssetDubbing({
    projectId: selectedProjectId.value,
    assetsId: dubbingForm.assetsId,
    text: dubbingForm.text,
    voice: dubbingForm.voice,
  });
  dubbingResult.value = result.url;
  message.success('角色配音已生成并绑定');
  await loadAssets();
}

onMounted(async () => {
  projects.value = await getProjects();
  const queryProjectId = Number(route.query.projectId);
  selectedProjectId.value = Number.isFinite(queryProjectId) && queryProjectId > 0
    ? queryProjectId
    : projects.value[0]?.id;
  await loadAssets();
});

watch(() => route.query.projectId, (value) => {
  const projectId = Number(value);
  if (projectId > 0 && projectId !== selectedProjectId.value) {
    selectedProjectId.value = projectId;
    void loadAssets();
  }
});
</script>

<template>
  <Page auto-content-height class="toon-page">
    <div class="toonflow-page-shell">
      <div class="toon-header asset-header">
        <div class="asset-heading"><div class="asset-heading-title"><h1 class="toon-title">资产库</h1><Tag :bordered="false">{{ assets.length }} 项项目资产</Tag></div><p class="toon-subtitle">按项目管理角色、场景、道具和服装资产。</p></div>
        <Space wrap>
          <Select
            :options="projectOptions"
            :value="selectedProjectId"
            placeholder="选择项目"
            style="width: 220px"
            @change="handleProjectChange"
          />
          <input
            ref="materialInput"
            accept="image/*,audio/*,video/*"
            class="hidden"
            type="file"
            @change="uploadMaterialFile"
          />
          <Button :disabled="!selectedProjectId" @click="materialInput?.click()">上传素材</Button>
          <Button :disabled="!selectedProjectId" type="primary" @click="openAsset()">新增资产</Button>
        </Space>
      </div>

      <Typography.Paragraph class="asset-library-tip" type="secondary">
        资产按项目隔离；选择项目后，只显示并使用该项目创建的资产。
      </Typography.Paragraph>

      <Empty v-if="!selectedProjectId" description="请先选择项目" />
      <template v-else>
        <div class="asset-workspace">
          <aside class="batch-sidebar">
            <div class="batch-title"><b>批量生产</b><Button type="link" size="small" :disabled="!selectedAssets.length" @click="clearSelection">清空</Button></div>
            <div class="batch-selection"><Checkbox :checked="allVisibleSelected" :indeterminate="someVisibleSelected" @change="toggleVisible($event.target.checked)">当前分类全选</Checkbox><span>{{ selectedAssets.length }} 项已选</span></div>
            <label>快捷选择</label>
            <Button block @click="selectVisible('all')">全选当前分类</Button>
            <Button block @click="selectVisible('empty')">全选提示词为空</Button>
            <Button block @click="selectVisible('missing')">全选未生成</Button>
            <Button block @click="selectVisible('invert')">反选当前分类</Button>
            <label>统一模型</label><Input :value="project?.imageModel ? `项目模型 #${project.imageModel}` : '未配置'" disabled />
            <label>分辨率</label><Select v-model:value="batchResolution" :options="['1K','2K','4K'].map(value=>({label:value,value}))" />
            <div v-if="batchRunning" class="batch-progress">{{ batchRunning === 'image' ? '图片生成' : '提示词生成' }}：{{ batchProgress.current }}/{{ batchProgress.total }}</div>
            <Button v-if="batchRunning === 'image'" block danger @click="cancelBatchImages">取消当前图片任务</Button>
            <Button block :loading="batchRunning==='prompt'" :disabled="!!batchRunning || !selectedAssets.length" @click="batchPolish">批量生成提示词</Button>
            <Button block class="toon-primary" type="primary" :loading="batchRunning==='image'" :disabled="!!batchRunning || !selectedAssets.length" @click="batchGenerateImages">批量生成图片</Button>
            <Button v-if="failedSelectedAssets.length" block danger :disabled="!!batchRunning" @click="retryFailedImages">重试失败图片（{{ failedSelectedAssets.length }}）</Button>
          </aside>
          <main class="asset-content">
        <Tabs v-model:active-key="activeCategory" class="asset-category-tabs">
          <Tabs.TabPane
            v-for="category in ASSET_CATEGORY_OPTIONS"
            :key="category.value"
          >
            <template #tab>
              <Space :size="6">
                <span>{{ category.label }}</span>
                <Tag class="category-count">{{ categoryCounts[category.value] }}</Tag>
              </Space>
            </template>
          </Tabs.TabPane>
        </Tabs>
        <div class="asset-toolbar">
          <Input.Search
            v-model:value="assetSearch"
            allow-clear
            placeholder="搜索名称或描述"
            style="max-width: 360px"
          />
          <Typography.Text type="secondary">
            当前分类共 {{ filteredAssets.length }} 项资产
          </Typography.Text>
        </div>
        <div v-if="loading" class="asset-loading">资产加载中…</div>
        <Empty
          v-else-if="filteredAssets.length === 0"
          :description="assetSearch ? '没有匹配的资产' : '暂无该类资产'"
        />
        <Row v-else :gutter="[16, 16]">
          <Col
            v-for="item in filteredAssets"
            :key="item.id"
            class="asset-card-column"
            :lg="8"
            :md="12"
            :sm="24"
            :xl="6"
            :xs="24"
          >
            <Card class="asset-card" hoverable>
              <template #cover>
                <div class="asset-cover">
                  <Checkbox class="asset-selector" :checked="selectedAssetIds.has(item.id)" @change="toggleAsset(item.id, $event.target.checked)" />
                  <div v-if="generatingAssetIds.has(item.id)" class="asset-progress"><span />生成中</div>
                  <Image
                    v-if="imagePath(item) && !failedImageIds.has(item.id)"
                    :alt="item.name"
                    :src="assetFileUrl(imagePath(item))"
                    :preview="true"
                    class="asset-thumb"
                    @error="failedImageIds.add(item.id)"
                  />
                  <div v-else class="asset-placeholder">{{ assetTypeLabel(item.type) }}</div>
                </div>
              </template>
              <Card.Meta
                :description="item.description || '暂无描述'"
                :title="item.name"
              />
              <div v-if="item.prompt" class="asset-prompt" :title="item.prompt">
                <Tag color="blue">AI 提示词</Tag>
                <span class="asset-prompt-text">{{ item.prompt }}</span>
              </div>
              <div class="asset-meta">
                <Typography.Text type="secondary">当前项目资产</Typography.Text>
              </div>
              <div class="asset-actions">
                <Space wrap :size="4">
                  <Button type="link" @click="openAsset(item)">编辑</Button>
                  <Button
                    v-if="['role', 'scene', 'tool', 'costume'].includes(item.type)"
                    :loading="polishingAssetIds.has(item.id)"
                    type="link"
                    @click="polishAsset(item)"
                  >
                    {{ polishingAssetIds.has(item.id) ? '润色中' : 'AI 润色' }}
                  </Button>
                  <Button
                    :loading="generatingAssetIds.has(item.id)"
                    type="link"
                    @click="generateAssetPicture(item)"
                  >
                    {{ generatingAssetIds.has(item.id) ? '生成中' : '生成图片' }}
                  </Button>
                  <Button v-if="item.type === 'role'" type="link" @click="matchAssetVoice(item)">
                    匹配音色
                  </Button>
                  <Button v-if="item.type === 'role'" type="link" @click="openDubbing(item)">
                    生成配音
                  </Button>
                  <Button danger type="link" @click="removeAsset(item)">删除</Button>
                </Space>
              </div>
            </Card>
          </Col>
        </Row>
          </main>
        </div>
      </template>
    </div>

    <Modal v-model:open="assetModalOpen" title="资产" width="760px" @ok="saveAssetForm">
      <Form :label-col="{ span: 4 }">
        <Form.Item label="名称"><Input v-model:value="assetForm.name" /></Form.Item>
        <Form.Item label="类型">
          <Select
            v-model:value="assetForm.type"
            :options="[
              { label: '角色', value: 'role' },
              { label: '场景', value: 'scene' },
              { label: '道具', value: 'tool' },
              { label: '服装', value: 'costume' },
            ]"
          />
        </Form.Item>
        <Form.Item label="描述"><Input.TextArea v-model:value="assetForm.description" :rows="3" /></Form.Item>
        <Form.Item label="提示词"><Input.TextArea v-model:value="assetForm.prompt" :rows="4" /></Form.Item>
      </Form>
    </Modal>

    <Modal
      v-model:open="dubbingModalOpen"
      :title="`生成配音 · ${dubbingForm.assetName}`"
      width="720px"
      @ok="createDubbing"
    >
      <Form layout="vertical">
        <Form.Item label="音色">
          <Select
            v-model:value="dubbingForm.voice"
            :options="[
              { label: 'Alloy', value: 'alloy' },
              { label: 'Echo', value: 'echo' },
              { label: 'Fable', value: 'fable' },
              { label: 'Nova', value: 'nova' },
            ]"
          />
        </Form.Item>
        <Form.Item label="文本"><Input.TextArea v-model:value="dubbingForm.text" :rows="7" /></Form.Item>
        <Form.Item v-if="dubbingResult" label="生成结果">
          <audio :src="dubbingResult" controls class="w-full"></audio>
        </Form.Item>
      </Form>
    </Modal>
  </Page>
</template>

<style scoped>
.toonflow-page-shell { display: flex; min-width: 0; height: 100%; min-height: 100%; flex-direction: column; overflow: auto; padding: 4px 2px 20px; }
.asset-header { align-items: flex-start; gap: 16px; }
.asset-heading { min-width: 0; }
.asset-heading-title { display: flex; align-items: center; gap: 10px; }
.asset-heading-title .toon-title { margin: 0; }
.asset-heading-title .ant-tag { margin: 0; border-radius: 999px; color: var(--ant-color-primary); background: var(--ant-color-primary-bg); }
.asset-library-tip { margin-bottom: 16px; }.asset-category-tabs { margin-bottom: 4px; }
.category-count { margin-inline-end: 0; }
.asset-toolbar {
  align-items: center;
  display: flex;
  justify-content: space-between;
  margin-bottom: 16px;
}
.asset-loading { color: var(--ant-color-text-secondary); padding: 64px; text-align: center; }
.asset-card-column { display: flex; }
.asset-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  width: 100%;
}
.asset-card :deep(.ant-card-cover) { flex: none; }
.asset-card :deep(.ant-card-body) {
  display: flex;
  flex: 1;
  flex-direction: column;
}
.asset-cover {
  background: var(--ant-color-fill-secondary);
  box-sizing: border-box;
  height: 200px;
  overflow: hidden;
  padding: 8px;
}
.asset-cover :deep(.ant-image) {
  display: block;
  height: 100%;
  width: 100%;
}
.asset-cover :deep(.ant-image-img) {
  height: 100%;
  object-fit: contain;
  object-position: center;
  width: 100%;
}
.asset-placeholder {
  align-items: center;
  background: var(--ant-color-fill-secondary);
  color: var(--ant-color-text-secondary);
  display: flex;
  height: 100%;
  justify-content: center;
  width: 100%;
}
.asset-meta { align-items: center; display: flex; gap: 8px; justify-content: space-between; margin: 16px 0 12px; }
.asset-prompt {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin-top: 12px;
  padding: 8px;
  border-radius: 6px;
  background: var(--ant-color-fill-quaternary);
}
.asset-prompt-text {
  display: -webkit-box;
  overflow: hidden;
  color: var(--ant-color-text-secondary);
  font-size: 12px;
  line-height: 18px;
  overflow-wrap: anywhere;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
}
.asset-actions { border-top: 1px solid var(--ant-color-border-secondary); margin-top: auto; padding-top: 8px; }
.asset-workspace { display: grid; align-items: start; gap: 18px; grid-template-columns: 220px minmax(0, 1fr); }.batch-sidebar { position: sticky; top: 16px; z-index: 4; display: grid; max-height: calc(100vh - 132px); overflow: auto; padding: 15px; border: 1px solid var(--toon-line); border-radius: 16px; background: color-mix(in srgb, #fafaf8 92%, transparent); box-shadow: 0 8px 24px rgb(15 23 42 / 7%); gap: 8px; }.batch-title,.batch-selection { display: flex; align-items: center; justify-content: space-between; gap: 6px; }.batch-selection { padding: 6px 0 9px; border-bottom: 1px solid var(--toon-line); }.batch-selection span { color: #8c8c8c; font-size: 11px; white-space: nowrap; }.batch-progress { padding: 7px 9px; border-radius: 7px; color: var(--ant-color-primary); background: var(--ant-color-primary-bg); font-size: 12px; text-align: center; }.batch-sidebar label { margin-top: 7px; color: #8c8c8c; font-size: 11px; }.asset-content { min-width: 0; }.asset-cover { position: relative; }.asset-selector { position: absolute; z-index: 3; top: 12px; left: 12px; padding: 5px; border-radius: 7px; background: rgb(255 255 255 / 90%); }.asset-progress { position: absolute; z-index: 2; inset: 0; display: grid; align-content: center; justify-items: center; gap: 8px; color: #fff; background: rgb(0 0 0 / 58%); }.asset-progress span { width: 26px; height: 26px; border: 2px solid rgb(255 255 255 / 35%); border-top-color: #fff; border-radius: 50%; animation: asset-spin .8s linear infinite; }@keyframes asset-spin{to{transform:rotate(360deg)}}
@media (max-width: 640px) {
  .asset-header { align-items: stretch; flex-direction: column; }
  .asset-header > .ant-space { width: 100%; }
  .asset-header .ant-select { width: 100% !important; }
  .asset-toolbar { align-items: stretch; flex-direction: column; gap: 8px; }
  .asset-workspace { grid-template-columns: 1fr; }.batch-sidebar { position: static; }
}
</style>

<script lang="ts" setup>
import type { AssetCategory } from './asset-types';

import type { ToonflowApi } from '#/api/toonflow';

import { computed, onActivated, onBeforeUnmount, onDeactivated, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';

import {
  Alert,
  Button,
  Card,
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
  theme,
  Typography,
} from 'ant-design-vue';

import {
  batchBindAudio,
  deleteAssets,
  generateAssetDubbing,
  getAssetLibrary,
  getProject,
  getProjects,
  saveAsset,
  uploadMaterial,
} from '#/api/toonflow';

import {
  ASSET_CATEGORY_OPTIONS,
  assetFileUrl,
  assetTypeLabel,
  isAssetInCategory,
} from './asset-types';

import { useAssetGeneration } from './useAssetGeneration';

import '../shared/page-card.css';
import '../styles/toon-theme.css';

const route = useRoute();
const router = useRouter();
const { token } = theme.useToken();
const pageColors = computed(() => ({
  '--toon-ink': token.value.colorText,
  '--toon-muted': token.value.colorTextSecondary,
  '--toon-line': token.value.colorBorderSecondary,
  '--toon-panel': token.value.colorBgContainer,
  '--asset-fill': token.value.colorFillSecondary,
  '--asset-fill-subtle': token.value.colorFillQuaternary,
  '--asset-primary': token.value.colorPrimary,
  '--asset-primary-bg': token.value.colorPrimaryBg,
  '--asset-shadow': token.value.boxShadowTertiary,
}));
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
const activeCategory = ref<AssetCategory>('role');
const assetSearch = ref('');
const assetStatus = ref('all');
const deleting = ref(false);
const selectedAssetIds = reactive(new Set<number>());
const batchResolution = ref('2K');
const generation = useAssetGeneration(selectedProjectId, project, assets, (id) => failedImageIds.delete(id));
const { generationFailedIds, generatingAssetIds, polishingAssetIds, batchRunning, batchProgress,
  batchProjectName, submitting, cancelling, statusError, cancelBatchImages } = generation;
const loadError = ref('');
let loadVersion = 0;
let pageActive = true;

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
    if (assetStatus.value === 'missing' && imagePath(asset)) return false;
    if (assetStatus.value === 'ready' && !imagePath(asset)) return false;
    if (assetStatus.value === 'failed' && !generationFailedIds.value.has(asset.id)) return false;
    if (assetStatus.value === 'running' && !generatingAssetIds.value.has(asset.id)) return false;
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
const failedSelectedAssets = computed(() => selectedAssets.value.filter((asset) => generationFailedIds.value.has(asset.id)));
const selectedVisibleCount = computed(() => filteredAssets.value.filter((asset) => selectedAssetIds.has(asset.id)).length);
const allVisibleSelected = computed(() => filteredAssets.value.length > 0 && selectedVisibleCount.value === filteredAssets.value.length);
const someVisibleSelected = computed(() => selectedVisibleCount.value > 0 && !allVisibleSelected.value);
function imagePath(asset: ToonflowApi.LibraryAsset) {
  return asset.imageFilePath || asset.imageUrl || (asset as ToonflowApi.Asset & { filePath?: string }).filePath || '';
}
function previewKind(asset: ToonflowApi.LibraryAsset) {
  const path = imagePath(asset).split(/[?#]/)[0] ?? '';
  if (/\.(mp4|webm|mov|m4v|ogv)$/i.test(path) || /^data:video\//i.test(path)) return 'video';
  if (/\.(mp3|wav|ogg|m4a|aac|flac)$/i.test(path) || /^data:audio\//i.test(path)) return 'audio';
  return 'image';
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
  const targetProjectId = selectedProjectId.value;
  const version = ++loadVersion;
  if (!targetProjectId || !pageActive) {
    assets.value = [];
    project.value = undefined;
    loading.value = false;
    return;
  }
  loading.value = true;
  try {
    const [nextAssets, nextProject] = await Promise.all([
      getAssetLibrary(targetProjectId), getProject(targetProjectId),
    ]);
    if (!pageActive || version !== loadVersion || selectedProjectId.value !== targetProjectId) return;
    assets.value = nextAssets;
    project.value = nextProject;
    failedImageIds.clear(); // Image display failures are separate from generation failures.
    const ids = new Set(nextAssets.map((asset) => asset.id));
    for (const id of selectedAssetIds) if (!ids.has(id)) selectedAssetIds.delete(id);
    loadError.value = '';
    await generation.refreshStatuses();
  } catch (error) {
    if (pageActive && version === loadVersion) loadError.value = error instanceof Error ? error.message : '资产加载失败，请重试';
  } finally {
    if (version === loadVersion) loading.value = false;
  }
}

async function selectProject(projectId?: number) {
  selectedProjectId.value = projectId;
  const pending = loadAssets();
  await router.replace({ query: projectId ? { projectId } : {} });
  await pending;
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
    type: asset?.type ?? (activeCategory.value === 'material' ? 'role' : activeCategory.value),
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
  const targetProjectId = selectedProjectId.value;
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
  if (!pageActive || targetProjectId !== selectedProjectId.value || !targetProjectId) return;
  await uploadMaterial({
    projectId: targetProjectId,
    base64Data,
    type: 'clip',
    name: file.name,
  });
  message.success('素材上传成功');
  await loadAssets();
}

function polishAsset(asset: ToonflowApi.Asset) {
  return generation.polish([asset]);
}
function generateAssetPicture(asset: ToonflowApi.Asset) {
  return generation.generate([asset], imageQuality.value ?? '2K');
}

function selectVisible(mode: 'all' | 'empty' | 'invert' | 'missing') {
  for (const asset of filteredAssets.value) {
    if (mode === 'invert') selectedAssetIds.has(asset.id) ? selectedAssetIds.delete(asset.id) : selectedAssetIds.add(asset.id);
    else if (mode === 'all' || (mode === 'empty' && !asset.prompt?.trim()) || (mode === 'missing' && !imagePath(asset))) selectedAssetIds.add(asset.id);
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

function batchPolish() {
  return generation.polish([...selectedAssets.value], true);
}
function batchGenerateImages() {
  return generation.generate([...selectedAssets.value], batchResolution.value);
}
function retryFailedImages() {
  return generation.generate([...failedSelectedAssets.value], batchResolution.value, true);
}

async function matchAssetVoice(asset: ToonflowApi.Asset) {
  if (!selectedProjectId.value) return;
  await batchBindAudio(selectedProjectId.value, [asset.id]);
  message.success('已匹配项目中的音色资产');
  await loadAssets();
}

function removeAsset(asset: ToonflowApi.Asset) {
  removeAssets([asset]);
}

function removeAssets(items: ToonflowApi.Asset[]) {
  if (!items.length || deleting.value || loading.value) return;
  const ids = items.map((item) => item.id);
  const targetProjectId = selectedProjectId.value;
  const isBusy = () => ids.some((id) => generatingAssetIds.value.has(id) || polishingAssetIds.has(id));
  if (isBusy()) {
    message.warning('所选资产中有正在执行的任务，请先取消任务或取消勾选这些资产');
    return;
  }
  Modal.confirm({
    title: items.length === 1 ? `确认删除“${items[0]!.name}”？` : `确认删除所选 ${items.length} 项资产？`,
    content: `${items.slice(0, 5).map((item) => item.name).join('、')}${items.length > 5 ? '等' : ''}。关联的图片、剧本绑定和人物形态也会一并删除，且无法恢复。`,
    okText: '删除',
    okType: 'danger',
    cancelText: '取消',
    async onOk() {
      if (targetProjectId !== selectedProjectId.value || !pageActive || isBusy()) {
        message.warning('项目或任务状态已变化，请重新选择需要删除的资产');
        return;
      }
      deleting.value = true;
      try {
        await deleteAssets(ids);
        if (targetProjectId === selectedProjectId.value) {
          for (const id of ids) {
            failedImageIds.delete(id);
            selectedAssetIds.delete(id);
          }
          await loadAssets();
        }
        message.success(`已删除 ${ids.length} 项资产`);
      } finally {
        deleting.value = false;
      }
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
  if (!pageActive) return;
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
watch(selectedProjectId, () => {
  loadVersion += 1;
  assets.value = [];
  project.value = undefined;
  selectedAssetIds.clear();
  failedImageIds.clear();
  assetModalOpen.value = false;
  dubbingModalOpen.value = false;
  loadError.value = '';
}, { flush: 'sync' });
watch([activeCategory, assetSearch, assetStatus], clearSelection);
onActivated(() => {
  const wasInactive = !pageActive;
  pageActive = true;
  generation.start();
  if (wasInactive) void loadAssets();
});
function suspend() {
  pageActive = false;
  loadVersion += 1;
  generation.stop();
}
onDeactivated(suspend);
onBeforeUnmount(suspend);
</script>

<template>
  <Page auto-content-height class="toon-page" :style="pageColors">
    <div class="toonflow-page-shell">
      <div class="toon-header asset-header">
        <div class="asset-heading"><div class="asset-heading-title"><h1 class="toon-title">资产库</h1><Tag :bordered="false">{{ assets.length }} 项项目资产</Tag></div><p class="toon-subtitle">按项目管理角色、场景、道具和服装资产。</p></div>
        <Space wrap>
          <Select
            :options="projectOptions"
            :value="selectedProjectId"
            :disabled="submitting || deleting"
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
          <Button :loading="loading" :disabled="!selectedProjectId" @click="loadAssets">刷新资产</Button>
          <Button :disabled="!project || loading" @click="materialInput?.click()">上传素材</Button>
          <Button :disabled="!project || loading" type="primary" @click="openAsset()">新增资产</Button>
        </Space>
      </div>

      <Typography.Paragraph class="asset-library-tip" type="secondary">
        资产按项目隔离；选择项目后，只显示并使用该项目创建的资产。
      </Typography.Paragraph>

      <Alert v-if="loadError" type="error" show-icon :message="loadError" class="mb-3" />
      <Alert v-if="statusError" type="warning" show-icon :message="`生成状态同步失败：${statusError}`" class="mb-3">
        <template #action><Button size="small" @click="generation.refreshStatuses">重新同步</Button></template>
      </Alert>
      <Alert v-if="generatingAssetIds.size" type="info" show-icon message="生成任务会在所属项目后台继续执行，切回项目后自动同步进度。" class="mb-3" />
      <Empty v-if="!selectedProjectId" description="请先选择项目" />
      <template v-else>
        <div class="asset-workspace">
          <main class="asset-content">
        <div class="asset-controls">
          <div class="asset-browse-row">
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
            <div class="asset-filters">
              <Input.Search
                v-model:value="assetSearch"
                allow-clear
                placeholder="搜索名称或描述"
              />
              <Select v-model:value="assetStatus" aria-label="筛选资产状态" :options="[
                { label: '全部状态', value: 'all' },
                { label: '已有图片 / 素材', value: 'ready' },
                { label: '缺少图片 / 素材', value: 'missing' },
                { label: '生成失败 / 已取消', value: 'failed' },
                { label: '正在生成', value: 'running' },
              ]" />
            </div>
          </div>
          <div class="asset-action-row">
            <div class="asset-selection-actions">
              <Checkbox :disabled="loading || deleting || !filteredAssets.length" :checked="allVisibleSelected" :indeterminate="someVisibleSelected" @change="toggleVisible($event.target.checked)">全选</Checkbox>
              <span class="asset-result-count">{{ filteredAssets.length }} 项</span>
              <span class="selection-count">已选 {{ selectedAssets.length }} 项</span>
              <Button size="small" :disabled="loading || deleting || !filteredAssets.length" @click="selectVisible('invert')">反选</Button>
              <Button size="small" :disabled="loading || deleting || !filteredAssets.length" @click="selectVisible('missing')">选择缺图</Button>
              <Button v-if="selectedAssets.length" size="small" type="link" :disabled="deleting" @click="clearSelection">取消选择</Button>
            </div>
            <div class="asset-batch-actions">
              <template v-if="activeCategory !== 'material'">
                <span class="production-label">批量生成</span>
                <Select v-model:value="batchResolution" aria-label="图片分辨率" :options="['1K','2K','4K'].map(value=>({label:value,value}))" />
                <Button :loading="batchRunning==='prompt'" :disabled="loading || deleting || !!batchRunning || !selectedAssets.length" @click="batchPolish">提示词</Button>
                <Button type="primary" :loading="batchRunning==='image'" :disabled="loading || deleting || !!batchRunning || !selectedAssets.length" @click="batchGenerateImages">生成图片</Button>
                <Button v-if="failedSelectedAssets.length" :disabled="loading || deleting || !!batchRunning" @click="retryFailedImages">重试失败（{{ failedSelectedAssets.length }}）</Button>
              </template>
              <Button danger :loading="deleting" :disabled="loading || !selectedAssets.length" @click="removeAssets([...selectedAssets])">批量删除<span v-if="selectedAssets.length">（{{ selectedAssets.length }}）</span></Button>
            </div>
          </div>
          <div v-if="batchRunning" class="batch-progress">
            <span>{{ batchProjectName }} · {{ batchRunning === 'image' ? '图片生成' : '提示词生成' }} {{ batchProgress.current }}/{{ batchProgress.total }}</span>
            <Button v-if="batchRunning === 'image'" size="small" danger :disabled="submitting" :loading="cancelling" @click="cancelBatchImages">取消图片任务</Button>
          </div>
        </div>
        <div v-if="loading" class="asset-loading">资产加载中…</div>
        <Empty
          v-else-if="filteredAssets.length === 0"
          :description="assetSearch ? '没有匹配的资产' : '暂无该类资产'"
        />
        <Row v-else :gutter="[16, 16]" class="asset-special-grid">
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
            <Card class="asset-card" :class="[`asset-card--${activeCategory}`, { 'asset-card--selected': selectedAssetIds.has(item.id) }]" hoverable>
              <template #cover>
                <div class="asset-cover">
                  <Checkbox
                    class="asset-selector"
                    :aria-label="`选择${item.name}`"
                    :checked="selectedAssetIds.has(item.id)"
                    :disabled="deleting"
                    @click.stop
                    @change="toggleAsset(item.id, $event.target.checked)"
                  />
                  <span class="asset-type-badge">{{ assetTypeLabel(item.type) }}</span>
                  <div v-if="generatingAssetIds.has(item.id)" class="asset-progress"><span />生成中</div>
                  <video v-if="activeCategory === 'material' && previewKind(item) === 'video'" class="asset-media-player" :src="assetFileUrl(imagePath(item))" controls playsinline preload="metadata" :aria-label="item.name" />
                  <div v-else-if="activeCategory === 'material' && previewKind(item) === 'audio'" class="asset-audio-preview"><span>音频素材</span><audio :src="assetFileUrl(imagePath(item))" controls preload="none" :aria-label="item.name" /></div>
                  <Image
                    v-else-if="imagePath(item) && !failedImageIds.has(item.id)"
                    :alt="item.name"
                    :src="assetFileUrl(imagePath(item))"
                    :preview="true"
                    class="asset-thumb"
                    @error="failedImageIds.add(item.id)"
                  />
                  <div v-else class="asset-placeholder"><span>{{ assetTypeLabel(item.type) }}</span><small>{{ failedImageIds.has(item.id) ? '预览加载失败' : '暂无预览' }}</small></div>
                </div>
              </template>
                <div class="asset-card-heading"><h3 :title="item.name">{{ item.name }}</h3><span>{{ imagePath(item) ? '已有预览' : '待完善' }}</span></div>
                <Typography.Paragraph class="asset-description" :ellipsis="{ rows: 2, expandable: true, symbol: '展开' }" :content="item.description || '暂无描述，编辑补充资产特征。'" />
              <details v-if="item.prompt" class="asset-prompt-details"><summary>查看 AI 提示词</summary><p>{{ item.prompt }}</p></details>
              <Tag v-if="generationFailedIds.has(item.id)" color="error" class="mt-3" :title="item.imageErrorReason">{{ item.imageState === '已取消' ? '已取消' : '生成失败' }}{{ item.imageErrorReason ? `：${item.imageErrorReason}` : '' }}</Tag>
              <Tag v-else-if="failedImageIds.has(item.id)" color="warning" class="mt-3">图片加载失败，可刷新重试</Tag>
              <div class="asset-actions">
                <Space wrap :size="4">
                  <Button type="link" :disabled="deleting" @click="openAsset(item)">编辑</Button>
                  <Button
                    v-if="['role', 'scene', 'tool', 'costume'].includes(item.type)"
                    :loading="polishingAssetIds.has(item.id)"
                    :disabled="deleting || !!batchRunning || loading"
                    type="link"
                    @click="polishAsset(item)"
                  >
                    {{ polishingAssetIds.has(item.id) ? '润色中' : 'AI 润色' }}
                  </Button>
                  <Button
                    v-if="['role', 'scene', 'tool', 'costume'].includes(item.type)"
                    :loading="generatingAssetIds.has(item.id)"
                    :disabled="deleting || !!batchRunning || polishingAssetIds.has(item.id) || loading"
                    type="primary"
                    class="asset-generate-button"
                    @click="generateAssetPicture(item)"
                  >
                    {{ generatingAssetIds.has(item.id) ? '生成中' : imagePath(item) ? '重新生成' : '生成图片' }}
                  </Button>
                  <Button danger :disabled="deleting || loading || generatingAssetIds.has(item.id) || polishingAssetIds.has(item.id)" @click="removeAsset(item)">删除</Button>
                </Space>
                <div v-if="item.type === 'role'" class="asset-voice-actions"><span>角色声音</span><Button size="small" @click="matchAssetVoice(item)">匹配音色</Button><Button size="small" @click="openDubbing(item)">生成配音</Button></div>
              </div>
            </Card>
          </Col>
        </Row>
          </main>
        </div>
      </template>
    </div>

    <Modal root-class-name="toon-overlay" v-model:open="assetModalOpen" title="资产" width="760px" @ok="saveAssetForm">
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

    <Modal root-class-name="toon-overlay"
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
.asset-heading-title .ant-tag { margin: 0; border-radius: 999px; }
.asset-heading-title .ant-tag,
.asset-prompt-tag { color: var(--asset-primary); background: var(--asset-primary-bg); }
.asset-library-tip { margin-bottom: 16px; }
.category-count { margin-inline-end: 0; }
.asset-loading { color: var(--toon-muted); padding: 64px; text-align: center; }
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
  background: var(--asset-fill);
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
  display: block;
  height: 100%;
  object-fit: contain;
  object-position: center;
  width: 100%;
}
.asset-placeholder {
  align-items: center;
  color: var(--toon-muted);
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
  background: var(--asset-fill-subtle);
}
.asset-prompt-text {
  display: -webkit-box;
  overflow: hidden;
  color: var(--toon-muted);
  font-size: 12px;
  line-height: 18px;
  overflow-wrap: anywhere;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
}
.asset-actions { border-top: 1px solid var(--toon-line); margin-top: auto; padding-top: 8px; }
.asset-content { min-width: 0; }.asset-cover { position: relative; }.asset-selector { position: absolute; z-index: 3; top: 12px; left: 12px; padding: 5px; border-radius: 7px; background: var(--toon-panel); }.asset-progress { position: absolute; z-index: 2; inset: 0; display: grid; align-content: center; justify-items: center; gap: 8px; color: #fff; background: rgb(0 0 0 / 58%); }.asset-progress span { width: 26px; height: 26px; border: 2px solid rgb(255 255 255 / 35%); border-top-color: #fff; border-radius: 50%; animation: asset-spin .8s linear infinite; }@keyframes asset-spin{to{transform:rotate(360deg)}}
@media (max-width: 640px) {
  .asset-header { align-items: stretch; flex-direction: column; }
  .asset-header > .ant-space { width: 100%; }
  .asset-header .ant-select { width: 100% !important; }
}

/* Keep selection and destructive actions visible while browsing the grid. */
.asset-workspace { display: block; }
.asset-controls { position: sticky; top: 0; z-index: 5; margin-bottom: 20px; padding: 0 16px 12px; border: 1px solid var(--toon-line); border-radius: 12px; background: var(--toon-panel); box-shadow: var(--asset-shadow); }
.asset-browse-row { display: flex; min-width: 0; align-items: flex-end; gap: 20px; }
.asset-category-tabs { min-width: 0; flex: 1; margin-bottom: 0; }
.asset-category-tabs :deep(.ant-tabs-nav) { margin-bottom: 0; }
.asset-filters { display: grid; width: min(440px, 42%); flex: none; grid-template-columns: minmax(180px, 1fr) 150px; gap: 8px; padding-bottom: 12px; }
.asset-action-row { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px 16px; padding-top: 10px; border-top: 1px solid var(--toon-line); }
.asset-selection-actions, .asset-batch-actions { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
.asset-result-count { color: var(--toon-muted); font-size: 12px; white-space: nowrap; }
.selection-count { color: var(--asset-primary); font-weight: 600; white-space: nowrap; }
.production-label { color: var(--toon-muted); font-size: 12px; }
.asset-batch-actions .ant-select { width: 78px; }
.batch-progress { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px; margin-top: 12px; padding: 8px 10px; border-radius: 6px; color: var(--asset-primary); background: var(--asset-primary-bg); font-size: 12px; }
@media (max-width: 1100px) {
  .asset-browse-row { align-items: stretch; flex-direction: column; gap: 8px; }
  .asset-filters { width: 100%; padding-bottom: 10px; }
}
@media (max-width: 640px) {
  .asset-controls { position: static; padding-inline: 12px; }
  .asset-filters { grid-template-columns: 1fr; }
  .asset-action-row { align-items: stretch; flex-direction: column; }
  .asset-batch-actions { padding-top: 10px; border-top: 1px dashed var(--toon-line); }
}

/* Cards adapt to the available workspace width. */
.asset-special-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 270px), 1fr)); row-gap: 16px; }
.asset-special-grid > .asset-card-column { max-width: none; width: 100%; padding-bottom: 0 !important; }
.asset-special-grid .asset-card { border-radius: 12px; border: 1px solid var(--toon-line); box-shadow: none; transition: border-color .2s, box-shadow .2s; }
.asset-special-grid .asset-card:hover { border-color: var(--asset-primary); box-shadow: var(--asset-shadow); }
.asset-special-grid .asset-card--selected { border-color: var(--asset-primary); box-shadow: 0 0 0 1px var(--asset-primary); }
.asset-special-grid .asset-cover { height: auto; aspect-ratio: 4 / 3; padding: 16px; border-bottom: 1px solid var(--toon-line); background: var(--asset-fill-subtle); }
.asset-special-grid .asset-card--scene .asset-cover { aspect-ratio: 16 / 9; padding: 0; }
.asset-special-grid .asset-card--costume .asset-cover { aspect-ratio: 1; }
.asset-special-grid .asset-card--role .asset-cover { aspect-ratio: 4 / 3; padding: 12px; }
.asset-special-grid .asset-card :deep(.ant-card-body) { min-width: 0; padding: 16px; gap: 12px; }
.asset-type-badge { position: absolute; z-index: 1; top: 12px; right: 12px; padding: 3px 9px; border: 1px solid var(--toon-line); border-radius: 6px; background: var(--toon-panel); color: var(--toon-muted); font-size: 11px; }
.asset-special-grid .asset-placeholder { flex-direction: column; gap: 8px; font-size: 18px; }
.asset-placeholder small { font-size: 12px; color: var(--toon-muted); }
.asset-media-player { width: 100%; height: 100%; object-fit: contain; }
.asset-audio-preview { display: flex; height: 100%; flex-direction: column; justify-content: center; gap: 20px; color: var(--toon-muted); text-align: center; }
.asset-audio-preview audio { width: 100%; min-width: 0; }
.asset-card-heading { display: flex; align-items: start; gap: 8px; justify-content: space-between; }
.asset-card-heading h3 { min-width: 0; margin: 0; overflow: hidden; font-size: 15px; font-weight: 600; line-height: 22px; text-overflow: ellipsis; white-space: nowrap; }
.asset-card-heading > span { flex-shrink: 0; color: var(--toon-muted); font-size: 11px; line-height: 22px; }
.asset-description { margin: 0 !important; min-height: 40px; color: var(--toon-muted); font-size: 12px; line-height: 20px; overflow-wrap: anywhere; }
.asset-prompt-details { padding: 8px 10px; border-radius: 6px; background: var(--asset-fill-subtle); font-size: 12px; color: var(--toon-muted); }
.asset-prompt-details summary { cursor: pointer; color: var(--asset-primary); }
.asset-prompt-details p { margin: 8px 0 0; max-height: 180px; overflow: auto; white-space: pre-wrap; overflow-wrap: anywhere; }
.asset-special-grid .asset-card :deep(.ant-tag) { max-width: 100%; white-space: normal; overflow-wrap: anywhere; }
.asset-special-grid .asset-actions { padding-top: 12px; }
.asset-special-grid .asset-actions :deep(.ant-space) { display: flex; justify-content: space-between; gap: 6px !important; }
.asset-special-grid .asset-actions :deep(.ant-btn-link) { padding-inline: 2px; font-size: 12px; }
.asset-special-grid .asset-generate-button { height: 30px; padding-inline: 10px; font-size: 12px; }
.asset-voice-actions { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; border-top: 1px dashed var(--toon-line); padding-top: 12px; margin-top: 12px; }
.asset-voice-actions > span { margin-right: auto; color: var(--toon-muted); font-size: 11px; }
@media (prefers-reduced-motion: reduce) { .asset-special-grid .asset-card { transition: none; } }
</style>

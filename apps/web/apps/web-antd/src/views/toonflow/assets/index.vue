<script lang="ts" setup>
import type { AssetCategory } from './asset-types';

import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';

import {
  Button,
  Card,
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
  generateAssetDubbing,
  generateAssetImage,
  getAssetLibrary,
  getProject,
  getProjects,
  linkProjectAsset,
  polishAssetPrompt,
  saveAsset,
  unlinkProjectAsset,
  uploadMaterial,
} from '#/api/toonflow';

import {
  ASSET_CATEGORY_OPTIONS,
  assetFileUrl,
  assetTypeLabel,
  isAssetInCategory,
} from './asset-types';

import '../shared/page-card.css';

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
    return [asset.name, asset.description, asset.prompt, asset.sourceProjectName]
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
    await generateAssetImage({
      projectId: selectedProjectId.value,
      model: String(project.value.imageModel),
      resolution: imageQuality.value,
      id: asset.id,
      type: asset.type,
      name: asset.name,
      prompt: visualPrompt,
    });
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

async function matchAssetVoice(asset: ToonflowApi.Asset) {
  if (!selectedProjectId.value) return;
  await batchBindAudio(selectedProjectId.value, [asset.id]);
  message.success('已匹配项目中的音色资产');
  await loadAssets();
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

async function toggleProjectLink(asset: ToonflowApi.LibraryAsset) {
  if (!selectedProjectId.value) return;
  if (asset.linkedToProject) {
    await unlinkProjectAsset(selectedProjectId.value, asset.id);
    message.success('已取消引用');
  } else {
    await linkProjectAsset(selectedProjectId.value, asset.id);
    message.success('资产已引用到当前项目');
  }
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
  <Page auto-content-height>
    <Card
      :bordered="false"
      class="toonflow-page-card h-full"
    >
      <template #title>
        <Space>
          <Typography.Text strong>资产库</Typography.Text>
          <Tag>{{ assets.length }} 项公共资产</Tag>
        </Space>
      </template>
      <template #extra>
        <Space>
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
      </template>

      <Typography.Paragraph class="asset-library-tip" type="secondary">
        所有项目共享同一资产库。选择项目后可引用已有资产；剧本与分镜只使用当前项目已引用的资产。
      </Typography.Paragraph>

      <Empty v-if="!selectedProjectId" description="请先选择项目" />
      <template v-else>
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
            placeholder="搜索名称、描述或来源项目"
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
                  <Image
                    v-if="item.imageFilePath && !failedImageIds.has(item.id)"
                    :alt="item.name"
                    :src="assetFileUrl(item.imageFilePath)"
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
                <Typography.Text
                  :content="`来源：${item.sourceProjectName || '当前项目'}`"
                  ellipsis
                  type="secondary"
                />
                <Tag :color="item.linkedToProject ? 'green' : 'default'">
                  {{ item.linkedToProject ? '已引用' : '未引用' }}
                </Tag>
              </div>
              <div class="asset-actions">
                <Space wrap :size="4">
                  <Button
                    v-if="item.projectId !== selectedProjectId"
                    :danger="item.linkedToProject"
                    type="link"
                    @click="toggleProjectLink(item)"
                  >
                    {{ item.linkedToProject ? '取消引用' : '引用到项目' }}
                  </Button>
                  <template v-if="item.projectId === selectedProjectId">
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
                  </template>
                </Space>
              </div>
            </Card>
          </Col>
        </Row>
      </template>
    </Card>

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
@media (max-width: 640px) {
  .asset-toolbar { align-items: stretch; flex-direction: column; gap: 8px; }
}
</style>

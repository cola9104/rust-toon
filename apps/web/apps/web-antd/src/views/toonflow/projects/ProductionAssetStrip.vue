<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, reactive, ref } from 'vue';

import { Empty, Form, Input, message, Modal, Tag } from 'ant-design-vue';

import { executeAgentTool, polishAssetPrompt, saveAsset } from '#/api/toonflow';

import { assetFileUrl, assetTypeLabel } from '../assets/asset-types';

const props = defineProps<{
  assets: ToonflowApi.Asset[];
  script?: ToonflowApi.Script;
}>();

const emit = defineEmits<{
  edit: [asset: ToonflowApi.Asset];
  generate: [asset: ToonflowApi.Asset];
  refresh: [];
}>();

const promptEditorOpen = ref(false);
const promptSaving = ref(false);
const promptAsset = ref<ToonflowApi.Asset>();
const promptText = ref('');
const promptDescription = ref('');
const pendingActionIds = reactive(new Set<number>());
const generatingAssetIds = reactive(new Set<number>());
const promptGeneratingIds = reactive(new Set<number>());

const assetRows = computed(() =>
  props.assets.filter(
    (asset) => !asset.parentAssetId && ['role', 'scene'].includes(asset.type),
  ),
);

const assetCount = computed(() =>
  assetRows.value.reduce(
    (count, asset) =>
      count +
      1 +
      (asset.type === 'role'
        ? (asset.derive?.length ?? 0) + pendingAppearances(asset).length
        : 0),
    0,
  ),
);

function pendingAppearances(asset: ToonflowApi.Asset) {
  const materializedIds = new Set(
    (asset.derive ?? []).map((derived) => derived.appearanceId).filter(Boolean),
  );
  return (asset.appearances ?? []).filter(
    (appearance) =>
      !materializedIds.has(appearance.id) &&
      !(asset.derive ?? []).some(
        (derived) =>
          !derived.appearanceId &&
          derived.name.trim() === appearance.name.trim() &&
          (derived.description || derived.prompt || '').trim() ===
            appearance.costumePrompt.trim(),
      ),
  );
}

function generationLabel(asset: ToonflowApi.Asset) {
  if (asset.imageFilePath) return '图片已就绪';
  if (asset.imageState === '生成中') return '生成中';
  if (asset.imageState === '生成失败') return '生成失败';
  return asset.parentAssetId ? '等待 Agent 生成' : '尚未生成图片';
}

function assetSummary(asset: ToonflowApi.Asset) {
  return asset.description || asset.remark || asset.prompt || generationLabel(asset);
}

function assetProjectId(asset: ToonflowApi.Asset) {
  const projectId = Number(asset.projectId || props.script?.projectId);
  if (!Number.isSafeInteger(projectId) || projectId <= 0) {
    throw new Error('当前制作数据缺少项目 ID，请刷新后重试');
  }
  return projectId;
}

function openPromptEditor(asset: ToonflowApi.Asset) {
  promptAsset.value = asset;
  promptDescription.value = asset.description || '';
  promptText.value = asset.prompt || asset.description || '';
  promptEditorOpen.value = true;
}

async function savePrompt() {
  const asset = promptAsset.value;
  if (!asset) return;
  promptSaving.value = true;
  try {
    await saveAsset({
      id: asset.id,
      projectId: assetProjectId(asset),
      name: asset.name,
      type: asset.type,
      description: promptDescription.value,
      prompt: promptText.value,
      remark: asset.remark,
      scriptId: asset.scriptId,
      parentAssetId: asset.parentAssetId,
      imageId: asset.imageId,
    });
    promptEditorOpen.value = false;
    message.success(`“${asset.name}”的造型描述和生成提示词已保存`);
    emit('refresh');
  } catch (error) {
    message.error(error instanceof Error ? error.message : '造型描述和生成提示词保存失败');
  } finally {
    promptSaving.value = false;
  }
}

async function polishDerivedPrompt(asset: ToonflowApi.Asset) {
  if (promptGeneratingIds.has(asset.id)) return;
  promptGeneratingIds.add(asset.id);
  try {
    const projectId = assetProjectId(asset);
    const result = await polishAssetPrompt({
      assetsId: asset.id,
      projectId,
      type: asset.type,
      name: asset.name,
      describe: asset.description || '',
    });
    asset.prompt = result.prompt;
    message.success(`“${asset.name}”的 AI 提示词已生成`);
    emit('refresh');
  } catch (error) {
    message.error(error instanceof Error ? error.message : 'AI 提示词生成失败');
  } finally {
    promptGeneratingIds.delete(asset.id);
  }
}

async function materializeAppearance(
  asset: ToonflowApi.Asset,
  appearance: NonNullable<ToonflowApi.Asset['appearances']>[number],
) {
  const scriptId = props.script?.id;
  if (!scriptId) throw new Error('请先选择制作剧本');
  const projectId = assetProjectId(asset);
  const created = await executeAgentTool({
    agentType: 'productionAgent',
    projectId,
    scriptId,
    toolName: 'add_deriveAsset',
    arguments: {
      assetsId: asset.id,
      appearanceId: appearance.id,
      name: appearance.name,
      desc: appearance.costumePrompt,
    },
  });
  const id = Number(created.result?.id);
  if (!Number.isSafeInteger(id) || id <= 0) throw new Error('创建衍生资产后未返回有效资产 ID');
  return {
    id,
    name: appearance.name,
    prompt: appearance.costumePrompt,
    description: appearance.costumePrompt,
    type: 'role',
    projectId,
    scriptId,
    parentAssetId: asset.id,
    appearanceId: appearance.id,
  } satisfies ToonflowApi.Asset;
}

async function editPendingAppearance(
  asset: ToonflowApi.Asset,
  appearance: NonNullable<ToonflowApi.Asset['appearances']>[number],
) {
  if (pendingActionIds.has(appearance.id)) return;
  pendingActionIds.add(appearance.id);
  try {
    const derived = await materializeAppearance(asset, appearance);
    emit('refresh');
    openPromptEditor(derived);
  } catch (error) {
    message.error(error instanceof Error ? error.message : '衍生资产创建失败');
  } finally {
    pendingActionIds.delete(appearance.id);
  }
}

async function polishPendingAppearance(
  asset: ToonflowApi.Asset,
  appearance: NonNullable<ToonflowApi.Asset['appearances']>[number],
) {
  if (pendingActionIds.has(appearance.id)) return;
  pendingActionIds.add(appearance.id);
  try {
    const derived = await materializeAppearance(asset, appearance);
    await polishDerivedPrompt(derived);
    emit('refresh');
  } catch (error) {
    message.error(error instanceof Error ? error.message : 'AI 提示词生成失败');
    emit('refresh');
  } finally {
    pendingActionIds.delete(appearance.id);
  }
}

function isAssetGenerating(asset: ToonflowApi.Asset) {
  return asset.imageState === '生成中' || generatingAssetIds.has(asset.id);
}

async function generateDerivedAsset(asset: ToonflowApi.Asset) {
  if (isAssetGenerating(asset)) return;
  generatingAssetIds.add(asset.id);
  try {
    await executeAgentTool({
      agentType: 'productionAgent',
      projectId: assetProjectId(asset),
      scriptId: asset.scriptId || props.script?.id,
      toolName: 'generate_deriveAsset',
      arguments: { ids: [asset.id], concurrentCount: 1 },
    });
    message.success(`“${asset.name}”衍生资产生成完成`);
  } catch (error) {
    message.error(error instanceof Error ? error.message : '衍生资产生成失败');
  } finally {
    generatingAssetIds.delete(asset.id);
    emit('refresh');
  }
}

async function generatePendingAppearance(
  asset: ToonflowApi.Asset,
  appearance: NonNullable<ToonflowApi.Asset['appearances']>[number],
) {
  if (!asset.imageFilePath) return message.warning(`请先生成“${asset.name}”的基础角色图片`);
  if (pendingActionIds.has(appearance.id)) return;
  pendingActionIds.add(appearance.id);
  try {
    const derived = await materializeAppearance(asset, appearance);
    await generateDerivedAsset(derived);
  } catch (error) {
    message.error(error instanceof Error ? error.message : '衍生资产生成失败');
  } finally {
    pendingActionIds.delete(appearance.id);
  }
}
</script>

<template>
  <section class="production-assets nopan" @click.stop>
    <header class="production-assets-heading">
      <div>
        <div class="production-assets-title">当前剧本制作资产</div>
        <div class="production-assets-subtitle">原资产与待制作衍生图</div>
      </div>
      <Tag>{{ assetCount }} 项</Tag>
    </header>

    <Empty
      v-if="assetRows.length === 0"
      :image="Empty.PRESENTED_IMAGE_SIMPLE"
      description="当前剧本暂未关联人物或场景资产"
    />

    <div v-else class="production-assets-canvas nowheel">
      <div class="production-asset-columns" aria-hidden="true">
        <span>基础资产</span><i>剧情派生</i><span>衍生资产</span>
      </div>
      <div v-for="asset in assetRows" :key="asset.id" class="production-asset-row">
        <article class="production-asset-card origin-card">
          <div class="production-asset-cover">
            <img
              v-if="asset.imageFilePath"
              :alt="asset.name"
              :src="assetFileUrl(asset.imageFilePath)"
              class="production-asset-image"
              decoding="async"
              loading="lazy"
            />
            <div v-else class="production-asset-image-placeholder">
              {{ assetTypeLabel(asset.type) }}
            </div>
            <Tag class="production-asset-kind" color="green">原资产</Tag>
          </div>
          <div class="production-asset-content">
            <div class="production-asset-name" :title="asset.name">{{ asset.name }}</div>
            <div class="production-asset-description" :title="assetSummary(asset)">
              {{ assetSummary(asset) }}
            </div>
          </div>
        </article>

        <div v-if="asset.type === 'role'" class="production-asset-connector" aria-hidden="true">
          <span>派生</span>
        </div>

        <div v-if="asset.type === 'role'" class="production-derived-list">
          <div
            v-for="derived in asset.derive ?? []"
            :key="derived.id"
            class="production-derived-node"
          >
            <article
              class="production-asset-card derived-card"
              :class="{ 'no-image': !derived.imageFilePath }"
            >
              <div class="production-asset-cover">
                <img
                  v-if="derived.imageFilePath"
                  :alt="derived.name"
                  :src="assetFileUrl(derived.imageFilePath)"
                  class="production-asset-image"
                  decoding="async"
                  loading="lazy"
                />
                <div v-else class="production-asset-image-placeholder derived-placeholder">
                  {{ generationLabel(derived) }}
                </div>
                <Tag class="production-asset-kind" color="orange">衍生</Tag>
              </div>
              <div class="production-asset-content">
                <div class="production-asset-name" :title="derived.name">
                  {{ derived.name }}
                </div>
                <div
                  class="production-asset-description"
                  :class="{
                    generating: derived.imageState === '生成中',
                    failed: derived.imageState === '生成失败',
                  }"
                  :title="derived.imageErrorReason || assetSummary(derived)"
                >
                  {{ assetSummary(derived) }}
                </div>
                <button
                  type="button"
                  class="production-asset-prompt"
                  @click="openPromptEditor(derived)"
                >
                  编辑
                </button>
                <button
                  type="button"
                  class="production-asset-prompt"
                  :disabled="promptGeneratingIds.has(derived.id)"
                  @click="polishDerivedPrompt(derived)"
                >
                  {{ promptGeneratingIds.has(derived.id) ? '生成中…' : 'AI 提示词' }}
                </button>
                <button
                  type="button"
                  class="production-asset-generate"
                  :disabled="isAssetGenerating(derived)"
                  @click="generateDerivedAsset(derived)"
                >
                  {{
                    isAssetGenerating(derived)
                      ? '生成中…'
                      : derived.imageFilePath
                        ? '重新生成'
                        : '生成图片'
                  }}
                </button>
                <button
                  type="button"
                  class="production-asset-edit"
                  @click="emit('edit', derived)"
                >
                  图片编辑
                </button>
              </div>
            </article>
          </div>

          <div
            v-for="appearance in pendingAppearances(asset)"
            :key="`appearance-${appearance.id}`"
            class="production-derived-node"
          >
            <article class="production-asset-card derived-card no-image">
              <div class="production-asset-cover">
                <div class="production-asset-image-placeholder derived-placeholder">
                  等待生成衍生人物
                </div>
                <Tag class="production-asset-kind" color="gold">待生成</Tag>
              </div>
              <div class="production-asset-content">
                <div class="production-asset-name" :title="appearance.name">
                  {{ appearance.name }}
                </div>
                <div
                  class="production-asset-description"
                  :title="appearance.costumePrompt"
                >
                  {{ appearance.costumePrompt }}
                </div>
                <div class="production-appearance-scenes">
                  {{ appearance.scenes.join('、') || '当前剧本' }}
                </div>
                <button
                  type="button"
                  class="production-asset-edit"
                  :disabled="pendingActionIds.has(appearance.id)"
                  title="创建衍生资产并编辑造型描述与提示词"
                  @click="editPendingAppearance(asset, appearance)"
                >
                  编辑
                </button>
                <button
                  type="button"
                  class="production-asset-prompt"
                  :disabled="pendingActionIds.has(appearance.id)"
                  title="按视觉手册生成衍生资产提示词"
                  @click="polishPendingAppearance(asset, appearance)"
                >
                  {{ pendingActionIds.has(appearance.id) ? '处理中…' : 'AI 提示词' }}
                </button>
                <button
                  type="button"
                  class="production-asset-generate"
                  :disabled="pendingActionIds.has(appearance.id) || !asset.imageFilePath"
                  :title="asset.imageFilePath ? '使用基础角色图生成衍生图片' : '请先生成基础角色图片'"
                  @click="generatePendingAppearance(asset, appearance)"
                >
                  {{ pendingActionIds.has(appearance.id) ? '处理中…' : '生成图片' }}
                </button>
              </div>
            </article>
          </div>

          <div
            v-if="!asset.derive?.length && !pendingAppearances(asset).length"
            class="production-derived-node"
          >
            <div class="production-no-derived">
              <span class="production-no-derived-icon">＋</span>
              <span>无衍生资产</span>
              <small>可由 Agent 根据分镜创建</small>
            </div>
          </div>
        </div>
      </div>
    </div>

    <Modal
      v-model:open="promptEditorOpen"
      root-class-name="toon-overlay"
      :title="`${promptAsset?.name ?? '衍生资产'} · 编辑造型`"
      width="760px"
      :confirm-loading="promptSaving"
      @ok="savePrompt"
    >
      <Form layout="vertical">
        <Form.Item label="造型描述">
          <Input.TextArea
            v-model:value="promptDescription"
            :rows="5"
            placeholder="描述服装、妆容、发型和稳定形态变化"
          />
        </Form.Item>
        <Form.Item label="生成提示词">
          <Input.TextArea
            v-model:value="promptText"
            :rows="10"
            placeholder="输入用于衍生资产生图的提示词"
          />
          <div class="production-prompt-help">
            保存后，生成图片或重新生成时会使用这里的提示词。
          </div>
        </Form.Item>
      </Form>
    </Modal>
  </section>
</template>

<style scoped>
.production-assets {
  --production-link-color: var(--ant-color-primary);

  overflow: hidden;
  background: var(--ant-color-bg-container);
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 10px;
}

.production-assets-heading {
  display: flex;
  align-items: stretch;
  justify-content: space-between;
  padding: 12px 14px;
  border-bottom: 1px solid var(--ant-color-border-secondary);
}

.production-assets-title {
  font-weight: 600;
}

.production-assets-subtitle {
  margin-top: 2px;
  font-size: 12px;
  color: var(--ant-color-text-tertiary);
}

.production-assets-canvas {
  max-height: 470px;
  padding: 18px;
  overflow: auto;
  background-color: var(--ant-color-fill-quaternary);
  background-image: radial-gradient(var(--ant-color-border) 0.8px, transparent 0.8px);
  background-size: 16px 16px;
}

.production-asset-columns {
  position: sticky;
  top: -18px;
  z-index: 3;
  display: grid;
  grid-template-columns: 150px 84px minmax(150px, 1fr);
  align-items: center;
  min-width: 440px;
  padding: 9px 18px;
  margin: -18px -18px 8px;
  font-size: 11px;
  font-weight: 600;
  color: var(--ant-color-text-secondary);
  background: color-mix(in srgb, var(--ant-color-bg-container) 94%, transparent);
  border-bottom: 1px solid var(--ant-color-border-secondary);
  backdrop-filter: blur(8px);
}

.production-asset-columns i { font-size: 10px; font-style: normal; color: var(--ant-color-warning); text-align: center; }

.production-asset-columns span:last-child { color: var(--ant-color-warning-text); }

.production-asset-row {
  display: flex;
  align-items: center;
  width: 100%;
  min-width: 100%;
  padding: 10px 0;
}

.production-asset-row + .production-asset-row {
  border-top: 1px dashed var(--ant-color-border-secondary);
}

.production-asset-card {
  flex: 0 0 150px;
  width: 150px;
  overflow: hidden;
  background: var(--ant-color-bg-container);
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 8px;
  box-shadow: 0 2px 8px rgb(0 0 0 / 6%);
}

.origin-card {
  align-self: center;
  border-color: color-mix(in srgb, var(--ant-color-success) 45%, transparent);
}

.derived-card {
  border-color: color-mix(in srgb, var(--ant-color-warning) 45%, transparent);
  box-shadow: 0 4px 14px color-mix(in srgb, var(--ant-color-warning) 15%, transparent);
}

.derived-card.no-image {
  border: 2px dashed var(--ant-color-warning);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--ant-color-warning) 10%, transparent);
}

.production-asset-cover {
  position: relative;
  height: 126px;
  overflow: hidden;
  background: var(--ant-color-fill-quaternary);
}

.production-asset-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.production-asset-image-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 12px;
  font-size: 12px;
  color: var(--ant-color-text-tertiary);
  text-align: center;
}

.derived-placeholder {
  height: calc(100% - 16px);
  margin: 8px;
  background: color-mix(in srgb, var(--ant-color-warning) 6%, var(--ant-color-bg-container));
  border: 1px dashed color-mix(in srgb, var(--ant-color-warning) 55%, transparent);
  border-radius: 6px;
}

.production-asset-kind {
  position: absolute;
  top: 7px;
  left: 7px;
  margin: 0;
}

.production-asset-content {
  padding: 9px 10px 10px;
}

.production-asset-name {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
}

.production-asset-description {
  display: -webkit-box;
  height: 34px;
  margin-top: 4px;
  overflow: hidden;
  -webkit-line-clamp: 2;
  font-size: 12px;
  line-height: 17px;
  color: var(--ant-color-text-tertiary);
  -webkit-box-orient: vertical;
}

.production-asset-description.generating {
  color: var(--ant-color-primary);
}

.production-asset-description.failed {
  color: var(--ant-color-error);
}

.production-appearance-scenes {
  margin-top: 7px;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 11px;
  color: var(--ant-color-warning-text);
  white-space: nowrap;
}

.production-asset-edit,.production-asset-generate,.production-asset-prompt {
  width: 100%;
  padding: 3px 6px;
  margin-top: 7px;
  font-size: 12px;
  color: var(--ant-color-primary);
  cursor: pointer;
  background: var(--ant-color-bg-container);
  border: 1px solid var(--ant-color-border);
  border-radius: 5px;
}

.production-asset-edit:hover,.production-asset-generate:hover,.production-asset-prompt:hover {
  border-color: var(--ant-color-primary);
}

.production-asset-generate { color: var(--ant-color-warning-text); }
.production-asset-edit:disabled,.production-asset-generate:disabled,.production-asset-prompt:disabled { cursor: not-allowed; opacity: .5; }

.production-prompt-help {
  margin-top: 8px;
  font-size: 12px;
  color: var(--ant-color-text-tertiary);
}

.production-asset-connector {
  position: relative;
  flex: 0 0 58px;
  width: 58px;
  min-height: 220px;
}

.production-asset-connector::before {
  position: absolute;
  top: 50%;
  right: 0;
  left: 0;
  height: 2px;
  content: '';
  background: var(--production-link-color);
  border-radius: 2px;
}

.production-asset-connector::after {
  position: absolute;
  top: calc(50% - 4px);
  right: 1px;
  width: 8px;
  height: 8px;
  content: '';
  border-top: 2px solid var(--production-link-color);
  border-right: 2px solid var(--production-link-color);
  transform: rotate(45deg);
}

.production-asset-connector > span {
  position: absolute;
  top: 50%;
  left: 50%;
  z-index: 1;
  padding: 1px 5px;
  font-size: 10px;
  line-height: 16px;
  color: var(--production-link-color);
  white-space: nowrap;
  background: var(--ant-color-bg-container, #fff);
  border: 1px solid color-mix(in srgb, var(--production-link-color) 35%, transparent);
  border-radius: 10px;
  transform: translate(-50%, -50%);
}

.production-derived-list {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-width: 214px;
  padding-left: 34px;
}

.production-derived-list::before {
  position: absolute;
  top: 116px;
  bottom: 116px;
  left: 0;
  width: 2px;
  content: '';
  background: var(--production-link-color);
  border-radius: 2px;
}

.production-derived-node {
  position: relative;
  display: flex;
  align-items: center;
  min-height: 220px;
}

.production-derived-node::before {
  position: absolute;
  top: 50%;
  left: -34px;
  width: 34px;
  height: 2px;
  content: '';
  background: var(--production-link-color);
  border-radius: 2px;
}

.production-derived-node::after {
  position: absolute;
  top: calc(50% - 3px);
  left: -6px;
  width: 7px;
  height: 7px;
  content: '';
  background: var(--production-link-color);
  border-radius: 50%;
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--production-link-color) 18%, transparent);
}

.production-no-derived {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 180px;
  min-height: 220px;
  color: var(--ant-color-text-secondary);
  background: color-mix(in srgb, var(--ant-color-bg-container) 82%, transparent);
  border: 1px dashed var(--ant-color-border);
  border-radius: 8px;
}

.production-no-derived-icon {
  margin-bottom: 4px;
  font-size: 24px;
  color: var(--ant-color-text-tertiary);
}

.production-no-derived small {
  margin-top: 4px;
  font-size: 11px;
  color: var(--ant-color-text-tertiary);
}

@media (max-width: 900px) {
  .production-assets-canvas {
    max-height: 400px;
    padding: 12px;
  }

  .production-asset-card {
    flex-basis: 132px;
    width: 132px;
  }
}
</style>

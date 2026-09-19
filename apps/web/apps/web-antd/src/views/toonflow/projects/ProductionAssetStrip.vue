<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, reactive, ref } from 'vue';

import { Button, Dropdown, Empty, Form, Input, Menu, message, Modal, Select, Tag } from 'ant-design-vue';

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
const promptName = ref('');
const promptText = ref('');
const compactView = ref(false);
const collapsedGroups = reactive(new Set<number>());
const promptParent = computed(() => assetRows.value.find((asset) => asset.id === promptAsset.value?.parentAssetId));

function toggleGroup(id: number) {
  if (collapsedGroups.has(id)) collapsedGroups.delete(id);
  else collapsedGroups.add(id);
}

function closePromptEditor() {
  if (promptSaving.value) return;
  const asset = promptAsset.value;
  if (asset && (promptName.value !== asset.name || promptDescription.value !== (asset.description || '') || promptText.value !== (asset.prompt || asset.description || ''))) {
    Modal.confirm({
      title: '放弃未保存的造型修改？',
      content: '关闭后，本次修改不会保存。',
      okText: '放弃修改',
      cancelText: '继续编辑',
      onOk: () => { promptEditorOpen.value = false; },
    });
    return;
  }
  promptEditorOpen.value = false;
}
const promptDescription = ref('');
const pendingActionIds = reactive(new Set<number>());
const generatingAssetIds = reactive(new Set<number>());
const promptGeneratingIds = reactive(new Set<number>());

const assetRows = computed(() =>
  props.assets.filter(
    (asset) => !asset.parentAssetId && ['role', 'scene'].includes(asset.type),
  ),
);

const search = ref('');
const statusFilter = ref('all');
const previewAsset = ref<ToonflowApi.Asset>();
const statusOptions = [
  { label: '全部造型', value: 'all' },
  { label: '待生成', value: 'pending' },
  { label: '生成中', value: 'running' },
  { label: '生成失败', value: 'failed' },
  { label: '已就绪', value: 'ready' },
];
function assetStatus(asset: ToonflowApi.Asset) {
  if (isAssetGenerating(asset)) return 'running';
  if (asset.imageState === '生成失败') return 'failed';
  return asset.imageFilePath ? 'ready' : 'pending';
}
function statusColor(asset: ToonflowApi.Asset) {
  return { running: 'blue', failed: 'red', ready: 'green', pending: 'default' }[assetStatus(asset)];
}
const stats = computed(() => {
  const result = { total: 0, ready: 0, running: 0, failed: 0, pending: 0 };
  for (const asset of assetRows.value.filter((item) => item.type === 'role')) {
    for (const derived of asset.derive ?? []) {
      result.total++;
      result[assetStatus(derived)]++;
    }
    const pending = pendingAppearances(asset).length;
    result.total += pending;
    result.pending += pending;
  }
  return result;
});
const visibleGroups = computed(() => {
  const query = search.value.trim().toLocaleLowerCase();
  const matches = (text: string) => text.toLocaleLowerCase().includes(query);
  return assetRows.value.map((asset) => {
    const parentMatch = matches(asset.name);
    const derived = (asset.derive ?? []).filter((item) =>
      (parentMatch || matches(`${item.name} ${assetSummary(item)} ${appearanceScenes(asset, item) || ''}`)) &&
      (statusFilter.value === 'all' || assetStatus(item) === statusFilter.value));
    const pending = pendingAppearances(asset).filter((item) =>
      (parentMatch || matches(`${item.name} ${item.costumePrompt} ${item.scenes.join(' ')}`)) &&
      ['all', 'pending'].includes(statusFilter.value));
    return { asset, derived, pending, visible: derived.length || pending.length || (parentMatch && statusFilter.value === 'all') };
  }).filter((group) => group.visible);
});
function appearanceScenes(asset: ToonflowApi.Asset, derived: ToonflowApi.Asset) {
  return asset.appearances?.find((item) => item.id === derived.appearanceId)?.scenes.join('、');
}

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
  if (isAssetGenerating(asset)) return '生成中';
  if (asset.imageState === '生成失败') return '生成失败';
  return asset.imageFilePath ? '已就绪' : '待生成';
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
  promptName.value = asset.name;
  promptDescription.value = asset.description || '';
  promptText.value = asset.prompt || asset.description || '';
  promptEditorOpen.value = true;
}

async function savePrompt(generate = false) {
  const asset = promptAsset.value;
  if (!asset || promptSaving.value) return;
  const name = promptName.value.trim();
  if (!name) return message.warning('请输入造型名称');
  if (generate && !promptText.value.trim()) return message.warning('请填写生成提示词');
  const savedAsset = { ...asset, name, description: promptDescription.value, prompt: promptText.value };
  let saved = false;
  promptSaving.value = true;
  try {
    await saveAsset({
      id: asset.id,
      projectId: assetProjectId(asset),
      name,
      type: asset.type,
      description: promptDescription.value,
      prompt: promptText.value,
      remark: asset.remark,
      scriptId: asset.scriptId,
      parentAssetId: asset.parentAssetId,
      imageId: asset.imageId,
    });
    promptEditorOpen.value = false;
    message.success(`“${name}”的造型已保存`);
    emit('refresh');
    saved = true;
  } catch (error) {
    message.error(error instanceof Error ? error.message : '造型描述和生成提示词保存失败');
  } finally {
    promptSaving.value = false;
  }
  if (saved && generate) await generateDerivedAsset(savedAsset);
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
  <section class="production-assets nopan nodrag" @click.stop @dblclick.stop>
    <header class="production-assets-heading">
      <div>
        <div class="production-assets-title">衍生资产 <span>{{ stats.total }} 套造型</span></div>
        <div class="production-assets-subtitle">按角色检查造型与场次，确认后生成图片</div>
      </div>
      <div class="production-assets-counts" aria-live="polite">
        <Tag color="green">就绪 {{ stats.ready }}</Tag>
        <Tag>待生成 {{ stats.pending }}</Tag>
        <Tag v-if="stats.running" color="blue">生成中 {{ stats.running }}</Tag>
        <Tag v-if="stats.failed" color="red">失败 {{ stats.failed }}</Tag>
      </div>
    </header>
    <div v-if="assetRows.length" class="production-assets-filters">
      <Input v-model:value="search" allow-clear placeholder="搜索角色、造型或场次" aria-label="搜索资产" />
      <Select v-model:value="statusFilter" :options="statusOptions" aria-label="造型状态" />
      <Button :aria-pressed="compactView" @click="compactView = !compactView">{{ compactView ? '卡片视图' : '紧凑视图' }}</Button>
    </div>
    <div class="production-assets-canvas nowheel" :class="{ 'is-compact': compactView }">
      <Empty v-if="!assetRows.length" :image="Empty.PRESENTED_IMAGE_SIMPLE" description="当前剧本暂无资产，请先让制作 Agent 分析人物与造型" />
      <Empty v-else-if="!visibleGroups.length" :image="Empty.PRESENTED_IMAGE_SIMPLE" description="没有匹配的资产，试试其他关键词或状态">
        <Button @click="search = ''; statusFilter = 'all'">清除筛选</Button>
      </Empty>
      <section v-for="{ asset, derived: derivatives, pending } in visibleGroups" :key="asset.id" class="production-asset-group">
        <header class="production-group-header">
          <button v-if="asset.imageFilePath" class="production-origin-preview" type="button" :aria-label="`预览${asset.name}基础图`" @click="previewAsset = asset">
            <img :src="assetFileUrl(asset.imageFilePath)" :alt="asset.name" loading="lazy" />
          </button>
          <div v-else class="production-origin-placeholder">{{ assetTypeLabel(asset.type) }}</div>
          <div class="production-group-title">
            <strong>{{ asset.name }}</strong>
            <p>{{ asset.type === 'role' ? '基础角色' : '基础场景' }} · {{ asset.type === 'role' ? `${(asset.derive?.length ?? 0) + pendingAppearances(asset).length} 套造型` : assetSummary(asset) }}</p>
          </div>
          <Tag v-if="!asset.imageFilePath" color="gold">基础图未生成</Tag>
          <Button size="small" @click="emit('edit', asset)">编辑基础图</Button>
          <Button v-if="asset.type === 'role'" size="small" type="text" :aria-expanded="!collapsedGroups.has(asset.id)" :aria-label="`${collapsedGroups.has(asset.id) ? '展开' : '收起'}${asset.name}的造型`" @click="toggleGroup(asset.id)">{{ collapsedGroups.has(asset.id) ? '展开' : '收起' }}</Button>
        </header>
        <div v-if="asset.type === 'role'" v-show="!collapsedGroups.has(asset.id)" class="production-derived-list">
          <article v-for="derived in derivatives" :key="derived.id" class="production-asset-card">
            <button class="production-asset-cover" type="button" :disabled="!derived.imageFilePath" :aria-label="`预览${derived.name}`" @click="previewAsset = derived">
              <img v-if="derived.imageFilePath" :src="assetFileUrl(derived.imageFilePath)" :alt="derived.name" loading="lazy" />
              <span v-else class="production-asset-placeholder">{{ isAssetGenerating(derived) ? '正在生成造型…' : '暂无造型图片' }}</span>
              <Tag class="production-asset-kind" :color="statusColor(derived)">{{ generationLabel(derived) }}</Tag>
            </button>
            <div class="production-asset-content">
              <strong class="production-asset-name" :title="derived.name">{{ derived.name }}</strong>
              <p class="production-asset-description" :title="assetSummary(derived)">{{ assetSummary(derived) }}</p>
              <p class="production-appearance-scenes">{{ appearanceScenes(asset, derived) || '当前剧本' }}</p>
              <p v-if="assetStatus(derived) === 'failed'" class="production-asset-error" :title="derived.imageErrorReason">{{ derived.imageErrorReason || '图片生成失败，请重试' }}</p>
              <div class="production-asset-actions">
                <Button type="primary" size="small" :loading="isAssetGenerating(derived)" @click="generateDerivedAsset(derived)">{{ isAssetGenerating(derived) ? '生成中' : assetStatus(derived) === 'failed' ? '重试生成' : derived.imageFilePath ? '重新生成' : '生成图片' }}</Button>
                <Button size="small" :disabled="isAssetGenerating(derived)" :aria-label="`编辑${derived.name}的造型`" @click="openPromptEditor(derived)">编辑造型</Button>
                <Dropdown :trigger="['click']">
                  <Button size="small" :aria-label="`${derived.name}更多操作`">···</Button>
                  <template #overlay><Menu>
                    <Menu.Item :disabled="promptGeneratingIds.has(derived.id)" @click="polishDerivedPrompt(derived)">{{ promptGeneratingIds.has(derived.id) ? '提示词生成中…' : 'AI 生成提示词' }}</Menu.Item>
                    <Menu.Item @click="emit('edit', derived)">图片编辑</Menu.Item>
                  </Menu></template>
                </Dropdown>
              </div>
            </div>
          </article>
          <article v-for="appearance in pending" :key="`appearance-${appearance.id}`" class="production-asset-card">
            <div class="production-asset-cover">
              <span class="production-asset-placeholder">造型已分析，等待生成</span>
              <Tag class="production-asset-kind">待生成</Tag>
            </div>
            <div class="production-asset-content">
              <strong class="production-asset-name" :title="appearance.name">{{ appearance.name }}</strong>
              <p class="production-asset-description" :title="appearance.costumePrompt">{{ appearance.costumePrompt }}</p>
              <p class="production-appearance-scenes">{{ appearance.scenes.join('、') || '当前剧本' }}</p>
              <p v-if="!asset.imageFilePath" class="production-asset-error">请先生成基础角色图片</p>
              <div class="production-asset-actions">
                <Button type="primary" size="small" :loading="pendingActionIds.has(appearance.id)" :disabled="!asset.imageFilePath" @click="generatePendingAppearance(asset, appearance)">生成图片</Button>
                <Button size="small" :aria-label="`编辑${appearance.name}的造型`" :disabled="pendingActionIds.has(appearance.id)" @click="editPendingAppearance(asset, appearance)">编辑造型</Button>
                <Dropdown :trigger="['click']">
                  <Button size="small" :disabled="pendingActionIds.has(appearance.id)" :aria-label="`${appearance.name}更多操作`">···</Button>
                  <template #overlay><Menu><Menu.Item @click="polishPendingAppearance(asset, appearance)">AI 生成提示词</Menu.Item></Menu></template>
                </Dropdown>
              </div>
            </div>
          </article>
          <div v-if="!derivatives.length && !pending.length" class="production-no-derived">暂无衍生造型，请让制作 Agent 根据当前剧本分析角色服装。</div>
        </div>
      </section>
    </div>
    <Modal :open="!!previewAsset" root-class-name="toon-overlay" :title="previewAsset?.name" :footer="null" width="860px" @cancel="previewAsset = undefined">
      <img v-if="previewAsset" :src="assetFileUrl(previewAsset.imageFilePath)" :alt="previewAsset.name" style="display: block; width: 100%; max-height: 75vh; object-fit: contain" />
    </Modal>

    <Modal
      :open="promptEditorOpen"
      root-class-name="toon-overlay"
      :title="`${promptAsset?.name ?? '衍生资产'} · 编辑造型`"
      width="1000px"
      :mask-closable="false"
      :closable="!promptSaving"
      :keyboard="!promptSaving"
      @cancel="closePromptEditor"
    >
      <div class="production-editor-layout">
        <aside class="production-editor-reference">
          <div class="production-editor-images">
            <figure v-if="promptParent">
              <img v-if="promptParent.imageFilePath" :src="assetFileUrl(promptParent.imageFilePath)" :alt="`${promptParent.name}基础图`" />
              <div v-else class="production-editor-empty">基础图未生成</div>
              <figcaption>{{ promptParent.name }} · 基础图</figcaption>
            </figure>
            <figure>
              <img v-if="promptAsset?.imageFilePath" :src="assetFileUrl(promptAsset.imageFilePath)" :alt="promptAsset.name" />
              <div v-else class="production-editor-empty">保存造型后生成图片</div>
              <figcaption>当前造型</figcaption>
            </figure>
          </div>
          <p v-if="promptParent && promptAsset" class="production-prompt-help">适用场次：{{ appearanceScenes(promptParent, promptAsset) || '当前剧本' }}</p>
          <p class="production-prompt-help">对照基础角色调整服装、妆容和发型，保持人物身份特征一致。</p>
        </aside>
        <Form layout="vertical" :disabled="promptSaving">
        <Form.Item label="造型名称" required>
          <Input v-model:value="promptName" placeholder="例如：日常校服、雨夜战损" />
        </Form.Item>
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
            :rows="8"
            placeholder="输入用于衍生资产生图的提示词"
          />
          <div class="production-prompt-help">
            描述用于说明造型；生成图片以此处提示词为准。修改描述后，请同步调整提示词。
          </div>
        </Form.Item>
        </Form>
      </div>
      <template #footer>
        <div class="production-editor-footer">
          <span class="production-prompt-help">保存后可重新生成图片，查看造型变化。</span>
          <Button :disabled="promptSaving" @click="closePromptEditor">取消</Button>
          <Button :loading="promptSaving" @click="savePrompt()">保存造型</Button>
          <Button type="primary" :loading="promptSaving" :disabled="!promptParent?.imageFilePath || (!!promptAsset && isAssetGenerating(promptAsset))" @click="savePrompt(true)">保存并生成图片</Button>
        </div>
      </template>
    </Modal>
  </section>
</template>

<style scoped>
.production-assets { overflow: hidden; color: var(--ant-color-text); background: var(--ant-color-bg-container); border: 1px solid var(--ant-color-border-secondary); border-radius: 10px; }
.production-assets-heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; padding: 16px 20px; }
.production-assets-title { font-size: 15px; font-weight: 600; }
.production-assets-title span { margin-left: 8px; font-size: 12px; font-weight: 400; color: var(--ant-color-text-tertiary); }
.production-assets-subtitle, .production-prompt-help { margin-top: 5px; font-size: 12px; color: var(--ant-color-text-secondary); }
.production-assets-counts { display: flex; flex-wrap: wrap; gap: 4px; }
.production-assets-counts :deep(.ant-tag) { margin: 0; }
.production-assets-filters { display: flex; flex-wrap: wrap; gap: 10px; padding: 0 20px 16px; }
.production-assets-filters > :first-child { flex: 1; min-width: 0; }
.production-assets-filters :deep(.ant-select) { width: 140px; flex-shrink: 0; }
.production-assets-canvas { max-height: 570px; padding: 0 20px 20px; overflow: auto; overscroll-behavior: contain; scrollbar-gutter: stable; }
.production-asset-group + .production-asset-group { margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--ant-color-border-secondary); }
.production-group-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.production-origin-preview, .production-origin-placeholder { display: grid; flex: 0 0 48px; width: 48px; height: 58px; overflow: hidden; padding: 0; border: 1px solid var(--ant-color-border-secondary); border-radius: 6px; background: var(--ant-color-fill-quaternary); place-items: center; font-size: 12px; }
.production-origin-preview { cursor: zoom-in; }
.production-origin-preview img { width: 100%; height: 100%; object-fit: contain; }
.production-group-title { flex: 1; min-width: 120px; }
.production-group-title strong { font-size: 14px; overflow-wrap: anywhere; }
.production-group-title p { margin: 4px 0 0; color: var(--ant-color-text-secondary); font-size: 12px; }
.production-derived-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 270px), 1fr)); gap: 14px; }
.production-asset-card { display: flex; flex-direction: column; min-width: 0; overflow: hidden; border: 1px solid var(--ant-color-border-secondary); border-radius: 9px; background: var(--ant-color-bg-container); }
.production-asset-cover { position: relative; display: flex; align-items: center; justify-content: center; width: 100%; height: 220px; padding: 0; overflow: hidden; background: var(--ant-color-fill-quaternary); border: 0; }
button.production-asset-cover:not(:disabled) { cursor: zoom-in; }
.production-asset-cover img { width: 100%; height: 100%; object-fit: contain; }
.production-asset-placeholder { padding: 20px; color: var(--ant-color-text-tertiary); font-size: 12px; text-align: center; }
.production-asset-kind { position: absolute; top: 10px; left: 10px; margin: 0; }
.production-asset-content { display: flex; flex: 1; flex-direction: column; padding: 12px; }
.production-asset-name { overflow: hidden; font-size: 14px; text-overflow: ellipsis; white-space: nowrap; }
.production-asset-description { display: -webkit-box; height: 54px; margin: 6px 0 0; overflow: hidden; -webkit-line-clamp: 3; -webkit-box-orient: vertical; color: var(--ant-color-text-secondary); font-size: 12px; line-height: 18px; }
.production-appearance-scenes { margin: 8px 0 12px; font-size: 12px; color: var(--ant-color-text-tertiary); overflow-wrap: anywhere; }
.production-asset-error { margin: 0 0 10px; color: var(--ant-color-error); font-size: 12px; overflow-wrap: anywhere; }
.production-asset-actions { display: flex; gap: 6px; margin-top: auto; }
.production-asset-actions > :first-child { flex: 1; }
.production-no-derived { grid-column: 1 / -1; padding: 22px; color: var(--ant-color-text-secondary); font-size: 12px; background: var(--ant-color-fill-quaternary); border: 1px dashed var(--ant-color-border); border-radius: 8px; }
.is-compact .production-derived-list { grid-template-columns: repeat(auto-fill, minmax(min(100%, 390px), 1fr)); }
.is-compact .production-asset-card { flex-direction: row; }
.is-compact .production-asset-cover { flex: 0 0 112px; width: 112px; height: auto; min-height: 190px; }
.is-compact .production-asset-content { min-width: 0; }
.production-editor-layout { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.4fr); gap: 24px; padding-top: 12px; }
.production-editor-reference { padding: 16px; align-self: start; background: var(--ant-color-fill-quaternary); border-radius: 10px; }
.production-editor-images { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
.production-editor-images figure { margin: 0; min-width: 0; }
.production-editor-images img, .production-editor-empty { width: 100%; height: 240px; object-fit: contain; border-radius: 6px; background: var(--ant-color-bg-container); }
.production-editor-empty { display: grid; padding: 12px; place-items: center; text-align: center; color: var(--ant-color-text-tertiary); font-size: 12px; }
.production-editor-images figcaption { margin-top: 8px; text-align: center; overflow-wrap: anywhere; font-size: 12px; }
.production-editor-footer { display: flex; flex-wrap: wrap; align-items: center; justify-content: flex-end; gap: 8px; }
.production-editor-footer > span { flex: 1; text-align: left; }
@media (max-width: 760px) {
  .production-editor-layout { grid-template-columns: minmax(0, 1fr); }
  .production-editor-images img, .production-editor-empty { height: 160px; }
  .production-editor-footer > span { flex-basis: 100%; }
}
@media (max-width: 420px) {
  .is-compact .production-asset-card { flex-direction: column; }
  .is-compact .production-asset-cover { flex-basis: auto; width: 100%; height: 180px; }
  .production-asset-actions { flex-wrap: wrap; }
}
button:focus-visible { outline: 2px solid var(--ant-color-primary); outline-offset: 2px; }
@media (max-width: 600px) {
  .production-assets-heading { padding: 12px; }
  .production-assets-filters { padding: 0 12px 12px; }
  .production-assets-canvas { padding: 0 12px 12px; }
  .production-group-header { flex-wrap: wrap; }
}
</style>

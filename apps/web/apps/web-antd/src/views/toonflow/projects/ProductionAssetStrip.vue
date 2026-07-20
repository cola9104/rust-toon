<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed } from 'vue';

import { Empty, Image, Tag } from 'ant-design-vue';

import { assetFileUrl, assetTypeLabel } from '../assets/asset-types';

const props = defineProps<{
  assets: ToonflowApi.Asset[];
}>();

const emit = defineEmits<{
  edit: [asset: ToonflowApi.Asset];
}>();

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
</script>

<template>
  <section class="production-assets">
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

    <div v-else class="production-assets-canvas">
      <div v-for="asset in assetRows" :key="asset.id" class="production-asset-row">
        <article class="production-asset-card origin-card">
          <div class="production-asset-cover">
            <Image
              v-if="asset.imageFilePath"
              :alt="asset.name"
              :src="assetFileUrl(asset.imageFilePath)"
              class="production-asset-image"
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
                <Image
                  v-if="derived.imageFilePath"
                  :alt="derived.name"
                  :src="assetFileUrl(derived.imageFilePath)"
                  class="production-asset-image"
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
                  class="production-asset-edit"
                  @click="emit('edit', derived)"
                >
                  编辑图片
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
  </section>
</template>

<style scoped>
.production-assets {
  --production-link-color: var(--ant-color-primary, #1677ff);

  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 10px;
  background: var(--ant-color-bg-container);
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
  color: var(--ant-color-text-tertiary);
  font-size: 12px;
}

.production-assets-canvas {
  max-height: 470px;
  overflow: auto;
  padding: 18px;
  background-color: var(--ant-color-fill-quaternary);
  background-image: radial-gradient(var(--ant-color-border) 0.8px, transparent 0.8px);
  background-size: 16px 16px;
}

.production-asset-row {
  display: flex;
  width: max-content;
  min-width: 100%;
  align-items: center;
  padding: 10px 0;
}

.production-asset-row + .production-asset-row {
  border-top: 1px dashed var(--ant-color-border-secondary);
}

.production-asset-card {
  width: 150px;
  flex: 0 0 150px;
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 8px;
  background: var(--ant-color-bg-container);
  box-shadow: 0 2px 8px rgb(0 0 0 / 6%);
}

.origin-card {
  align-self: center;
  border-color: color-mix(in srgb, var(--ant-color-success) 45%, transparent);
}

.derived-card {
  border-color: color-mix(in srgb, var(--ant-color-warning) 45%, transparent);
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

.production-asset-cover :deep(.ant-image),
.production-asset-cover :deep(.ant-image-img) {
  width: 100%;
  height: 100%;
}

.production-asset-cover :deep(.ant-image-img) {
  object-fit: cover;
}

.production-asset-image-placeholder {
  display: flex;
  height: 100%;
  align-items: center;
  justify-content: center;
  padding: 12px;
  color: var(--ant-color-text-tertiary);
  font-size: 12px;
  text-align: center;
}

.derived-placeholder {
  height: calc(100% - 16px);
  margin: 8px;
  border: 1px dashed color-mix(in srgb, var(--ant-color-warning) 55%, transparent);
  border-radius: 6px;
  background: color-mix(in srgb, var(--ant-color-warning) 6%, var(--ant-color-bg-container));
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
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.production-asset-description {
  display: -webkit-box;
  height: 34px;
  overflow: hidden;
  margin-top: 4px;
  color: var(--ant-color-text-tertiary);
  font-size: 12px;
  line-height: 17px;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.production-asset-description.generating {
  color: var(--ant-color-primary);
}

.production-asset-description.failed {
  color: var(--ant-color-error);
}

.production-appearance-scenes {
  overflow: hidden;
  margin-top: 7px;
  color: var(--ant-color-warning-text);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.production-asset-edit {
  width: 100%;
  margin-top: 7px;
  padding: 3px 6px;
  border: 1px solid var(--ant-color-border);
  border-radius: 5px;
  color: var(--ant-color-primary);
  font-size: 12px;
  background: var(--ant-color-bg-container);
  cursor: pointer;
}

.production-asset-edit:hover {
  border-color: var(--ant-color-primary);
}

.production-asset-connector {
  position: relative;
  width: 58px;
  min-height: 220px;
  flex: 0 0 58px;
}

.production-asset-connector::before {
  position: absolute;
  top: 50%;
  right: 0;
  left: 0;
  height: 2px;
  border-radius: 2px;
  background: var(--production-link-color);
  content: '';
}

.production-asset-connector::after {
  position: absolute;
  top: calc(50% - 4px);
  right: 1px;
  width: 8px;
  height: 8px;
  border-top: 2px solid var(--production-link-color);
  border-right: 2px solid var(--production-link-color);
  content: '';
  transform: rotate(45deg);
}

.production-asset-connector > span {
  position: absolute;
  z-index: 1;
  top: 50%;
  left: 50%;
  padding: 1px 5px;
  border: 1px solid color-mix(in srgb, var(--production-link-color) 35%, transparent);
  border-radius: 10px;
  background: var(--ant-color-bg-container, #fff);
  color: var(--production-link-color);
  font-size: 10px;
  line-height: 16px;
  transform: translate(-50%, -50%);
  white-space: nowrap;
}

.production-derived-list {
  position: relative;
  display: flex;
  min-width: 214px;
  flex-direction: column;
  gap: 12px;
  padding-left: 34px;
}

.production-derived-list::before {
  position: absolute;
  top: 116px;
  bottom: 116px;
  left: 0;
  width: 2px;
  border-radius: 2px;
  background: var(--production-link-color);
  content: '';
}

.production-derived-node {
  position: relative;
  display: flex;
  min-height: 220px;
  align-items: center;
}

.production-derived-node::before {
  position: absolute;
  top: 50%;
  left: -34px;
  width: 34px;
  height: 2px;
  border-radius: 2px;
  background: var(--production-link-color);
  content: '';
}

.production-derived-node::after {
  position: absolute;
  top: calc(50% - 3px);
  left: -6px;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--production-link-color);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--production-link-color) 18%, transparent);
  content: '';
}

.production-no-derived {
  display: flex;
  width: 180px;
  min-height: 220px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 1px dashed var(--ant-color-border);
  border-radius: 8px;
  color: var(--ant-color-text-secondary);
  background: color-mix(in srgb, var(--ant-color-bg-container) 82%, transparent);
}

.production-no-derived-icon {
  margin-bottom: 4px;
  color: var(--ant-color-text-tertiary);
  font-size: 24px;
}

.production-no-derived small {
  margin-top: 4px;
  color: var(--ant-color-text-tertiary);
  font-size: 11px;
}

@media (max-width: 900px) {
  .production-assets-canvas {
    max-height: 400px;
    padding: 12px;
  }

  .production-asset-card {
    width: 132px;
    flex-basis: 132px;
  }
}
</style>

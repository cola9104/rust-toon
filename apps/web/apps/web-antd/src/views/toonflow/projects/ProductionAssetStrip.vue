<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed } from 'vue';

import { Empty, Tag } from 'ant-design-vue';

import { assetFileUrl, assetTypeLabel } from '../assets/asset-types';

const props = defineProps<{
  assets: ToonflowApi.Asset[];
}>();

const emit = defineEmits<{
  edit: [asset: ToonflowApi.Asset];
  generate: [asset: ToonflowApi.Asset];
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
                  v-if="!derived.imageFilePath && derived.imageState !== '生成中'"
                  type="button"
                  class="production-asset-generate"
                  @click="emit('generate', derived)"
                >
                  直接生成
                </button>
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

.production-asset-edit,.production-asset-generate {
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

.production-asset-edit:hover,.production-asset-generate:hover {
  border-color: var(--ant-color-primary);
}

.production-asset-generate { color: var(--ant-color-warning-text); }

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

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';

import { Button, Checkbox, Empty, Image, Tag } from 'ant-design-vue';

import { assetFileUrl } from '../assets/asset-types';
import StoryboardTrackStrip from './StoryboardTrackStrip.vue';
import { groupStoryboardsByTrack } from './storyboard-track-groups';

const props = defineProps<{ assets: any[]; storyboards: any[] }>();
const emit = defineEmits<{
  exportImages: [ids: number[]];
  reorder: [ids: number[]];
}>();

const activeIndex = ref(0);
const selectedIds = ref<number[]>([]);
const orderedIds = ref<number[]>([]);
const initialIds = ref<number[]>([]);

watch(
  () => props.storyboards.map((item) => item.id),
  (ids) => {
    if (!initialIds.value.length) initialIds.value = [...ids];
    const existing = orderedIds.value.filter((id) => ids.includes(id));
    orderedIds.value = [...existing, ...ids.filter((id) => !existing.includes(id))];
    activeIndex.value = Math.min(activeIndex.value, Math.max(0, ids.length - 1));
  },
  { immediate: true },
);

const orderedStoryboards = computed(() =>
  orderedIds.value
    .map((id) => props.storyboards.find((item) => item.id === id))
    .filter(Boolean),
);
const current = computed(() => orderedStoryboards.value[activeIndex.value]);
const currentAssets = computed(() => {
  const ids = new Set((current.value?.associateAssetsIds ?? []).map(Number));
  return props.assets.filter((asset) => ids.has(Number(asset.id)));
});
const currentDescription = computed(() =>
  current.value?.description || current.value?.videoDesc || current.value?.describe || '',
);
const storyboardGroups = computed(() =>
  groupStoryboardsByTrack(orderedStoryboards.value, { preserveOrder: true }),
);
const currentGroup = computed(() =>
  storyboardGroups.value.find((group) => group.items.some((item) => item.id === current.value?.id)),
);
const currentGroupIndex = computed(() =>
  currentGroup.value?.items.findIndex((item) => item.id === current.value?.id) ?? -1,
);
function previewUrl(item: any) {
  return assetFileUrl(item?.imageFilePath || item?.filePath || item?.fileUrl || item?.src);
}
function storyboardNumber(item: any) {
  const group = storyboardGroups.value.find((candidate) => candidate.items.some((storyboard) => storyboard.id === item.id));
  return group ? group.items.findIndex((storyboard) => storyboard.id === item.id) + 1 : 1;
}
function storyboardLabel(item: any) {
  const group = storyboardGroups.value.find((candidate) => candidate.items.some((storyboard) => storyboard.id === item.id));
  return `轨道 ${group?.name || '默认轨道'} · 分镜 ${storyboardNumber(item)}`;
}
const currentLabel = computed(() => current.value ? storyboardLabel(current.value) : '暂无分镜');
const allSelected = computed({
  get: () => orderedIds.value.length > 0 && orderedIds.value.every((id) => selectedIds.value.includes(id)),
  set: (checked: boolean) => { selectedIds.value = checked ? [...orderedIds.value] : []; },
});

function selectShot(index: number) { activeIndex.value = index; }
function toggleSelected(id: number, checked: boolean) {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, id])]
    : selectedIds.value.filter((item) => item !== id);
}
function togglePreviewTrack(_trackId: number | undefined, checked: boolean, ids: number[]) {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, ...ids])]
    : selectedIds.value.filter((id) => !ids.includes(id));
}
function selectStoryboard(id: number) {
  const index = orderedStoryboards.value.findIndex((item) => item.id === id);
  if (index >= 0) selectShot(index);
}
function handleReorder(ids: number[]) {
  orderedIds.value = ids;
  emit('reorder', ids);
}
function restoreOrder() {
  orderedIds.value = initialIds.value.filter((id) => props.storyboards.some((item) => item.id === id));
  activeIndex.value = 0;
  emit('reorder', orderedIds.value);
}

</script>

<template>
  <div v-if="current" class="quick-preview">
    <section class="preview-main">
      <div class="visual-column">
        <div class="hero-image">
          <img
            v-if="previewUrl(current)"
            :src="previewUrl(current)"
            :alt="currentLabel"
            class="hero-image-content"
          />
          <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="暂无图片" />
        </div>
        <div class="image-navigation">
          <Button shape="circle" :disabled="activeIndex === 0" @click="selectShot(activeIndex - 1)">‹</Button>
          <span>{{ currentLabel }}（{{ currentGroupIndex + 1 }} / {{ currentGroup?.items.length || 0 }}）</span>
          <Button shape="circle" :disabled="activeIndex >= orderedStoryboards.length - 1" @click="selectShot(activeIndex + 1)">›</Button>
        </div>
      </div>

      <aside class="info-panel">
        <section><h4><i />分镜描述</h4><p>【{{ currentLabel }}】{{ currentDescription || '暂无描述' }}</p></section>
        <section><h4><i />时长</h4><p>{{ current.duration || 3 }} 秒</p></section>
        <section>
          <h4><i />涉及资产</h4>
          <div v-if="currentAssets.length" class="asset-list">
            <article v-for="asset in currentAssets" :key="asset.id">
              <Image v-if="previewUrl(asset)" :src="previewUrl(asset)" :width="76" :height="76" />
              <div v-else class="asset-image-empty">暂无图片</div>
              <Tag>{{ asset.name }}（{{ asset.type === 'role' ? '角色' : asset.type === 'tool' ? '道具' : '场景' }}）</Tag>
            </article>
          </div>
          <Tag v-else>暂无出场人物</Tag>
        </section>
        <section class="prompt-info"><h4><i />图片提示词</h4><p><b>场景描述：</b>{{ currentDescription || '暂无描述' }}</p><p><b>提示词：</b>{{ current.prompt || '暂无提示词' }}</p></section>
      </aside>
    </section>

    <section class="shot-list-area">
      <header>
        <div><Checkbox v-model:checked="allSelected">全选</Checkbox><Button type="text" @click="restoreOrder">↶ 还原排序</Button></div>
        <Button type="text" @click="emit('exportImages', selectedIds)">⇩ 导出图片</Button>
      </header>
      <StoryboardTrackStrip
        :active-storyboard-id="current?.id"
        :draggable="true"
        :preserve-order="true"
        :selected-storyboard-ids="selectedIds"
        :show-storyboard-checkbox="true"
        :show-track-checkbox="true"
        :storyboards="orderedStoryboards"
        @reorder="handleReorder"
        @storyboard-click="selectStoryboard"
        @storyboard-toggle="toggleSelected"
        @track-toggle="togglePreviewTrack"
      />
    </section>
  </div>
  <Empty v-else class="preview-empty" :image="Empty.PRESENTED_IMAGE_SIMPLE" description="暂无分镜图" />
</template>

<style scoped>
.quick-preview { display: grid; height: 100%; grid-template-rows: minmax(0, 1fr) 184px; overflow: hidden; background: var(--ant-color-bg-container); }.preview-main { display: grid; min-height: 0; grid-template-columns: minmax(400px, 42%) minmax(0, 58%); gap: 0; }.visual-column { display: grid; min-height: 0; align-content: center; justify-items: start; padding: 24px 28px 18px; grid-template-rows: auto auto; }.hero-image { display: grid; width: 100%; max-width: 660px; overflow: hidden; aspect-ratio: 16 / 9; margin: 0; border-radius: 8px; background: #111827; place-items: start; }.hero-image :deep(.ant-image), .hero-image :deep(img) { width: 100%; height: 100%; object-fit: contain; object-position: left center; }.player-controls { width: 100%; max-width: 660px; margin: 0; padding-top: 12px; }.control-buttons { display: flex; justify-content: center; gap: 12px; }.progress-row { display: grid; grid-template-columns: 42px 1fr 42px; align-items: center; gap: 8px; margin-top: 10px; color: var(--ant-color-text-tertiary); font-size: 11px; }.progress-track { position: relative; height: 8px; border-radius: 4px; background: var(--ant-color-fill-secondary); cursor: pointer; }.progress-segment { position: absolute; height: 100%; border-right: 1px solid var(--ant-color-bg-container); }.progress-segment.active { background: var(--ant-color-primary-bg-hover); }.progress-segment.completed { background: var(--ant-color-primary-border); }.progress-track b { position: absolute; height: 2px; top: 3px; left: 0; background: var(--ant-color-primary); }.progress-track em { position: absolute; top: -3px; width: 14px; height: 14px; margin-left: -7px; border: 3px solid #fff; border-radius: 50%; background: var(--ant-color-primary); box-shadow: 0 1px 4px rgb(0 0 0 / 25%); }.info-panel { overflow-y: auto; padding: 24px 30px; border-left: 1px solid var(--ant-color-border-secondary); background: var(--ant-color-bg-layout); }.info-panel section { margin-bottom: 22px; }.info-panel h4 { display: flex; align-items: center; gap: 7px; margin: 0 0 9px; font-size: 14px; }.info-panel h4 i { width: 4px; height: 16px; border-radius: 2px; background: var(--ant-color-primary); }.info-panel p { max-width: 880px; margin: 4px 0; color: var(--ant-color-text-secondary); font-size: 12px; line-height: 1.65; overflow-wrap: anywhere; }.prompt-info p + p { margin-top: 9px; }.asset-list { display: flex; flex-wrap: wrap; gap: 10px; }.asset-list article { display: grid; max-width: 120px; gap: 5px; }.asset-list :deep(img) { border-radius: 7px; object-fit: contain; background: var(--ant-color-fill-secondary); }.asset-list :deep(.ant-tag) { overflow: hidden; margin: 0; text-overflow: ellipsis; white-space: nowrap; }.shot-list-area { min-height: 0; padding: 10px 18px 14px; border-top: 1px solid var(--ant-color-border-secondary); background: var(--ant-color-bg-container); }.shot-list-area header { display: flex; height: 34px; align-items: center; justify-content: space-between; }.shot-list-area header > div { display: flex; align-items: center; gap: 8px; }.shot-list { display: flex; height: 122px; gap: 10px; overflow-x: auto; padding: 4px 2px 8px; }.shot-item { position: relative; width: 164px; flex: 0 0 164px; padding: 5px; border: 2px solid transparent; border-radius: 7px; background: var(--ant-color-fill-tertiary); cursor: grab; }.shot-item.active { border-color: var(--ant-color-primary); }.shot-item > :deep(.ant-checkbox-wrapper) { position: absolute; z-index: 2; top: 9px; left: 9px; }.shot-item > div { position: relative; display: grid; height: 100%; overflow: hidden; border-radius: 4px; background: #111827; place-items: center; }.shot-item img { width: 100%; height: 100%; object-fit: contain; object-position: left center; }.shot-item :deep(.ant-tag) { position: absolute; right: 4px; bottom: 4px; margin: 0; color: #fff; background: rgb(0 0 0 / 62%); }.preview-empty { margin-top: 180px; }
@media (max-width: 1000px) { .preview-main { grid-template-columns: 1fr; overflow-y: auto; }.info-panel { border-top: 1px solid var(--ant-color-border-secondary); border-left: 0; }.quick-preview { grid-template-rows: minmax(0, 1fr) 178px; } }

/* The preview must never push its information panel outside the viewport. */
.quick-preview,
.preview-main,
.visual-column,
.info-panel,
.shot-list-area {
  min-width: 0;
  max-width: 100%;
  box-sizing: border-box;
}

.preview-main {
  grid-template-columns: 430px minmax(0, 1fr);
  overflow: visible;
}

.visual-column {
  display: block;
  overflow: visible;
  padding-top: 8px;
}

.quick-preview {
  height: auto;
  min-height: 100%;
  overflow: visible;
  grid-template-rows: auto auto;
}

.shot-list-area {
  overflow: visible;
}

.asset-image-empty {
  display: grid;
  width: 76px;
  height: 76px;
  border-radius: 7px;
  color: var(--ant-color-text-tertiary);
  background: var(--ant-color-fill-secondary);
  font-size: 11px;
  place-items: center;
}

.shot-list {
  display: flex;
  height: auto;
  align-items: flex-start;
  overflow-x: auto;
  overflow-y: visible;
}

.shot-item {
  width: 164px;
  min-width: 0;
  flex: 0 0 164px;
}

.shot-item > div {
  height: auto;
  min-height: 0;
}

.shot-item img {
  display: block;
  width: 100%;
  height: auto;
  max-width: 100%;
  max-height: none;
}

.hero-image {
  display: block;
  width: 100%;
  max-width: none;
  height: auto;
  max-height: none;
  min-height: 0;
  overflow: hidden;
  aspect-ratio: auto;
}

.player-controls {
  width: 100%;
  max-width: none;
}

.hero-image-content {
  position: static;
  display: block;
  width: 100% !important;
  height: auto !important;
  min-width: 0;
  min-height: 0;
  max-width: 100%;
  max-height: none;
  object-position: left center !important;
}

.info-panel {
  display: block;
  visibility: visible;
  width: 100%;
}

@media (max-width: 900px) {
  .quick-preview { overflow: visible; grid-template-rows: auto auto; }
  .preview-main { grid-template-columns: 1fr; overflow: visible; }
  .visual-column { min-height: 380px; }
  .hero-image, .player-controls { width: min(100%, 420px); }
  .hero-image { height: auto; max-height: 236px; aspect-ratio: 16 / 9; }
  .info-panel { min-height: 420px; overflow: visible; border-top: 1px solid var(--ant-color-border-secondary); border-left: 0; }
}

/* Match the reference workbench: preview and details above, horizontal shots below. */
.quick-preview {
  display: grid;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  grid-template-rows: minmax(0, 1fr) 132px;
}

.preview-main {
  display: grid;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  grid-template-columns: minmax(0, 60%) minmax(280px, 40%);
}

.visual-column {
  display: grid;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  padding: 12px 18px 8px;
  align-content: start;
  grid-template-rows: auto auto;
}

.hero-image {
  position: relative;
  display: block;
  width: 100%;
  max-width: none;
  height: auto;
  max-height: none;
  min-height: 0;
  overflow: hidden;
  aspect-ratio: 16 / 9;
}

.hero-image-content {
  position: absolute;
  inset: 0;
  display: block;
  width: 100% !important;
  height: 100% !important;
  max-width: 100%;
  max-height: 100%;
  object-fit: contain !important;
  object-position: center !important;
}

.player-controls {
  width: 100%;
  max-width: none;
  padding-top: 8px;
}

.info-panel {
  display: block;
  min-width: 0;
  min-height: 0;
  overflow-y: auto;
  padding: 18px 20px;
}

.shot-list-area {
  height: 132px;
  overflow: hidden;
  padding: 6px 14px 10px;
}

.shot-list-area header {
  height: 28px;
}

.shot-list {
  display: flex;
  height: 88px;
  align-items: stretch;
  overflow-x: auto;
  overflow-y: hidden;
}

.shot-item {
  width: 132px;
  flex: 0 0 132px;
}

.shot-item > div {
  width: 100%;
  height: auto;
  aspect-ratio: 16 / 9;
}

.shot-item img {
  width: 100%;
  height: 100%;
  max-height: 100%;
  object-fit: contain;
  object-position: center;
}

@media (max-width: 900px) {
  .quick-preview { height: auto; overflow: visible; grid-template-rows: auto auto; }
  .preview-main { grid-template-columns: 1fr; overflow: visible; }
  .visual-column { min-height: 420px; }
  .info-panel { min-height: 320px; overflow: visible; }
  .shot-list-area { height: 132px; }
}
.quick-preview { grid-template-rows: minmax(0, 1fr) 210px; }
.shot-list-area { overflow: visible; }
.shot-list { height: 145px; }
.shot-item { width: 190px; flex-basis: 190px; }
.hero-image { max-width: 1000px; }
.image-navigation { display: flex; width: 100%; max-width: 1000px; align-items: center; justify-content: center; gap: 18px; padding-top: 10px; color: var(--ant-color-text-secondary); font-size: 12px; }
@media (max-width: 900px) {
  .hero-image, .image-navigation { width: min(100%, 1000px); max-width: 1000px; }
  .hero-image { max-height: 562px; }
}

/* Final preview layout: keep the image preview independent from video-track sizing. */
.quick-preview {
  display: grid;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  grid-template-rows: minmax(0, 1fr) 174px;
}
.preview-main {
  display: grid;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  grid-template-columns: minmax(0, 60%) minmax(280px, 40%);
}
.visual-column {
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  padding: 12px 18px 8px;
  align-content: start;
}
.hero-image {
  width: 100%;
  max-width: none;
  aspect-ratio: 16 / 9;
}
.hero-image-content {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
  object-position: center !important;
}
.image-navigation {
  width: 100%;
  max-width: none;
  padding-top: 8px;
}
.info-panel {
  min-width: 0;
  min-height: 0;
  overflow-y: auto;
  padding: 18px 20px;
}
.shot-list-area {
  height: 174px;
  overflow: hidden;
  padding: 8px 14px 10px;
}
.shot-list {
  height: 145px;
  overflow-x: auto;
  overflow-y: hidden;
}
.shot-item {
  width: 190px;
  flex-basis: 190px;
}
@media (max-width: 900px) {
  .quick-preview { height: auto; min-height: 100%; overflow: visible; grid-template-rows: auto auto; }
  .preview-main { grid-template-columns: 1fr; overflow: visible; }
  .visual-column { overflow: visible; }
  .hero-image, .image-navigation { width: 100%; max-width: none; }
  .hero-image { max-height: none; }
  .info-panel { border-top: 1px solid var(--ant-color-border-secondary); border-left: 0; }
}

/* Keep the original single-row storyboard strip with one horizontal scrollbar. */
.quick-preview {
  height: 100%;
  min-height: 0;
  overflow: hidden;
  grid-template-rows: minmax(0, 1fr) 256px;
}

.shot-list-area {
  height: 256px;
  overflow: hidden;
  padding: 14px;
}

.shot-list-area header {
  height: 34px;
  margin-bottom: 10px;
}

.shot-list {
  display: flex;
  height: 160px;
  align-items: flex-start;
  gap: 10px;
  padding: 0 2px 7px;
  overflow-x: auto;
  overflow-y: hidden;
}

.shot-group-strip {
  display: flex;
  width: max-content;
  min-width: 0;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 4px;
}

.shot-list-area .shot-group-title {
  display: flex;
  height: 22px;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
  white-space: nowrap;
}

.shot-group-title > span {
  color: var(--ant-color-text-tertiary);
  font-size: 11px;
}

.shot-group-items {
  display: flex;
  height: 119px;
  width: max-content;
  gap: 10px;
}

.shot-group-items .shot-item {
  height: 100%;
}

@media (max-width: 900px) {
  .quick-preview { height: auto; min-height: 100%; overflow: visible; grid-template-rows: auto auto; }
  .shot-list-area { height: 256px; overflow: hidden; }
}
</style>

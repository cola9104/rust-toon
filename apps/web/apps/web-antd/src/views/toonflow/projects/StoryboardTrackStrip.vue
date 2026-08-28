<script lang="ts" setup>
import { computed, ref } from 'vue';

import { Checkbox, Tag } from 'ant-design-vue';

import { assetFileUrl } from '../assets/asset-types';
import {
  groupStoryboardsByTrack,
  sortStoryboards,
  type StoryboardTrackItem,
} from './storyboard-track-groups';

interface TrackStripGroup<T extends StoryboardTrackItem = StoryboardTrackItem> {
  key: string;
  trackId?: number;
  name: string;
  items: T[];
}

const props = withDefaults(defineProps<{
  activeStoryboardId?: number;
  activeTrackId?: number;
  draggable?: boolean;
  preserveOrder?: boolean;
  selectedStoryboardIds?: number[];
  selectedTrackIds?: number[];
  showStoryboardCheckbox?: boolean;
  showTrackCheckbox?: boolean;
  storyboards: StoryboardTrackItem[];
}>(), {
  draggable: false,
  preserveOrder: false,
  selectedStoryboardIds: () => [],
  selectedTrackIds: () => [],
  showStoryboardCheckbox: false,
  showTrackCheckbox: false,
});

const emit = defineEmits<{
  reorder: [ids: number[]];
  storyboardClick: [storyboardId: number, trackId?: number];
  storyboardToggle: [storyboardId: number, checked: boolean];
  trackClick: [trackId: number];
  trackToggle: [trackId: number | undefined, checked: boolean, storyboardIds: number[]];
}>();

const draggingId = ref<number>();

const groups = computed<TrackStripGroup[]>(() => {
  const source = props.preserveOrder ? [...props.storyboards] : sortStoryboards(props.storyboards);
  return groupStoryboardsByTrack(source, { preserveOrder: true }).map((group) => ({
    ...group,
    trackId: group.items[0]?.trackId === undefined ? undefined : Number(group.items[0]?.trackId),
  }));
});

function imageUrl(item: StoryboardTrackItem) {
  const value = (item as any)?.imageFilePath || (item as any)?.filePath || (item as any)?.fileUrl || (item as any)?.src;
  return assetFileUrl(value);
}

function storyboardLabel(group: TrackStripGroup, index: number) {
  return `轨道 ${group.name} · 分镜 ${index + 1}`;
}

function trackChecked(group: TrackStripGroup) {
  if (!group.items.length) return false;
  if (props.showStoryboardCheckbox) {
    return group.items.every((item) => props.selectedStoryboardIds.includes(item.id));
  }
  return group.trackId !== undefined && props.selectedTrackIds.includes(group.trackId);
}

function storyboardChecked(item: StoryboardTrackItem) {
  return props.selectedStoryboardIds.includes(item.id);
}

function clickTrack(group: TrackStripGroup) {
  if (group.trackId !== undefined) emit('trackClick', group.trackId);
}

function toggleTrack(group: TrackStripGroup, checked: boolean) {
  emit('trackToggle', group.trackId, checked, group.items.map((item) => item.id));
}

function clickStoryboard(group: TrackStripGroup, item: StoryboardTrackItem) {
  emit('storyboardClick', item.id, group.trackId);
}

function dropOn(targetId: number) {
  if (!props.draggable || !draggingId.value || draggingId.value === targetId) return;
  const ids = props.storyboards.map((item) => item.id);
  const from = ids.indexOf(draggingId.value);
  const to = ids.indexOf(targetId);
  if (from < 0 || to < 0) return;
  ids.splice(to, 0, ...ids.splice(from, 1));
  draggingId.value = undefined;
  emit('reorder', ids);
}
</script>

<template>
  <div class="storyboard-track-strip">
    <section v-for="group in groups" :key="group.key" class="storyboard-track-group" :class="{ active: group.trackId === activeTrackId }">
      <header class="storyboard-track-group-title" @click="clickTrack(group)">
        <Checkbox
          v-if="showTrackCheckbox"
          class="track-checkbox"
          :checked="trackChecked(group)"
          :disabled="!group.items.length"
          @click.stop="clickTrack(group)"
          @change="toggleTrack(group, $event.target.checked)"
        />
        <span>{{ `轨道 ${group.name}` }}</span>
        <small>{{ group.items.length }} 个分镜</small>
      </header>
      <div class="storyboard-track-group-items">
        <button
          v-for="(item, index) in group.items"
          :key="item.id"
          type="button"
          class="storyboard-track-shot"
          :class="{ active: item.id === activeStoryboardId }"
          :draggable="draggable"
          @click="clickStoryboard(group, item)"
          @dragstart="draggingId = item.id"
          @dragover.prevent
          @drop="dropOn(item.id)"
        >
          <Checkbox
            v-if="showStoryboardCheckbox"
            class="storyboard-checkbox"
            :checked="storyboardChecked(item)"
            @click.stop
            @change="emit('storyboardToggle', item.id, $event.target.checked)"
          />
          <div class="storyboard-track-shot-media">
            <img v-if="imageUrl(item)" :src="imageUrl(item)" :alt="storyboardLabel(group, index)" decoding="async" loading="lazy" />
            <span v-else>暂无图片</span>
            <Tag>{{ storyboardLabel(group, index) }}</Tag>
          </div>
        </button>
        <div v-if="!group.items.length" class="storyboard-track-shot storyboard-track-shot--empty">暂无分镜图片</div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.storyboard-track-strip {
  display: flex;
  width: 100%;
  min-width: 0;
  align-items: flex-start;
  gap: 10px;
  overflow-x: auto;
  padding: 0 2px 7px;
}
.storyboard-track-group {
  display: flex;
  width: max-content;
  min-width: 0;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 4px;
}
.storyboard-track-group.active .storyboard-track-group-title { color: var(--ant-color-primary); }
.storyboard-track-group-title {
  display: flex;
  height: 28px;
  align-items: center;
  gap: 8px;
  color: var(--ant-color-text-secondary);
  cursor: pointer;
  white-space: nowrap;
}
.storyboard-track-group-title .track-checkbox {
  flex: 0 0 auto;
  padding: 3px 5px;
  border-radius: 5px;
  background: #fff;
  box-shadow: 0 0 0 1px rgb(15 23 42 / 14%);
}
.track-checkbox :deep(.ant-checkbox-inner) {
  width: 16px;
  height: 16px;
  border: 2px solid #475569;
  background: #fff;
}
.track-checkbox:hover :deep(.ant-checkbox-inner),
.track-checkbox :deep(.ant-checkbox-input:focus + .ant-checkbox-inner) {
  border-color: #1677ff;
}
.track-checkbox :deep(.ant-checkbox-checked .ant-checkbox-inner),
.track-checkbox :deep(.ant-checkbox-indeterminate .ant-checkbox-inner) {
  border-color: #0958d9;
  background: #0958d9;
}
.track-checkbox :deep(.ant-checkbox-checked .ant-checkbox-inner::after) {
  border-color: #fff;
}
.storyboard-track-group-title > span { font-size: 11px; }
.storyboard-track-group-title > small { color: var(--ant-color-text-tertiary); font-size: 10px; }
.storyboard-track-group-items { display: flex; width: max-content; height: 145px; gap: 10px; }
.storyboard-track-shot {
  position: relative;
  display: grid;
  width: 190px;
  height: auto;
  flex: 0 0 190px;
  overflow: hidden;
  padding: 5px;
  border: 2px solid transparent;
  border-radius: 7px;
  background: var(--ant-color-fill-tertiary);
  cursor: pointer;
  place-items: center;
}
.storyboard-track-shot.active { border-color: var(--ant-color-primary); }
.storyboard-track-shot-media {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 16 / 9;
  overflow: hidden;
  border-radius: 4px;
  background: #111827;
  place-items: center;
}
.storyboard-track-shot-media img { display: block; width: 100%; height: 100%; object-fit: contain; }
.storyboard-track-shot-media > span { color: var(--ant-color-text-quaternary); font-size: 11px; }
.storyboard-track-shot .storyboard-checkbox { position: absolute; z-index: 2; top: 7px; left: 7px; padding: 3px; border-radius: 5px; background: rgb(255 255 255 / 92%); }
.storyboard-track-shot-media :deep(.ant-tag) { position: absolute; right: 4px; bottom: 4px; max-width: calc(100% - 8px); margin: 0; overflow: hidden; color: #fff; text-overflow: ellipsis; white-space: nowrap; background: rgb(0 0 0 / 65%); }
.storyboard-track-shot--empty { color: var(--ant-color-text-quaternary); font-size: 11px; }
</style>

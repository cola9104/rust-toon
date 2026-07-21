<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, ref, watch } from 'vue';

import { Button, Checkbox, Empty, Modal, Popconfirm, Slider, Space, Tag, Tooltip } from 'ant-design-vue';

import { assetFileUrl } from '../assets/asset-types';

const props = defineProps<{
  busy?: boolean;
  storyboards: ToonflowApi.Storyboard[];
}>();

const emit = defineEmits<{
  batchDelete: [ids: number[]];
  edit: [storyboard: ToonflowApi.Storyboard];
  editImage: [storyboard: ToonflowApi.Storyboard];
  exportImages: [ids: number[]];
  generate: [ids: number[], compulsory: boolean];
  insertAfter: [storyboard: ToonflowApi.Storyboard];
  openTrack: [trackId: number];
  reorder: [ids: number[]];
  remove: [storyboard: ToonflowApi.Storyboard];
}>();

const selectedIds = ref<number[]>([]);
const gridPreviewOpen = ref(false);
const gridScale = ref(100);
const draggingId = ref<number>();
const allSelected = computed(
  () => props.storyboards.length > 0 && selectedIds.value.length === props.storyboards.length,
);
const hasGenerating = computed(() => props.storyboards.some((item) => item.state === '生成中'));
const groups = computed(() => {
  const grouped = new Map<string, ToonflowApi.Storyboard[]>();
  for (const storyboard of props.storyboards) {
    const name = storyboard.track?.trim() || '默认轨道';
    grouped.set(name, [...(grouped.get(name) ?? []), storyboard]);
  }
  return [...grouped.entries()].map(([name, items]) => ({
    duration: items.reduce((total, item) => total + (item.duration ?? 0), 0),
    items,
    name,
  }));
});
const statusAnnouncement = computed(() => {
  const generating = props.storyboards.filter((item) => item.state === '生成中').length;
  const failed = props.storyboards.filter((item) => item.state === '生成失败').length;
  const completed = props.storyboards.filter((item) => item.state === '已完成').length;
  return `分镜状态：${completed} 个已完成，${generating} 个生成中，${failed} 个失败`;
});

watch(
  () => props.storyboards.map((item) => item.id),
  (ids) => {
    selectedIds.value = selectedIds.value.filter((id) => ids.includes(id));
  },
);

function toggleAll(checked: boolean) {
  selectedIds.value = checked ? props.storyboards.map((item) => item.id) : [];
}

function toggleStoryboard(id: number, checked: boolean) {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, id])]
    : selectedIds.value.filter((selectedId) => selectedId !== id);
}

function toggleGroup(ids: number[], checked: boolean) {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, ...ids])]
    : selectedIds.value.filter((id) => !ids.includes(id));
}

function statusColor(state?: string) {
  if (state === '已完成') return 'success';
  if (state === '生成中') return 'processing';
  if (state === '生成失败') return 'error';
  return 'default';
}

function generateSelected(compulsory = false) {
  const ids = selectedIds.value.length
    ? selectedIds.value
    : props.storyboards.map((item) => item.id);
  emit('generate', ids, compulsory);
}

function selectedOrAll() {
  return selectedIds.value.length ? selectedIds.value : props.storyboards.map((item) => item.id);
}
function dropOn(targetId: number) {
  const sourceId = draggingId.value;
  draggingId.value = undefined;
  if (!sourceId || sourceId === targetId) return;
  const ids = props.storyboards.map((item) => item.id);
  const from = ids.indexOf(sourceId);
  const to = ids.indexOf(targetId);
  if (from < 0 || to < 0) return;
  ids.splice(to, 0, ...ids.splice(from, 1));
  emit('reorder', ids);
}
function restoreOrder() {
  emit('reorder', props.storyboards.map((item) => item.id).sort((a, b) => a - b));
}
</script>

<template>
  <section class="storyboard-panel" aria-label="分镜面板">
    <span class="sr-only" aria-live="polite">{{ statusAnnouncement }}</span>
    <header class="panel-tools">
      <Checkbox
        :checked="allSelected"
        :disabled="storyboards.length === 0"
        @change="toggleAll($event.target.checked)"
      >
        全选
      </Checkbox>
      <span class="selection-summary">已选 {{ selectedIds.length }} / {{ storyboards.length }}</span>
      <Space size="small" wrap>
        <Button size="small" type="primary" :loading="busy" @click="generateSelected(false)">
          {{ selectedIds.length ? '生成选中' : '生成全部' }}
        </Button>
        <Tooltip title="忽略已有图片并重新生成">
          <Button size="small" :disabled="busy" @click="generateSelected(true)">强制重生成</Button>
        </Tooltip>
        <Popconfirm
          title="确认删除选中的分镜？关联图片编辑流也会删除。"
          :disabled="selectedIds.length === 0"
          @confirm="emit('batchDelete', [...selectedIds])"
        >
          <Button danger size="small" :disabled="selectedIds.length === 0">批量删除</Button>
        </Popconfirm>
        <Button size="small" @click="gridPreviewOpen = true">宫格预览</Button>
        <Button size="small" @click="emit('exportImages', selectedOrAll())">导出图片</Button>
        <Popconfirm title="确认按初始创建顺序还原？" @confirm="restoreOrder">
          <Button size="small">还原排序</Button>
        </Popconfirm>
      </Space>
    </header>

    <div v-if="storyboards.length" class="storyboard-groups" :aria-busy="hasGenerating">
      <section v-for="group in groups" :key="group.name" class="storyboard-group">
        <header class="group-header">
          <Checkbox
            :checked="group.items.every((item) => selectedIds.includes(item.id))"
            @change="toggleGroup(group.items.map((item) => item.id), $event.target.checked)"
          >
            {{ group.name }}
          </Checkbox>
          <span>{{ group.items.length }} 个分镜 · {{ group.duration }}s</span>
          <Button
            size="small"
            :disabled="busy"
            @click="emit('generate', group.items.map((item) => item.id), false)"
          >
            整组生成
          </Button>
          <Button
            v-if="group.items[0]?.trackId"
            size="small"
            @click="emit('openTrack', group.items[0]!.trackId!)"
          >
            视频轨道
          </Button>
        </header>
        <div class="storyboard-grid">
          <article
            v-for="item in group.items"
            :key="item.id"
            class="storyboard-card"
            draggable="true"
            tabindex="0"
            @dragend="draggingId = undefined"
            @dragover.prevent
            @dragstart="draggingId = item.id"
            @drop.prevent="dropOn(item.id)"
            @keydown.space.prevent="toggleStoryboard(item.id, !selectedIds.includes(item.id))"
          >
        <div class="storyboard-cover">
          <img
            v-if="item.filePath || item.src"
            :src="assetFileUrl(item.filePath || item.src)"
            :alt="`分镜 ${item.index ?? item.id}`"
          />
          <span v-else>{{ item.state === '生成中' ? '生成中…' : '等待图片' }}</span>
          <Checkbox
            :checked="selectedIds.includes(item.id)"
            class="storyboard-check"
            :aria-label="`选择分镜 ${item.index ?? item.id}`"
            @change="toggleStoryboard(item.id, $event.target.checked)"
          />
          <Tag class="storyboard-index" color="blue">{{ item.index ?? item.id }}</Tag>
        </div>
        <div class="storyboard-card-body">
          <div class="storyboard-meta">
            <b>{{ item.track || '默认轨道' }} · {{ item.duration || 0 }}s</b>
            <Tag :color="statusColor(item.state)">{{ item.state || '未生成' }}</Tag>
          </div>
          <p>{{ item.videoDesc || item.prompt || '等待 Agent 写入描述' }}</p>
          <p v-if="item.reason" class="storyboard-error" role="alert">{{ item.reason }}</p>
          <Space size="small" wrap>
            <Button size="small" @click="emit('edit', item)">编辑</Button>
            <Button size="small" @click="emit('insertAfter', item)">在后面插入</Button>
            <Button size="small" @click="emit('editImage', item)">图片生成流</Button>
            <Button size="small" :loading="item.state === '生成中'" @click="emit('generate', [item.id], false)">
              {{ item.state === '生成失败' ? '重试' : '生成' }}
            </Button>
            <Popconfirm title="确认删除这个分镜？" @confirm="emit('remove', item)">
              <Button danger size="small">删除</Button>
            </Popconfirm>
          </Space>
          <div v-if="item.associateAssetsIds?.length" class="associated-assets">
            关联资产：<Tag v-for="assetId in item.associateAssetsIds" :key="assetId">{{ assetId }}</Tag>
          </div>
        </div>
          </article>
        </div>
      </section>
    </div>
    <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="分镜表确认后，Agent 将写入分镜" />
    <Modal v-model:open="gridPreviewOpen" title="分镜宫格预览" width="92vw" :footer="null">
      <div class="preview-scale"><span>缩放比例 {{ gridScale }}%</span><Slider v-model:value="gridScale" :min="60" :max="160" /></div>
      <div class="preview-grid" :style="{ '--preview-scale': `${gridScale / 100}` }">
        <figure v-for="item in storyboards" :key="item.id">
          <img v-if="item.filePath || item.src" :src="assetFileUrl(item.filePath || item.src)" :alt="`分镜 ${item.index ?? item.id}`" />
          <div v-else>暂无图片</div>
          <figcaption>#{{ item.index ?? item.id }} · {{ item.duration || 0 }}s</figcaption>
        </figure>
      </div>
    </Modal>
  </section>
</template>

<style scoped>
.storyboard-panel { display: flex; min-height: 0; flex-direction: column; gap: 12px; }
.panel-tools { display: flex; align-items: center; gap: 10px; justify-content: space-between; flex-wrap: wrap; }
.selection-summary { color: var(--ant-color-text-secondary); font-size: 12px; margin-right: auto; }
.storyboard-grid { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 0; }
.storyboard-groups { display: flex; flex-direction: column; gap: 16px; }
.storyboard-group { overflow: hidden; border: 1px solid var(--ant-color-border-secondary); border-radius: 10px; }
.group-header { display: flex; align-items: center; gap: 12px; padding: 8px 10px; background: var(--ant-color-fill-quaternary); }
.group-header span { flex: 1; color: var(--ant-color-text-secondary); font-size: 12px; }
.storyboard-group .storyboard-grid { padding: 10px; }
.storyboard-card { width: 276px; flex: 0 0 276px; overflow: hidden; margin: 4px; border: 1px solid var(--ant-color-border-secondary); border-radius: 8px; background: var(--ant-color-bg-container); }
.storyboard-card[draggable="true"] { cursor: grab; }
.storyboard-card[draggable="true"]:active { cursor: grabbing; }
.storyboard-card:focus-visible { outline: 3px solid color-mix(in srgb, var(--ant-color-primary) 45%, transparent); outline-offset: 2px; }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; margin: -1px; padding: 0; border: 0; clip: rect(0, 0, 0, 0); white-space: nowrap; }
.storyboard-cover { position: relative; display: grid; min-height: 128px; place-items: center; overflow: hidden; background: var(--ant-color-fill-quaternary); color: var(--ant-color-text-secondary); }
.storyboard-cover img { width: 100%; height: 150px; object-fit: cover; }
.storyboard-check { position: absolute; left: 8px; top: 8px; padding: 3px; border-radius: 4px; background: color-mix(in srgb, var(--ant-color-bg-container) 86%, transparent); }
.storyboard-index { position: absolute; right: 6px; top: 6px; margin: 0; }
.storyboard-card-body { padding: 10px; }
.storyboard-meta { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.storyboard-card-body p { display: -webkit-box; min-height: 40px; overflow: hidden; margin: 8px 0; color: var(--ant-color-text-secondary); -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
.storyboard-card-body .storyboard-error { min-height: 0; color: var(--ant-color-error); }
.associated-assets { margin-top: 8px; color: var(--ant-color-text-secondary); font-size: 11px; }
.preview-scale { display: grid; grid-template-columns: 150px minmax(220px, 420px); align-items: center; gap: 12px; margin-bottom: 16px; }
.preview-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(calc(220px * var(--preview-scale)), 1fr)); gap: 12px; max-height: 72vh; overflow: auto; }
.preview-grid figure { overflow: hidden; margin: 0; border: 1px solid var(--ant-color-border-secondary); border-radius: 8px; background: var(--ant-color-bg-container); }
.preview-grid img, .preview-grid figure > div { width: 100%; aspect-ratio: 16 / 9; object-fit: cover; display: grid; place-items: center; background: var(--ant-color-fill-quaternary); }
.preview-grid figcaption { padding: 7px 9px; }
@media (max-width: 900px) { .storyboard-card { width: 100%; flex-basis: 100%; } }
</style>

<script lang="ts" setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';

import { AiModelTypeEnum } from '@vben/constants';

import {
  Button,
  Checkbox,
  Empty,
  Input,
  Modal,
  Select,
  Slider,
  Switch,
  Tag,
  Tooltip,
} from 'ant-design-vue';

import { assetFileUrl } from '../assets/asset-types';
import { updateVideoContinuityMode } from '#/api/toonflow';
import { getModelSimpleList } from '#/api/ai/model/model';
import StoryboardQuickPreview from './StoryboardQuickPreview.vue';
import StoryboardTrackStrip from './StoryboardTrackStrip.vue';
import { storyboardsForTrack } from './storyboard-track-groups';
import { defaultVideoGenerationMode, videoFrameRole } from './video-generation-mode';

const props = defineProps<{
  assets: any[];
  storyboards: any[];
  tracks: any[];
  initialTab?: 'preview' | 'generate' | 'editor';
  initialTrackId?: number;
  videoMode?: string;
  videoModel?: number;
  videoRatio?: string;
}>();

const emit = defineEmits<{
  cancelVideo: [video: any];
  deleteVideo: [video: any];
  generatePrompt: [track: any];
  generateVideo: [track: any];
  openTrack: [trackId: number];
  retryVideo: [video: any, track: any];
  reorderStoryboards: [ids: number[]];
  savePrompt: [track: any];
  selectVideo: [track: any, video: any];
  exportStoryboardImages: [ids: number[]];
  exportVideo: [videoIds: number[]];
  batchGeneratePrompts: [tracks: any[]];
  batchGenerateVideos: [tracks: any[]];
  batchDownload: [tracks: any[]];
  refresh: [];
  stateChange: [state: { tab: 'preview' | 'generate' | 'editor'; trackId?: number }];
}>();

const activeTrackId = ref<number | undefined>(props.initialTrackId);
const activeTab = ref<'preview' | 'generate' | 'editor'>(props.initialTab ?? 'preview');
const previewVideo = ref<any>();
const compareOpen = ref(false);
const compareIds = ref<number[]>([]);
const addReferenceOpen = ref(false);
const videoModelOptions = ref<Array<{ label: string; value: number; supportsAudio: boolean }>>([]);
const activeEditorIndex = ref(0);
const playingSequence = ref(false);
const editorPlaying = ref(false);
const editorVolume = ref(100);
const editorPlayer = ref<HTMLVideoElement>();
const selectedTrackIds = ref<number[]>([]);
const trackSelectionInitialized = ref(false);
const selectedEditorTrackIds = ref<number[]>([]);
const editorSelectionInitialized = ref(false);
const editorAutoSelectNewClips = ref(false);
const editorVideoError = ref(false);

const activeTrack = computed(() =>
  props.tracks.find((track) => Number(track.id) === Number(activeTrackId.value)) ?? props.tracks[0],
);
const availableClips = computed(() =>
  props.tracks
    .map((track, index) => {
      const videos = track.videoList ?? [];
      const video =
        videos.find((item: any) => Number(item.id) === Number(track.selectVideoId)) ??
        videos.find((item: any) => ['生成成功', '已完成'].includes(item.state));
      const src = videoUrl(video);
      return src
        ? { ...video, src, duration: track.duration || 5, index, trackId: track.id }
        : undefined;
    })
    .filter(Boolean),
);
const selectedClips = computed(() =>
  availableClips.value.filter((clip: any) => selectedEditorTrackIds.value.includes(clip.trackId)),
);
const selectedEditorVideoIds = computed(() => selectedClips.value.map((clip: any) => Number(clip.id)));
const totalDuration = computed(() =>
  selectedClips.value.reduce((sum, clip: any) => sum + Number(clip.duration || 0), 0),
);
const timelineTicks = computed(() => {
  const total = Math.max(0, Math.round(totalDuration.value));
  if (total === 0) return [0];
  const ticks = [0];
  for (let tick = 5; tick < total; tick += 5) ticks.push(tick);
  if (ticks.at(-1) !== total) ticks.push(total);
  return ticks;
});
const timelineContentWidth = computed(() => {
  const clipWidth = selectedClips.value.reduce(
    (sum, clip: any) => sum + timelineClipWidth(clip),
    0,
  );
  return `${Math.max(560, clipWidth + Math.max(0, selectedClips.value.length - 1) * 2 + 12)}px`;
});
const activeEditorClip = computed(() => selectedClips.value[activeEditorIndex.value]);
const activePreviewVideo = computed(() => {
  const videos = activeTrack.value?.videoList ?? [];
  const selectedId = Number(activeTrack.value?.selectVideoId);
  return videos.find((video: any) => Number(video.id) === selectedId && videoUrl(video))
    ?? videos.find((video: any) => videoUrl(video));
});
const referenceAssets = computed(() => props.assets.filter((asset) => previewUrl(asset)));
const compareVideos = computed(() => {
  const videos = activeTrack.value?.videoList ?? [];
  return compareIds.value.map((id) => videos.find((video: any) => video.id === id)).filter(Boolean);
});
const activeModelSupportsAudio = computed(() => {
  if (!activeTrack.value) return true;
  const model = videoModelOptions.value.find((item) => item.value === generation(activeTrack.value).model);
  return model?.supportsAudio ?? true;
});
const selectedTracks = computed(() => props.tracks.filter((track) => selectedTrackIds.value.includes(Number(track.id))));
const selectedTrackCount = computed(() => selectedTracks.value.length);
function successfulVideos(track: any) {
  return (track.videoList ?? []).filter((video: any) => ['生成成功', '已完成'].includes(video.state));
}

function timelineClipWidth(clip: any) {
  const duration = Math.max(1, Number(clip.duration) || 5);
  return Math.max(120, Math.round(duration * 32));
}

function timelineClipStyle(clip: any) {
  return { flex: `0 0 ${timelineClipWidth(clip)}px` };
}

function initializeEditorSelection() {
  selectedEditorTrackIds.value = availableClips.value.map((clip: any) => clip.trackId);
  editorSelectionInitialized.value = true;
  editorAutoSelectNewClips.value = true;
  activeEditorIndex.value = 0;
}

function toggleEditorClip(trackId: number, checked: boolean) {
  editorAutoSelectNewClips.value = false;
  selectedEditorTrackIds.value = checked
    ? [...new Set([...selectedEditorTrackIds.value, trackId])]
    : selectedEditorTrackIds.value.filter((id) => id !== trackId);
}

function toggleAllEditorClips() {
  const allIds = availableClips.value.map((clip: any) => clip.trackId);
  const selectAll = selectedEditorTrackIds.value.length !== allIds.length;
  selectedEditorTrackIds.value = selectAll ? allIds : [];
  editorAutoSelectNewClips.value = selectAll;
}

function exportSelectedVideos() {
  if (selectedEditorVideoIds.value.length < 2) return;
  emit('exportVideo', selectedEditorVideoIds.value);
}

function focusEditorClip(clip: any) {
  const index = selectedClips.value.findIndex((item: any) => item.trackId === clip.trackId);
  selectEditorClip(index);
}

function selectEditorClip(index: number) {
  if (index < 0 || index >= selectedClips.value.length) return;
  editorPlayer.value?.pause();
  editorPlaying.value = false;
  playingSequence.value = false;
  activeEditorIndex.value = index;
  restoreEditorPlayer();
}

function stepEditor(delta: number) {
  const nextIndex = activeEditorIndex.value + delta;
  if (nextIndex < 0 || nextIndex >= selectedClips.value.length) return;
  selectEditorClip(nextIndex);
}

function isSelectedVideo(track: any, video: any) {
  return Number(track.selectVideoId) === Number(video.id);
}

function toggleCompare(video: any) {
  if (!['生成成功', '已完成'].includes(video.state)) return;
  if (compareIds.value.includes(video.id)) {
    compareIds.value = compareIds.value.filter((id) => id !== video.id);
  } else if (compareIds.value.length < 2) {
    compareIds.value = [...compareIds.value, video.id];
  }
  if (compareIds.value.length === 2) compareOpen.value = true;
}

function toggleTrack(id: number | undefined, checked: boolean) {
  if (id === undefined) return;
  const trackId = Number(id);
  if (!Number.isFinite(trackId)) return;
  selectedTrackIds.value = checked ? [trackId] : [];
}

function generation(track: any) {
  track.generation ??= {};
  track.generation.audio ??= true;
  const storyboards = trackStoryboards(track);
  const storyboard = storyboards[0];
  track.generation.duration = Number(track.duration || storyboard?.duration || track.generation.duration || 4);
  track.generation.mode ??= defaultVideoGenerationMode(storyboards.length, props.videoMode);
  track.generation.model ??= props.videoModel;
  track.generation.resolution ??= '1080p';
  track.generation.continuityMode ??= track.continuityMode || 'auto';
  return track.generation;
}

async function persistContinuityMode(track: any) {
  const mode = generation(track).continuityMode || 'auto';
  track.continuityMode = mode;
  await updateVideoContinuityMode(track.id, mode);
}

function trackStoryboards(track: any) {
  return storyboardsForTrack(props.storyboards, track?.id);
}

function storyboardMediaForTrack(track: any) {
  const medias = Array.isArray(track?.medias) ? track.medias : [];
  return trackStoryboards(track).map((storyboard: any) => {
    const media = medias.find((item: any) => item.sources === 'storyboard' && Number(item.id) === Number(storyboard.id));
    return {
      ...media,
      id: storyboard.id,
      src: storyboard.filePath || storyboard.src || media?.src,
      fileType: 'image',
      sources: 'storyboard',
      index: storyboard.index,
    };
  });
}

function trackMediaItems(track: any) {
  const storyboardIds = new Set(trackStoryboards(track).map((storyboard: any) => Number(storyboard.id)));
  const references = (Array.isArray(track?.medias) ? track.medias : []).filter(
    (media: any) => media.sources !== 'storyboard' && (!media.storyboardId || storyboardIds.has(Number(media.storyboardId))),
  );
  return [...storyboardMediaForTrack(track), ...references];
}

function storyboardMediaLabel(track: any, media: any) {
  const storyboards = trackStoryboards(track);
  const index = storyboards.findIndex((storyboard: any) => Number(storyboard.id) === Number(media?.id));
  const position = index >= 0 ? index : 0;
  const role = videoFrameRole(position, storyboards.length, generation(track).mode);
  const roleLabel = { first: '首帧', last: '尾帧', firstLast: '首尾帧', reference: '参考' }[role];
  return `P${position + 1} ${roleLabel}`;
}

function referenceMediaLabel(track: any, media: any) {
  const references = trackMediaItems(track).filter((item: any) => item.sources !== 'storyboard');
  const index = references.findIndex((item: any) => item === media);
  return `参考素材 ${index >= 0 ? index + 1 : 1}`;
}

function selectedStoryboard(track: any) {
  generation(track);
  return trackStoryboards(track)[0];
}

function activateTrack(track: any) {
  activeTrackId.value = Number(track.id);
  generation(track);
}

function activateTrackById(trackId: number) {
  const normalizedTrackId = Number(trackId);
  const track = props.tracks.find((item) => Number(item.id) === normalizedTrackId);
  if (track) activateTrack(track);
}

function activateStoryboardTrack(_storyboardId: number, trackId?: number) {
  if (trackId !== undefined) activateTrackById(trackId);
}

function mediaName(media: any, index: number) {
  if (media.name) return media.name;
  if (media.sources === 'storyboard') return `分镜 ${media.index ?? media.id ?? index + 1}`;
  return media.fileType === 'audio' ? `音频 ${index + 1}` : `参考素材 ${index + 1}`;
}

function mediaUrl(media: any) {
  return assetFileUrl(media?.src || media?.imageFilePath || media?.filePath || media?.fileUrl);
}

function videoUrl(video: any) {
  return assetFileUrl(video?.src || video?.filePath || video?.fileUrl);
}

function previewUrl(item: any) {
  return assetFileUrl(item?.imageFilePath || item?.filePath || item?.fileUrl || item?.src);
}

function addReferenceToTrack(track: any, asset: any) {
  const medias = track.medias ?? (track.medias = []);
  if (medias.some((media: any) => media.sources === 'assets' && Number(media.id) === Number(asset.id))) return;
  medias.push({ id: asset.id, name: asset.name, src: previewUrl(asset), fileType: 'image', sources: 'assets', storyboardId: selectedStoryboard(track)?.id });
}

function addReference(asset: any) {
  if (activeTrack.value) addReferenceToTrack(activeTrack.value, asset);
}

function removeReference(track: any, index: number) {
  track.medias?.splice(index, 1);
}

function stateColor(state?: string) {
  if (state === '生成成功' || state === '已完成') return 'green';
  if (state === '生成中') return 'processing';
  if (state === '生成失败') return 'red';
  return 'default';
}

function playSequence() {
  if (!selectedClips.value.length) return;

  const player = editorPlayer.value;
  if (player && !player.paused && !player.ended) {
    player.pause();
    playingSequence.value = false;
    editorPlaying.value = false;
    return;
  }

  if (player?.ended) activeEditorIndex.value = 0;
  playingSequence.value = true;
  restoreEditorPlayer();
}

function handleEditorEnded() {
  editorPlaying.value = false;
  if (!playingSequence.value) return;
  if (activeEditorIndex.value < selectedClips.value.length - 1) {
    activeEditorIndex.value += 1;
  } else {
    playingSequence.value = false;
  }
}

function handleEditorPlay() {
  editorPlaying.value = true;
  playingSequence.value = true;
}

function handleEditorPause() {
  editorPlaying.value = false;
}

function syncEditorVolume() {
  if (editorPlayer.value) editorPlayer.value.volume = editorVolume.value / 100;
}

function restoreEditorPlayer() {
  void nextTick(() => {
    const player = editorPlayer.value;
    if (!player) return;
    editorVideoError.value = false;
    player.pause();
    player.load();
    editorPlaying.value = false;
    syncEditorVolume();
    if (playingSequence.value) {
      void player.play().catch(() => {
        playingSequence.value = false;
        editorPlaying.value = false;
      });
    }
  });
}

function handleEditorLoaded() {
  const player = editorPlayer.value;
  if (!player) return;
  editorVideoError.value = false;
  syncEditorVolume();
  if (!playingSequence.value) {
    player.currentTime = 0;
    player.pause();
    editorPlaying.value = false;
  }
}

function handleEditorError() {
  editorVideoError.value = true;
  playingSequence.value = false;
  editorPlaying.value = false;
}

watch(selectedClips, (clips) => {
  activeEditorIndex.value = Math.min(activeEditorIndex.value, Math.max(0, clips.length - 1));
});
watch(activeTab, (tab) => {
  if (tab === 'generate' || tab === 'editor') emit('refresh');
  if (tab === 'editor') {
    if (!editorSelectionInitialized.value) initializeEditorSelection();
    restoreEditorPlayer();
  }
});
watch([activeTab, activeTrackId], ([tab, trackId]) => {
  emit('stateChange', { tab, trackId: trackId === undefined ? undefined : Number(trackId) });
});
watch(() => props.initialTab, (tab) => {
  if (tab) activeTab.value = tab;
});
watch(() => props.initialTrackId, (trackId) => {
  if (trackId !== undefined) activateTrackById(trackId);
});
watch(activeEditorClip, () => {
  if (activeTab.value === 'editor') restoreEditorPlayer();
});
watch(availableClips, (clips) => {
  const availableIds = new Set(clips.map((clip: any) => clip.trackId));
  selectedEditorTrackIds.value = editorAutoSelectNewClips.value
    ? clips.map((clip: any) => clip.trackId)
    : selectedEditorTrackIds.value.filter((id) => availableIds.has(id));
}, { deep: true, immediate: true });
watch(selectedTrackIds, (ids) => {
  const normalizedIds = ids.map(Number).filter(Number.isFinite);
  const lastId = normalizedIds.at(-1);
  const nextIds = lastId === undefined ? [] : [lastId];
  if (nextIds.length === ids.length && nextIds.every((id, index) => id === ids[index])) return;
  selectedTrackIds.value = nextIds;
}, { deep: true, immediate: true });
watch(() => props.tracks.map((track) => Number(track.id)).filter(Number.isFinite), (ids) => {
  if (!ids.length) {
    selectedTrackIds.value = [];
    trackSelectionInitialized.value = false;
    activeTrackId.value = undefined;
    return;
  }
  const fallbackTrackId = ids[0];
  if (fallbackTrackId === undefined) return;
  const validSelectedIds = [...new Set(selectedTrackIds.value.map(Number).filter((id) => ids.includes(id)))];
  if (!trackSelectionInitialized.value) {
    selectedTrackIds.value = [activeTrackId.value !== undefined && ids.includes(Number(activeTrackId.value)) ? Number(activeTrackId.value) : fallbackTrackId];
    trackSelectionInitialized.value = true;
  } else if (selectedTrackIds.value.length > 0 && validSelectedIds.length === 0) {
    selectedTrackIds.value = [activeTrackId.value !== undefined && ids.includes(Number(activeTrackId.value)) ? Number(activeTrackId.value) : fallbackTrackId];
  } else {
    selectedTrackIds.value = validSelectedIds;
  }
  if (activeTrackId.value === undefined || !ids.includes(Number(activeTrackId.value))) {
    activeTrackId.value = fallbackTrackId;
  }
}, { deep: true, immediate: true });
watch(activeTrackId, (id) => {
  const trackId = id === undefined ? undefined : Number(id);
  if (trackId !== undefined && Number.isFinite(trackId)) {
    selectedTrackIds.value = [trackId];
  }
  const track = props.tracks.find((item) => Number(item.id) === trackId);
  if (track) generation(track);
  compareIds.value = [];
  compareOpen.value = false;
});
watch(editorVolume, (volume) => {
  if (editorPlayer.value) editorPlayer.value.volume = volume / 100;
});

onMounted(async () => {
  try {
    const models = await getModelSimpleList(AiModelTypeEnum.VIDEO);
    videoModelOptions.value = models.map((model) => ({ label: model.name || model.model, value: model.id, supportsAudio: model.config?.capabilities ? (model.config.capabilities as any).audio !== false : true }));
  } catch {
    if (props.videoModel) videoModelOptions.value = [{ label: `项目模型 #${props.videoModel}`, value: props.videoModel, supportsAudio: true }];
  }
});
</script>

<template>
  <div class="toonflow-workbench-shell" lang="zh-CN" translate="no">
    <header class="workbench-topbar">
      <nav class="workbench-tabs" aria-label="视频工作台功能">
        <Tooltip title="分镜图预览">
          <button class="workbench-tab" :class="{ 'workbench-tab--active': activeTab === 'preview' }" type="button" @click="activeTab = 'preview'"><span>▣</span><b>分镜图预览</b></button>
        </Tooltip>
        <Tooltip title="轨道生成">
          <button class="workbench-tab" :class="{ 'workbench-tab--active': activeTab === 'generate' }" type="button" @click="activeTab = 'generate'"><span>▶</span><b>轨道生成</b></button>
        </Tooltip>
        <Tooltip title="剪辑台">
          <button class="workbench-tab" :class="{ 'workbench-tab--active': activeTab === 'editor' }" type="button" @click="activeTab = 'editor'"><span>✂</span><b>剪辑台</b></button>
        </Tooltip>
      </nav>
      <div class="workbench-nav-status">
        <span class="workbench-status-dot" />
        <span>{{ tracks.length }} 条轨道</span>
      </div>
    </header>

    <div class="workbench-content">
      <StoryboardQuickPreview
        v-if="activeTab === 'preview'"
        :assets="assets"
        :storyboards="storyboards"
        @export-images="emit('exportStoryboardImages', $event)"
        @reorder="emit('reorderStoryboards', $event)"
      />

      <div v-else-if="activeTab === 'generate'" class="generation-page">
        <template v-if="activeTrack">
          <section class="generation-main">
            <div class="generation-left-column">
              <div class="generation-player" :class="{ 'has-video': videoUrl(activePreviewVideo) }">
                <video v-if="videoUrl(activePreviewVideo)" :key="activePreviewVideo?.id" :src="videoUrl(activePreviewVideo)" controls disablepictureinpicture disableremoteplayback controlslist="nodownload noplaybackrate" preload="metadata" playsinline />
                <div v-else class="player-placeholder"><span>▶</span><p>生成视频后在这里预览</p></div>
              </div>

              <section class="history-section setting-block history-under-preview">
                <div class="section-heading"><div><b>历史版本</b><span>{{ successfulVideos(activeTrack).length }} 个可用候选 · 选择一个结果作为当前轨道视频</span></div><Tag :color="stateColor(activeTrack.state)">{{ activeTrack.state || '未生成' }}</Tag></div>
                <div v-if="activeTrack.videoList?.length" class="video-grid">
                    <article v-for="(video, versionIndex) in activeTrack.videoList" :key="video.id" class="video-card" :class="{ 'video-card--selected': isSelectedVideo(activeTrack, video) }">
                      <button class="video-preview" type="button" @click="previewVideo = video"><video v-if="videoUrl(video)" :src="videoUrl(video)" muted playsinline preload="metadata" /><div v-else class="video-placeholder">{{ video.state }}</div><Tag class="video-state" :color="stateColor(video.state)">{{ video.state }}</Tag><Tag v-if="video.retryOfId" class="video-retry">重试自 V{{ video.retryOfId }}</Tag></button>
                    <div class="video-actions"><span class="version-label">V{{ Number(versionIndex) + 1 }}</span><Button v-if="['生成成功','已完成'].includes(video.state)" size="small" @click="emit('selectVideo', activeTrack, video)">{{ isSelectedVideo(activeTrack, video) ? '已选中' : '选中' }}</Button><Button v-if="['生成成功','已完成'].includes(video.state)" size="small" :type="compareIds.includes(video.id) ? 'primary' : 'default'" @click="toggleCompare(video)">{{ compareIds.includes(video.id) ? '已加入对比' : '对比' }}</Button><Button v-if="video.state === '生成中'" size="small" @click="emit('cancelVideo', video)">取消</Button><Button v-if="['生成失败','已取消'].includes(video.state)" size="small" @click="emit('retryVideo', video, activeTrack)">重试</Button><Button danger size="small" type="text" @click="emit('deleteVideo', video)">删除</Button></div>
                  </article>
                </div>
                <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="暂无历史版本" />
              </section>
            </div>

            <aside class="generation-settings">
              <section class="setting-block prompt-block">
                <div class="section-heading"><div><b>视频提示词</b><span>描述镜头运动与画面变化</span></div><Button size="small" :loading="activeTrack.promptGenerating" :disabled="activeTrack.promptGenerating" @click="emit('generatePrompt', activeTrack)">{{ activeTrack.promptGenerating ? '生成中…' : 'AI 生成' }}</Button></div>
                <Input.TextArea v-model:value="activeTrack.prompt" :auto-size="{ minRows: 10, maxRows: 16 }" placeholder="输入视频提示词…" />
              </section>

              <section class="setting-block">
                <div class="section-heading"><div><b>轨道分镜与参考素材</b><span>按轨道和分镜顺序查看素材</span></div><Button size="small" @click="addReferenceOpen = true">＋ 添加图片</Button></div>
                <div v-if="trackMediaItems(activeTrack).length" class="media-strip">
                  <article v-for="(media, index) in trackMediaItems(activeTrack)" :key="`${media.sources}-${media.id}-${index}`" class="media-card">
                    <div class="media-preview">
                      <img v-if="media.fileType === 'image' && mediaUrl(media)" :src="mediaUrl(media)" :alt="mediaName(media, Number(index))" class="media-image" />
                      <div v-else-if="media.fileType === 'audio'" class="audio-preview">♪</div>
                      <div v-else class="empty-media">暂无图片</div>
                      <span class="media-order">{{ media.sources === 'storyboard' ? storyboardMediaLabel(activeTrack, media) : referenceMediaLabel(activeTrack, media) }}</span><span class="media-source">{{ media.sources === 'storyboard' ? '分镜' : '参考素材' }}</span>
                    </div>
                    <Button danger size="small" type="text" @click="removeReference(activeTrack, activeTrack.medias.indexOf(media))">删除</Button>
                  </article>
                </div>
                <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="暂无参考素材" />
              </section>

              <section class="setting-block parameter-block">
                <div class="section-heading parameter-heading"><div><b>生成参数</b><span>决定当前轨道的视频输出</span></div><Tag color="blue">{{ videoRatio || '16:9' }}</Tag></div>
                <div class="parameter-grid">
                  <label><span>视频模型</span><Select v-model:value="generation(activeTrack).model" :options="videoModelOptions" placeholder="选择视频模型" size="small" /></label>
                  <label><span>生成模式</span><Select v-model:value="generation(activeTrack).mode" :options="[{label:'纯文本',value:'text'},{label:'单图首帧',value:'singleImage'},{label:'首尾帧',value:'startEndRequired'},{label:'尾帧可选',value:'endFrameOptional'},{label:'首帧可选',value:'startFrameOptional'}]" size="small" /></label>
                  <label><span>镜头衔接</span><Select v-model:value="generation(activeTrack).continuityMode" :options="[{label:'自动判断',value:'auto'},{label:'强制使用上一尾帧',value:'always'},{label:'不使用上一尾帧',value:'never'}]" size="small" @change="persistContinuityMode(activeTrack)" /></label>
                  <label><span>分辨率</span><Select v-model:value="generation(activeTrack).resolution" :options="[{label:'720p',value:'720p'},{label:'1080p',value:'1080p'}]" size="small" /></label>
                  <label class="parameter-field--readonly"><span>分镜时长</span><span class="duration-readonly">{{ generation(activeTrack).duration }} 秒 · 来自分镜</span></label>
                </div>
              <div class="generate-actions"><label v-if="activeModelSupportsAudio" class="audio-setting"><span>生成音频</span><Switch v-model:checked="generation(activeTrack).audio" /></label><span v-else class="audio-unavailable">当前视频模型不支持原生音频</span><Button type="primary" :disabled="(!activeTrack.prompt?.trim() && !selectedStoryboard(activeTrack)?.videoDesc?.trim()) || activeTrack.videoGenerating" :loading="activeTrack.videoGenerating || activeTrack.state === '生成中'" @click="emit('generateVideo', activeTrack)">生成视频</Button></div>
              </section>

            </aside>
          </section>

          <section class="track-filmstrip setting-block">
            <div class="section-heading"><div><b>选择轨道</b><span>{{ selectedTrackCount }} 项已选（单选）</span></div><div class="batch-track-actions"><Button size="small" :disabled="!selectedTracks.length || selectedTracks.some((track:any) => track.promptGenerating)" :loading="selectedTracks.some((track:any) => track.promptGenerating)" @click="emit('batchGeneratePrompts', selectedTracks)">生成提示词</Button><Button size="small" :disabled="!selectedTracks.length || selectedTracks.some((track:any) => track.videoGenerating)" :loading="selectedTracks.some((track:any) => track.videoGenerating)" @click="emit('batchGenerateVideos', selectedTracks)">生成视频</Button><Button size="small" :disabled="!selectedTracks.length" @click="emit('batchDownload', selectedTracks)">下载视频</Button><Button size="small" @click="emit('openTrack', activeTrack.id)">调整分镜</Button></div></div>
            <StoryboardTrackStrip
              :active-track-id="Number(activeTrack.id)"
              :preserve-order="true"
              :selected-track-ids="selectedTrackIds"
              :show-track-checkbox="true"
              :storyboards="storyboards"
              @storyboard-click="activateStoryboardTrack"
              @track-click="activateTrackById"
              @track-toggle="toggleTrack"
            />
          </section>
        </template>
        <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="分镜生成后进入视频工作台" />
      </div>

      <div v-else class="editor-pane">
        <section class="editor-workspace">
          <aside class="editor-media-library">
            <header><div class="editor-panel-title"><b>视频素材</b><small>选择参与合成的片段</small></div><div class="editor-media-header-actions"><Tag>{{ selectedClips.length }} / {{ availableClips.length }}</Tag><Button size="small" type="link" :disabled="!availableClips.length" @click="toggleAllEditorClips">{{ selectedClips.length === availableClips.length ? '取消全选' : '全选' }}</Button></div></header>
            <button v-for="clip in availableClips" :key="clip.trackId" :class="{ active: activeEditorClip?.trackId === clip.trackId }" @click="focusEditorClip(clip)">
              <Checkbox class="editor-clip-check" :checked="selectedEditorTrackIds.includes(Number(clip.trackId))" @click.stop @change="toggleEditorClip(Number(clip.trackId), $event.target.checked)" />
              <video :src="clip.src" muted playsinline autoplay loop preload="auto" disablepictureinpicture /><span>轨道 {{ clip.index + 1 }}.mp4<small>{{ clip.duration }}s</small></span>
            </button>
            <Empty v-if="!availableClips.length" :image="Empty.PRESENTED_IMAGE_SIMPLE" description="暂无视频素材" />
            <Empty v-else-if="!selectedClips.length" :image="Empty.PRESENTED_IMAGE_SIMPLE" description="请选择要合成的视频" />
          </aside>

          <main class="editor-stage">
            <div class="editor-stage-heading"><div><b>片段预览</b><span v-if="activeEditorClip">当前片段 · {{ activeEditorClip.duration }} 秒</span></div><Tag v-if="activeEditorClip" color="blue">{{ activeEditorIndex + 1 }} / {{ selectedClips.length }}</Tag></div>
            <div class="editor-canvas">
              <video v-if="activeEditorClip?.src" :key="activeEditorClip.trackId" ref="editorPlayer" :src="activeEditorClip.src" :autoplay="playingSequence" controls playsinline preload="auto" @ended="handleEditorEnded" @loadeddata="handleEditorLoaded" @error="handleEditorError" @play="handleEditorPlay" @pause="handleEditorPause" />
              <div v-if="editorVideoError" class="editor-video-error"><span>!</span><p>视频资源加载失败，请稍后重试</p><Button size="small" @click="restoreEditorPlayer">重新加载</Button></div>
              <div v-else-if="!activeEditorClip?.src" class="editor-empty"><span class="editor-play">▶</span><p>请先在轨道生成中选中视频</p><Button type="primary" @click="activeTab = 'generate'">进入轨道生成</Button></div>
            </div>
            <div class="editor-transport"><Button shape="circle" :disabled="activeEditorIndex === 0" title="上一段" @click="stepEditor(-1)">◀</Button><Button shape="circle" type="primary" :disabled="!selectedClips.length" :title="editorPlaying ? '暂停播放' : '播放当前片段'" @click="playSequence">{{ editorPlaying ? 'Ⅱ' : '▶' }}</Button><Button shape="circle" :disabled="activeEditorIndex >= selectedClips.length - 1" title="下一段" @click="stepEditor(1)">▶</Button><span class="editor-transport-status"><b>片段 {{ activeEditorIndex + 1 }} / {{ selectedClips.length || 0 }}</b><small>{{ activeEditorClip?.duration || 0 }} 秒</small></span></div>
          </main>

          <aside class="editor-properties">
            <header><div class="editor-panel-title"><b>视频属性</b><small>当前片段设置</small></div></header>
            <label><span>画面比例</span><b>{{ videoRatio || '16:9' }}</b></label>
            <label><span>分辨率</span><b>1080p</b></label>
            <label><span>当前片段</span><b>{{ activeEditorClip?.duration || 0 }}s</b></label>
            <label><span>成片时长</span><b>{{ totalDuration }}s</b></label>
            <div class="volume-control"><span>音量 {{ editorVolume }}%</span><Slider v-model:value="editorVolume" :min="0" :max="100" /></div>
            <Button type="primary" :disabled="selectedClips.length < 2" @click="exportSelectedVideos">合并导出视频</Button>
            <small v-if="selectedClips.length < 2" class="editor-export-hint">至少选择 2 个视频片段</small>
          </aside>
        </section>

        <section class="timeline-panel editor-timeline">
          <div class="timeline-toolbar"><b>主轨道（视频）</b><span>{{ selectedClips.length }} 个片段 · {{ totalDuration }} 秒</span></div>
          <div class="timeline-lane">
            <div class="timeline-lane-label">视频</div>
            <div class="timeline-scroll">
              <div class="timeline-ruler" :style="{ width: timelineContentWidth }"><span v-for="tick in timelineTicks" :key="tick">{{ tick }}s</span></div>
              <div v-if="selectedClips.length" class="clip-track" :style="{ width: timelineContentWidth }">
                <button v-for="(clip,index) in selectedClips" :key="clip.trackId" class="timeline-clip" :class="{ active: activeEditorIndex === index }" :style="timelineClipStyle(clip)" type="button" @click="selectEditorClip(index)"><video :src="clip.src" muted playsinline autoplay loop preload="metadata" disablepictureinpicture /><span>{{ index + 1 }}. 轨道 {{ clip.index + 1 }} · {{ clip.duration }}s</span></button>
              </div>
              <div v-else class="empty-track">暂无可拼接视频片段</div>
            </div>
          </div>
        </section>
      </div>
    </div>

    <Modal v-model:open="previewVideo" width="76vw" :footer="null" title="视频预览" destroy-on-close>
          <video v-if="videoUrl(previewVideo)" :key="previewVideo?.id" :src="videoUrl(previewVideo)" class="preview-player" controls disablepictureinpicture disableremoteplayback controlslist="nodownload noplaybackrate" preload="metadata" playsinline autoplay />
    </Modal>
    <Modal v-model:open="compareOpen" width="90vw" title="候选版本对比" :footer="null" destroy-on-close>
      <div class="compare-grid">
        <article v-for="video in compareVideos" :key="video.id" class="compare-item">
          <div class="compare-heading"><b>候选版本 #{{ video.id }}</b><Tag :color="isSelectedVideo(activeTrack, video) ? 'blue' : 'default'">{{ isSelectedVideo(activeTrack, video) ? '当前版本' : '候选' }}</Tag></div>
          <video v-if="videoUrl(video)" :src="videoUrl(video)" controls preload="metadata" playsinline />
          <Button v-if="!isSelectedVideo(activeTrack, video)" type="primary" @click="emit('selectVideo', activeTrack, video); compareOpen = false">设为当前版本</Button>
        </article>
      </div>
    </Modal>
    <Modal v-model:open="addReferenceOpen" :title="`添加项目资产 · 当前为轨道 ${Math.max(0, tracks.findIndex((track) => track.id === activeTrack?.id) + 1)}`" width="760px" :footer="null">
      <div class="asset-picker">
        <button v-for="asset in referenceAssets" :key="asset.id" type="button" @click="addReference(asset)">
          <img :src="previewUrl(asset)" :alt="asset.name" /><span>{{ asset.name }}</span><b>＋</b>
        </button>
      </div>
    </Modal>
  </div>
</template>

<style scoped>
.toonflow-workbench-shell { display: grid; width: 100%; height: 100%; min-width: 0; min-height: 0; overflow: hidden; grid-template-rows: 64px minmax(0, 1fr); background: var(--ant-color-bg-container); }
.workbench-topbar { display: grid; min-width: 0; align-items: center; border-bottom: 1px solid var(--ant-color-border-secondary); grid-template-columns: minmax(170px, 1fr) auto minmax(170px, 1fr); padding: 0 18px; background: var(--ant-color-bg-container); }
.workbench-nav-status { display: flex; grid-column: 3; align-items: center; gap: 6px; justify-self: end; color: var(--ant-color-text-tertiary); font-size: 11px; }.workbench-status-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--ant-color-success); box-shadow: 0 0 0 3px var(--ant-color-success-bg); }
.workbench-tabs { display: flex; grid-column: 2; height: 100%; align-items: stretch; gap: 4px; justify-self: center; }.workbench-tabs button { position: relative; display: flex; min-width: 96px; align-items: center; justify-content: center; gap: 6px; padding: 0 12px; border: 0; color: var(--ant-color-text-secondary); background: transparent; cursor: pointer; }.workbench-tabs button::after { position: absolute; right: 10px; bottom: 0; left: 10px; height: 3px; border-radius: 3px 3px 0 0; background: transparent; content: ''; }.workbench-tabs button:hover { color: var(--ant-color-primary); background: var(--ant-color-fill-quaternary); }.workbench-tabs button.active { color: var(--ant-color-primary); }.workbench-tabs button.active::after { background: var(--ant-color-primary); }.workbench-tabs span { font-size: 16px; }.workbench-tabs b { font-size: 12px; font-weight: 500; }
.workbench-tabs button.active { color: var(--ant-color-primary); background: var(--ant-color-primary-bg); }
.workbench-tabs button.active span { color: var(--ant-color-primary); }
.workbench-tabs button.active b { color: var(--ant-color-primary); font-weight: 600; }
.workbench-tabs .workbench-tab--active { color: #1677ff !important; background: rgb(22 119 255 / 12%) !important; }
.workbench-tabs .workbench-tab--active::after { background: #1677ff !important; }
.workbench-tabs .workbench-tab--active span, .workbench-tabs .workbench-tab--active b { color: #1677ff !important; }
.workbench-tabs .workbench-tab--active b { font-weight: 700; }
.workbench-content { min-width: 0; min-height: 0; overflow-x: hidden; overflow-y: auto; background: var(--ant-color-bg-layout); }
.toonflow-workbench { display: grid; width: 100%; height: 100%; grid-template-columns: 240px minmax(0, 1fr); overflow: hidden; background: var(--ant-color-bg-layout); }
.editor-pane { width: 100%; height: 100%; overflow-y: auto; padding: 20px 28px; background: var(--ant-color-bg-layout); }
.pane-heading { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }.pane-heading h3 { margin: 0; font-size: 18px; }.pane-heading p { margin: 4px 0 0; color: var(--ant-color-text-tertiary); font-size: 12px; }
.editor-preview { display: grid; width: min(820px, 100%); overflow: hidden; aspect-ratio: 16 / 9; margin: 0 auto 18px; border-radius: 9px; color: #fff; background: #0b0f19; place-items: center; }.editor-preview video { width: 100%; height: 100%; object-fit: contain; }.editor-empty { display: grid; gap: 10px; text-align: center; place-items: center; }.editor-empty p { margin: 0; color: #94a3b8; }.editor-play { display: grid; width: 58px; height: 58px; border-radius: 50%; background: rgb(255 255 255 / 12%); place-items: center; }
.editor-workspace { display: grid; min-height: 480px; overflow: hidden; border: 1px solid var(--ant-color-border-secondary); border-radius: 8px 8px 0 0; grid-template-columns: 210px minmax(0, 1fr) 240px; background: var(--ant-color-bg-container); }
.editor-media-library, .editor-properties { min-width: 0; padding: 12px; background: var(--ant-color-bg-container); }.editor-media-library { overflow-y: auto; border-right: 1px solid var(--ant-color-border-secondary); }.editor-properties { border-left: 1px solid var(--ant-color-border-secondary); }.editor-media-library header, .editor-properties header { display: flex; height: 34px; align-items: center; justify-content: space-between; margin-bottom: 10px; }
.editor-media-library > button { display: grid; width: 100%; min-width: 0; align-items: center; gap: 8px; margin-bottom: 8px; padding: 5px; border: 1px solid transparent; border-radius: 6px; text-align: left; background: var(--ant-color-fill-tertiary); cursor: pointer; grid-template-columns: 68px minmax(0, 1fr); }.editor-media-library > button.active { border-color: var(--ant-color-primary); background: var(--ant-color-primary-bg); }.editor-media-library video { width: 68px; height: 48px; object-fit: cover; background: #000; }.editor-media-library button span { overflow: hidden; font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }.editor-media-library small { display: block; color: var(--ant-color-text-tertiary); }
.editor-media-library > header { min-width: 0; }
.editor-media-header-actions { display: flex; min-width: 0; align-items: center; gap: 4px; }
.editor-media-library > button { position: relative; }
.editor-clip-check { position: absolute; z-index: 2; top: 6px; left: 6px; padding: 3px; border-radius: 4px; background: rgb(255 255 255 / 92%); }
.editor-stage { display: grid; min-width: 0; padding: 18px; background: #eef1f5; grid-template-rows: minmax(0, 1fr) 48px; }.editor-canvas { display: grid; width: 100%; min-height: 0; align-self: center; overflow: hidden; aspect-ratio: 16 / 9; background: #000; place-items: center; }.editor-canvas video { display: block; width: 100%; height: 100%; object-fit: contain; }.editor-transport { display: flex; align-items: center; justify-content: center; gap: 12px; color: var(--ant-color-text-secondary); }.editor-transport span { margin-left: 8px; font-size: 12px; }
.editor-video-error { display: grid; gap: 8px; color: #cbd5e1; text-align: center; place-items: center; }.editor-video-error span { display: grid; width: 42px; height: 42px; border-radius: 50%; color: #fff; background: var(--ant-color-error); font-size: 24px; place-items: center; }.editor-video-error p { margin: 0; }
.editor-properties label { display: flex; align-items: center; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid var(--ant-color-border-secondary); }.editor-properties label span, .volume-control > span { color: var(--ant-color-text-secondary); font-size: 12px; }.volume-control { margin: 18px 0; }.editor-properties > .ant-btn { width: 100%; }
.editor-export-hint { display: block; margin-top: 8px; color: var(--ant-color-text-tertiary); font-size: 11px; text-align: center; }
.editor-timeline { border-top: 0; border-radius: 0 0 8px 8px; }.timeline-clip.active { border-color: #fff; box-shadow: 0 0 0 2px var(--ant-color-primary); }
.timeline-panel { padding: 14px; border: 1px solid var(--ant-color-border-secondary); border-radius: 9px; background: var(--ant-color-bg-container); }.timeline-toolbar, .timeline-ruler { display: flex; align-items: center; justify-content: space-between; }.timeline-toolbar span { color: var(--ant-color-text-tertiary); font-size: 12px; }.timeline-ruler { margin: 12px 0 5px; padding-left: 96px; color: var(--ant-color-text-tertiary); font-size: 10px; }.clip-track { display: flex; min-height: 74px; gap: 2px; padding: 6px 6px 6px 96px; border-radius: 5px; background: var(--ant-color-fill-tertiary); }.timeline-clip { position: relative; min-width: 90px; overflow: hidden; padding: 0; border: 2px solid var(--ant-color-primary); border-radius: 4px; color: #fff; background: #111827; cursor: pointer; }.timeline-clip video { width: 100%; height: 100%; object-fit: cover; opacity: 0.7; }.timeline-clip span { position: absolute; bottom: 3px; left: 5px; font-size: 10px; text-shadow: 0 1px 2px #000; }.empty-track { display: grid; height: 74px; margin-left: 96px; color: var(--ant-color-text-tertiary); background: var(--ant-color-fill-tertiary); place-items: center; }.subtitle-track { display: flex; height: 42px; align-items: center; gap: 22px; margin-top: 5px; padding: 0 12px; border-radius: 5px; background: var(--ant-color-fill-tertiary); }.subtitle-track b { width: 72px; }.subtitle-track span { flex: 1; padding: 4px 8px; border-radius: 3px; color: var(--ant-color-text-secondary); font-size: 11px; background: var(--ant-color-warning-bg); }
.track-sidebar { overflow-y: auto; padding: 12px; border-right: 1px solid var(--ant-color-border-secondary); background: var(--ant-color-bg-container); }
.sidebar-title { display: flex; align-items: center; justify-content: space-between; padding: 4px 4px 12px; }
.sidebar-title span { display: grid; width: 24px; height: 24px; border-radius: 12px; color: var(--ant-color-text-secondary); background: var(--ant-color-fill-secondary); place-items: center; }
.track-tab { display: flex; width: 100%; align-items: center; gap: 10px; margin-bottom: 8px; padding: 10px; border: 1px solid transparent; border-radius: 8px; color: inherit; text-align: left; background: transparent; cursor: pointer; }
.track-tab:hover { background: var(--ant-color-fill-tertiary); }
.track-tab.active { border-color: var(--ant-color-primary-border); background: var(--ant-color-primary-bg); }
.track-number { display: grid; width: 28px; height: 28px; flex: 0 0 28px; border-radius: 6px; color: var(--ant-color-text-secondary); background: var(--ant-color-fill-secondary); place-items: center; }
.track-tab.active .track-number { color: #fff; background: var(--ant-color-primary); }
.track-summary { display: grid; min-width: 0; flex: 1; }
.track-summary small { overflow: hidden; color: var(--ant-color-text-tertiary); font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
.state-dot { width: 7px; height: 7px; flex: 0 0 7px; border-radius: 50%; background: var(--ant-color-text-quaternary); }
.state-green { background: var(--ant-color-success); }.state-processing { background: var(--ant-color-primary); }.state-red { background: var(--ant-color-error); }
.track-workspace { overflow-y: auto; padding: 20px; }
.workspace-header, .section-heading, .prompt-actions, .video-actions { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.workspace-header h3 { margin: 0; font-size: 18px; }.workspace-header p { margin: 3px 0 0; color: var(--ant-color-text-tertiary); font-size: 12px; }
.workbench-section { margin-top: 16px; padding: 16px; border: 1px solid var(--ant-color-border-secondary); border-radius: 10px; background: var(--ant-color-bg-container); }
.section-heading { margin-bottom: 12px; }.section-heading > div { display: flex; align-items: baseline; gap: 10px; }.section-heading span { color: var(--ant-color-text-tertiary); font-size: 12px; }
.media-strip { display: flex; gap: 10px; overflow-x: auto; padding-bottom: 4px; }
.media-card { width: 132px; min-width: 0; flex: 0 0 132px; }.media-preview { position: relative; display: grid; width: 100%; height: auto; overflow: hidden; aspect-ratio: 16 / 9; border-radius: 7px; background: var(--ant-color-fill-secondary); place-items: center; }
.media-preview .media-image, .media-preview video { display: block; width: 100%; height: 100%; }
.media-preview .media-image { max-width: 100%; max-height: 100%; object-fit: scale-down !important; object-position: center; }
.media-preview video { object-fit: cover; }
.media-order, .media-source { position: absolute; top: 6px; padding: 1px 6px; border-radius: 10px; color: #fff; font-size: 10px; background: rgb(0 0 0 / 60%); }.media-order { left: 6px; }.media-source { right: 6px; }
.audio-preview, .empty-media { display: grid; height: 100%; color: var(--ant-color-text-tertiary); place-items: center; }.audio-preview { font-size: 28px; }
.duration-readonly { color: var(--ant-color-text-secondary); font-size: 12px; }
.media-name { overflow: hidden; margin-top: 6px; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.prompt-section :deep(textarea) { resize: none; }.prompt-actions { margin-top: 12px; }.prompt-actions > span { color: var(--ant-color-text-secondary); font-size: 12px; }
.video-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 12px; }
.video-card { overflow: hidden; border: 1px solid var(--ant-color-border-secondary); border-radius: 8px; }
.video-card--selected { border-color: var(--ant-color-primary); box-shadow: 0 0 0 2px var(--ant-color-primary-bg); }
.compare-grid { display:grid; gap:16px; grid-template-columns:repeat(2,minmax(0,1fr)); }.compare-item { padding:12px; border:1px solid var(--ant-color-border-secondary); border-radius:8px; }.compare-heading { display:flex; align-items:center; justify-content:space-between; margin-bottom:10px; }.compare-item video { display:block; width:100%; max-height:60vh; aspect-ratio:16/9; margin-bottom:12px; background:#000; object-fit:contain; }
.video-preview { position: relative; display: grid; width: 100%; overflow: hidden; aspect-ratio: 16 / 9; padding: 0; border: 0; color: #fff; background: #111827; cursor: pointer; place-items: center; }.video-preview video { width: 100%; height: 100%; object-fit: cover; }
.video-placeholder { display: grid; gap: 8px; color: #cbd5e1; font-size: 12px; place-items: center; }.video-state { position: absolute; top: 8px; left: 8px; }.play-mark { position: absolute; display: grid; width: 38px; height: 38px; border-radius: 50%; background: rgb(0 0 0 / 50%); place-items: center; }
.generating-ring { width: 24px; height: 24px; border: 2px solid rgb(255 255 255 / 25%); border-top-color: #fff; border-radius: 50%; animation: spin 0.9s linear infinite; }
.error-reason { margin: 8px 10px 0; color: var(--ant-color-error); font-size: 11px; line-height: 1.4; }.video-actions { justify-content: flex-end; padding: 8px; }.version-label { margin-right: auto; color: var(--ant-color-text-tertiary); font-size: 11px; }
.empty-workbench { grid-column: 1 / -1; align-self: center; }.preview-player { display: block; width: 100%; max-height: 72vh; background: #000; }
.generation-page { display: grid; width: 100%; max-width: 100%; min-width: 0; overflow-x: hidden; gap: 0; padding: 0; box-sizing: border-box; grid-template-rows: auto auto auto; }
.generation-main { display: grid; width: 100%; max-width: 100%; min-width: 0; align-items: stretch; overflow: hidden; gap: 0; grid-template-columns: minmax(0, 56%) minmax(0, 44%); }
.generation-player { position: relative; display: grid; width: calc(100% - 40px); max-width: 100%; min-width: 0; height: auto; min-height: 0; align-self: start; overflow: hidden; aspect-ratio: 16 / 9; margin: 20px; border-radius: 8px; color: #fff; background: #070b12; box-sizing: border-box; place-items: center; }
.generation-player.has-video { display: grid; height: auto; min-height: 0; padding: 6px; }
.generation-player video { position: absolute; inset: 6px; display: block; width: calc(100% - 12px) !important; height: calc(100% - 12px) !important; max-width: calc(100% - 12px); max-height: calc(100% - 12px); object-fit: contain !important; object-position: center !important; background: #000; }
.player-placeholder { display: grid; gap: 10px; color: #94a3b8; text-align: center; place-items: center; }.player-placeholder span { display: grid; width: 64px; height: 64px; border-radius: 50%; background: rgb(255 255 255 / 10%); font-size: 24px; place-items: center; }.player-placeholder p { margin: 0; }
.generation-settings { display: grid; width: 100%; max-width: 100%; min-width: 0; overflow: hidden; gap: 0; padding: 20px; border-left: 1px solid var(--ant-color-border-secondary); background: var(--ant-color-bg-layout); box-sizing: border-box; }.setting-block { min-width: 0; padding: 14px; overflow: hidden; border: 1px solid var(--ant-color-border-secondary); border-radius: 0; background: var(--ant-color-bg-container); box-sizing: border-box; }.setting-block + .setting-block { border-top: 0; }.generation-settings > .setting-block:first-child { border-radius: 8px 8px 0 0; }.generation-settings > .setting-block:last-child { border-radius: 0 0 8px 8px; }.setting-block .section-heading { margin-bottom: 10px; }
.prompt-block :deep(textarea) { min-height: 240px !important; resize: vertical; }
.parameter-grid { display: grid; margin-bottom: 14px; gap: 10px; grid-template-columns: repeat(4, minmax(0, 1fr)); }.parameter-grid label { display: grid; min-width: 0; gap: 5px; }.parameter-grid label > span { color: var(--ant-color-text-secondary); font-size: 12px; }.parameter-grid :deep(.ant-select), .parameter-grid :deep(.ant-input-number) { width: 100%; }
.parameter-grid :deep(.ant-select-selector), .parameter-grid :deep(.ant-select-selection-item) { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.generate-actions { display: flex; align-items: center; justify-content: space-between; gap: 16px; }.generate-actions .audio-setting { display: flex; align-items: center; gap: 9px; color: var(--ant-color-text-secondary); font-size: 12px; }
.track-strip { display: flex; gap: 10px; overflow-x: auto; padding-bottom: 7px; }.track-strip button { position: relative; display: grid; width: 300px; flex: 0 0 300px; overflow: hidden; padding: 5px; border: 2px solid transparent; border-radius: 8px; color: var(--ant-color-text-secondary); background: var(--ant-color-fill-tertiary); cursor: pointer; gap: 5px; }.track-strip button.active { border-color: var(--ant-color-primary); }.track-frame-gallery { display: grid; width: 100%; height: 168px; gap: 3px; border-radius: 5px; background: #111827; }.track-frame { position: relative; display: grid; min-width: 0; overflow: hidden; border-radius: 5px; background: #111827; place-items: center; }.track-frame img { display: block; width: 100%; height: 100%; object-fit: contain; }.track-frame small { position: absolute; right: 4px; bottom: 4px; padding: 1px 4px; border-radius: 8px; color: #fff; font-size: 10px; background: rgb(0 0 0 / 65%); }.track-frame--empty { grid-column: 1 / -1; color: var(--ant-color-text-quaternary); font-size: 10px; }.track-strip > button > span:last-child { overflow: hidden; font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
.generation-page > .history-section, .generation-page > .track-filmstrip { border-right: 0; border-left: 0; border-radius: 0; }
.generation-page > .history-section { border-bottom: 0; }
.batch-track-actions{display:flex;flex-wrap:wrap;justify-content:flex-end;gap:6px}.track-strip button .track-check{position:absolute;z-index:2;top:9px;left:9px;padding:4px;border-radius:5px;background:rgb(255 255 255 / 92%)}
.editor-clip-check :deep(.ant-checkbox-inner) { width: 16px; height: 16px; border: 2px solid #475569; background: #fff; }
.editor-clip-check:hover :deep(.ant-checkbox-inner), .editor-clip-check :deep(.ant-checkbox-input:focus + .ant-checkbox-inner) { border-color: #1677ff; }
.editor-clip-check :deep(.ant-checkbox-checked .ant-checkbox-inner), .editor-clip-check :deep(.ant-checkbox-indeterminate .ant-checkbox-inner) { border-color: #0958d9; background: #0958d9; }
.editor-clip-check :deep(.ant-checkbox-checked .ant-checkbox-inner::after) { border-color: #fff; }
.asset-picker { display: grid; max-height: 65vh; overflow-y: auto; gap: 12px; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); }.asset-picker button { position: relative; display: grid; overflow: hidden; padding: 6px; border: 1px solid var(--ant-color-border-secondary); border-radius: 8px; background: var(--ant-color-bg-container); cursor: pointer; gap: 6px; }.asset-picker button:hover { border-color: var(--ant-color-primary); }.asset-picker img { width: 100%; height: 112px; object-fit: contain; background: var(--ant-color-fill-secondary); }.asset-picker span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }.asset-picker b { position: absolute; top: 10px; right: 10px; display: grid; width: 24px; height: 24px; border-radius: 50%; color: #fff; background: var(--ant-color-primary); place-items: center; }
@keyframes spin { to { transform: rotate(360deg); } }
@media (max-width: 900px) { .toonflow-workbench { grid-template-columns: 1fr; }.track-sidebar { display: flex; overflow-x: auto; border-right: 0; border-bottom: 1px solid var(--ant-color-border-secondary); }.sidebar-title { display: none; }.track-tab { width: 190px; flex: 0 0 190px; }.track-workspace { padding: 12px; } }
@media (max-width: 900px) { .toonflow-workbench-shell { grid-template-rows: 58px minmax(0, 1fr); }.workbench-topbar { grid-template-columns: 1fr auto; padding: 0 12px; }.workbench-tabs { grid-column: 1; justify-self: start; gap: 2px; overflow-x: auto; }.workbench-tabs button { min-width: 96px; padding: 0 10px; }.workbench-nav-status { grid-column: 2; font-size: 10px; } }
@media (max-width: 900px) { .generation-main { grid-template-columns: 1fr; }.generation-player { width: calc(100% - 32px); max-width: none; height: auto; min-height: 260px; aspect-ratio: 16 / 9; margin: 16px; }.generation-settings { padding: 16px; border-top: 1px solid var(--ant-color-border-secondary); border-left: 0; }.parameter-grid { grid-template-columns: 1fr; } }

.toonflow-workbench-shell,
.workbench-content,
.toonflow-workbench,
.track-workspace,
.editor-pane {
  min-width: 0;
  max-width: 100%;
  box-sizing: border-box;
}
.track-strip button { width: 300px; flex-basis: 300px; }
.track-strip img { height: 168px; }
.generation-page { min-height: 100%; grid-template-rows: minmax(0, 1fr) auto; }
.generation-main { min-height: 0; }
.generation-settings { overflow-y: auto; }
.track-filmstrip { align-self: end; }
.generation-player { grid-column: 1; grid-row: 1; }
.history-under-preview { grid-column: 1; grid-row: 2; margin: 0 20px 20px; }
.generation-settings { grid-column: 2; grid-row: 1 / span 2; }

/* Match the storyboard preview: one horizontal strip with per-track storyboard cards. */
.track-strip {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  overflow-x: auto;
  padding-bottom: 7px;
}

.track-strip-group {
  display: flex;
  width: max-content;
  min-width: 0;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 4px;
  padding: 5px;
  border: 2px solid transparent;
  border-radius: 8px;
  background: var(--ant-color-fill-tertiary);
}

.track-strip-group.active {
  border-color: var(--ant-color-primary);
}

.track-strip-group-title {
  display: flex;
  height: 24px;
  align-items: center;
  gap: 8px;
  color: var(--ant-color-text-secondary);
  cursor: pointer;
  white-space: nowrap;
}

.track-strip-group-title .track-check {
  position: static;
  flex: 0 0 auto;
  padding: 2px;
  border-radius: 5px;
  background: rgb(255 255 255 / 92%);
}

.track-strip-group-title > span {
  overflow: hidden;
  max-width: 360px;
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.track-strip-group-items {
  display: flex;
  width: max-content;
  height: 168px;
  gap: 3px;
}

.track-strip .track-shot {
  position: relative;
  display: grid;
  width: 150px;
  height: 168px;
  flex: 0 0 150px;
  overflow: hidden;
  padding: 0;
  border: 0;
  border-radius: 5px;
  background: #111827;
  cursor: pointer;
  place-items: center;
}

.track-strip .track-shot img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.track-shot small {
  position: absolute;
  right: 4px;
  bottom: 4px;
  max-width: calc(100% - 8px);
  overflow: hidden;
  padding: 1px 4px;
  border-radius: 8px;
  color: #fff;
  font-size: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: rgb(0 0 0 / 65%);
}

.track-shot--empty {
  color: var(--ant-color-text-quaternary);
  font-size: 11px;
}
.history-under-preview .video-grid { grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 10px; }
.editor-timeline { min-width: 0; overflow: hidden; }
.timeline-lane { display: grid; min-width: 0; align-items: start; grid-template-columns: 72px minmax(0, 1fr); }
.timeline-lane-label { display: grid; min-height: 74px; align-items: center; padding: 6px 10px; color: var(--ant-color-text-secondary); font-size: 12px; background: var(--ant-color-fill-tertiary); }
.timeline-scroll { min-width: 0; overflow-x: auto; overflow-y: hidden; padding-bottom: 4px; }
.timeline-scroll .timeline-ruler { min-width: 560px; padding-left: 0; box-sizing: border-box; }
.timeline-scroll .clip-track { min-width: 560px; box-sizing: border-box; }
.timeline-scroll .clip-track { padding-left: 6px; }
.timeline-scroll .empty-track { margin-left: 0; }
.timeline-scroll .timeline-clip { flex-grow: 0; flex-shrink: 0; }
.timeline-scroll .timeline-clip > video { pointer-events: none; }

/* Second-pass generation workspace polish. */
.generation-page {
  gap: 12px;
  padding: 12px;
  background: var(--ant-color-bg-layout);
}

.generation-main {
  gap: 12px;
  overflow: visible;
}

.generation-player {
  width: calc(100% - 24px);
  min-height: 260px;
  margin: 12px;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 14px;
  box-shadow: 0 10px 24px rgb(15 23 42 / 8%);
}

.player-placeholder {
  min-height: 220px;
  padding: 24px;
  border: 1px dashed rgb(148 163 184 / 45%);
  border-radius: 12px;
  background: radial-gradient(circle at 50% 35%, rgb(30 41 59 / 72%), rgb(7 11 18 / 96%));
  box-sizing: border-box;
}

.player-placeholder span {
  box-shadow: 0 0 0 8px rgb(255 255 255 / 4%);
}

.generation-settings {
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 14px;
  background: var(--ant-color-bg-container);
  box-shadow: 0 6px 18px rgb(15 23 42 / 6%);
}

.generation-settings > .setting-block,
.generation-settings > .setting-block:first-child,
.generation-settings > .setting-block:last-child {
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 10px;
}

.generation-settings > .setting-block + .setting-block {
  border-top: 1px solid var(--ant-color-border-secondary);
}

.prompt-block :deep(textarea) {
  min-height: 190px !important;
  padding: 10px 12px;
  border-radius: 8px;
  line-height: 1.6;
}

.generate-actions {
  margin-top: 4px;
  padding-top: 12px;
  border-top: 1px dashed var(--ant-color-border-secondary);
}

.generate-actions > .ant-btn {
  min-width: 112px;
  font-weight: 600;
}

.generation-page > .history-section,
.generation-page > .track-filmstrip {
  margin: 0;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 12px;
  background: var(--ant-color-bg-container);
  box-shadow: 0 6px 16px rgb(15 23 42 / 5%);
}

.generation-page > .history-section {
  padding: 14px;
}

.generation-page > .track-filmstrip {
  padding: 14px 14px 10px;
}

.generation-page > .track-filmstrip .section-heading {
  margin-bottom: 10px;
}

.track-strip-group {
  transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
}

.track-strip-group:hover {
  border-color: var(--ant-color-primary-border);
  box-shadow: 0 5px 14px rgb(15 23 42 / 8%);
  transform: translateY(-1px);
}

.track-strip-group.active {
  box-shadow: 0 0 0 2px var(--ant-color-primary-bg), 0 5px 14px rgb(22 119 255 / 12%);
}

.video-card {
  transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
}

.video-card:hover {
  border-color: var(--ant-color-primary-border);
  box-shadow: 0 6px 16px rgb(15 23 42 / 9%);
  transform: translateY(-1px);
}

.video-card--selected {
  box-shadow: 0 0 0 2px var(--ant-color-primary-bg), 0 6px 16px rgb(22 119 255 / 12%);
}

.video-placeholder {
  min-height: 96px;
  background: radial-gradient(circle at 50% 35%, #273449, #111827);
}

.editor-workspace {
  box-shadow: 0 8px 20px rgb(15 23 42 / 6%);
}

.editor-stage {
  background: radial-gradient(circle at 50% 30%, #f8fafc, #e2e8f0);
}

@media (max-width: 900px) {
  .generation-page {
    gap: 8px;
    padding: 8px;
  }

  .generation-main {
    gap: 8px;
  }

  .generation-player {
    width: calc(100% - 16px);
    margin: 8px;
  }

  .generation-settings {
    gap: 8px;
    padding: 8px;
  }

  .generation-page > .history-section,
  .generation-page > .track-filmstrip {
    border-radius: 10px;
  }
}

/* Make generation parameters readable in the narrow settings column. */
.parameter-block {
  padding: 16px;
}

.parameter-heading {
  margin-bottom: 14px;
}

.parameter-heading > div {
  min-width: 0;
}

.parameter-heading > div > span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.parameter-heading :deep(.ant-tag) {
  flex: none;
  margin: 0;
  font-weight: 600;
}

.parameter-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
  margin-bottom: 16px;
}

.parameter-grid label {
  gap: 7px;
  padding: 9px;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 8px;
  background: var(--ant-color-bg-layout);
}

.parameter-grid label > span:first-child {
  color: var(--ant-color-text-secondary);
  font-size: 11px;
  font-weight: 600;
}

.parameter-grid :deep(.ant-select-selector),
.parameter-grid :deep(.ant-input-number) {
  border-radius: 6px;
}

.duration-readonly {
  display: flex;
  min-height: 24px;
  align-items: center;
  padding: 3px 8px;
  overflow: hidden;
  border-radius: 6px;
  color: var(--ant-color-text-secondary);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: var(--ant-color-fill-tertiary);
}

@media (max-width: 900px) {
  .parameter-grid {
    grid-template-columns: 1fr;
  }
}

/* Refine the three editing surfaces without changing the playback model. */
.editor-pane {
  padding: 16px 22px 22px;
}

.editor-workspace {
  min-height: 520px;
  border-radius: 12px 12px 0 0;
  box-shadow: 0 8px 20px rgb(15 23 42 / 6%);
  grid-template-columns: 220px minmax(0, 1fr) 248px;
}

.editor-media-library,
.editor-properties {
  padding: 14px;
}

.editor-media-library header,
.editor-properties header {
  height: auto;
  min-height: 38px;
  align-items: flex-start;
  margin-bottom: 12px;
}

.editor-panel-title {
  display: grid;
  min-width: 0;
  gap: 3px;
}

.editor-panel-title small {
  color: var(--ant-color-text-tertiary);
  font-size: 11px;
}

.editor-media-header-actions {
  align-items: flex-start;
}

.editor-media-header-actions :deep(.ant-tag) {
  margin: 0;
  line-height: 20px;
}

.editor-media-library > button {
  margin-bottom: 8px;
  padding: 6px;
  border-radius: 8px;
  transition: border-color 160ms ease, background 160ms ease, box-shadow 160ms ease, transform 160ms ease;
}

.editor-media-library > button:hover {
  border-color: var(--ant-color-primary-border);
  box-shadow: 0 4px 10px rgb(15 23 42 / 7%);
  transform: translateY(-1px);
}

.editor-media-library > button.active {
  box-shadow: 0 0 0 2px var(--ant-color-primary-bg), 0 4px 10px rgb(22 119 255 / 9%);
}

.editor-stage {
  min-width: 0;
  padding: 14px 18px 12px;
  background: radial-gradient(circle at 50% 20%, #f8fafc, #e2e8f0);
  grid-template-rows: 32px minmax(0, 1fr) 48px;
}

.editor-stage-heading {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.editor-stage-heading > div {
  display: flex;
  min-width: 0;
  align-items: baseline;
  gap: 8px;
}

.editor-stage-heading span {
  overflow: hidden;
  color: var(--ant-color-text-tertiary);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.editor-stage-heading :deep(.ant-tag) {
  margin: 0;
  flex: none;
}

.editor-canvas {
  border: 1px solid rgb(15 23 42 / 12%);
  border-radius: 10px;
  box-shadow: 0 8px 18px rgb(15 23 42 / 12%);
}

.editor-transport {
  height: 42px;
  gap: 8px;
}

.editor-transport :deep(.ant-btn) {
  box-shadow: none;
}

.editor-transport-status {
  display: grid;
  min-width: 56px;
  gap: 2px;
  margin-left: 4px;
  text-align: center;
}

.editor-transport-status b {
  color: var(--ant-color-text-secondary);
  font-size: 11px;
  font-weight: 600;
}

.editor-transport-status small {
  color: var(--ant-color-text-tertiary);
  font-size: 10px;
}

.editor-properties {
  background: linear-gradient(180deg, var(--ant-color-bg-container), var(--ant-color-bg-layout));
}

.editor-properties label {
  padding: 11px 0;
}

.editor-properties label b {
  color: var(--ant-color-text);
  font-size: 12px;
}

.volume-control {
  margin: 16px 0;
  padding: 10px;
  border-radius: 8px;
  background: var(--ant-color-fill-tertiary);
}

.editor-timeline {
  margin-top: 12px;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 0 0 12px 12px;
  box-shadow: 0 6px 16px rgb(15 23 42 / 5%);
}

.timeline-toolbar {
  min-height: 26px;
}

.timeline-clip {
  transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
}

.timeline-clip:hover {
  box-shadow: 0 4px 10px rgb(15 23 42 / 16%);
  transform: translateY(-1px);
}

@media (max-width: 1200px) {
  .editor-workspace {
    grid-template-columns: 190px minmax(0, 1fr) 214px;
  }

  .editor-pane {
    padding-inline: 14px;
  }
}

@media (max-width: 900px) {
  .editor-pane {
    padding: 12px;
  }

  .editor-workspace {
    min-height: 0;
    grid-template-columns: 1fr;
  }

  .editor-media-library {
    max-height: 238px;
    border-right: 0;
    border-bottom: 1px solid var(--ant-color-border-secondary);
  }

  .editor-stage {
    min-height: 390px;
    padding: 12px;
    grid-template-rows: 30px minmax(0, 1fr) 48px;
  }

  .editor-properties {
    border-top: 1px solid var(--ant-color-border-secondary);
    border-left: 0;
  }

  .editor-timeline {
    margin-top: 8px;
    border-radius: 0 0 10px 10px;
  }
}

/* Keep the generation cards in their own columns. The right settings card
 * must not stretch the preview/history column to the same height. */
.generation-page {
  display: block;
  min-height: 0;
  padding: 16px;
  overflow: visible;
  background: var(--ant-color-bg-layout);
}

.generation-main {
  display: grid;
  min-height: 0;
  align-items: start;
  gap: 16px;
  overflow: visible;
  grid-template-columns: minmax(0, 1.12fr) minmax(360px, 0.88fr);
}

.generation-left-column {
  display: grid;
  min-width: 0;
  align-content: start;
  gap: 16px;
}

.generation-player {
  width: 100%;
  min-height: 0;
  margin: 0;
  border-radius: 14px;
}

.history-under-preview {
  grid-column: auto;
  grid-row: auto;
  margin: 0;
}

.generation-settings {
  grid-column: auto;
  grid-row: auto;
  align-self: start;
  max-height: calc(100vh - 142px);
  overflow-y: auto;
}

.generation-page > .track-filmstrip {
  margin-top: 16px;
  align-self: auto;
}

@media (max-width: 1100px) {
  .generation-main {
    grid-template-columns: minmax(0, 1fr) minmax(320px, 0.82fr);
  }
}

@media (max-width: 900px) {
  .generation-page {
    padding: 10px;
  }

  .generation-main {
    grid-template-columns: 1fr;
  }

  .generation-settings {
    max-height: none;
    overflow: visible;
  }

  .generation-page > .track-filmstrip {
    margin-top: 10px;
  }
}
</style>

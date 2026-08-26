<script setup lang="ts">
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onBeforeUnmount, ref, watch } from 'vue';

import {
  Button,
  Card,
  Empty,
  message,
  Modal,
  Skeleton,
  Space,
  Tag,
} from 'ant-design-vue';

import {
  getProjectVideoArchive,
  setEpisodeRenderCurrent,
} from '#/api/toonflow';

import { assetFileUrl } from '../../assets/asset-types';
import { presentEpisodeArchive, renderVersionLabel } from '../video-archive';

interface ProjectDetailContext {
  openProductionForScript: (scriptId: number) => void;
  projectId: number;
}

const props = defineProps<{ context: ProjectDetailContext }>();

const episodes = ref<ToonflowApi.VideoArchiveEpisode[]>([]);
const loading = ref(false);
const settingCurrentId = ref<number>();
const previewEpisode = ref<ToonflowApi.VideoArchiveEpisode>();
const previewRender = ref<ToonflowApi.EpisodeRender>();
let loadGeneration = 0;

const presentedEpisodes = computed(() =>
  episodes.value.map((episode) => presentEpisodeArchive(episode)),
);

function episodeLabel(episode: ToonflowApi.VideoArchiveEpisode) {
  return (episode.episodeNo ?? 0) > 0
    ? `第 ${episode.episodeNo} 集`
    : episode.scriptName;
}

function renderUrl(render?: ToonflowApi.EpisodeRender) {
  return assetFileUrl(render?.url);
}

function posterUrl(render?: ToonflowApi.EpisodeRender) {
  return assetFileUrl(render?.posterUrl ?? undefined);
}

function stateMeta(state: string) {
  const normalized = state.toLocaleLowerCase();
  if (['completed', 'ready', 'success', '生成成功'].includes(normalized)) {
    return { color: 'green', label: '已完成' };
  }
  if (['error', 'failed', '生成失败'].includes(normalized)) {
    return { color: 'red', label: '失败' };
  }
  if (['pending', 'queued', 'running', '生成中'].includes(normalized)) {
    return { color: 'processing', label: '生成中' };
  }
  return { color: 'default', label: state || '未知' };
}

function formatTime(value: number | string) {
  if (!value) return '时间未知';
  const normalized =
    typeof value === 'number' && value < 1_000_000_000_000
      ? value * 1000
      : value;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? '时间未知' : date.toLocaleString();
}

async function loadArchive() {
  const projectId = Number(props.context.projectId);
  const generation = ++loadGeneration;
  if (!Number.isSafeInteger(projectId) || projectId <= 0) {
    episodes.value = [];
    return;
  }
  loading.value = true;
  try {
    const archive = await getProjectVideoArchive(projectId);
    if (generation === loadGeneration) episodes.value = archive.episodes ?? [];
  } catch {
    if (generation === loadGeneration) {
      episodes.value = [];
      message.error('剧集成果加载失败，请稍后重试');
    }
  } finally {
    if (generation === loadGeneration) loading.value = false;
  }
}

function play(
  episode: ToonflowApi.VideoArchiveEpisode,
  render: ToonflowApi.EpisodeRender,
) {
  if (!renderUrl(render)) return message.warning('该版本还没有可播放的视频');
  previewEpisode.value = episode;
  previewRender.value = render;
}

function closePreview() {
  previewEpisode.value = undefined;
  previewRender.value = undefined;
}

function download(
  episode: ToonflowApi.VideoArchiveEpisode,
  render: ToonflowApi.EpisodeRender,
) {
  const url = renderUrl(render);
  if (!url) return message.warning('该版本还没有可下载的视频');
  const link = document.createElement('a');
  link.href = url;
  link.download = `episode-${episode.episodeNo || episode.scriptId}-${renderVersionLabel(render)}.mp4`;
  link.rel = 'noopener';
  link.click();
}

async function makeCurrent(
  episode: ToonflowApi.VideoArchiveEpisode,
  render: ToonflowApi.EpisodeRender,
) {
  if (render.isCurrent || settingCurrentId.value) return;
  settingCurrentId.value = render.id;
  try {
    const updated = await setEpisodeRenderCurrent(render.id);
    episodes.value = episodes.value.map((item) =>
      item.scriptId === episode.scriptId
        ? {
            ...item,
            renders: item.renders.map((candidate) => ({
              ...candidate,
              ...(candidate.id === updated.id ? updated : {}),
              isCurrent: candidate.id === updated.id,
            })),
          }
        : item,
    );
    message.success(
      `${episodeLabel(episode)}已切换到 ${renderVersionLabel(updated)}`,
    );
  } finally {
    settingCurrentId.value = undefined;
  }
}

watch(() => props.context.projectId, loadArchive, { immediate: true });
onBeforeUnmount(() => {
  loadGeneration += 1;
});
</script>

<template>
  <section class="detail-panel archive-panel" aria-labelledby="archive-title">
    <header class="archive-header">
      <div>
        <p class="archive-kicker">PROJECT DELIVERABLES</p>
        <h2 id="archive-title">剧集成果</h2>
        <p>按集管理最终成片与历史版本。切换“当前版本”不会删除任何历史成果。</p>
      </div>
      <Button :loading="loading" @click="loadArchive">刷新成果</Button>
    </header>

    <div v-if="loading && episodes.length === 0" class="archive-loading">
      <Skeleton v-for="item in 2" :key="item" active />
    </div>

    <Empty
      v-else-if="presentedEpisodes.length === 0"
      description="还没有剧集成果。完成视频合成后，成片会按剧集归档在这里。"
    />

    <div v-else class="episode-list">
      <Card
        v-for="episode in presentedEpisodes"
        :key="episode.scriptId"
        :bordered="false"
        class="episode-card"
      >
        <template #title>
          <div class="episode-heading">
            <span class="episode-number">{{ episodeLabel(episode) }}</span>
            <span class="episode-name">{{ episode.scriptName }}</span>
          </div>
        </template>
        <template #extra>
          <Space>
            <Tag>{{ episode.renders.length }} 个版本</Tag>
            <Button
              size="small"
              @click="context.openProductionForScript(episode.scriptId)"
            >
              回到制作
            </Button>
          </Space>
        </template>

        <Empty
          v-if="!episode.featured"
          :description="`${episodeLabel(episode)}尚未生成成片`"
        >
          <template #image>
            <span class="empty-film" aria-hidden="true">▣</span>
          </template>
        </Empty>

        <div v-else class="episode-content">
          <article class="featured-render">
            <button
              class="render-cover render-cover--featured"
              type="button"
              :aria-label="`播放${episodeLabel(episode)} ${renderVersionLabel(episode.featured)}`"
              @click="play(episode, episode.featured)"
            >
              <img
                v-if="posterUrl(episode.featured)"
                :alt="`${episode.scriptName} ${renderVersionLabel(episode.featured)} 海报`"
                :src="posterUrl(episode.featured)"
              />
              <span v-else class="render-placeholder" aria-hidden="true">▶</span>
              <span class="play-label">播放成片</span>
            </button>
            <div class="featured-copy">
              <div class="render-tags">
                <Tag v-if="episode.featured.isCurrent" color="blue">
                  当前版本
                </Tag>
                <Tag v-if="episode.featuredIsLatest" color="purple">
                  最新版本
                </Tag>
                <Tag :color="stateMeta(episode.featured.state).color">
                  {{ stateMeta(episode.featured.state).label }}
                </Tag>
              </div>
              <h3>{{ renderVersionLabel(episode.featured) }}</h3>
              <p>
                更新于
                {{
                  formatTime(
                    episode.featured.updatedAt || episode.featured.createdAt,
                  )
                }}
              </p>
              <p
                v-if="episode.featured.sourceVideoIds.length"
                class="source-count"
              >
                由 {{ episode.featured.sourceVideoIds.length }} 个视频片段合成
              </p>
              <Space wrap>
                <Button type="primary" @click="play(episode, episode.featured)">
                  播放
                </Button>
                <Button @click="download(episode, episode.featured)">
                  下载 MP4
                </Button>
                <Button
                  v-if="!episode.featured.isCurrent"
                  :disabled="
                    episode.featured.state.toLocaleLowerCase() !== 'ready'
                  "
                  :loading="settingCurrentId === episode.featured.id"
                  @click="makeCurrent(episode, episode.featured)"
                >
                  设为当前
                </Button>
              </Space>
            </div>
          </article>

          <section class="history-section" aria-label="历史版本">
            <div class="history-heading">
              <h3>历史版本</h3>
              <span>{{
                episode.history.length ? '可随时恢复为当前版本' : '暂无其他版本'
              }}</span>
            </div>
            <div v-if="episode.history.length" class="history-list">
              <article
                v-for="render in episode.history"
                :key="render.id"
                class="history-render"
              >
                <button
                  class="render-cover render-cover--history"
                  type="button"
                  :aria-label="`播放${renderVersionLabel(render)}`"
                  @click="play(episode, render)"
                >
                  <img
                    v-if="posterUrl(render)"
                    alt=""
                    :src="posterUrl(render)"
                  />
                  <span v-else class="render-placeholder" aria-hidden="true">▶</span>
                </button>
                <div class="history-copy">
                  <div>
                    <b>{{ renderVersionLabel(render) }}</b>
                    <Tag v-if="render.id === episode.latest?.id" color="purple">
                      最新
                    </Tag>
                    <Tag v-if="render.isCurrent" color="blue">当前</Tag>
                  </div>
                  <small>{{
                    formatTime(render.updatedAt || render.createdAt)
                  }}</small>
                </div>
                <Space class="history-actions" size="small">
                  <Button
                    size="small"
                    type="link"
                    @click="play(episode, render)"
                  >
                    播放
                  </Button>
                  <Button
                    size="small"
                    type="link"
                    @click="download(episode, render)"
                  >
                    下载
                  </Button>
                  <Button
                    v-if="!render.isCurrent"
                    :disabled="render.state.toLocaleLowerCase() !== 'ready'"
                    size="small"
                    type="link"
                    :loading="settingCurrentId === render.id"
                    @click="makeCurrent(episode, render)"
                  >
                    设为当前
                  </Button>
                </Space>
              </article>
            </div>
          </section>
        </div>
      </Card>
    </div>

    <Modal
      :footer="null"
      :open="!!previewRender"
      :title="
        previewEpisode && previewRender
          ? `${episodeLabel(previewEpisode)} · ${renderVersionLabel(previewRender)}`
          : '播放成片'
      "
      width="960px"
      @cancel="closePreview"
    >
      <video
        v-if="previewRender"
        :key="previewRender.id"
        autoplay
        class="archive-player"
        controls
        playsinline
        preload="metadata"
        :poster="posterUrl(previewRender)"
        :src="renderUrl(previewRender)"
      ></video>
    </Modal>
  </section>
</template>

<style scoped>
.archive-panel {
  display: grid;
  gap: 18px;
}
.archive-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
  padding: 22px 24px;
  border: 1px solid var(--toon-line, #e8e8e8);
  border-radius: 18px;
  background: linear-gradient(135deg, #fff 55%, #f4f6ff);
}
.archive-header h2 {
  margin: 2px 0 5px;
  font-size: 22px;
}
.archive-header p {
  margin: 0;
  color: var(--ant-color-text-secondary);
}
.archive-kicker {
  color: #5b5bd6 !important;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.14em;
}
.archive-loading {
  display: grid;
  gap: 16px;
  padding: 24px;
  border: 1px solid var(--toon-line, #e8e8e8);
  border-radius: 18px;
  background: #fff;
}
.episode-list {
  display: grid;
  gap: 18px;
}
.episode-card {
  border: 1px solid var(--toon-line, #e8e8e8);
  border-radius: 18px;
  box-shadow: 0 8px 30px rgb(15 23 42 / 5%);
}
.episode-heading {
  display: flex;
  min-width: 0;
  align-items: baseline;
  gap: 10px;
}
.episode-number {
  flex: 0 0 auto;
  font-weight: 800;
}
.episode-name {
  overflow: hidden;
  color: var(--ant-color-text-secondary);
  font-size: 12px;
  font-weight: 400;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.episode-content {
  display: grid;
  grid-template-columns: minmax(300px, 0.9fr) minmax(380px, 1.35fr);
  gap: 22px;
}
.featured-render {
  display: grid;
  grid-template-columns: minmax(180px, 1fr) minmax(150px, 0.8fr);
  gap: 18px;
  padding: 16px;
  border-radius: 14px;
  background: #f7f7f5;
}
.render-cover {
  position: relative;
  overflow: hidden;
  padding: 0;
  border: 0;
  border-radius: 12px;
  color: #fff;
  background: #151515;
  cursor: pointer;
}
.render-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.render-cover--featured {
  min-height: 190px;
  aspect-ratio: 16 / 9;
}
.render-placeholder {
  position: absolute;
  inset: 0;
  display: grid;
  color: rgb(255 255 255 / 90%);
  background: radial-gradient(circle at 40% 35%, #53536d, #17171c 70%);
  font-size: 31px;
  place-items: center;
}
.play-label {
  position: absolute;
  right: 10px;
  bottom: 10px;
  padding: 4px 9px;
  border-radius: 999px;
  background: rgb(0 0 0 / 68%);
  font-size: 11px;
}
.featured-copy {
  align-self: center;
  min-width: 0;
}
.featured-copy h3 {
  margin: 8px 0 2px;
  font-size: 25px;
}
.featured-copy p {
  margin: 0 0 12px;
  color: var(--ant-color-text-secondary);
  font-size: 12px;
}
.featured-copy .source-count {
  margin-top: -5px;
}
.render-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.history-section {
  min-width: 0;
}
.history-heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 10px;
}
.history-heading h3 {
  margin: 0;
  font-size: 14px;
}
.history-heading span {
  color: var(--ant-color-text-tertiary);
  font-size: 11px;
}
.history-list {
  display: grid;
  max-height: 330px;
  gap: 8px;
  overflow-y: auto;
  padding-right: 3px;
}
.history-render {
  display: grid;
  grid-template-columns: 104px minmax(125px, 1fr) auto;
  align-items: center;
  gap: 12px;
  padding: 8px;
  border: 1px solid var(--toon-line, #e8e8e8);
  border-radius: 12px;
}
.render-cover--history {
  width: 104px;
  aspect-ratio: 16 / 9;
}
.render-cover--history .render-placeholder {
  font-size: 16px;
}
.history-copy {
  min-width: 0;
}
.history-copy > div {
  display: flex;
  align-items: center;
  gap: 5px;
}
.history-copy small {
  display: block;
  overflow: hidden;
  margin-top: 4px;
  color: var(--ant-color-text-tertiary);
  text-overflow: ellipsis;
  white-space: nowrap;
}
.history-actions {
  justify-self: end;
}
.archive-player {
  display: block;
  width: 100%;
  max-height: 72vh;
  border-radius: 10px;
  background: #000;
}
.empty-film {
  display: grid;
  width: 64px;
  height: 50px;
  color: #9ca3af;
  font-size: 32px;
  place-items: center;
}
@media (max-width: 1100px) {
  .episode-content {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 720px) {
  .archive-header,
  .featured-render {
    grid-template-columns: 1fr;
  }
  .archive-header {
    flex-direction: column;
  }
  .history-render {
    grid-template-columns: 88px 1fr;
  }
  .render-cover--history {
    width: 88px;
  }
  .history-actions {
    grid-column: 1 / -1;
    justify-self: start;
  }
}
</style>

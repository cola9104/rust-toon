<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';

import VideoWorkbenchPanel from './VideoWorkbenchPanel.vue';
import { useProjectDetail } from './detail/useProjectDetail';
import { normalizeProductionDocument } from './production-flow-document';

import '../styles/toon-theme.css';

type WorkbenchTab = 'preview' | 'generate' | 'editor';

defineOptions({ name: 'ToonflowVideoWorkbench' });

const route = useRoute();
const router = useRouter();
const view = useProjectDetail();
const context = view.panelContext;

const storyboardPlan = computed(() => {
  try {
    const flow = JSON.parse(String(context.flowText || '{}'));
    return normalizeProductionDocument(flow.storyboardTable, 'storyboardTable');
  } catch {
    return '';
  }
});

const initialTab = computed<WorkbenchTab>(() => {
  const tab = String(route.query.tab || '');
  return ['preview', 'generate', 'editor'].includes(tab) ? (tab as WorkbenchTab) : 'preview';
});

const initialTrackId = computed(() => {
  const trackId = Number(route.query.trackId);
  return Number.isSafeInteger(trackId) && trackId > 0 ? trackId : undefined;
});

function replaceWorkbenchQuery(updates: Record<string, string | undefined>) {
  const query = { ...route.query, ...updates };
  Object.keys(query).forEach((key) => {
    if (query[key] === undefined) delete query[key];
  });
  void router.replace({ query });
}

function updateWorkbenchState(state: { tab: WorkbenchTab; trackId?: number }) {
  replaceWorkbenchQuery({
    tab: state.tab,
    trackId: state.trackId ? String(state.trackId) : undefined,
  });
}

watch(
  () => context.selectedScriptId,
  (scriptId) => {
    replaceWorkbenchQuery({ scriptId: scriptId ? String(scriptId) : undefined });
  },
);
</script>

<template>
  <Page auto-content-height class="toon-page">
    <div class="toonflow-video-workbench-route">
      <div class="workbench-panel-frame">
        <VideoWorkbenchPanel
          :assets="context.productionAssets"
          :initial-tab="initialTab"
          :initial-track-id="initialTrackId"
          :storyboard-plan="storyboardPlan"
          :storyboards="context.storyboards"
          :tracks="context.videoTracks"
          :video-mode="context.videoMode"
          :video-model="context.project?.videoModel"
          :video-ratio="context.project?.videoRatio"
          @batch-download="context.downloadSelectedVideos"
          @batch-generate-prompts="context.generateSelectedVideoPrompts"
          @batch-generate-videos="context.generateSelectedVideos"
          @cancel-video="context.cancelVideo"
          @delete-video="context.removeVideo"
          @export-storyboard-images="context.downloadSelectedStoryboardImages"
          @export-video="context.exportVideo"
          @generate-prompt="context.createVideoPrompt"
          @generate-video="context.generateVideo"
          @open-track="context.openVideoTrack"
          @refresh="context.loadFlow"
          @reorder-storyboards="context.saveStoryboardOrder"
          @retry-video="context.retryVideo"
          @save-prompt="context.saveTrackPrompt"
          @select-video="context.chooseVideo"
          @state-change="updateWorkbenchState"
        />
      </div>
    </div>
  </Page>
</template>

<style scoped>
.toonflow-video-workbench-route {
  display: flex;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  flex-direction: column;
  gap: 0;
  overflow: hidden;
}

.workbench-panel-frame {
  display: flex;
  min-width: 0;
  min-height: 0;
  flex: 1;
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 16px;
  background: var(--ant-color-bg-container);
  box-shadow: 0 8px 24px rgb(15 23 42 / 6%);
}

.workbench-panel-frame :deep(.toonflow-workbench-shell) {
  border-radius: 15px;
}

@media (max-width: 900px) {
  .toonflow-video-workbench-route {
    overflow-y: auto;
  }

  .workbench-panel-frame {
    min-height: 560px;
    flex: none;
  }
}
</style>

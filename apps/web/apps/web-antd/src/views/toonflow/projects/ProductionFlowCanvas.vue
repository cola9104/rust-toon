<script lang="ts" setup>
import type { Edge, Node } from '@vue-flow/core';
import type { ToonflowApi } from '#/api/toonflow';

import { computed } from 'vue';

import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { Handle, Position, VueFlow } from '@vue-flow/core';
import { Empty, Tag } from 'ant-design-vue';

import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

import { assetFileUrl } from '../assets/asset-types';
import ProductionAssetStrip from './ProductionAssetStrip.vue';

const props = defineProps<{
  assets: ToonflowApi.Asset[];
  flowText: string;
  script?: ToonflowApi.Script;
  storyboards: ToonflowApi.Storyboard[];
}>();

const emit = defineEmits<{
  editAsset: [asset: ToonflowApi.Asset];
}>();

const flowData = computed<Record<string, any>>(() => {
  try {
    return JSON.parse(props.flowText || '{}');
  } catch {
    return {};
  }
});

const directorPlan = computed(() =>
  textValue(flowData.value.scriptPlan || flowData.value.directorPlan),
);
const storyboardPlan = computed(() =>
  textValue(flowData.value.storyboardTable || flowData.value.storyboard),
);
const nodes = computed<Node[]>(() => [
  { id: 'script', type: 'script', position: { x: 40, y: 40 }, data: {} },
  { id: 'assets', type: 'assets', position: { x: 40, y: 390 }, data: {} },
  { id: 'director', type: 'director', position: { x: 1080, y: 40 }, data: {} },
  { id: 'storyboard-table', type: 'storyboardTable', position: { x: 1680, y: 40 }, data: {} },
  { id: 'storyboard', type: 'storyboard', position: { x: 2440, y: 40 }, data: {} },
]);

const edges: Edge[] = [
  { id: 'script-assets', source: 'script', target: 'assets', animated: true },
  { id: 'assets-director', source: 'assets', target: 'director', animated: true },
  { id: 'director-storyboard-table', source: 'director', target: 'storyboard-table', animated: true },
  { id: 'storyboard-table-panel', source: 'storyboard-table', target: 'storyboard', animated: true },
];

function textValue(value: any) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return JSON.stringify(value, null, 2);
}

function shortText(value: string, limit = 1800) {
  return value.length > limit ? `${value.slice(0, limit)}…` : value;
}
</script>

<template>
  <div class="production-flow-shell">
    <VueFlow
      :nodes="nodes"
      :edges="edges"
      :min-zoom="0.35"
      :max-zoom="1.4"
      :default-viewport="{ x: 20, y: 20, zoom: 0.68 }"
      :nodes-draggable="false"
      :nodes-connectable="false"
      class="production-flow"
    >
      <Background :gap="18" :size="1" pattern-color="#cbd5e1" />
      <Controls position="bottom-left" />

      <template #node-script>
        <section class="flow-stage-node stage-script">
          <Handle type="source" :position="Position.Right" />
          <header class="stage-header">
            <div><span class="stage-index">1</span> 已选剧本</div>
            <Tag :color="script ? 'green' : 'default'">{{ script ? '已就绪' : '等待选择' }}</Tag>
          </header>
          <div v-if="script" class="script-body">
            <h3>{{ script.name }}</h3>
            <pre>{{ shortText(script.content) }}</pre>
          </div>
          <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="请先选择需要制作的剧本" />
        </section>
      </template>

      <template #node-assets>
        <section class="flow-stage-node stage-assets" :class="{ waiting: !script }">
          <Handle type="target" :position="Position.Top" />
          <Handle type="source" :position="Position.Right" />
          <header class="stage-header simple-header">
            <div><span class="stage-index">2</span> 原资产与人物衍生资产</div>
            <Tag :color="assets.length ? 'green' : 'gold'">
              {{ assets.length ? '资产已载入' : '等待 Agent 分析' }}
            </Tag>
          </header>
          <ProductionAssetStrip :assets="assets" @edit="emit('editAsset', $event)" />
        </section>
      </template>

      <template #node-director>
        <section class="flow-stage-node stage-text stage-director" :class="{ waiting: !directorPlan }">
          <Handle type="target" :position="Position.Left" />
          <Handle type="source" :position="Position.Right" />
          <header class="stage-header">
            <div><span class="stage-index">3</span> 导演规划</div>
            <Tag :color="directorPlan ? 'green' : 'processing'">
              {{ directorPlan ? 'Agent 已完成' : '等待 Agent 输出' }}
            </Tag>
          </header>
          <pre v-if="directorPlan">{{ shortText(directorPlan) }}</pre>
          <div v-else class="stage-waiting">Agent 将根据剧本和人物资产生成导演规划</div>
        </section>
      </template>

      <template #node-storyboardTable>
        <section class="flow-stage-node stage-table" :class="{ waiting: !storyboardPlan }">
          <Handle type="target" :position="Position.Left" />
          <Handle type="source" :position="Position.Right" />
          <header class="stage-header">
            <div><span class="stage-index">4</span> 分镜表</div>
            <Tag :color="storyboardPlan ? 'green' : 'processing'">
              {{ storyboardPlan ? 'Agent 已完成' : '等待 Agent 输出' }}
            </Tag>
          </header>
          <pre v-if="storyboardPlan" class="table-content">{{ shortText(storyboardPlan, 5200) }}</pre>
          <div v-else class="stage-waiting">导演规划确认后，Agent 将构建结构化分镜表</div>
        </section>
      </template>

      <template #node-storyboard>
        <section class="flow-stage-node stage-storyboard" :class="{ waiting: !storyboards.length }">
          <Handle type="target" :position="Position.Left" />
          <header class="stage-header">
            <div><span class="stage-index">5</span> 分镜面板与分镜图</div>
            <Tag :color="storyboards.length ? 'green' : 'processing'">
              {{ storyboards.length ? `${storyboards.length} 个分镜` : '等待 Agent 输出' }}
            </Tag>
          </header>
          <div v-if="storyboards.length" class="storyboard-grid">
            <article v-for="item in storyboards" :key="item.id" class="storyboard-card">
              <div class="storyboard-cover">
                <img
                  v-if="item.filePath || item.src"
                  :src="assetFileUrl(item.filePath || item.src)"
                  :alt="`分镜 ${item.index}`"
                />
                <span v-else>{{ item.state === '生成中' ? '生成中…' : '等待图片' }}</span>
                <Tag class="storyboard-index" color="blue">{{ item.index ?? item.id }}</Tag>
              </div>
              <div class="storyboard-card-body">
                <b>{{ item.track || '默认轨道' }} · {{ item.duration || 0 }}s</b>
                <p>{{ item.videoDesc || item.prompt || '等待 Agent 写入描述' }}</p>
              </div>
            </article>
          </div>
          <div v-else class="stage-waiting">
            分镜表确认后，Agent 将写入分镜面板并按需生成图片
          </div>
        </section>
      </template>
    </VueFlow>
  </div>
</template>

<style scoped>
.production-flow-shell {
  height: calc(100vh - 250px);
  min-height: 720px;
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 10px;
  background: var(--ant-color-bg-layout);
}

.production-flow {
  width: 100%;
  height: 100%;
}

.flow-stage-node {
  width: 520px;
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 12px;
  background: var(--ant-color-bg-container);
  box-shadow: 0 8px 24px rgb(15 23 42 / 8%);
}

.flow-stage-node.waiting {
  border-style: dashed;
}

.stage-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-bottom: 1px solid var(--ant-color-border-secondary);
  font-weight: 600;
}

.simple-header {
  border-bottom: 0;
}

.stage-index {
  display: inline-flex;
  width: 24px;
  height: 24px;
  align-items: center;
  justify-content: center;
  margin-right: 8px;
  border-radius: 50%;
  color: #fff;
  font-size: 12px;
  background: var(--ant-color-primary);
}

.stage-script {
  width: 920px;
  min-height: 250px;
}

.stage-assets {
  width: 920px;
}

.stage-director {
  width: 520px;
}

.stage-table {
  width: 680px;
  min-height: 720px;
}

.stage-storyboard {
  width: 760px;
  min-height: 620px;
}

.script-body,
.stage-text,
.stage-storyboard {
  min-height: 220px;
}

.script-body {
  padding: 12px 16px 16px;
}

.script-body h3 {
  margin: 0 0 8px;
  font-size: 15px;
}

pre {
  max-height: 220px;
  overflow: auto;
  margin: 0;
  padding: 14px 16px;
  color: var(--ant-color-text-secondary);
  font-family: inherit;
  font-size: 12px;
  line-height: 1.7;
  white-space: pre-wrap;
}

.stage-waiting {
  display: flex;
  min-height: 150px;
  align-items: center;
  justify-content: center;
  color: var(--ant-color-text-tertiary);
}

.storyboard-list {
  max-height: 300px;
  overflow: auto;
  padding: 10px 14px 14px;
}

.table-content {
  max-height: 650px;
}

.storyboard-grid {
  display: grid;
  max-height: 700px;
  overflow: auto;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  padding: 12px;
}

.storyboard-card {
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 7px;
  background: var(--ant-color-bg-container);
}

.storyboard-cover {
  position: relative;
  display: flex;
  height: 110px;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  color: var(--ant-color-text-tertiary);
  font-size: 12px;
  background: var(--ant-color-fill-quaternary);
}

.storyboard-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.storyboard-index {
  position: absolute;
  top: 5px;
  left: 5px;
  margin: 0;
}

.storyboard-card-body {
  padding: 7px 8px;
  font-size: 11px;
}

.storyboard-card-body p {
  display: -webkit-box;
  overflow: hidden;
  margin: 4px 0 0;
  color: var(--ant-color-text-tertiary);
  line-height: 15px;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.storyboard-item {
  display: grid;
  grid-template-columns: 50px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
  border-bottom: 1px solid var(--ant-color-border-secondary);
  font-size: 12px;
}

.storyboard-item span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

:deep(.vue-flow__edge-path) {
  stroke: var(--ant-color-primary);
  stroke-width: 2;
}

:deep(.vue-flow__handle) {
  width: 10px;
  height: 10px;
  border: 2px solid #fff;
  background: var(--ant-color-primary);
}
</style>

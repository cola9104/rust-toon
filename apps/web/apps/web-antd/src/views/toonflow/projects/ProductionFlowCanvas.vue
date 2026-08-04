<script lang="ts" setup>
import type { Connection, Edge, Node } from '@vue-flow/core';
import type { ToonflowApi, WorkflowNodeRun } from '#/api/toonflow';
import type { ProductionWorkflowDefinition } from './production-workflow';

import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';
import { Handle, Position, VueFlow } from '@vue-flow/core';
import {
  Button,
  Descriptions,
  Drawer,
  Empty,
  Form,
  Input,
  InputNumber,
  message,
  Modal,
  Select,
  Space,
  Switch,
  Tag,
  Typography,
} from 'ant-design-vue';

import { validateWorkflow } from '#/api/toonflow';
import { MarkdownView } from '#/components/markdown-view';

import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

import ProductionAssetStrip from './ProductionAssetStrip.vue';
import { normalizeProductionDocument } from './production-flow-document';
import {
  defaultProductionWorkflow,
  normalizeProductionWorkflow,
  workflowHasCycle,
  workflowPath,
  workflowNodeMeta,
  workflowNodeViewType,
} from './production-workflow';
import StoryboardPanel from './StoryboardPanel.vue';
import VideoWorkbenchPanel from './VideoWorkbenchPanel.vue';

const props = defineProps<{
  assets: ToonflowApi.Asset[];
  storyboardBusy?: boolean;
  storyboardProgressCurrent?: number;
  storyboardProgressTotal?: number;
  storyboardRunState?: string;
  flowText: string;
  imageModel?: number;
  imageQuality?: string;
  script?: ToonflowApi.Script;
  storyboards: ToonflowApi.Storyboard[];
  videoMode?: string;
  videoModel?: number;
  videoRatio?: string;
  videoTracks: any[];
  workflowNodeRuns?: Record<string, WorkflowNodeRun>;
}>();

const emit = defineEmits<{
  batchDeleteStoryboards: [ids: number[]];
  cancelStoryboards: [];
  cancelNode: [nodeId: string];
  cancelTrackVideo: [video: any];
  deleteTrackVideo: [video: any];
  editAsset: [asset: ToonflowApi.Asset];
  editStoryboard: [storyboard: ToonflowApi.Storyboard];
  editStoryboardImage: [storyboard: ToonflowApi.Storyboard];
  exportStoryboardImages: [ids: number[]];
  exportVideo: [];
  generateStoryboards: [ids: number[], compulsory: boolean];
  insertStoryboardAfter: [storyboard: ToonflowApi.Storyboard];
  generateTrackVideo: [track: any];
  generateVideoPrompt: [track: any];
  openVideoTrack: [trackId: number];
  retryStoryboards: [];
  retryNode: [nodeId: string];
  retryTrackVideo: [video: any, track: any];
  runNode: [nodeId: string, config: Record<string, unknown>];
  runSequence: [nodeIds: string[]];
  savePositions: [positions: Record<string, { x: number; y: number }>];
  saveWorkflow: [workflow: ProductionWorkflowDefinition];
  saveVideoPrompt: [track: any];
  selectTrackVideo: [track: any, video: any];
  updateFlowSection: [key: 'scriptPlan' | 'storyboardTable', value: string];
  removeStoryboard: [storyboard: ToonflowApi.Storyboard];
  reorderStoryboards: [ids: number[]];
}>();

const flowInstance = ref<any>();
const spacePressed = ref(false);
const editorOpen = ref(false);
const workbenchOpen = ref(false);
const selectedNodeId = ref<string>();
const nodeConfigDraft = ref<Record<string, any>>({});
const editorKey = ref<'scriptPlan' | 'storyboardTable'>('scriptPlan');
const editorValue = ref('');
const flowData = computed<Record<string, any>>(() => {
  try {
    return JSON.parse(props.flowText || '{}');
  } catch {
    return {};
  }
});

const directorPlan = computed(() =>
  normalizeProductionDocument(
    flowData.value.scriptPlan || flowData.value.directorPlan,
    'scriptPlan',
  ),
);
const storyboardPlan = computed(() =>
  normalizeProductionDocument(flowData.value.storyboardTable, 'storyboardTable'),
);
const workbenchCover = computed(() => {
  for (const track of props.videoTracks) {
    const videos = track.videoList ?? track.video_list ?? [];
    const selectedId = track.selectVideoId ?? track.select_video_id ?? track.videoId ?? track.video_id;
    const selected = videos.find((video: any) => video.id === selectedId);
    const available = selected ?? videos.find((video: any) => video.src);
    if (available?.src) return available.src;
  }
  return '';
});
const savedPositions = computed(() =>
  flowData.value.canvas?.layoutVersion === 7 ? flowData.value.canvas.positions || {} : {},
);
const workflow = computed(() => normalizeProductionWorkflow(flowData.value.workflow));
const selectedWorkflowNode = computed(() =>
  workflow.value.nodes.find((node) => node.id === selectedNodeId.value),
);
const selectedNodeMeta = computed(() =>
  workflowNodeMeta(selectedWorkflowNode.value?.type ?? ''),
);

function runtimeState(nodeId: string) {
  const nodeRun = props.workflowNodeRuns?.[nodeId];
  if (nodeRun) {
    if (nodeRun.state === 'running') {
      const progress = nodeRun.progressTotal > 1
        ? ` ${nodeRun.progressCurrent}/${nodeRun.progressTotal}`
        : '';
      return { color: 'processing', label: `运行中${progress}`, state: 'running' };
    }
    if (nodeRun.state === 'failed') return { color: 'red', label: '失败', state: 'failed' };
    if (nodeRun.state === 'cancelled') return { color: 'orange', label: '已取消', state: 'cancelled' };
    if (nodeRun.state === 'success') return { color: 'green', label: '已完成', state: 'success' };
  }
  if (nodeId === 'script') {
    return props.script
      ? { color: 'green', label: '已就绪', state: 'success' }
      : { color: 'default', label: '等待输入', state: 'pending' };
  }
  if (nodeId === 'scriptPlan') {
    return directorPlan.value
      ? { color: 'green', label: '已完成', state: 'success' }
      : { color: 'default', label: '等待运行', state: 'pending' };
  }
  if (nodeId === 'storyboardTable') {
    return storyboardPlan.value
      ? { color: 'green', label: '已完成', state: 'success' }
      : { color: 'default', label: '等待运行', state: 'pending' };
  }
  if (nodeId === 'storyboard') {
    const state = props.storyboardRunState;
    if (state === 'running') return { color: 'processing', label: '运行中', state };
    if (state === 'failed') return { color: 'red', label: '失败', state };
    if (state === 'cancelled') return { color: 'orange', label: '已取消', state };
    if (state === 'success') return { color: 'green', label: '已完成', state };
    return props.storyboards.length > 0
      ? { color: 'blue', label: `${props.storyboards.length} 个分镜`, state: 'ready' }
      : { color: 'default', label: '等待输入', state: 'pending' };
  }
  if (nodeId === 'workbench') {
    const videoCount = props.videoTracks.reduce(
      (total, track) => total + (track.videoList ?? track.video_list ?? []).length,
      0,
    );
    return videoCount > 0
      ? { color: 'green', label: `${videoCount} 个视频`, state: 'success' }
      : { color: 'default', label: '等待输入', state: 'pending' };
  }
  return { color: 'default', label: '未运行', state: 'pending' };
}
const nodes = computed<Node[]>(() =>
  workflow.value.nodes.map((node) => ({
    id: node.id,
    type: workflowNodeViewType(node.type),
    dragHandle: '.dragHandle',
    position: savedPositions.value[node.id] || node.position,
    data: {
      config: node.config,
      meta: workflowNodeMeta(node.type),
      runtime: runtimeState(node.id),
      workflowType: node.type,
    },
  })),
);
const edges = computed<Edge[]>(() =>
  workflow.value.edges.map((edge) => ({
    ...edge,
    animated: false,
    style: { stroke: '#64748b', strokeWidth: 3 },
  })),
);

function selectNode(event: { node: Node }) {
  selectedNodeId.value = event.node.id;
  const node = workflow.value.nodes.find((item) => item.id === event.node.id);
  nodeConfigDraft.value = {
    ...(node?.config ?? {}),
    ...(node?.type === 'storyboard.image'
      ? {
          compulsory: Boolean(node.config?.compulsory),
          concurrentCount: Number(node.config?.concurrentCount ?? 5),
        }
      : {}),
    ...(node?.type === 'director.plan'
      ? { prompt: String(node.config?.prompt ?? '读取当前剧本与资产，生成完整导演规划并写入工作区。') }
      : {}),
    ...(node?.type === 'storyboard.plan'
      ? { prompt: String(node.config?.prompt ?? '读取剧本、资产和导演规划，生成完整分镜表并写入工作区。') }
      : {}),
    ...(node?.type === 'video.generate'
      ? {
          audio: Boolean(node.config?.audio),
          concurrentCount: Number(node.config?.concurrentCount ?? 2),
          resolution: String(node.config?.resolution ?? '1080p'),
        }
      : {}),
  };
}

function saveWorkflow(definition: ProductionWorkflowDefinition) {
  emit('saveWorkflow', definition);
}

function saveNodeConfig(showMessage = true) {
  const selected = selectedWorkflowNode.value;
  if (!selected) return;
  const definition = {
    ...workflow.value,
    nodes: workflow.value.nodes.map((node) =>
      node.id === selected.id ? { ...node, config: { ...nodeConfigDraft.value } } : node,
    ),
  };
  saveWorkflow(definition);
  if (showMessage) message.success('节点配置已保存');
}

function runSelectedNode() {
  const selected = selectedWorkflowNode.value;
  if (!selected || !selectedNodeMeta.value.executable) return;
  saveNodeConfig(false);
  emit('runNode', selected.id, { ...nodeConfigDraft.value });
}

function runSelectedPath(direction: 'downstream' | 'upstream') {
  const selected = selectedWorkflowNode.value;
  if (!selected) return;
  saveNodeConfig(false);
  emit('runSequence', workflowPath(workflow.value, selected.id, direction));
}

function connectNodes(connection: Connection) {
  const source = connection.source;
  const target = connection.target;
  if (!source || !target || source === target) {
    message.warning('不能把节点连接到自身');
    return;
  }
  if (workflow.value.edges.some((edge) => edge.source === source && edge.target === target)) {
    message.info('这两个节点已经连接');
    return;
  }
  if (workflow.value.edges.some((edge) => edge.target === target)) {
    message.warning('一个输入端口只能连接一个上游节点，请先删除原连线');
    return;
  }
  const definition: ProductionWorkflowDefinition = {
    ...workflow.value,
    edges: [
      ...workflow.value.edges,
      { id: `${source}-${target}-${Date.now()}`, source, target },
    ],
  };
  if (workflowHasCycle(definition)) {
    message.error('该连线会形成循环依赖');
    return;
  }
  saveWorkflow(definition);
}

function deleteEdges(deleted: Edge[]) {
  const deletedIds = new Set(deleted.map((edge) => edge.id));
  saveWorkflow({
    ...workflow.value,
    edges: workflow.value.edges.filter((edge) => !deletedIds.has(edge.id)),
  });
}

function arrangeNodes() {
  const defaults = defaultProductionWorkflow();
  const defaultPositions = new Map(defaults.nodes.map((node) => [node.id, node.position]));
  const definition = {
    ...workflow.value,
    nodes: workflow.value.nodes.map((node, index) => ({
      ...node,
      position: defaultPositions.get(node.id) ?? { x: index * 1000, y: 0 },
    })),
  };
  saveWorkflow(definition);
  emit(
    'savePositions',
    Object.fromEntries(definition.nodes.map((node) => [node.id, node.position])),
  );
  window.setTimeout(() => flowInstance.value?.fitView?.({ duration: 350, padding: 0.08 }), 50);
}

async function validateCurrentWorkflow() {
  try {
    const result = await validateWorkflow(workflow.value as unknown as Record<string, any>);
    const labels = result.executionOrder.map((id) =>
      workflowNodeMeta(workflow.value.nodes.find((node) => node.id === id)?.type ?? '').label,
    );
    message.success(`工作流有效：${labels.join(' → ')}`);
  } catch (error) {
    message.error(error instanceof Error ? error.message : '工作流校验失败');
  }
}

function openEditor(key: 'scriptPlan' | 'storyboardTable') {
  editorKey.value = key;
  editorValue.value = key === 'scriptPlan' ? directorPlan.value : storyboardPlan.value;
  editorOpen.value = true;
}
function saveEditor() {
  emit('updateFlowSection', editorKey.value, editorValue.value);
  editorOpen.value = false;
}
function saveNodePositions(event: any) {
  const positions: Record<string, { x: number; y: number }> = {
    ...Object.fromEntries(workflow.value.nodes.map((node) => [node.id, node.position])),
    ...savedPositions.value,
  };
  for (const node of flowInstance.value?.getNodes?.() || []) {
    positions[node.id] = { x: node.position.x, y: node.position.y };
  }
  for (const node of event?.nodes || []) {
    positions[node.id] = { x: node.position.x, y: node.position.y };
  }
  if (event?.node) positions[event.node.id] = event.node.position;
  emit('savePositions', positions);
}

function focusStage(stageId: string) {
  void flowInstance.value?.fitView({
    duration: 350,
    maxZoom: 1,
    nodes: [{ id: stageId }],
    padding: 0.12,
  });
}

defineExpose({ focusStage });

function handleSpaceDown(event: KeyboardEvent) {
  if (event.code !== 'Space' || event.repeat) return;
  const target = event.target as HTMLElement | null;
  if (target?.matches('input, textarea, [contenteditable="true"]')) return;
  event.preventDefault();
  spacePressed.value = true;
}
function handleSpaceUp(event: KeyboardEvent) {
  if (event.code === 'Space') spacePressed.value = false;
}
onMounted(() => {
  window.addEventListener('keydown', handleSpaceDown);
  window.addEventListener('keyup', handleSpaceUp);
});
onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleSpaceDown);
  window.removeEventListener('keyup', handleSpaceUp);
});
</script>

<template>
  <div class="production-flow-shell" :class="{ 'space-panning': spacePressed }">
    <div class="workflow-toolbar">
      <Space :size="6">
        <Typography.Text strong>节点工作流</Typography.Text>
        <Tag>{{ workflow.nodes.length }} 节点</Tag>
        <Tag>{{ workflow.edges.length }} 连线</Tag>
        <Button size="small" @click="flowInstance?.fitView?.({ duration: 350, padding: 0.08 })">
          适应画布
        </Button>
        <Button size="small" @click="arrangeNodes">整理布局</Button>
        <Button size="small" type="primary" ghost @click="validateCurrentWorkflow">校验工作流</Button>
      </Space>
      <Typography.Text type="secondary">拖动端口连接节点 · 选中连线后按 Delete 删除 · 任务提交后由后端持续运行</Typography.Text>
    </div>
    <VueFlow
      :nodes="nodes"
      :edges="edges"
      :min-zoom="0.35"
      :max-zoom="1.4"
      :default-viewport="{ x: 20, y: 82, zoom: 0.68 }"
      :pan-on-scroll="true"
      :zoom-on-scroll="false"
      :nodes-draggable="!spacePressed"
      :pan-on-drag="spacePressed ? [0] : true"
      :nodes-connectable="true"
      :edges-updatable="false"
      :delete-key-code="['Backspace', 'Delete']"
      class="production-flow"
      @connect="connectNodes"
      @edges-delete="deleteEdges"
      @init="flowInstance = $event"
      @node-click="selectNode"
      @node-drag-stop="saveNodePositions"
    >
      <Background :gap="18" :size="1" pattern-color="#cbd5e1" />
      <Controls position="bottom-left" />
      <MiniMap pannable zoomable position="bottom-right" />

      <template #node-default="{ data }">
        <section class="flow-stage-node flow-unknown-node">
          <Handle id="input" type="target" :position="Position.Left" />
          <span class="port-label port-label-input">{{ data.meta.input }}</span>
          <Handle id="output" type="source" :position="Position.Right" />
          <span class="port-label port-label-output">{{ data.meta.output }}</span>
          <header class="stage-header dragHandle">
            <div>自定义节点</div>
            <Tag :color="data.runtime.color">{{ data.runtime.label }}</Tag>
          </header>
          <div class="stage-waiting">当前前端版本尚未注册此节点视图</div>
        </section>
      </template>

      <template #node-script="{ data }">
        <section class="flow-stage-node stage-script">
          <Handle id="output" type="source" :position="Position.Right" />
          <span class="port-label port-label-output">{{ data.meta.output }}</span>
          <header class="stage-header dragHandle">
            <div><span class="stage-index">1</span> 剧本与衍生资产</div>
            <Tag :color="data.runtime.color">{{ data.runtime.label }}</Tag>
          </header>
          <div v-if="script" class="script-body">
            <h3>{{ script.name }}</h3>
            <pre>{{ script.content }}</pre>
          </div>
          <Empty v-else :image="Empty.PRESENTED_IMAGE_SIMPLE" description="请先选择需要制作的剧本" />
          <section class="embedded-assets" :class="{ waiting: !script }">
            <header class="embedded-assets-header">
              <div>衍生资产</div>
              <Tag :color="assets.length ? 'green' : 'gold'">
                {{ assets.length ? '资产已载入' : '等待 Agent 分析' }}
              </Tag>
            </header>
            <ProductionAssetStrip :assets="assets" @edit="emit('editAsset', $event)" />
          </section>
        </section>
      </template>

      <template #node-scriptPlan="{ data }">
        <section class="flow-stage-node stage-text stage-director" :class="{ waiting: !directorPlan }">
          <Handle id="input" type="target" :position="Position.Left" />
          <span class="port-label port-label-input">{{ data.meta.input }}</span>
          <Handle id="output" type="source" :position="Position.Right" />
          <span class="port-label port-label-output">{{ data.meta.output }}</span>
          <header class="stage-header dragHandle">
            <div>导演规划</div>
            <Space>
              <Tag :color="data.runtime.color">{{ data.runtime.label }}</Tag>
              <Button size="small" type="link" @click.stop="openEditor('scriptPlan')">编辑</Button>
            </Space>
          </header>
          <div v-if="directorPlan" class="director-content">
            <MarkdownView :content="directorPlan" />
          </div>
          <div v-else class="stage-waiting">Agent 将根据剧本和人物资产生成导演规划</div>
        </section>
      </template>

      <template #node-storyboardTable="{ data }">
        <section class="flow-stage-node stage-table" :class="{ waiting: !storyboardPlan }">
          <Handle id="input" type="target" :position="Position.Left" />
          <span class="port-label port-label-input">{{ data.meta.input }}</span>
          <Handle id="output" type="source" :position="Position.Right" />
          <span class="port-label port-label-output">{{ data.meta.output }}</span>
          <header class="stage-header dragHandle">
            <div>分镜表</div>
            <Space>
              <Tag :color="data.runtime.color">{{ data.runtime.label }}</Tag>
              <Button size="small" type="link" @click.stop="openEditor('storyboardTable')">编辑</Button>
            </Space>
          </header>
          <div v-if="storyboardPlan" class="storyboard-table-content">
            <MarkdownView :content="storyboardPlan" />
          </div>
          <div v-else class="stage-waiting">导演规划确认后，Agent 将构建结构化分镜表</div>
        </section>
      </template>

      <template #node-storyboard="{ data }">
        <section class="flow-stage-node stage-storyboard" :class="[{ waiting: !storyboards.length }, `runtime-${data.runtime.state}`]">
          <Handle id="input" type="target" :position="Position.Left" />
          <span class="port-label port-label-input">{{ data.meta.input }}</span>
          <Handle id="output" type="source" :position="Position.Right" />
          <span class="port-label port-label-output">{{ data.meta.output }}</span>
          <header class="stage-header dragHandle">
            <div>分镜面板</div>
            <Tag :color="data.runtime.color">{{ data.runtime.label }}</Tag>
          </header>
          <StoryboardPanel
            :busy="storyboardBusy"
            :progress-current="storyboardProgressCurrent"
            :progress-total="storyboardProgressTotal"
            :run-state="storyboardRunState"
            :storyboards="storyboards"
            @batch-delete="emit('batchDeleteStoryboards', $event)"
            @cancel="emit('cancelStoryboards')"
            @edit="emit('editStoryboard', $event)"
            @edit-image="emit('editStoryboardImage', $event)"
            @export-images="emit('exportStoryboardImages', $event)"
            @generate="(ids, compulsory) => emit('generateStoryboards', ids, compulsory)"
            @insert-after="emit('insertStoryboardAfter', $event)"
            @open-track="emit('openVideoTrack', $event)"
            @remove="emit('removeStoryboard', $event)"
            @reorder="emit('reorderStoryboards', $event)"
            @retry="emit('retryStoryboards')"
          />
        </section>
      </template>

      <template #node-workbench="{ data }">
        <section class="flow-stage-node stage-workbench">
          <Handle id="input" type="target" :position="Position.Left" />
          <span class="port-label port-label-input">{{ data.meta.input }}</span>
          <header class="stage-header dragHandle">
            <div>视频工作台</div>
            <Tag :color="data.runtime.color">{{ data.runtime.label }}</Tag>
          </header>
          <div class="workbench-preview" @click.stop="workbenchOpen = true">
            <video v-if="workbenchCover" :src="workbenchCover" muted preload="metadata" />
            <div class="workbench-play" aria-hidden="true"><span /></div>
          </div>
        </section>
      </template>
    </VueFlow>
    <Drawer
      :open="Boolean(selectedWorkflowNode)"
      :title="selectedNodeMeta.label"
      placement="right"
      :width="390"
      @close="selectedNodeId = undefined"
    >
      <div v-if="selectedWorkflowNode" class="node-config-panel">
        <Typography.Paragraph type="secondary">
          {{ selectedNodeMeta.description }}
        </Typography.Paragraph>
        <Descriptions bordered size="small" :column="1">
          <Descriptions.Item label="节点 ID">{{ selectedWorkflowNode.id }}</Descriptions.Item>
          <Descriptions.Item label="节点类型">{{ selectedWorkflowNode.type }}</Descriptions.Item>
          <Descriptions.Item label="运行状态">
            <Tag :color="runtimeState(selectedWorkflowNode.id).color">
              {{ runtimeState(selectedWorkflowNode.id).label }}
            </Tag>
          </Descriptions.Item>
          <Descriptions.Item
            v-if="workflowNodeRuns?.[selectedWorkflowNode.id]?.progressTotal"
            label="执行进度"
          >
            {{ workflowNodeRuns[selectedWorkflowNode.id]!.progressCurrent }} /
            {{ workflowNodeRuns[selectedWorkflowNode.id]!.progressTotal }}
          </Descriptions.Item>
          <Descriptions.Item
            v-if="workflowNodeRuns?.[selectedWorkflowNode.id]?.attempt"
            label="执行次数"
          >
            {{ workflowNodeRuns[selectedWorkflowNode.id]!.attempt }}
          </Descriptions.Item>
        </Descriptions>
        <Typography.Paragraph
          v-if="workflowNodeRuns?.[selectedWorkflowNode.id]?.errorReason"
          class="node-run-error"
          type="danger"
        >
          {{ workflowNodeRuns[selectedWorkflowNode.id]!.errorReason }}
        </Typography.Paragraph>
        <details v-if="workflowNodeRuns?.[selectedWorkflowNode.id]?.output" class="node-run-output">
          <summary>查看节点输出</summary>
          <pre>{{ JSON.stringify(workflowNodeRuns[selectedWorkflowNode.id]!.output, null, 2) }}</pre>
        </details>

        <Form v-if="selectedWorkflowNode.type === 'storyboard.image'" class="node-config-form" layout="vertical">
          <Form.Item label="并发生成数量">
            <InputNumber v-model:value="nodeConfigDraft.concurrentCount" :min="1" :max="10" style="width: 100%" />
          </Form.Item>
          <Form.Item label="强制重新生成">
            <Switch v-model:checked="nodeConfigDraft.compulsory" />
          </Form.Item>
          <Descriptions bordered size="small" :column="1">
            <Descriptions.Item label="图片模型">{{ imageModel || '跟随项目配置' }}</Descriptions.Item>
            <Descriptions.Item label="图片质量">{{ imageQuality || '2K' }}</Descriptions.Item>
            <Descriptions.Item label="画面比例">{{ videoRatio || '16:9' }}</Descriptions.Item>
          </Descriptions>
        </Form>

        <Form
          v-else-if="['director.plan', 'storyboard.plan'].includes(selectedWorkflowNode.type)"
          class="node-config-form"
          layout="vertical"
        >
          <Form.Item label="节点执行指令">
            <Input.TextArea v-model:value="nodeConfigDraft.prompt" :rows="6" />
          </Form.Item>
          <Typography.Text
            v-if="selectedWorkflowNode.type === 'storyboard.plan'"
            type="secondary"
          >
            执行分为两步：生成并复审分镜表，然后自动写入分镜面板。重跑成功后会替换旧面板；失败或取消会保留旧版本。
          </Typography.Text>
        </Form>

        <Form v-else-if="selectedWorkflowNode.type === 'video.generate'" class="node-config-form" layout="vertical">
          <Form.Item label="并发生成数量">
            <InputNumber v-model:value="nodeConfigDraft.concurrentCount" :min="1" :max="10" style="width: 100%" />
          </Form.Item>
          <Form.Item label="分辨率">
            <Select
              v-model:value="nodeConfigDraft.resolution"
              :options="[
                { label: '720p', value: '720p' },
                { label: '1080p', value: '1080p' },
              ]"
            />
          </Form.Item>
          <Form.Item label="生成音频">
            <Switch v-model:checked="nodeConfigDraft.audio" />
          </Form.Item>
          <Descriptions bordered size="small" :column="1">
            <Descriptions.Item label="视频模型">{{ videoModel || '跟随项目配置' }}</Descriptions.Item>
            <Descriptions.Item label="生成模式">{{ videoMode || 'startEndRequired' }}</Descriptions.Item>
            <Descriptions.Item label="视频比例">{{ videoRatio || '16:9' }}</Descriptions.Item>
          </Descriptions>
        </Form>

        <div class="node-config-actions">
          <Button @click="saveNodeConfig()">保存配置</Button>
          <Button @click="runSelectedPath('upstream')">运行到此</Button>
          <Button @click="runSelectedPath('downstream')">从此继续</Button>
          <Button
            v-if="workflowNodeRuns?.[selectedWorkflowNode.id]?.state === 'running'"
            danger
            @click="emit('cancelNode', selectedWorkflowNode.id)"
          >取消</Button>
          <Button
            v-if="['cancelled', 'failed'].includes(workflowNodeRuns?.[selectedWorkflowNode.id]?.state || '')"
            @click="emit('retryNode', selectedWorkflowNode.id)"
          >重试</Button>
          <Button
            type="primary"
            :disabled="!selectedNodeMeta.executable || workflowNodeRuns?.[selectedWorkflowNode.id]?.state === 'running'"
            :loading="workflowNodeRuns?.[selectedWorkflowNode.id]?.state === 'running'"
            @click="runSelectedNode"
          >
            {{ selectedNodeMeta.executable ? '运行此节点' : '运行器待接入' }}
          </Button>
        </div>
      </div>
    </Drawer>
    <Modal
      v-model:open="workbenchOpen"
      :closable="false"
      :footer="null"
      :keyboard="true"
      :mask-closable="false"
      :style="{ top: '0', paddingBottom: '0' }"
      :width="'100vw'"
      wrap-class-name="toonflow-workbench-modal"
    >
      <VideoWorkbenchPanel
        :assets="assets"
        :storyboards="storyboards"
        :tracks="videoTracks"
        :video-mode="videoMode"
        :video-model="videoModel"
        :video-ratio="videoRatio"
        @close="workbenchOpen = false"
        @cancel-video="emit('cancelTrackVideo', $event)"
        @delete-video="emit('deleteTrackVideo', $event)"
        @generate-prompt="emit('generateVideoPrompt', $event)"
        @generate-video="emit('generateTrackVideo', $event)"
        @open-track="emit('openVideoTrack', $event)"
        @retry-video="(video, track) => emit('retryTrackVideo', video, track)"
        @reorder-storyboards="emit('reorderStoryboards', $event)"
        @save-prompt="emit('saveVideoPrompt', $event)"
        @select-video="(track, video) => emit('selectTrackVideo', track, video)"
        @export-storyboard-images="emit('exportStoryboardImages', $event)"
        @export-video="emit('exportVideo')"
      />
    </Modal>
    <Modal v-model:open="editorOpen" :title="editorKey === 'scriptPlan' ? '编辑导演规划' : '编辑分镜表'" width="90vw" @ok="saveEditor">
      <Input.TextArea v-model:value="editorValue" :auto-size="{ minRows: 18, maxRows: 32 }" />
    </Modal>
  </div>
</template>

<style scoped>
.production-flow-shell {
  position: relative;
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
.workflow-toolbar {
  position: absolute;
  z-index: 6;
  top: 12px;
  right: 12px;
  left: 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 10px;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 9px;
  background: color-mix(in srgb, var(--ant-color-bg-container) 92%, transparent);
  box-shadow: 0 6px 20px rgb(15 23 42 / 8%);
  backdrop-filter: blur(8px);
}
.production-flow-shell.space-panning,
.production-flow-shell.space-panning * { cursor: grab !important; }

.flow-stage-node {
  position: relative;
  width: 520px;
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 12px;
  background: var(--ant-color-bg-container);
  box-shadow: 0 8px 24px rgb(15 23 42 / 8%);
}

:deep(.vue-flow__node.selected .flow-stage-node) {
  border-color: var(--ant-color-primary);
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--ant-color-primary) 25%, transparent),
    0 12px 30px rgb(15 23 42 / 12%);
}

.flow-stage-node.runtime-running {
  border-color: var(--ant-color-primary);
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--ant-color-primary) 18%, transparent);
}

.port-label {
  position: absolute;
  z-index: 2;
  top: 48px;
  max-width: 130px;
  overflow: hidden;
  color: var(--ant-color-text-tertiary);
  font-size: 10px;
  line-height: 18px;
  text-overflow: ellipsis;
  white-space: nowrap;
  pointer-events: none;
}

.port-label-input { left: 10px; }
.port-label-output { right: 10px; text-align: right; }

.node-config-form { margin-top: 20px; }
.node-run-error { margin-top: 14px; }
.node-run-output {
  margin-top: 14px;
  padding: 10px 12px;
  border-radius: 8px;
  background: var(--ant-color-fill-quaternary);
}
.node-run-output summary { cursor: pointer; }
.node-run-output pre { max-height: 240px; margin-top: 8px; padding: 0; overflow: auto; }
.node-config-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 24px;
}

.stage-header {
  border-bottom: 0;
}

.stage-header > div:first-child {
  width: fit-content;
  padding: 5px 10px;
  border-radius: 8px 0;
  color: #fff;
  background: #000;
}

.flow-stage-node.waiting {
  border-style: dashed;
}

.stage-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-bottom: 0;
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
  max-width: 920px;
  min-height: 250px;
}

.embedded-assets {
  border-top: 1px solid var(--ant-color-border-secondary);
}

.embedded-assets-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px 4px;
  font-weight: 600;
}

.embedded-assets :deep(.production-assets) {
  border: 0;
  border-radius: 0;
}

.embedded-assets :deep(.production-assets-heading) {
  display: none;
}

.embedded-assets :deep(.production-assets-canvas) {
  width: 100%;
  max-height: none;
  overflow: visible;
}

.stage-director {
  width: fit-content;
  min-width: 200px;
  max-width: 920px;
  overflow: visible;
}

.director-content {
  min-width: 520px;
  margin-top: 8px;
  padding: 0 16px 16px;
  user-select: text;
}

.director-content :deep(.markdown-view) {
  width: auto;
  max-width: 888px;
}

.stage-table {
  width: fit-content;
  min-width: 200px;
  max-width: 920px;
  overflow: visible;
}

.storyboard-table-content {
  min-width: 680px;
  margin-top: 8px;
  padding: 0 16px 16px;
  user-select: text;
}

.storyboard-table-content :deep(.markdown-view) {
  width: auto;
  max-width: 888px;
}

.director-content :deep(.markdown-view),
.storyboard-table-content :deep(.markdown-view) {
  color: var(--ant-color-text);
  font-family: inherit;
  font-size: 14px;
  line-height: 1.7;
}

.director-content :deep(.markdown-view > :first-child),
.storyboard-table-content :deep(.markdown-view > :first-child) {
  margin-top: 0;
}

.director-content :deep(.markdown-view h1),
.director-content :deep(.markdown-view h2),
.director-content :deep(.markdown-view h3),
.storyboard-table-content :deep(.markdown-view h1),
.storyboard-table-content :deep(.markdown-view h2),
.storyboard-table-content :deep(.markdown-view h3) {
  margin: 16px 0 8px;
  color: var(--ant-color-text);
  font-weight: 600;
  line-height: 1.45;
}

.director-content :deep(.markdown-view p),
.storyboard-table-content :deep(.markdown-view p) {
  margin: 0 0 8px;
}

.director-content :deep(.markdown-view ul),
.director-content :deep(.markdown-view ol),
.storyboard-table-content :deep(.markdown-view ul),
.storyboard-table-content :deep(.markdown-view ol) {
  margin: 0 0 10px;
  padding-left: 24px;
  color: var(--ant-color-text);
  font-size: 14px;
  line-height: 1.7;
}

.director-content :deep(.markdown-view li),
.storyboard-table-content :deep(.markdown-view li) {
  margin: 2px 0;
}

.storyboard-table-content :deep(.markdown-view table) {
  display: table;
  width: 100%;
  margin: 8px 0 12px;
  border-collapse: collapse;
  table-layout: auto;
}

.storyboard-table-content :deep(.markdown-view th),
.storyboard-table-content :deep(.markdown-view td) {
  padding: 8px 10px;
  border: 1px solid var(--ant-color-border-secondary);
  vertical-align: top;
  text-align: left;
  white-space: normal;
  overflow-wrap: anywhere;
}

.storyboard-table-content :deep(.markdown-view th) {
  background: var(--ant-color-fill-quaternary);
  font-weight: 600;
  white-space: nowrap;
}

.storyboard-table-content :deep(.markdown-view tr:nth-child(even) td) {
  background: color-mix(in srgb, var(--ant-color-fill-quaternary) 55%, transparent);
}

.stage-storyboard {
  width: 920px;
  max-width: 920px;
}
.stage-workbench {
  width: 320px;
  min-width: 280px;
  cursor: pointer;
  transition: filter 0.1s ease;
}
.stage-workbench:active { filter: brightness(0.92); }
.workbench-preview {
  position: relative;
  display: grid;
  width: calc(100% - 24px);
  overflow: hidden;
  aspect-ratio: 16 / 9;
  margin: 0 12px 12px;
  border-radius: 8px;
  background: var(--ant-color-fill-secondary);
  place-items: center;
}
.workbench-preview video { width: 100%; height: 100%; object-fit: cover; }
.workbench-play {
  position: absolute;
  display: grid;
  width: 58px;
  height: 58px;
  border-radius: 50%;
  background: rgb(0 0 0 / 42%);
  place-items: center;
  transition: transform 0.1s ease;
}
.workbench-play span {
  width: 0;
  height: 0;
  margin-left: 5px;
  border-top: 12px solid transparent;
  border-bottom: 12px solid transparent;
  border-left: 19px solid #fff;
}
.stage-workbench:hover .workbench-play { transform: scale(1.08); }
.dragHandle { cursor: grab; }
.dragHandle:active { cursor: grabbing; }

.script-body,
.stage-text,
.stage-storyboard {
  min-height: 220px;
}

.script-body {
  padding: 12px 16px 16px;
}

.script-body pre {
  max-height: none;
  overflow: visible;
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
  width: 14px;
  height: 14px;
  border: 3px solid #fff;
  background: var(--ant-color-primary);
  box-shadow: 0 0 0 1px var(--ant-color-primary);
}

:deep(.vue-flow__edge.selected .vue-flow__edge-path) {
  stroke: var(--ant-color-error);
  stroke-width: 4;
}

:deep(.vue-flow__minimap) {
  overflow: hidden;
  border: 1px solid var(--ant-color-border-secondary);
  border-radius: 8px;
  background: var(--ant-color-bg-container);
}
</style>

<style>
.toonflow-workbench-modal { overflow: hidden; }
.toonflow-workbench-modal .ant-modal { width: 100vw !important; max-width: 100vw; margin: 0; padding: 0; inset-inline: 0; }
.toonflow-workbench-modal .ant-modal-content { width: 100vw; max-width: 100vw; height: 100vh; padding: 0; overflow: hidden; border-radius: 0; box-sizing: border-box; }
.toonflow-workbench-modal .ant-modal-body { width: 100%; max-width: 100vw; height: 100%; padding: 0; overflow: hidden; box-sizing: border-box; }
</style>

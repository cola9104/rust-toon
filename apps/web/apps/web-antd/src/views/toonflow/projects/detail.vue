<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';

import { Page } from '@vben/common-ui';

import {
  Button,
  Card,
  Col,
  Form,
  Input,
  InputNumber,
  List,
  Modal,
  Popconfirm,
  Row,
  Select,
  Space,
  Statistic,
  Table,
  Tabs,
  Tag,
  Typography,
  message,
} from 'ant-design-vue';

import {
  addNovel,
  addScript,
  addStoryboard,
  addVideoTrack,
  batchBindAudio,
  batchGenerateVideoPrompts,
  batchGenerateVideos,
  clearAgentMemory,
  deleteNovel,
  deleteScripts,
  deleteTrackVideo,
  exportFinalVideo,
  extractScriptAssets,
  getAssets,
  getAgentMemories,
  getAgentRunState,
  getAgentRunEvents,
  getScriptAgentPlan,
  getFlowData,
  getImageFlow,
  generateAssetImage,
  generateAssetDubbing,
  generateFlowImage,
  generateStoryboardImages,
  generateTrackVideo,
  generateVideoPrompt,
  previewStoryboardImages,
  generateNovelEvents,
  getNovelData,
  getProject,
  getProjectStatistics,
  polishAssetPrompt,
  getScripts,
  getStoryboards,
  getVideoWorkbench,
  removeStoryboard,
  reorderVideoTracks,
  retryTrackVideo,
  bindTrackStoryboards,
  cancelTrackVideo,
  startAgent,
  stopAgent,
  retryAgent,
  saveAsset,
  saveFlowData,
  saveImageFlow,
  saveScriptAgentPlan,
  selectTrackVideo,
  updateNovel,
  updateScript,
  updateVideoTrackPrompt,
  updateImageFlow,
  uploadFlowImage,
  uploadMaterial,
} from '#/api/toonflow';
import { router } from '#/router';

const route = useRoute();
const projectId = computed(() => Number(route.params.id));

const activeTab = ref('novel');
const loading = ref(false);
const project = ref<ToonflowApi.Project>();
const statistics = reactive<ToonflowApi.ProjectStatistics>({ roleCount: 0, scriptCount: 0, videoCount: 0, storyboardCount: 0 });
const novels = ref<ToonflowApi.NovelChapter[]>([]);
const scripts = ref<ToonflowApi.Script[]>([]);
const assets = ref<ToonflowApi.Asset[]>([]);
const storyboards = ref<ToonflowApi.Storyboard[]>([]);
const materialInput = ref<HTMLInputElement>();
const selectedScriptId = ref<number>();
const flowText = ref('{\n  "script": "",\n  "storyboard": [],\n  "workbench": { "videoList": [] }\n}');

const novelModalOpen = ref(false);
const scriptModalOpen = ref(false);
const assetModalOpen = ref(false);
const storyboardModalOpen = ref(false);
const flowImageModalOpen = ref(false);
const flowImageResult = ref('');
const imageFlowId = ref<number>();
const imageFlowNodes = ref<any[]>([]);
const imageFlowEdges = ref<any[]>([]);
const flowUploadInput = ref<HTMLInputElement>();
const storyboardPreviewOpen = ref(false);
const storyboardPreview = ref('');
const dubbingModalOpen = ref(false);
const dubbingResult = ref('');
const dubbingForm = reactive({ assetsId: 0, assetName: '', text: '', voice: 'alloy' });
const videoTracks = ref<any[]>([]);
const flowImageForm = reactive({ prompt: '', references: '' });
const agentType = ref<'productionAgent' | 'scriptAgent'>('scriptAgent');
const agentInput = ref('');
const agentSending = ref(false);
const activeAgentRunId = ref<number>();
const agentRunState = ref('idle');
const lastAgentRunId = ref<number>();
const agentStreamText = ref('');
const agentEventCursor = ref(0);
const agentMemories = ref<ToonflowApi.AgentMemory[]>([]);
const agentIsolationKey = computed(() => `${agentType.value}:${projectId.value}:${agentType.value === 'productionAgent' ? (selectedScriptId.value ?? 'none') : 'project'}`);
const scriptPlan = reactive({ storySkeleton: '', adaptationStrategy: '' });

const novelForm = reactive({
  id: undefined as number | undefined,
  index: 1,
  reel: '',
  chapter: '',
  chapterData: '',
  event: '',
});

const batchNovelText = ref('');

const scriptForm = reactive({
  id: undefined as number | undefined,
  name: '',
  content: '',
  assets: [] as number[],
});

const assetForm = reactive({
  id: undefined as number | undefined,
  name: '',
  type: 'role',
  description: '',
  prompt: '',
  remark: '',
});

const storyboardForm = reactive({
  prompt: '',
  duration: 4,
  state: '未生成',
  videoDesc: '',
  shouldGenerateImage: 1,
  track: 'main',
  associateAssetsIds: [] as number[],
});

const scriptOptions = computed(() =>
  scripts.value.map((item) => ({ label: item.name, value: item.id })),
);

const assetOptions = computed(() =>
  assets.value.map((item) => ({ label: `${item.name} (${item.type})`, value: item.id })),
);

const novelColumns = [
  { title: '序号', dataIndex: 'index', width: 80 },
  { title: '分卷', dataIndex: 'reel', width: 140 },
  { title: '章节', dataIndex: 'chapter', width: 180 },
  { title: '事件状态', dataIndex: 'eventState', width: 100 },
  { title: '事件', dataIndex: 'event' },
  { title: '操作', key: 'action', width: 150 },
];

const storyboardColumns = [
  { title: '顺序', dataIndex: 'index', width: 80 },
  { title: '轨道', dataIndex: 'track', width: 100 },
  { title: '时长', dataIndex: 'duration', width: 80 },
  { title: '状态', dataIndex: 'state', width: 100 },
  { title: '提示词', dataIndex: 'prompt' },
  { title: '操作', key: 'action', width: 100 },
];

async function loadProject() {
  const [projectData, statisticData] = await Promise.all([getProject(projectId.value), getProjectStatistics(projectId.value)]);
  project.value = projectData;
  Object.assign(statistics, statisticData);
}

async function loadNovels() {
  novels.value = await getNovelData(projectId.value);
}

async function loadScripts() {
  scripts.value = await getScripts(projectId.value);
  if (!selectedScriptId.value && scripts.value.length > 0) {
    selectedScriptId.value = scripts.value[0]!.id;
  }
}

async function loadAssets() {
  assets.value = await getAssets(projectId.value);
}

async function loadFlow() {
  if (!selectedScriptId.value) {
    flowText.value =
      '{\n  "script": "",\n  "storyboard": [],\n  "workbench": { "videoList": [] }\n}';
    storyboards.value = [];
    return;
  }
  const flow = await getFlowData(projectId.value, selectedScriptId.value);
  flowText.value = JSON.stringify(flow, null, 2);
  storyboards.value = await getStoryboards(projectId.value, selectedScriptId.value);
  const workbench = await getVideoWorkbench(projectId.value, selectedScriptId.value);
  videoTracks.value = workbench.trackList ?? [];
}

async function loadAll() {
  loading.value = true;
  try {
    await Promise.all([loadProject(), loadNovels(), loadScripts(), loadAssets()]);
    await loadFlow();
  } finally {
    loading.value = false;
  }
}

function openNovel(chapter?: any) {
  Object.assign(novelForm, {
    id: chapter?.id,
    index: chapter?.index ?? novels.value.length + 1,
    reel: chapter?.reel ?? '',
    chapter: chapter?.chapter ?? '',
    chapterData: chapter?.chapterData ?? '',
    event: chapter?.event ?? '',
  });
  batchNovelText.value = '';
  novelModalOpen.value = true;
}

async function saveNovel() {
  if (batchNovelText.value.trim()) {
    const chapters = batchNovelText.value
      .split(/\n(?=第.+章|Chapter\s+\d+)/i)
      .map((text, index) => {
        const lines = text.trim().split('\n');
        return {
          index: index + 1,
          reel: '',
          chapter: lines[0] || `第${index + 1}章`,
          chapterData: lines.slice(1).join('\n') || text.trim(),
        };
      })
      .filter((item) => item.chapterData.trim());
    if (chapters.length === 0) {
      message.warning('没有可导入的章节内容');
      return;
    }
    await addNovel(projectId.value, chapters);
  } else if (novelForm.id) {
    await updateNovel({ ...novelForm, id: novelForm.id });
  } else {
    await addNovel(projectId.value, [{ ...novelForm }]);
  }
  novelModalOpen.value = false;
  await loadNovels();
}

async function removeNovel(row: any) {
  await deleteNovel(row.id);
  await loadNovels();
}

async function extractNovelEvents(row: any) {
  await generateNovelEvents(projectId.value, [row.id]);
  message.success('事件提取任务已提交，可在任务中心查看进度');
  window.setTimeout(loadNovels, 2000);
}

function openScript(script?: any) {
  Object.assign(scriptForm, {
    id: script?.id,
    name: script?.name ?? '',
    content: script?.content ?? '',
    assets:
      script?.relatedAssets?.map((item: { id: number; name: string }) => item.id) ??
      [],
  });
  scriptModalOpen.value = true;
}

async function saveScript() {
  if (!scriptForm.name.trim()) {
    message.warning('请输入剧本名称');
    return;
  }
  if (scriptForm.id) {
    await updateScript({
      id: scriptForm.id,
      name: scriptForm.name,
      content: scriptForm.content,
      assets: scriptForm.assets,
    });
  } else {
    const result = await addScript({
      projectId: projectId.value,
      name: scriptForm.name,
      content: scriptForm.content,
      assets: scriptForm.assets,
    });
    selectedScriptId.value = result.id;
  }
  scriptModalOpen.value = false;
  await loadScripts();
  await loadFlow();
}

async function removeScript(script: any) {
  await deleteScripts([script.id]);
  if (selectedScriptId.value === script.id) {
    selectedScriptId.value = undefined;
  }
  await loadScripts();
  await loadFlow();
}

async function extractAssetsFromScript(script: ToonflowApi.Script) {
  await extractScriptAssets(projectId.value, [script.id]);
  message.success('资产提取任务已提交');
  window.setTimeout(async () => {
    await Promise.all([loadScripts(), loadAssets()]);
  }, 3000);
}

async function uploadMaterialFile(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  const base64Data = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
  await uploadMaterial({
    projectId: projectId.value,
    base64Data,
    type: 'clip',
    name: file.name,
  });
  message.success('素材上传成功');
  await loadAssets();
}

function openAsset(asset?: any) {
  Object.assign(assetForm, {
    id: asset?.id,
    name: asset?.name ?? '',
    type: asset?.type ?? 'role',
    description: asset?.description ?? '',
    prompt: asset?.prompt ?? '',
    remark: asset?.remark ?? '',
  });
  assetModalOpen.value = true;
}

async function saveAssetForm() {
  await saveAsset({
    ...assetForm,
    projectId: projectId.value,
  });
  assetModalOpen.value = false;
  await loadAssets();
}

async function polishAsset(asset: any) {
  const result = await polishAssetPrompt({ assetsId: asset.id, projectId: projectId.value, type: asset.type, name: asset.name, describe: asset.description || '' });
  asset.prompt = result.prompt;
  message.success('资产提示词已生成');
  await loadAssets();
}

async function generateAssetPicture(asset: any) {
  if (!project.value?.imageModel) return message.warning('请先在项目配置中选择图片模型');
  await generateAssetImage({ projectId: projectId.value, model: project.value.imageModel, resolution: project.value.imageQuality || '1024x1024', id: asset.id, type: asset.type, name: asset.name, prompt: asset.prompt || asset.description || '' });
  message.success('资产图片已生成');
  await loadAssets();
}

async function matchAssetVoice(asset: any) {
  await batchBindAudio(projectId.value, [asset.id]);
  message.success('已匹配项目中的音色资产');
  await loadAssets();
}

function openDubbing(asset: any) {
  Object.assign(dubbingForm, {
    assetsId: asset.id,
    assetName: asset.name,
    text: asset.description || asset.prompt || '',
    voice: 'alloy',
  });
  dubbingResult.value = '';
  dubbingModalOpen.value = true;
}

async function createDubbing() {
  if (!dubbingForm.text.trim()) return message.warning('请输入配音文本');
  const result = await generateAssetDubbing({
    projectId: projectId.value,
    assetsId: dubbingForm.assetsId,
    text: dubbingForm.text,
    voice: dubbingForm.voice,
  });
  dubbingResult.value = result.url;
  message.success('角色配音已生成并绑定');
  await loadAssets();
}

async function loadAgentMemory() {
  agentMemories.value = await getAgentMemories(agentType.value, agentIsolationKey.value);
  if (agentType.value === 'scriptAgent') {
    const plan = await getScriptAgentPlan(projectId.value);
    Object.assign(scriptPlan, plan.data);
  }
}

async function sendAgentMessage() {
  const content = agentInput.value.trim();
  if (!content) return;
  agentSending.value = true;
  try {
    agentInput.value = '';
    const run = await startAgent({
      agentType: agentType.value,
      isolationKey: agentIsolationKey.value,
      projectId: projectId.value,
      scriptId: agentType.value === 'productionAgent' ? selectedScriptId.value : undefined,
      content,
    });
    activeAgentRunId.value = run.id;
    lastAgentRunId.value = run.id;
    agentRunState.value = run.state;
    agentStreamText.value = '';
    agentEventCursor.value = 0;
    while (activeAgentRunId.value === run.id) {
      await new Promise((resolve) => setTimeout(resolve, 800));
      const events = await getAgentRunEvents(run.id, agentEventCursor.value);
      for (const event of events) {
        agentEventCursor.value = event.id;
        if (event.eventType === 'delta') agentStreamText.value += event.data.text || '';
      }
      const state = await getAgentRunState(run.id);
      agentRunState.value = state.state;
      if (state.state !== 'running') {
        activeAgentRunId.value = undefined;
        if (state.state === 'failed') message.error(state.errorReason || 'Agent 执行失败');
        if (state.state === 'canceled') message.info('Agent 执行已中止');
        await loadAgentMemory();
        agentStreamText.value = '';
        break;
      }
    }
  } finally {
    agentSending.value = false;
  }
}

async function retryAgentRun() {
  if (!lastAgentRunId.value) return;
  const run = await retryAgent(lastAgentRunId.value);
  lastAgentRunId.value = run.id;
  activeAgentRunId.value = run.id;
  agentRunState.value = run.state;
  agentStreamText.value = '';
  agentEventCursor.value = 0;
  agentSending.value = true;
  try {
    while (activeAgentRunId.value === run.id) {
      await new Promise((resolve) => setTimeout(resolve, 800));
      const events = await getAgentRunEvents(run.id, agentEventCursor.value);
      for (const event of events) { agentEventCursor.value = event.id; agentStreamText.value += event.data.text || ''; }
      const state = await getAgentRunState(run.id);
      agentRunState.value = state.state;
      if (state.state !== 'running') { activeAgentRunId.value = undefined; await loadAgentMemory(); agentStreamText.value = ''; break; }
    }
  } finally { agentSending.value = false; }
}

async function stopAgentRun() {
  if (!activeAgentRunId.value) return;
  const id = activeAgentRunId.value;
  await stopAgent(id);
  activeAgentRunId.value = undefined;
  agentRunState.value = 'canceled';
}

async function resetAgentMemory() {
  await clearAgentMemory(agentType.value, agentIsolationKey.value);
  agentMemories.value = [];
  message.success('当前 Agent 会话记忆已清空');
}

async function saveAgentWorkspace() {
  await saveScriptAgentPlan(projectId.value, {
    ...scriptPlan,
    script: scripts.value.map(({ id, name, content }) => ({ id, name, content })),
  });
  message.success('剧本 Agent 工作区已保存');
}

async function saveFlowText() {
  if (!selectedScriptId.value) {
    message.warning('请先选择剧本');
    return;
  }
  let data: Record<string, any>;
  try {
    data = JSON.parse(flowText.value);
  } catch {
    message.error('Flow JSON 格式不正确');
    return;
  }
  await saveFlowData(projectId.value, selectedScriptId.value, data);
  message.success('生产工作流已保存');
}

async function createFlowImage() {
  if (!project.value?.imageModel) return message.warning('请先配置项目图片模型');
  const result = await generateFlowImage({ projectId: projectId.value, model: project.value.imageModel, quality: project.value.imageQuality || '1024x1024', ratio: project.value.videoRatio || '16:9', prompt: flowImageForm.prompt, references: flowImageForm.references.split('\n').map((value) => value.trim()).filter(Boolean) });
  flowImageResult.value = result.url;
  const generatedNode = imageFlowNodes.value.find((node) => node.type === 'generated');
  if (generatedNode) generatedNode.data.generatedImage = result.url;
  message.success('工作流图片已生成');
}

function addImageFlowNode(type: 'generated' | 'prompt' | 'upload') {
  const id = `${type}-${Date.now()}`;
  imageFlowNodes.value.push({
    id,
    type,
    position: { x: imageFlowNodes.value.length * 260, y: 0 },
    data:
      type === 'upload'
        ? { image: '' }
        : type === 'prompt'
          ? { prompt: '' }
          : { generatedImage: '', references: [] },
  });
  if (imageFlowNodes.value.length > 1) {
    const source = imageFlowNodes.value.at(-2)?.id;
    imageFlowEdges.value.push({ id: `edge-${source}-${id}`, source, target: id });
  }
}

async function openImageFlowEditor() {
  if (!selectedScriptId.value) return message.warning('请先选择剧本');
  if (imageFlowId.value) {
    const flow = await getImageFlow(imageFlowId.value);
    imageFlowNodes.value = flow?.nodes ?? [];
    imageFlowEdges.value = flow?.edges ?? [];
  }
  if (imageFlowNodes.value.length === 0) {
    addImageFlowNode('upload');
    addImageFlowNode('prompt');
    addImageFlowNode('generated');
  }
  flowImageModalOpen.value = true;
}

async function saveVisualImageFlow() {
  if (imageFlowId.value) {
    await updateImageFlow(imageFlowId.value, imageFlowNodes.value, imageFlowEdges.value);
  } else {
    const result = await saveImageFlow(imageFlowNodes.value, imageFlowEdges.value);
    imageFlowId.value = result.id;
  }
  message.success('图片工作流已保存');
}

async function uploadImageFlowReference(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file || !selectedScriptId.value) return;
  const base64Data = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
  const url = await uploadFlowImage(projectId.value, selectedScriptId.value, base64Data);
  const uploadNode = imageFlowNodes.value.find((node) => node.type === 'upload');
  if (uploadNode) uploadNode.data.image = url;
  flowImageForm.references = [
    ...flowImageForm.references.split('\n').filter(Boolean),
    url,
  ].join('\n');
  message.success('参考图上传成功');
}

function removeImageFlowNode(id: string) {
  imageFlowNodes.value = imageFlowNodes.value.filter((node) => node.id !== id);
  imageFlowEdges.value = imageFlowEdges.value.filter(
    (edge) => edge.source !== id && edge.target !== id,
  );
}

function openStoryboard() {
  Object.assign(storyboardForm, {
    prompt: '',
    duration: 4,
    state: '未生成',
    videoDesc: '',
    shouldGenerateImage: 1,
    track: 'main',
    associateAssetsIds: [],
  });
  storyboardModalOpen.value = true;
}

async function saveStoryboardForm() {
  if (!selectedScriptId.value) {
    message.warning('请先选择剧本');
    return;
  }
  await addStoryboard({
    ...storyboardForm,
    projectId: projectId.value,
    scriptId: selectedScriptId.value,
  });
  storyboardModalOpen.value = false;
  await loadFlow();
}

async function deleteStoryboard(row: any) {
  await removeStoryboard(row.id);
  await loadFlow();
}

async function generateAllStoryboardImages() {
  if (!selectedScriptId.value || storyboards.value.length === 0) return message.warning('当前剧本没有可生成的分镜');
  await generateStoryboardImages({ storyboardIds: storyboards.value.map((item) => item.id), projectId: projectId.value, scriptId: selectedScriptId.value, concurrentCount: 5 });
  message.success('分镜图片生成任务已提交');
  window.setTimeout(loadFlow, 3000);
}

async function previewAllStoryboardImages() {
  if (storyboards.value.length === 0) return message.warning('当前没有分镜');
  storyboardPreview.value = (await previewStoryboardImages(storyboards.value.map((item) => item.id))) || '';
  if (!storyboardPreview.value) return message.warning('还没有可预览的分镜图片');
  storyboardPreviewOpen.value = true;
}

async function createVideoTrack() { if (!selectedScriptId.value) return message.warning('请先选择剧本'); await addVideoTrack(projectId.value, selectedScriptId.value); await loadFlow(); }
async function moveVideoTrack(index:number,direction:-1|1){if(!selectedScriptId.value)return;const target=index+direction;if(target<0||target>=videoTracks.value.length)return;const list=[...videoTracks.value];[list[index],list[target]]=[list[target],list[index]];videoTracks.value=list;await reorderVideoTracks(projectId.value,selectedScriptId.value,list.map(track=>track.id))}
async function bindUnassignedStoryboards(track:any){const ids=storyboards.value.filter(item=>!videoTracks.value.some(other=>other.medias?.some((media:any)=>media.id===item.id))).map(item=>item.id);if(!ids.length)return message.info('没有未绑定的分镜');await bindTrackStoryboards(track.id,ids);await loadFlow();message.success('分镜已绑定到轨道')}
async function saveTrackPrompt(track:any) { await updateVideoTrackPrompt(track.id, track.prompt || ''); message.success('视频提示词已保存'); }
async function createVideoPrompt(track:any) { if (!project.value?.videoModel) return message.warning('请先配置视频模型'); track.prompt=await generateVideoPrompt({trackId:track.id,projectId:projectId.value,info:track.medias??[],model:project.value.videoModel,mode:project.value.mode||'text'}); message.success('视频提示词已生成'); }
async function generateVideo(track:any) { if (!selectedScriptId.value || !project.value?.videoModel) return message.warning('请先配置项目视频模型'); const id=await generateTrackVideo({ projectId:projectId.value,scriptId:selectedScriptId.value,trackId:track.id,prompt:track.prompt||'',model:project.value.videoModel,mode:project.value.mode||'text',resolution:project.value.imageQuality||'1080p',duration:track.duration||5,audio:false,uploadData:track.medias??[] }); message.success(`视频任务 ${id} 已提交`); window.setTimeout(loadFlow,3000); }
async function generateAllVideoPrompts(){if(!project.value?.videoModel)return message.warning('请先配置视频模型');await batchGenerateVideoPrompts({projectId:projectId.value,model:project.value.videoModel,mode:project.value.mode||'text',concurrentCount:5,trackData:videoTracks.value.map(track=>({trackId:track.id,info:track.medias??[]}))});message.success('批量提示词任务已提交');window.setTimeout(loadFlow,3000)}
async function generateAllVideos(){if(!selectedScriptId.value||!project.value?.videoModel)return message.warning('请先选择剧本并配置视频模型');await batchGenerateVideos({projectId:projectId.value,scriptId:selectedScriptId.value,model:project.value.videoModel,mode:project.value.mode||'text',resolution:project.value.imageQuality||'1080p',audio:false,trackData:videoTracks.value.map(track=>({trackId:track.id,prompt:track.prompt||'',duration:track.duration||5,uploadData:track.medias??[]}))});message.success('批量视频任务已提交');window.setTimeout(loadFlow,3000)}
async function chooseVideo(track:any,video:any){await selectTrackVideo(track.id,video.id);track.selectVideoId=video.id;message.success('候选视频已选择')}
async function removeVideo(video:any){await deleteTrackVideo(video.id);await loadFlow()}
async function cancelVideo(video:any){await cancelTrackVideo(video.id);await loadFlow()}
async function retryVideo(video:any,track:any){if(!project.value?.videoModel)return message.warning('请先配置视频模型');await retryTrackVideo({id:video.id,model:project.value.videoModel,mode:project.value.mode||'text',resolution:project.value.imageQuality||'1080p',audio:false,uploadData:track.medias??[]});message.success('视频重试任务已提交');window.setTimeout(loadFlow,3000)}
async function exportVideo(){if(!selectedScriptId.value)return message.warning('请先选择剧本');const result=await exportFinalVideo(projectId.value,selectedScriptId.value);message.success(`成片导出任务 ${result.taskId} 已提交，请到任务中心查看`)}

watch(selectedScriptId, () => {
  loadFlow();
});

onMounted(loadAll);
</script>

<template>
  <Page auto-content-height>
    <Card :bordered="false" :loading="loading" class="h-full">
      <template #title>
        <Space>
          <Button @click="router.back()">返回</Button>
          <Typography.Text strong>{{ project?.name || '项目详情' }}</Typography.Text>
          <Tag>{{ project?.videoRatio || '9:16' }}</Tag>
        </Space>
      </template>
      <template #extra>
        <Button @click="loadAll">刷新</Button>
      </template>

      <Row :gutter="16" class="mb-4">
        <Col :span="6"><Card size="small"><Statistic title="角色资产" :value="statistics.roleCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="剧本" :value="statistics.scriptCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="分镜" :value="statistics.storyboardCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="视频" :value="statistics.videoCount" /></Card></Col>
      </Row>

      <Tabs v-model:active-key="activeTab">
        <Tabs.TabPane key="novel" tab="原文">
          <div class="tab-tools">
            <Button type="primary" @click="openNovel()">导入章节</Button>
          </div>
          <Table
            :columns="novelColumns"
            :data-source="novels"
            :pagination="{ pageSize: 8 }"
            row-key="id"
            size="small"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.dataIndex === 'eventState'">
                <Tag :color="record.eventState === 1 ? 'green' : record.eventState === -1 ? 'red' : 'processing'">
                  {{ record.eventState === 1 ? '已提取' : record.eventState === -1 ? '失败' : '处理中' }}
                </Tag>
              </template>
              <template v-if="column.key === 'action'">
                <Space>
                  <Button type="link" @click="openNovel(record)">编辑</Button>
                  <Button type="link" @click="extractNovelEvents(record)">提取事件</Button>
                  <Popconfirm title="确认删除章节？" @confirm="removeNovel(record)">
                    <Button danger type="link">删除</Button>
                  </Popconfirm>
                </Space>
              </template>
            </template>
          </Table>
        </Tabs.TabPane>

        <Tabs.TabPane key="script" tab="剧本与资产">
          <Row :gutter="16">
            <Col :span="14">
              <Card size="small" title="剧本">
                <template #extra>
                  <Button size="small" type="primary" @click="openScript()">新增剧本</Button>
                </template>
                <List :data-source="scripts" item-layout="vertical">
                  <template #renderItem="{ item }">
                    <List.Item>
                      <template #actions>
                        <Button type="link" @click="openScript(item)">编辑</Button>
                        <Button type="link" @click="extractAssetsFromScript(item)">AI 提取资产</Button>
                        <Popconfirm title="确认删除剧本？" @confirm="removeScript(item)">
                          <Button danger type="link">删除</Button>
                        </Popconfirm>
                      </template>
                      <List.Item.Meta :description="`${item.content.length} 字`" :title="item.name" />
                      <div class="script-preview">{{ item.content }}</div>
                    </List.Item>
                  </template>
                </List>
              </Card>
            </Col>
            <Col :span="10">
              <Card size="small" title="资产">
                <template #extra>
                  <Space>
                    <input
                      ref="materialInput"
                      accept="image/*,audio/*,video/*"
                      class="hidden"
                      type="file"
                      @change="uploadMaterialFile"
                    />
                    <Button size="small" @click="materialInput?.click()">上传素材</Button>
                    <Button size="small" type="primary" @click="openAsset()">新增资产</Button>
                  </Space>
                </template>
                <List :data-source="assets" size="small">
                  <template #renderItem="{ item }">
                    <List.Item>
                      <template #actions>
                        <Button type="link" @click="openAsset(item)">编辑</Button>
                        <Button type="link" @click="polishAsset(item)">AI 润色</Button>
                        <Button type="link" @click="generateAssetPicture(item)">生成图片</Button>
                        <Button v-if="item.type !== 'audio'" type="link" @click="matchAssetVoice(item)">匹配音色</Button>
                        <Button v-if="item.type !== 'audio'" type="link" @click="openDubbing(item)">生成配音</Button>
                      </template>
                      <List.Item.Meta :description="item.description" :title="item.name">
                        <template #avatar>
                          <Tag>{{ item.type }}</Tag>
                        </template>
                      </List.Item.Meta>
                    </List.Item>
                  </template>
                </List>
              </Card>
            </Col>
          </Row>
        </Tabs.TabPane>

        <Tabs.TabPane key="production" tab="生产">
          <Space class="mb-3">
            <Select
              v-model:value="selectedScriptId"
              :options="scriptOptions"
              placeholder="选择剧本"
              style="width: 240px"
            />
            <Button @click="loadFlow">读取 Flow</Button>
            <Button type="primary" @click="saveFlowText">保存 Flow</Button>
            <Button @click="openImageFlowEditor">图片编辑工作流</Button>
            <Button @click="openStoryboard">新增分镜</Button>
            <Button type="primary" @click="generateAllStoryboardImages">批量生成分镜图</Button>
            <Button @click="previewAllStoryboardImages">合成预览</Button>
          </Space>
          <Row :gutter="16">
            <Col :span="12">
              <Card size="small" title="生产 Flow JSON">
                <Input.TextArea v-model:value="flowText" class="flow-editor" />
              </Card>
            </Col>
            <Col :span="12">
              <Card size="small" title="分镜">
                <Table
                  :columns="storyboardColumns"
                  :data-source="storyboards"
                  :pagination="{ pageSize: 8 }"
                  row-key="id"
                  size="small"
                >
                  <template #bodyCell="{ column, record }">
                    <template v-if="column.key === 'action'">
                      <Popconfirm title="确认删除分镜？" @confirm="deleteStoryboard(record)">
                        <Button danger type="link">删除</Button>
                      </Popconfirm>
                    </template>
                  </template>
                </Table>
              </Card>
            </Col>
          </Row>
        </Tabs.TabPane>
        <Tabs.TabPane key="video" tab="视频轨道">
          <Space class="mb-3"><Select v-model:value="selectedScriptId" :options="scriptOptions" placeholder="选择剧本" style="width:240px"/><Button type="primary" @click="createVideoTrack">新增轨道</Button><Button @click="generateAllVideoPrompts">批量提示词</Button><Button @click="generateAllVideos">批量视频</Button><Button type="primary" @click="exportVideo">导出成片</Button><Button @click="loadFlow">刷新状态</Button></Space>
          <Card v-for="(track,trackIndex) in videoTracks" :key="track.id" class="mb-3" size="small">
            <template #title>轨道 {{ track.id }} · {{ track.duration || 0 }} 秒</template>
            <template #extra><Space><Button :disabled="trackIndex===0" @click="moveVideoTrack(trackIndex,-1)">上移</Button><Button :disabled="trackIndex===videoTracks.length-1" @click="moveVideoTrack(trackIndex,1)">下移</Button><Button @click="bindUnassignedStoryboards(track)">绑定未分配分镜</Button><Button @click="createVideoPrompt(track)">AI 生成提示词</Button><Button @click="saveTrackPrompt(track)">保存提示词</Button><Button type="primary" @click="generateVideo(track)">生成视频</Button></Space></template>
            <Input.TextArea v-model:value="track.prompt" :rows="3" placeholder="视频生成提示词"/>
            <div class="mt-2"><Tag v-for="media in track.medias" :key="media.id">{{media.index}} · 分镜 {{media.id}}</Tag></div>
            <div class="mt-3 flex gap-3 overflow-x-auto"><div v-for="video in track.videoList" :key="video.id"><video v-if="video.src" :src="video.src" controls class="h-40 rounded border"/><Tag>{{video.state}}</Tag><Space><Button v-if="video.state==='生成成功'" size="small" type="link" @click="chooseVideo(track,video)">{{track.selectVideoId===video.id?'已选中':'选择'}}</Button><Button v-if="video.state==='生成中'" size="small" type="link" @click="cancelVideo(video)">取消</Button><Button v-if="['生成失败','已取消'].includes(video.state)" size="small" type="link" @click="retryVideo(video,track)">重试</Button><Button danger size="small" type="link" @click="removeVideo(video)">删除</Button></Space></div><Tag v-if="!track.videoList?.length">暂无候选视频</Tag></div>
          </Card>
        </Tabs.TabPane>

        <Tabs.TabPane key="agent" tab="Agent 工作台">
          <Card size="small">
            <template #title>
              <Space>
                <Select
                  v-model:value="agentType"
                  :options="[
                    { label: '剧本 Agent', value: 'scriptAgent' },
                    { label: '生产 Agent', value: 'productionAgent' },
                  ]"
                  style="width: 180px"
                  @change="loadAgentMemory"
                />
                <Select
                  v-if="agentType === 'productionAgent'"
                  v-model:value="selectedScriptId"
                  :options="scriptOptions"
                  placeholder="选择生产剧本"
                  style="width: 220px"
                  @change="loadAgentMemory"
                />
              </Space>
            </template>
            <template #extra>
              <Space><Button @click="loadAgentMemory">刷新记忆</Button><Popconfirm title="确认清空当前会话记忆？" @confirm="resetAgentMemory"><Button danger>清空记忆</Button></Popconfirm></Space>
            </template>
            <List :data-source="agentMemories.filter((item) => item.memoryType === 'message')" class="agent-chat" size="small">
              <template #renderItem="{ item }">
                <List.Item :class="`agent-message agent-message-${item.role.split(':')[0]}`">
                  <List.Item.Meta :title="item.role.startsWith('user') ? '你' : 'Agent'">
                    <template #description><Typography.Paragraph class="whitespace-pre-wrap">{{ item.content }}</Typography.Paragraph></template>
                  </List.Item.Meta>
                </List.Item>
              </template>
            </List>
            <Card v-if="agentStreamText" class="mb-3" size="small" title="Agent 正在输出">
              <Typography.Paragraph class="whitespace-pre-wrap">{{ agentStreamText }}</Typography.Paragraph>
            </Card>
            <Card v-if="agentType === 'scriptAgent'" class="mb-3" size="small" title="剧本 Agent 工作区">
              <template #extra><Button type="primary" @click="saveAgentWorkspace">保存工作区</Button></template>
              <Row :gutter="16">
                <Col :span="12"><Form.Item label="故事骨架"><Input.TextArea v-model:value="scriptPlan.storySkeleton" :rows="8" /></Form.Item></Col>
                <Col :span="12"><Form.Item label="改编策略"><Input.TextArea v-model:value="scriptPlan.adaptationStrategy" :rows="8" /></Form.Item></Col>
              </Row>
            </Card>
            <Space.Compact class="mt-3 w-full">
              <Input.TextArea v-model:value="agentInput" :auto-size="{ minRows: 3, maxRows: 8 }" placeholder="输入任务或修改要求" @keydown.ctrl.enter.prevent="sendAgentMessage" />
              <Button :loading="agentSending" type="primary" @click="sendAgentMessage">发送</Button>
              <Button v-if="activeAgentRunId" danger @click="stopAgentRun">停止</Button>
              <Button v-if="!activeAgentRunId && ['failed', 'canceled', 'interrupted'].includes(agentRunState)" @click="retryAgentRun">重试</Button>
            </Space.Compact>
            <div class="mt-2 text-xs text-gray-500">运行状态：{{ agentRunState }}</div>
          </Card>
        </Tabs.TabPane>
      </Tabs>
    </Card>

    <Modal v-model:open="novelModalOpen" title="章节" width="820px" @ok="saveNovel">
      <Form :label-col="{ span: 4 }">
        <Form.Item label="批量导入">
          <Input.TextArea
            v-model:value="batchNovelText"
            :rows="6"
            placeholder="可粘贴多章文本；留空则保存下方单章"
          />
        </Form.Item>
        <Form.Item label="序号">
          <InputNumber v-model:value="novelForm.index" :min="1" />
        </Form.Item>
        <Form.Item label="分卷">
          <Input v-model:value="novelForm.reel" />
        </Form.Item>
        <Form.Item label="章节">
          <Input v-model:value="novelForm.chapter" />
        </Form.Item>
        <Form.Item label="正文">
          <Input.TextArea v-model:value="novelForm.chapterData" :rows="8" />
        </Form.Item>
        <Form.Item label="事件">
          <Input.TextArea v-model:value="novelForm.event" :rows="3" />
        </Form.Item>
      </Form>
    </Modal>

    <Modal v-model:open="scriptModalOpen" title="剧本" width="900px" @ok="saveScript">
      <Form :label-col="{ span: 3 }">
        <Form.Item label="名称">
          <Input v-model:value="scriptForm.name" />
        </Form.Item>
        <Form.Item label="关联资产">
          <Select
            v-model:value="scriptForm.assets"
            :options="assetOptions"
            mode="multiple"
            placeholder="选择剧本使用的角色、场景、道具"
          />
        </Form.Item>
        <Form.Item label="内容">
          <Input.TextArea v-model:value="scriptForm.content" :rows="14" />
        </Form.Item>
      </Form>
    </Modal>

    <Modal v-model:open="assetModalOpen" title="资产" width="760px" @ok="saveAssetForm">
      <Form :label-col="{ span: 4 }">
        <Form.Item label="名称">
          <Input v-model:value="assetForm.name" />
        </Form.Item>
        <Form.Item label="类型">
          <Select
            v-model:value="assetForm.type"
            :options="[
              { label: '角色', value: 'role' },
              { label: '场景', value: 'scene' },
              { label: '道具', value: 'tool' },
            ]"
          />
        </Form.Item>
        <Form.Item label="描述">
          <Input.TextArea v-model:value="assetForm.description" :rows="3" />
        </Form.Item>
        <Form.Item label="提示词">
          <Input.TextArea v-model:value="assetForm.prompt" :rows="4" />
        </Form.Item>
      </Form>
    </Modal>

    <Modal v-model:open="storyboardModalOpen" title="分镜" width="820px" @ok="saveStoryboardForm">
      <Form :label-col="{ span: 4 }">
        <Form.Item label="轨道">
          <Input v-model:value="storyboardForm.track" />
        </Form.Item>
        <Form.Item label="时长">
          <InputNumber v-model:value="storyboardForm.duration" :min="1" />
        </Form.Item>
        <Form.Item label="关联资产">
          <Select
            v-model:value="storyboardForm.associateAssetsIds"
            :options="assetOptions"
            mode="multiple"
          />
        </Form.Item>
        <Form.Item label="画面描述">
          <Input.TextArea v-model:value="storyboardForm.videoDesc" :rows="4" />
        </Form.Item>
        <Form.Item label="图片提示词">
          <Input.TextArea v-model:value="storyboardForm.prompt" :rows="5" />
        </Form.Item>
      </Form>
    </Modal>
    <Modal
      v-model:open="dubbingModalOpen"
      :title="`生成配音 · ${dubbingForm.assetName}`"
      width="720px"
      @ok="createDubbing"
    >
      <Form layout="vertical">
        <Form.Item label="音色">
          <Select
            v-model:value="dubbingForm.voice"
            :options="[
              { label: 'Alloy', value: 'alloy' },
              { label: 'Echo', value: 'echo' },
              { label: 'Fable', value: 'fable' },
              { label: 'Nova', value: 'nova' },
              { label: 'Onyx', value: 'onyx' },
              { label: 'Shimmer', value: 'shimmer' },
            ]"
          />
        </Form.Item>
        <Form.Item label="配音文本">
          <Input.TextArea v-model:value="dubbingForm.text" :rows="7" />
        </Form.Item>
        <Form.Item v-if="dubbingResult" label="生成结果">
          <audio :src="dubbingResult" controls class="w-full" />
        </Form.Item>
      </Form>
    </Modal>
    <Modal v-model:open="flowImageModalOpen" title="可视化图片工作流" width="1100px" :footer="null">
      <Space class="mb-3">
        <Button @click="addImageFlowNode('upload')">上传节点</Button>
        <Button @click="addImageFlowNode('prompt')">提示词节点</Button>
        <Button @click="addImageFlowNode('generated')">生成节点</Button>
        <input ref="flowUploadInput" accept="image/*" class="hidden" type="file" @change="uploadImageFlowReference" />
        <Button @click="flowUploadInput?.click()">上传参考图</Button>
        <Button type="primary" @click="saveVisualImageFlow">保存工作流</Button>
        <Button type="primary" @click="createFlowImage">执行生成</Button>
      </Space>
      <div class="image-flow-canvas">
        <Card v-for="(node, index) in imageFlowNodes" :key="node.id" class="image-flow-node" size="small">
          <template #title>{{ index + 1 }}. {{ node.type === 'upload' ? '参考图' : node.type === 'prompt' ? '提示词' : '生成结果' }}</template>
          <template #extra><Button danger size="small" type="link" @click="removeImageFlowNode(node.id)">删除</Button></template>
          <template v-if="node.type === 'upload'">
            <img v-if="node.data.image" :src="node.data.image" class="h-40 w-full rounded object-contain" />
            <div v-else class="image-flow-empty">尚未上传参考图</div>
          </template>
          <template v-else-if="node.type === 'prompt'">
            <Input.TextArea v-model:value="node.data.prompt" :rows="7" @change="flowImageForm.prompt = node.data.prompt" />
          </template>
          <template v-else>
            <img v-if="node.data.generatedImage || flowImageResult" :src="node.data.generatedImage || flowImageResult" class="h-40 w-full rounded object-contain" />
            <div v-else class="image-flow-empty">执行后显示生成图片</div>
          </template>
          <div v-if="index < imageFlowNodes.length - 1" class="image-flow-arrow">→</div>
        </Card>
      </div>
      <Typography.Paragraph class="mt-3 text-gray-500">
        节点按从左到右顺序执行，工作流 ID：{{ imageFlowId || '尚未保存' }}
      </Typography.Paragraph>
    </Modal>
    <Modal v-model:open="storyboardPreviewOpen" title="分镜合成预览" width="1100px" :footer="null">
      <img v-if="storyboardPreview" :src="storyboardPreview" class="w-full rounded border" />
    </Modal>
  </Page>
</template>

<style scoped>
.tab-tools {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 12px;
}

.script-preview {
  color: #4b5563;
  display: -webkit-box;
  line-height: 22px;
  max-height: 66px;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
}

.flow-editor {
  font-family:
    ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono',
    'Courier New', monospace;
  min-height: 520px;
}

.mb-3 {
  margin-bottom: 12px;
}

.agent-chat {
  max-height: 560px;
  min-height: 300px;
  overflow: auto;
}

.agent-message-assistant {
  background: rgb(248 250 252);
}

.image-flow-canvas {
  display: flex;
  min-height: 280px;
  gap: 36px;
  overflow-x: auto;
  padding: 24px;
  border: 1px dashed var(--ant-color-border);
  border-radius: 8px;
  background: var(--ant-color-fill-quaternary);
}

.image-flow-node {
  position: relative;
  min-width: 280px;
  max-width: 280px;
}

.image-flow-arrow {
  position: absolute;
  top: 50%;
  right: -30px;
  color: var(--ant-color-primary);
  font-size: 24px;
}

.image-flow-empty {
  display: flex;
  height: 160px;
  align-items: center;
  justify-content: center;
  color: var(--ant-color-text-tertiary);
}
</style>

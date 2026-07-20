<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

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
  Upload,
  message,
} from 'ant-design-vue';

import {
  addNovel,
  addScript,
  addStoryboard,
  addVideoTrack,
  batchGenerateVideoPrompts,
  batchGenerateVideos,
  clearAgentMemory,
  deleteNovel,
  deleteScripts,
  deleteTrackVideo,
  exportFinalVideo,
  extractScriptAssets,
  getAssets,
  getFlowData,
  getImageFlow,
  generateFlowImage,
  generateStoryboardImages,
  generateTrackVideo,
  generateVideoPrompt,
  previewStoryboardImages,
  generateNovelEvents,
  getNovelData,
  getProject,
  getProjectStatistics,
  getScripts,
  getStoryboards,
  getVideoWorkbench,
  removeStoryboard,
  reorderVideoTracks,
  retryTrackVideo,
  bindTrackStoryboards,
  cancelTrackVideo,
  saveFlowData,
  saveImageFlow,
  saveScriptAgentPlan,
  selectTrackVideo,
  updateNovel,
  updateScript,
  updateVideoTrackPrompt,
  updateImageFlow,
  uploadFlowImage,
} from '#/api/toonflow';
import { parseNovelText } from './novel-import';
import AgentChat from './AgentChat.vue';

defineOptions({ name: 'ToonflowProjectDetail' });

const route = useRoute();
const router = useRouter();
const projectId = computed(() => Number(route.params.id));

const activeTab = ref('novel');
const loading = ref(false);
const project = ref<ToonflowApi.Project>();
const imageQuality = computed(() =>
  ['1K', '2K', '4K'].includes(project.value?.imageQuality ?? '')
    ? project.value!.imageQuality
    : '2K',
);
const videoMode = computed(() =>
  ['text', 'singleImage', 'startEndRequired', 'endFrameOptional', 'startFrameOptional'].includes(
    project.value?.mode ?? '',
  )
    ? project.value!.mode
    : 'text',
);
const statistics = reactive<ToonflowApi.ProjectStatistics>({ roleCount: 0, scriptCount: 0, videoCount: 0, storyboardCount: 0 });
const novels = ref<ToonflowApi.NovelChapter[]>([]);
const scripts = ref<ToonflowApi.Script[]>([]);
const assets = ref<ToonflowApi.Asset[]>([]);
const storyboards = ref<ToonflowApi.Storyboard[]>([]);
const selectedScriptId = ref<number>();
const flowText = ref('{\n  "script": "",\n  "storyboard": [],\n  "workbench": { "videoList": [] }\n}');

const novelModalOpen = ref(false);
const scriptModalOpen = ref(false);
const storyboardModalOpen = ref(false);
const flowImageModalOpen = ref(false);
const flowImageResult = ref('');
const imageFlowId = ref<number>();
const imageFlowNodes = ref<any[]>([]);
const imageFlowEdges = ref<any[]>([]);
const flowUploadInput = ref<HTMLInputElement>();
const storyboardPreviewOpen = ref(false);
const storyboardPreview = ref('');
const videoTracks = ref<any[]>([]);
const flowImageForm = reactive({ prompt: '', references: '' });
const agentType = ref<'productionAgent' | 'scriptAgent'>('scriptAgent');
const scriptPlan = reactive({ storySkeleton: '', adaptationStrategy: '' });

// Agent workspace tabs - populated in real-time from sub-agent outputs
const workspaceTabs = reactive<{ key: string; label: string; content: string }[]>([
  { key: 'storySkeleton', label: '故事骨架', content: '' },
  { key: 'adaptationStrategy', label: '改编策略', content: '' },
  { key: 'script', label: '剧本', content: '' },
]);
const workspaceActiveTab = ref('storySkeleton');

// Pipeline stages for process visualization
type StageStatus = 'pending' | 'active' | 'completed' | 'review';
const pipelineStages = reactive<{ key: string; label: string; status: StageStatus }[]>([
  { key: 'init', label: '项目初始化', status: 'completed' },
  { key: 'skeleton', label: '故事骨架', status: 'pending' },
  { key: 'adaptation', label: '改编策略', status: 'pending' },
  { key: 'script', label: '剧本编写', status: 'pending' },
]);

function updatePipelineStage(toolName: string, status: StageStatus) {
  const stageMap: Record<string, string> = {
    storySkeleton: 'skeleton',
    run_sub_agent_storySkeleton: 'skeleton',
    adaptationStrategy: 'adaptation',
    run_sub_agent_adaptationStrategy: 'adaptation',
    script: 'script',
    run_sub_agent_script: 'script',
    save_scripts: 'script',
  };
  const stageKey = stageMap[toolName];
  if (!stageKey) return;
  const idx = pipelineStages.findIndex((s) => s.key === stageKey);
  if (idx >= 0) {
    pipelineStages[idx].status = status;
    // Mark previous stages as completed
    for (let i = 0; i < idx; i++) {
      if (pipelineStages[i].status === 'active') pipelineStages[i].status = 'completed';
    }
  }
}

function onAgentToolResult(payload: { toolName: string; result: any }) {
  const { toolName, result } = payload;
  // Extract workspace content from sub-agent results
  let raw = typeof result === 'string' ? result : JSON.stringify(result);
  // If result is a JSON wrapper like {"agent":"...","content":"..."}, extract content
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object' && parsed.content && typeof parsed.content === 'string') {
      raw = parsed.content;
    }
  } catch { /* not JSON, use raw string */ }
  let content = raw;

  // Match tool name to workspace tab and pipeline stage
  if (toolName.includes('storySkeleton') || toolName.includes('skeleton')) {
    workspaceTabs[0].content = extractXmlContent(content, 'storySkeleton') || content;
    workspaceActiveTab.value = 'adaptationStrategy';
    updatePipelineStage(toolName, 'completed');
  } else if (toolName.includes('adaptationStrategy') || toolName.includes('adaptation')) {
    workspaceTabs[1].content = extractXmlContent(content, 'adaptationStrategy') || content;
    workspaceActiveTab.value = 'script';
    updatePipelineStage(toolName, 'completed');
  } else if (toolName.includes('script') && !toolName.includes('get_script')) {
    workspaceTabs[2].content = extractScriptItems(content);
    workspaceActiveTab.value = 'script';
    updatePipelineStage(toolName, 'completed');
  } else if (toolName === 'save_scripts') {
    workspaceActiveTab.value = 'script';
    updatePipelineStage(toolName, 'completed');
  } else if (toolName.includes('supervision') || toolName.includes('review')) {
    // Supervision agent reviewing - mark current stage as review
    const currentStage = pipelineStages.find((s) => s.status === 'completed');
    if (currentStage) currentStage.status = 'review';
  }
}

function extractXmlContent(text: string, tag: string): string | null {
  const regex = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, 'i');
  const match = text.match(regex);
  return match ? match[1].trim() : null;
}

function extractScriptItems(text: string): string {
  const matches = text.matchAll(/<scriptItem\s+name="([^"]*)">([\s\S]*?)<\/scriptItem>/gi);
  const items: string[] = [];
  for (const m of matches) {
    items.push(`### ${m[1]}\n\n${m[2].trim()}`);
  }
  return items.length > 0 ? items.join('\n\n---\n\n') : text;
}

function formatEventDisplay(eventJson: string): string {
  if (!eventJson) return '';
  try {
    const arr = JSON.parse(eventJson);
    if (!Array.isArray(arr)) return eventJson;
    return arr.map((e: any, i: number) => `${i + 1}.${e.name}：${e.detail}`).join('；');
  } catch {
    return eventJson;
  }
}

function renderMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/^### (.+)$/gm, '<h4>$1</h4>')
    .replace(/^## (.+)$/gm, '<h3>$1</h3>')
    .replace(/^# (.+)$/gm, '<h2>$1</h2>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/\n\n/g, '</p><p>')
    .replace(/\n/g, '<br>');
}

// Agent chat messages (WebSocket-driven)
interface ChatContentBlock { type: string; id: string; data: any; status: string }
interface ChatMessage { id: string; role: string; name?: string; status: string; datetime: string; content: ChatContentBlock[] }
const chatMessages = ref<ChatMessage[]>([]);
const agentChatRef = ref<InstanceType<typeof AgentChat> | null>(null);

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
  { title: '序号', dataIndex: 'index', width: 60 },
  { title: '分卷', dataIndex: 'reel', width: 100 },
  { title: '章节', dataIndex: 'chapter', width: 140, ellipsis: true },
  { title: '状态', dataIndex: 'eventState', width: 70 },
  { title: '事件', dataIndex: 'event', width: 300, ellipsis: true },
  { title: '操作', key: 'action', width: 140, fixed: 'right' as const },
];

const storyboardColumns = [
  { title: '顺序', dataIndex: 'index', width: 60 },
  { title: '轨道', dataIndex: 'track', width: 80 },
  { title: '时长', dataIndex: 'duration', width: 70 },
  { title: '状态', dataIndex: 'state', width: 90 },
  { title: '提示词', dataIndex: 'prompt', ellipsis: true },
  { title: '操作', key: 'action', width: 90 },
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
  if (!projectId.value || isNaN(projectId.value)) return;
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
    const chapters = parseNovelText(batchNovelText.value);
    if (chapters.length === 0) {
      message.warning('没有可导入的章节内容');
      return;
    }
    await importNovelChapters(chapters);
  } else if (novelForm.id) {
    await updateNovel({ ...novelForm, id: novelForm.id });
  } else {
    await addNovel(projectId.value, [{ ...novelForm }]);
  }
  novelModalOpen.value = false;
  await loadNovels();
}

async function importNovelChapters(chapters: ReturnType<typeof parseNovelText>) {
  const batchSize = 20;
  for (let start = 0; start < chapters.length; start += batchSize) {
    await addNovel(projectId.value, chapters.slice(start, start + batchSize));
  }
}

async function importNovelFile(file: File) {
  try {
    const buffer = await file.arrayBuffer();
    let content = new TextDecoder('utf-8').decode(buffer);
    if (content.includes('\uFFFD')) content = new TextDecoder('gb18030').decode(buffer);
    const title = file.name.replace(/\.(?:md|txt)$/i, '');
    const chapters = parseNovelText(content, title);
    if (!chapters.length) {
      message.warning('文件中没有可导入的正文');
      return false;
    }
    await importNovelChapters(chapters);
    message.success(`已从文件导入 ${chapters.length} 个章节`);
    await loadNovels();
  } catch (error) {
    message.error(error instanceof Error ? error.message : '文件导入失败');
  }
  return false;
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

async function extractAllNovelEvents() {
  const ids = novels.value.filter((chapter) => chapter.eventState !== 1).map((chapter) => chapter.id);
  if (!ids.length) {
    message.info('没有待提取事件的章节');
    return;
  }
  await generateNovelEvents(projectId.value, ids);
  message.success(`已提交 ${ids.length} 个章节的事件提取任务`);
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

async function loadAgentMemory() {
  // No-op: backend sends history via WebSocket on connect
}

async function resetAgentWorkspace() {
  // Clear chat messages
  chatMessages.value = [];
  // Reset workspace tabs
  workspaceTabs.forEach((t) => (t.content = ''));
  workspaceActiveTab.value = 'storySkeleton';
  // Reset pipeline stages
  pipelineStages.forEach((s) => (s.status = s.key === 'init' ? 'completed' : 'pending'));
  // Clear server-side memory
  try {
    const agentIsolationKey = `${agentType.value}:${projectId.value}:${agentType.value === 'productionAgent' ? (selectedScriptId.value ?? 'none') : 'project'}`;
    await clearAgentMemory(agentType.value, agentIsolationKey);
  } catch { /* ignore */ }
  // Reconnect WebSocket
  agentChatRef.value?.disconnect();
  setTimeout(() => agentChatRef.value?.connect(), 200);
  message.success('已重新开始');
}

async function saveAgentWorkspace() {
  await saveScriptAgentPlan(projectId.value, {
    ...scriptPlan,
    script: scripts.value.map(({ id, name, content }) => ({ id, name, content })),
  });
  message.success('剧本 Agent 工作区已保存');
}

function openScriptGeneration() {
  agentType.value = 'scriptAgent';
  chatMessages.value = [];
  agentChatRef.value?.connect();
  setTimeout(() => {
    agentChatRef.value?.send(
      '你好，请先读取当前项目的章节事件和已有剧本，分析项目的整体状态，然后告诉我你的分析和建议，并询问我是否需要开始生成下一集剧本。',
    );
  }, 300);
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
  const result = await generateFlowImage({ projectId: projectId.value, model: String(project.value.imageModel), quality: imageQuality.value, ratio: project.value.videoRatio || '16:9', prompt: flowImageForm.prompt, references: flowImageForm.references.split('\n').map((value) => value.trim()).filter(Boolean) });
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
async function createVideoPrompt(track:any) { if (!project.value?.videoModel) return message.warning('请先配置视频模型'); track.prompt=await generateVideoPrompt({trackId:track.id,projectId:projectId.value,info:track.medias??[],model:project.value.videoModel,mode:videoMode.value}); message.success('视频提示词已生成'); }
async function generateVideo(track:any) { if (!selectedScriptId.value || !project.value?.videoModel) return message.warning('请先配置项目视频模型'); const id=await generateTrackVideo({ projectId:projectId.value,scriptId:selectedScriptId.value,trackId:track.id,prompt:track.prompt||'',model:project.value.videoModel,mode:videoMode.value,resolution:'1080p',duration:track.duration||5,audio:false,uploadData:track.medias??[] }); message.success(`视频任务 ${id} 已提交`); window.setTimeout(loadFlow,3000); }
async function generateAllVideoPrompts(){if(!project.value?.videoModel)return message.warning('请先配置视频模型');await batchGenerateVideoPrompts({projectId:projectId.value,model:project.value.videoModel,mode:videoMode.value,concurrentCount:5,trackData:videoTracks.value.map(track=>({trackId:track.id,info:track.medias??[]}))});message.success('批量提示词任务已提交');window.setTimeout(loadFlow,3000)}
async function generateAllVideos(){if(!selectedScriptId.value||!project.value?.videoModel)return message.warning('请先选择剧本并配置视频模型');await batchGenerateVideos({projectId:projectId.value,scriptId:selectedScriptId.value,model:project.value.videoModel,mode:videoMode.value,resolution:'1080p',audio:false,trackData:videoTracks.value.map(track=>({trackId:track.id,prompt:track.prompt||'',duration:track.duration||5,uploadData:track.medias??[]}))});message.success('批量视频任务已提交');window.setTimeout(loadFlow,3000)}
async function chooseVideo(track:any,video:any){await selectTrackVideo(track.id,video.id);track.selectVideoId=video.id;message.success('候选视频已选择')}
async function removeVideo(video:any){await deleteTrackVideo(video.id);await loadFlow()}
async function cancelVideo(video:any){await cancelTrackVideo(video.id);await loadFlow()}
async function retryVideo(video:any,track:any){if(!project.value?.videoModel)return message.warning('请先配置视频模型');await retryTrackVideo({id:video.id,model:project.value.videoModel,mode:videoMode.value,resolution:'1080p',audio:false,uploadData:track.medias??[]});message.success('视频重试任务已提交');window.setTimeout(loadFlow,3000)}
async function exportVideo(){if(!selectedScriptId.value)return message.warning('请先选择剧本');const result=await exportFinalVideo(projectId.value,selectedScriptId.value);message.success(`成片导出任务 ${result.taskId} 已提交，请到任务中心查看`)}

watch(selectedScriptId, () => {
  loadFlow();
});

onMounted(loadAll);
watch(projectId, () => loadAll());
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
            <Space>
              <Upload accept=".txt,.md,text/plain,text/markdown" :before-upload="importNovelFile" :show-upload-list="false">
                <Button type="primary">导入文件</Button>
              </Upload>
              <Button @click="openNovel()">手动导入</Button>
              <Button @click="extractAllNovelEvents">提取全部待处理事件</Button>
            </Space>
          </div>
          <Table
            :columns="novelColumns"
            :data-source="novels"
            :scroll="{ x: 840 }"
            :pagination="{ pageSize: 10, showSizeChanger: true, pageSizeOptions: ['5', '10', '20', '50'], showTotal: (total: number) => `共 ${total} 章` }"
            row-key="id"
            size="small"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.dataIndex === 'eventState'">
                <Tag :color="record.eventState === 1 ? 'green' : record.eventState === -1 ? 'red' : 'default'">
                  {{ record.eventState === 1 ? '已提取' : record.eventState === -1 ? '失败' : '待提取' }}
                </Tag>
              </template>
              <template v-if="column.dataIndex === 'event'">
                <span class="event-text">{{ formatEventDisplay(record.event) }}</span>
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

        <Tabs.TabPane key="script" tab="剧本">
              <Card size="small" title="剧本">
                <template #extra>
                  <Space>
                    <Button
                      size="small"
                      @click="router.push({ path: '/toonflow/assets', query: { projectId } })"
                    >
                      打开资产库
                    </Button>
                    <Button size="small" @click="openScript()">手动新增</Button>
                  </Space>
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
                  :scroll="{ x: 500 }"
                  :data-source="storyboards"
                  :pagination="{ pageSize: 10, showSizeChanger: true, pageSizeOptions: ['5', '10', '20', '50'], showTotal: (total: number) => `共 ${total} 个` }"
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
          <Card size="small" title="Agent 工作台">
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
              <Space>
                <Popconfirm title="确认清除所有对话和工作区内容？" @confirm="resetAgentWorkspace">
                  <Button>重新开始</Button>
                </Popconfirm>
                <Button type="primary" @click="openScriptGeneration">AI 生成剧本</Button>
              </Space>
            </template>

            <Row :gutter="16">
              <Col :span="agentType === 'scriptAgent' ? 8 : 24">
                <AgentChat
                  ref="agentChatRef"
                  :agent-type="agentType"
                  :project-id="projectId"
                  :script-id="agentType === 'productionAgent' ? selectedScriptId : undefined"
                  :messages="chatMessages"
                  @tool-result="onAgentToolResult"
                />
              </Col>
              <Col v-if="agentType === 'scriptAgent'" :span="16">
                <Card size="small" class="workspace-card">
                  <template #extra>
                    <Button type="primary" size="small" @click="saveAgentWorkspace">保存工作区</Button>
                  </template>
                  <!-- Pipeline progress -->
                  <div class="pipeline-bar">
                    <div
                      v-for="(stage, i) in pipelineStages"
                      :key="stage.key"
                      class="pipeline-step"
                      :class="[stage.status, { last: i === pipelineStages.length - 1 }]"
                    >
                      <span class="pipeline-dot">{{ stage.status === 'completed' ? '✓' : stage.status === 'active' ? '●' : stage.status === 'review' ? '🔍' : '○' }}</span>
                      <span class="pipeline-label">{{ stage.label }}</span>
                      <span v-if="i < pipelineStages.length - 1" class="pipeline-line" />
                    </div>
                  </div>
                  <Tabs v-model:activeKey="workspaceActiveTab" size="small">
                    <Tabs.TabPane v-for="tab in workspaceTabs" :key="tab.key" :tab="tab.label">
                      <div class="workspace-pane">
                        <div v-if="!tab.content" class="workspace-placeholder">
                          Agent 将在此展示{{ tab.label }}...
                        </div>
                        <div v-else class="workspace-output" v-html="renderMarkdown(tab.content)" />
                      </div>
                    </Tabs.TabPane>
                  </Tabs>
                </Card>
              </Col>
            </Row>
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
.event-text {
  font-size: 12px;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.workspace-card {
  height: 680px;
  display: flex;
  flex-direction: column;
}
/* Pipeline progress bar */
.pipeline-bar {
  display: flex;
  align-items: center;
  padding: 8px 4px 12px;
  gap: 0;
  border-bottom: 1px solid #f0f0f0;
  margin-bottom: 4px;
}
.pipeline-step {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  white-space: nowrap;
}
.pipeline-step.pending { color: #bfbfbf; }
.pipeline-step.active { color: #1677ff; font-weight: 600; }
.pipeline-step.completed { color: #52c41a; }
.pipeline-step.review { color: #faad14; }
.pipeline-dot { font-size: 14px; width: 18px; text-align: center; flex-shrink: 0; }
.pipeline-label { flex-shrink: 0; }
.pipeline-line {
  flex: 1;
  height: 2px;
  min-width: 12px;
  background: #e8e8e8;
  margin: 0 4px;
}
.pipeline-step.completed .pipeline-line { background: #52c41a; }
.pipeline-step.active .pipeline-line { background: #1677ff; }
.workspace-card :deep(.ant-card-body) {
  padding: 8px 12px;
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.workspace-card :deep(.ant-tabs) {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.workspace-card :deep(.ant-tabs-content-holder) {
  flex: 1;
  overflow: hidden;
}
.workspace-card :deep(.ant-tabs-content) {
  height: 100%;
  overflow-y: auto;
}
.workspace-pane {
  height: 100%;
  min-height: 0;
}
.workspace-placeholder {
  color: #bfbfbf;
  font-size: 13px;
  padding: 16px 0;
  text-align: center;
}
.workspace-output {
  font-size: 13px;
  line-height: 1.8;
  white-space: pre-wrap;
  word-break: break-word;
}
.workspace-output :deep(h2) { font-size: 16px; margin: 10px 0 6px; border-bottom: 1px solid #f0f0f0; padding-bottom: 4px; }
.workspace-output :deep(h3) { font-size: 15px; margin: 8px 0 4px; }
.workspace-output :deep(h4) { font-size: 14px; margin: 6px 0 3px; color: #1677ff; }
.workspace-output :deep(strong) { font-weight: 600; }
.workspace-output :deep(li) { margin-left: 16px; }
.workspace-output :deep(p) { margin: 4px 0; }
.workspace-output :deep(hr) { border: none; border-top: 1px dashed #e8e8e8; margin: 12px 0; }

</style>

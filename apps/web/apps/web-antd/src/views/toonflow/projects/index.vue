<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';
import { AiModelTypeEnum } from '@vben/constants';

import {
  Button,
  Empty,
  Form,
  Input,
  message,
  Modal,
  Popconfirm,
  Select,
  Space,
  Tag,
} from 'ant-design-vue';

import { getModelSimpleList } from '#/api/ai/model/model';
import {
  createProject,
  deleteProject,
  getCreativeManuals,
  getProjects,
  updateProject,
} from '#/api/toonflow';

import '../shared/page-card.css';
import '../styles/toon-theme.css';
import ToonCard from '../components/ToonCard.vue';

defineOptions({ name: 'ToonflowProjects' });

const router = useRouter();

const loading = ref(false);
const saving = ref(false);
const modalOpen = ref(false);
const projects = ref<ToonflowApi.Project[]>([]);
const manuals = ref<ToonflowApi.CreativeManual[]>([]);
const chatModels = ref<{ label: string; value: number }[]>([]);
const imageModels = ref<{ label: string; value: number }[]>([]);
const videoModels = ref<{ label: string; value: number }[]>([]);
const imageQualityOptions = [
  { label: '1K（快速）', value: '1K' },
  { label: '2K（推荐）', value: '2K' },
  { label: '4K（高质量）', value: '4K' },
];
const videoModeOptions = [
  { label: '文生视频', value: 'text' },
  { label: '单图参考', value: 'singleImage' },
  { label: '首尾帧（必须）', value: 'startEndRequired' },
  { label: '首帧必填、尾帧可选', value: 'endFrameOptional' },
  { label: '尾帧必填、首帧可选', value: 'startFrameOptional' },
];
const visualManualOptions = computed(() => manuals.value.filter((item) => item.kind === 'visual').map((item) => ({ label: item.name, value: item.path })));
const directorManualOptions = computed(() => manuals.value.filter((item) => item.kind === 'director').map((item) => ({ label: item.name, value: item.path })));

const form = reactive<ToonflowApi.SaveProject>({
  projectType: 'short_drama',
  chatModel: undefined,
  imageModel: undefined,
  imageQuality: '2K',
  videoModel: undefined,
  name: '',
  intro: '',
  type: '短剧',
  artStyle: '',
  directorManual: '',
  mode: 'startEndRequired',
  videoRatio: '16:9',
});

function resetForm() {
  Object.assign(form, {
    id: undefined,
    projectType: 'short_drama',
    chatModel: undefined,
    imageModel: undefined,
    imageQuality: '2K',
    videoModel: undefined,
    name: '',
    intro: '',
    type: '短剧',
    artStyle: '',
    directorManual: '',
    mode: 'startEndRequired',
    videoRatio: '16:9',
  });
}

async function loadProjects() {
  loading.value = true;
  try {
    projects.value = await getProjects();
  } finally {
    loading.value = false;
  }
}

async function loadManuals() {
  manuals.value = await getCreativeManuals();
}
async function loadModels() {
  const [chats, images, videos] = await Promise.all([
    getModelSimpleList(AiModelTypeEnum.CHAT),
    getModelSimpleList(AiModelTypeEnum.IMAGE),
    getModelSimpleList(AiModelTypeEnum.VIDEO),
  ]);
  chatModels.value = chats.map((item) => ({ label: item.model, value: item.id }));
  imageModels.value = images.map((item) => ({ label: item.model, value: item.id }));
  videoModels.value = videos.map((item) => ({ label: item.model, value: item.id }));
}

function modelLabel(options: Array<{ label: string; value: number }>, id?: number) {
  return options.find((option) => option.value === id)?.label || '未配置';
}
function ratioLabel(ratio?: string) {
  const value = ratio || '16:9';
  return value === '9:16' ? `竖屏 ${value}` : value === '1:1' ? `方形 ${value}` : `横屏 ${value}`;
}

async function openCreate() {
  resetForm();
  await loadModels();
  modalOpen.value = true;
}

async function openEdit(project: any) {
  Object.assign(form, project);
  if (!imageQualityOptions.some((option) => option.value === form.imageQuality)) {
    form.imageQuality = '2K';
  }
  if (!videoModeOptions.some((option) => option.value === form.mode)) {
    form.mode = 'startEndRequired';
  }
  if (!form.videoRatio) form.videoRatio = '16:9';
  await loadModels();
  modalOpen.value = true;
}

async function handleSave() {
  if (!form.name.trim()) {
    message.warning('请输入项目名称');
    return;
  }
  saving.value = true;
  try {
    if (form.id) {
      await updateProject(form);
      message.success('项目已更新');
    } else {
      await createProject(form);
      message.success('项目已创建');
    }
    modalOpen.value = false;
    await loadProjects();
  } finally {
    saving.value = false;
  }
}

async function handleDelete(project: any) {
  await deleteProject(project.id);
  message.success('项目已删除');
  await loadProjects();
}

async function openProject(project: { id?: number }) {
  if (!project.id) {
    message.error('项目 ID 无效，无法进入');
    return;
  }
  try {
    await router.push({
      name: 'ToonflowProjectDetail',
      params: { id: String(project.id) },
    });
  } catch (error) {
    message.error(error instanceof Error ? error.message : '项目详情页打开失败');
  }
}

onMounted(() => Promise.all([loadProjects(), loadManuals(), loadModels()]));
</script>

<template>
  <Page auto-content-height class="toon-page">
    <div class="toonflow-page-shell">
      <div class="toon-header">
        <div><h1 class="toon-title">项目工作台</h1><p class="toon-subtitle">从故事到成片，继续你的创作。</p></div>
        <Space>
          <Button @click="loadProjects">刷新</Button>
          <Button class="toon-primary" type="primary" @click="openCreate">＋ 新建项目</Button>
        </Space>
      </div>

      <div v-if="loading" class="project-loading">正在加载项目…</div>
      <Empty v-else-if="projects.length === 0" description="暂无项目" />
      <div v-else class="toon-grid project-grid">
        <ToonCard v-for="record in projects" :key="record.id" clickable padding="none" class="project-card" @click="openProject(record)">
          <div class="project-card__cover toon-dots">
            <span class="project-card__initial">{{ record.name.slice(0, 1) }}</span>
            <span class="ratio-badge">{{ ratioLabel(record.videoRatio) }}</span>
          </div>
          <div class="project-card__body">
            <div class="project-card__heading"><h3>{{ record.name }}</h3><span class="project-type">{{ record.type || '短剧' }}</span></div>
            <p>{{ record.intro || '还没有项目简介，进入项目开始创作。' }}</p>
            <div class="project-card__tags"><Tag>{{ record.artStyle || '默认视觉' }}</Tag><Tag>{{ videoModeOptions.find((option) => option.value === record.mode)?.label || '文生视频' }}</Tag></div>
            <div class="project-card__models"><span>对话 · {{ modelLabel(chatModels, record.chatModel) }}</span><span>图像 · {{ modelLabel(imageModels, record.imageModel) }}</span><span>视频 · {{ modelLabel(videoModels, record.videoModel) }}</span></div>
            <div class="project-card__actions" @click.stop>
              <Button type="link" @click="openProject(record)">进入创作</Button>
              <Button type="text" @click="openEdit(record)">编辑</Button>
              <Popconfirm title="确认删除该项目及其原文、剧本、分镜数据？" @confirm="handleDelete(record)"><Button danger type="text">删除</Button></Popconfirm>
            </div>
          </div>
        </ToonCard>
      </div>
    </div>

    <Modal
      v-model:open="modalOpen"
      :confirm-loading="saving"
      :title="form.id ? '编辑项目' : '新建项目'"
      width="760px"
      :body-style="{ maxHeight: '60vh', overflowY: 'auto' }"
      @ok="handleSave"
    >
      <Form :label-col="{ span: 5 }" :model="form" class="mt-4">
        <Form.Item label="项目名称" required>
          <Input v-model:value="form.name" placeholder="短剧项目名称" />
        </Form.Item>
        <Form.Item label="简介">
          <Input.TextArea v-model:value="form.intro" :rows="3" />
        </Form.Item>
        <Form.Item label="小说类型">
          <Input v-model:value="form.type" placeholder="如：热血逆袭、甜宠、重生复仇、悬疑探案..." />
        </Form.Item>
        <Form.Item label="视觉手册">
          <Select v-model:value="form.artStyle" allow-clear :options="visualManualOptions" placeholder="选择视觉手册" />
        </Form.Item>
        <Form.Item label="导演手册">
          <Select v-model:value="form.directorManual" allow-clear :options="directorManualOptions" placeholder="选择导演手册" />
        </Form.Item>
        <Form.Item label="视频比例">
          <Select
            v-model:value="form.videoRatio"
            :options="[
              { label: '9:16', value: '9:16' },
              { label: '16:9', value: '16:9' },
              { label: '1:1', value: '1:1' },
            ]"
          />
        </Form.Item>
        <Form.Item label="图片模型">
          <Select v-model:value="form.imageModel" allow-clear :options="imageModels" placeholder="选择统一图片模型" />
        </Form.Item>
        <Form.Item label="对话模型">
          <Select v-model:value="form.chatModel" allow-clear :options="chatModels" placeholder="选择 Agent 对话模型" />
        </Form.Item>
        <Form.Item label="视频模型">
          <Select v-model:value="form.videoModel" allow-clear :options="videoModels" placeholder="选择统一视频模型" />
        </Form.Item>
        <Form.Item label="视频生成模式">
          <Select
            v-model:value="form.mode"
            :options="videoModeOptions"
            placeholder="选择视频生成方式"
          />
        </Form.Item>
        <Form.Item label="图片质量">
          <Select
            v-model:value="form.imageQuality"
            :options="imageQualityOptions"
            placeholder="选择图片分辨率"
          />
        </Form.Item>
      </Form>
    </Modal>
  </Page>
</template>

<style scoped>
.toonflow-page-shell { min-height: 100%; height: 100%; min-width: 0; overflow: auto; padding: 4px 2px 20px; }
.project-name {
  font-weight: 600;
}

.project-intro {
  color: #6b7280;
  font-size: 12px;
  line-height: 20px;
  max-width: 420px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.project-loading { display: grid; min-height: 280px; color: #737373; place-items: center; }
.project-grid { grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)) !important; gap: 18px; }
.project-card { display: flex; min-height: 372px; flex-direction: column; padding: 0 !important; overflow: hidden; border: 1px solid var(--toon-line) !important; border-radius: 18px !important; background: var(--toon-panel) !important; box-shadow: 0 8px 26px rgb(0 0 0 / 10%) !important; }
.project-card:hover { border-color: var(--ant-color-primary-border) !important; box-shadow: 0 14px 34px rgb(0 0 0 / 16%) !important; transform: translateY(-3px); }
.project-card__cover { position: relative; display: grid; height: 148px; flex: 0 0 148px; background-color: var(--toon-canvas); place-items: center; }
.project-card__initial { display: grid; width: 58px; height: 58px; border: 1px solid var(--ant-color-primary-border); border-radius: 17px; color: var(--ant-color-primary); background: var(--toon-panel); font-size: 25px; font-weight: 700; box-shadow: 0 8px 20px rgb(0 0 0 / 12%); place-items: center; }
.project-card__cover > .ratio-badge { position: absolute; top: 13px; right: 14px; margin: 0; color: var(--toon-muted); font-size: 11px; font-weight: 600; letter-spacing: .01em; }
.project-card__body { display: flex; min-width: 0; flex: 1; flex-direction: column; padding: 17px 18px 14px; }.project-card__heading { display: flex; align-items: center; justify-content: space-between; gap: 10px; }.project-card__heading h3 { overflow: hidden; margin: 0; color: var(--toon-ink); font-size: 17px; text-overflow: ellipsis; white-space: nowrap; }.project-card__body > p { height: 40px; overflow: hidden; margin: 9px 0 12px; color: var(--toon-muted); font-size: 12px; line-height: 20px; }
.project-type { flex: none; margin: 0; padding: 3px 9px; border-radius: 999px; color: var(--ant-color-primary); background: var(--ant-color-primary-bg); font-size: 11px; }
.project-card__tags { display: flex; flex-wrap: wrap; gap: 5px; }.project-card__models { display: grid; margin-top: 14px; color: var(--toon-muted); font-size: 11px; gap: 5px; }.project-card__models span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }.project-card__actions { display: flex; justify-content: flex-end; gap: 2px; margin: auto -8px 0; border-top: 1px solid var(--toon-line); padding-top: 9px; }
</style>

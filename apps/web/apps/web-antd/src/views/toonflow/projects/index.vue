<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';
import { AiModelTypeEnum } from '@vben/constants';

import {
  Button,
  Card,
  Empty,
  Form,
  Input,
  message,
  Modal,
  Popconfirm,
  Select,
  Space,
  Table,
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

defineOptions({ name: 'ToonflowProjects' });

const router = useRouter();

const loading = ref(false);
const saving = ref(false);
const modalOpen = ref(false);
const projects = ref<ToonflowApi.Project[]>([]);
const manuals = ref<ToonflowApi.CreativeManual[]>([]);
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

const columns = [
  { title: '项目名称', dataIndex: 'name', key: 'name', width: 220 },
  { title: '类型', dataIndex: 'type', key: 'type', width: 100 },
  { title: '视觉手册', dataIndex: 'artStyle', key: 'artStyle', width: 140 },
  { title: '比例', dataIndex: 'videoRatio', key: 'videoRatio', width: 90 },
  { title: '图片模型', dataIndex: 'imageModel', key: 'imageModel', width: 160 },
  { title: '视频模型', dataIndex: 'videoModel', key: 'videoModel', width: 160 },
  { title: '视频生成模式', dataIndex: 'mode', key: 'mode', width: 160 },
  { title: '操作', key: 'action', width: 220, fixed: 'right' as const },
];

function resetForm() {
  Object.assign(form, {
    id: undefined,
    projectType: 'short_drama',
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
  const [images, videos] = await Promise.all([
    getModelSimpleList(AiModelTypeEnum.IMAGE),
    getModelSimpleList(AiModelTypeEnum.VIDEO),
  ]);
  imageModels.value = images.map((item) => ({ label: item.model, value: item.id }));
  videoModels.value = videos.map((item) => ({ label: item.model, value: item.id }));
}

function modelLabel(options: Array<{ label: string; value: number }>, id?: number) {
  return options.find((option) => option.value === id)?.label || '未配置';
}

function openCreate() {
  resetForm();
  modalOpen.value = true;
}

function openEdit(project: any) {
  Object.assign(form, project);
  if (!imageQualityOptions.some((option) => option.value === form.imageQuality)) {
    form.imageQuality = '2K';
  }
  if (!videoModeOptions.some((option) => option.value === form.mode)) {
    form.mode = 'startEndRequired';
  }
  if (!form.videoRatio) form.videoRatio = '16:9';
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
  <Page auto-content-height>
    <Card :bordered="false" class="toonflow-page-card h-full">
      <template #title>项目工作台</template>
      <template #extra>
        <Space>
          <Button @click="loadProjects">刷新</Button>
          <Button type="primary" @click="openCreate">新建项目</Button>
        </Space>
      </template>

      <Table
        :columns="columns"
        :data-source="projects"
        :loading="loading"
        :pagination="{ pageSize: 10, showSizeChanger: true, pageSizeOptions: ['5', '10', '20', '50'], showTotal: (total: number) => `共 ${total} 个项目` }"
        row-key="id"
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'name'">
            <Button class="project-name p-0" type="link" @click="openProject(record)">{{ record.name }}</Button>
            <div class="project-intro">{{ record.intro || '未填写简介' }}</div>
          </template>
          <template v-if="column.key === 'mode'">
            <Tag>{{ videoModeOptions.find((option) => option.value === record.mode)?.label || '文生视频' }}</Tag>
          </template>
          <template v-if="column.key === 'imageModel'">
            {{ modelLabel(imageModels, record.imageModel) }}
          </template>
          <template v-if="column.key === 'videoModel'">
            {{ modelLabel(videoModels, record.videoModel) }}
          </template>
          <template v-if="column.key === 'action'">
            <Space>
              <Button type="link" @click="openProject(record)">进入</Button>
              <Button type="link" @click="openEdit(record)">编辑</Button>
              <Popconfirm
                title="确认删除该项目及其原文、剧本、分镜数据？"
                @confirm="handleDelete(record)"
              >
                <Button danger type="link">删除</Button>
              </Popconfirm>
            </Space>
          </template>
        </template>
        <template #emptyText>
          <Empty description="暂无项目" />
        </template>
      </Table>
    </Card>

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
</style>

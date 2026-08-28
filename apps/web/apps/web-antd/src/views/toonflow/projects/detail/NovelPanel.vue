<script setup lang="ts">
import type { TablePaginationConfig } from 'ant-design-vue';

import { computed, reactive, ref } from 'vue';

import { Button, Form, Input, InputNumber, message, Modal, Popconfirm, Space, Table, Tag, Upload } from 'ant-design-vue';

import { addNovel, updateNovel } from '#/api/toonflow';

import { parseNovelText } from '../novel-import';

const props = defineProps<{ context: any }>();
const modalOpen = ref(false);
const batchText = ref('');
const form = reactive({
  chapter: '',
  chapterData: '',
  event: '',
  id: undefined as number | undefined,
  index: 1,
  reel: '',
});

const tablePagination = computed<TablePaginationConfig>(() => ({
  current: props.context.novelPage,
  pageSize: props.context.novelPageSize,
  pageSizeOptions: ['5', '10', '20', '50'],
  showSizeChanger: true,
  showTotal: (total) => `共 ${total} 章`,
  total: props.context.novelTotal,
}));

function changeTablePage(pagination: TablePaginationConfig) {
  props.context.changeNovelPage(
    pagination.current ?? 1,
    pagination.pageSize ?? 10,
  );
}

function openNovel(chapter?: any) {
  Object.assign(form, {
    chapter: chapter?.chapter ?? '',
    chapterData: chapter?.chapterData ?? '',
    event: chapter?.event ?? '',
    id: chapter?.id,
    index: chapter?.index ?? props.context.novelTotal + 1,
    reel: chapter?.reel ?? '',
  });
  batchText.value = '';
  modalOpen.value = true;
}

async function saveNovel() {
  if (batchText.value.trim()) {
    const chapters = parseNovelText(batchText.value);
    if (!chapters.length) return message.warning('没有可导入的章节内容');
    for (let start = 0; start < chapters.length; start += 20) {
      await addNovel(props.context.projectId, chapters.slice(start, start + 20));
    }
  } else if (form.id) {
    await updateNovel({ ...form, id: form.id });
  } else {
    await addNovel(props.context.projectId, [{ ...form }]);
  }
  modalOpen.value = false;
  await props.context.reloadNovels();
}
</script>
<template>
  <section class="detail-panel detail-panel--novel">
    <div class="tab-tools">
      <Space>
        <Upload
          accept=".txt,.md,text/plain,text/markdown"
          :before-upload="context.importNovelFile"
          :show-upload-list="false"
        >
          <Button type="primary">导入文件</Button>
        </Upload>
        <Button @click="openNovel()">手动导入</Button>
        <Button @click="context.extractAllNovelEvents">提取全部待处理事件</Button>
      </Space>
    </div>
    <Table
      class="novel-table"
      :columns="context.novelColumns"
      :data-source="context.novels"
      :loading="context.novelLoading"
      :pagination="tablePagination"
      :scroll="{ x: 1408 }"
      row-key="id"
      size="small"
      @change="changeTablePage"
    >
      <template #bodyCell="{ column, record }">
        <Tag
          v-if="column.dataIndex === 'eventState'"
          :color="record.eventState === 1 ? 'green' : record.eventState === -1 ? 'red' : 'default'"
        >
          {{ record.eventState === 1 ? '已提取' : record.eventState === -1 ? '失败' : '待提取' }}
        </Tag>
        <span
          v-if="column.dataIndex === 'chapterData'"
          class="novel-cell-text"
          :title="record.chapterData || ''"
        >
          {{ record.chapterData || '暂无正文' }}
        </span>
        <span
          v-if="column.dataIndex === 'event'"
          class="novel-cell-text"
          :title="context.formatEventDisplay(record.event)"
        >
          {{ context.formatEventDisplay(record.event) || '尚未提取事件' }}
        </span>
        <Space v-if="column.key === 'action'" :size="4" class="novel-actions">
          <Button size="small" type="link" @click="openNovel(record)">编辑</Button>
          <Button size="small" type="link" @click="context.extractNovelEvents(record)">提取事件</Button>
          <Popconfirm title="确认删除章节？" @confirm="context.removeNovel(record)">
            <Button danger size="small" type="link">删除</Button>
          </Popconfirm>
        </Space>
      </template>
    </Table>
  </section>
  <Modal v-model:open="modalOpen" title="章节" width="820px" @ok="saveNovel">
    <Form :label-col="{ span: 4 }">
      <Form.Item label="批量导入">
        <Input.TextArea
          v-model:value="batchText"
          :rows="6"
          placeholder="可粘贴多章文本；留空则保存下方单章"
        />
      </Form.Item>
      <Form.Item label="序号"><InputNumber v-model:value="form.index" :min="1" /></Form.Item>
      <Form.Item label="分卷"><Input v-model:value="form.reel" /></Form.Item>
      <Form.Item label="章节"><Input v-model:value="form.chapter" /></Form.Item>
      <Form.Item label="正文"><Input.TextArea v-model:value="form.chapterData" :rows="8" /></Form.Item>
      <Form.Item label="事件"><Input.TextArea v-model:value="form.event" :rows="3" /></Form.Item>
    </Form>
  </Modal>
</template>

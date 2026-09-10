<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue';
import { Page } from '@vben/common-ui';
import { Button, Card, Empty, Input, List, Select, Space, Tag, message } from 'ant-design-vue';
import { deleteModelPromptMap, getModelPromptMaps, getModelSimpleList, saveModelPromptMap } from '#/api/ai/model/model';
import { getPrompts } from '#/api/toonflow';
import type { ToonflowApi } from '#/api/toonflow';

type ModelOption = { label: string; value: number };
const models = ref<ModelOption[]>([]);
const prompts = ref<ToonflowApi.Prompt[]>([]);
const mappings = ref<Array<{ id: number; modelConfigId: number; promptKey: string; enabled: boolean; modelName: string; model: string }>>([]);
const modelId = ref<number>();
const promptKey = ref('');
const loading = ref(false);
const saving = ref(false);
const promptOptions = computed(() => prompts.value.map((item) => ({ label: `${item.name} · ${item.sourceKey || item.id}`, value: item.sourceKey || String(item.id) })));

async function load() {
  loading.value = true;
  try {
    const [chat, image, video, speech, promptRows] = await Promise.all([getModelSimpleList(1), getModelSimpleList(2), getModelSimpleList(4), getModelSimpleList(3), getPrompts()]);
    models.value = [...chat, ...image, ...video, ...speech].map((item) => ({ label: `${item.name} · ${item.model}`, value: item.id }));
    prompts.value = promptRows;
    mappings.value = await getModelPromptMaps();
  } finally { loading.value = false; }
}
async function addMapping() {
  if (!modelId.value || !promptKey.value) return message.warning('请选择模型和 Prompt');
  saving.value = true;
  try { await saveModelPromptMap({ modelConfigId: modelId.value, promptKey: promptKey.value }); message.success('映射已保存'); promptKey.value = ''; mappings.value = await getModelPromptMaps(); } finally { saving.value = false; }
}
async function removeMapping(id: number) { await deleteModelPromptMap(id); mappings.value = mappings.value.filter((item) => item.id !== id); message.success('映射已删除'); }
onMounted(load);
</script>
<template>
  <Page auto-content-height class="toon-page">
    <Card :bordered="false" class="toonflow-page-card toon-surface"><div class="toon-header"><div><h1 class="toon-title">模型 Prompt 映射</h1><p class="toon-subtitle">为模型选择对应的提示词。</p></div><Button :loading="loading" @click="load">刷新</Button></div>
      <Space wrap><Select v-model:value="modelId" :options="models" show-search option-filter-prop="label" placeholder="选择 Vendor 模型" style="width:300px" /><Select v-model:value="promptKey" :options="promptOptions" show-search option-filter-prop="label" placeholder="选择 Prompt" style="width:320px" /><Input v-model:value="promptKey" placeholder="或直接输入 Prompt Key" style="width:260px" /><Button type="primary" :loading="saving" @click="addMapping">添加映射</Button></Space>
      <List v-if="mappings.length || loading" class="mt-4" bordered :data-source="mappings"><template #renderItem="{item}"><List.Item><List.Item.Meta :title="`${item.modelName} · ${item.model}`" :description="item.promptKey" /><Tag :color="item.enabled ? 'green' : 'default'">{{ item.enabled ? '启用' : '停用' }}</Tag><Button danger type="link" @click="removeMapping(item.id)">删除</Button></List.Item></template></List>
      <Empty v-if="!loading && !mappings.length" class="mt-6" description="暂无模型 Prompt 映射" />
    </Card>
  </Page>
</template>

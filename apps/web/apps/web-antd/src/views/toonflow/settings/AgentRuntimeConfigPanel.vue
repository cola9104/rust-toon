<script setup lang="ts">
import type { ToonflowApi } from '#/api/toonflow';

import { computed } from 'vue';
import { Card, Select, Space, Table, Tag } from 'ant-design-vue';

const props = defineProps<{
  agents: ToonflowApi.AgentDeployment[];
  prompts: ToonflowApi.Prompt[];
  skills: ToonflowApi.Skill[];
}>();

const promptOptions = computed(() => props.prompts.map((item) => ({ label: item.name, value: item.sourceKey || String(item.id) })));
const configuredCount = computed(() => props.agents.filter((item) => item.modelConfigId).length);
const enabledCount = computed(() => props.agents.filter((item) => !item.disabled).length);

function role(key: string) {
  if (key.includes('supervisionAgent')) return '监督 Agent';
  if (key.includes('decisionAgent')) return '决策 Agent';
  if (key.includes(':')) return '子 Agent';
  return '主 Agent';
}

const columns = [
  { title: 'Agent', dataIndex: 'name', width: 190 },
  { title: '层级', key: 'role', width: 100 },
  { title: 'Prompt', key: 'prompt', width: 190 },
  { title: '记忆范围', key: 'memory', width: 120 },
];
</script>

<template>
  <Card size="small" title="Agent 运行配置">
    <div class="runtime-summary"><span><b>{{ configuredCount }}</b> 已配置模型</span><span><b>{{ enabledCount }}</b> 个启用中</span><span><b>{{ prompts.length }}</b> 个 Prompt</span><span><b>{{ skills.length }}</b> 个 Skill</span></div>
    <Table :columns="columns" :data-source="agents" :pagination="false" row-key="id" size="small">
      <template #bodyCell="{ column, record }">
        <Tag v-if="column.key === 'role'" :color="role(record.key) === '监督 Agent' ? 'orange' : record.key.includes(':') ? 'blue' : 'green'">{{ role(record.key) }}</Tag>
        <Select v-else-if="column.key === 'prompt'" v-model:value="record.promptSourceKey" :options="promptOptions" allow-clear placeholder="选择 Prompt" style="width: 175px" />
        <Select v-else-if="column.key === 'memory'" v-model:value="record.memoryScope" :options="[{ label: '项目', value: 'project' }, { label: '剧本', value: 'script' }, { label: '节点', value: 'node' }]" style="width: 105px" />
      </template>
    </Table>
    <Space class="panel-hint">Prompt 可按 Agent 覆盖；Skill 按 Toonflow-app 规则由 Agent 类型和项目上下文自动加载，不在这里绑定。</Space>
  </Card>
</template>

<style scoped>.panel-hint{margin-top:12px;color:#8c8c8c;font-size:12px}.runtime-summary{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:12px}.runtime-summary span{padding:7px 10px;border:1px solid var(--ant-color-border-secondary);border-radius:8px;color:var(--ant-color-text-secondary);font-size:12px}.runtime-summary b{margin-right:3px;color:var(--ant-color-primary);font-size:16px}</style>

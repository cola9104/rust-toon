<script setup lang="ts">
import type { ToonflowApi } from '#/api/toonflow';

import { computed } from 'vue';
import { Drawer, Empty, List, Tag } from 'ant-design-vue';

const props = defineProps<{
  events: ToonflowApi.AgentRunEvent[];
  loading?: boolean;
  open: boolean;
  runId?: number;
  state?: string;
}>();

const emit = defineEmits<{ close: []; refresh: [] }>();
const title = computed(() => props.runId ? `Agent 运行 #${props.runId}` : 'Agent 运行事件');
</script>

<template>
  <Drawer :open="open" :title="title" width="560" @close="emit('close')">
    <div class="run-meta"><Tag :color="state === 'failed' ? 'red' : state === 'running' ? 'blue' : 'default'">{{ state || '未知' }}</Tag><span>事件 {{ events.length }} 条</span><a @click="emit('refresh')">刷新</a></div>
    <Empty v-if="!loading && events.length === 0" description="暂无运行事件" />
    <List v-else :data-source="events" :loading="loading" item-layout="vertical">
      <template #renderItem="{ item }"><List.Item><List.Item.Meta :title="item.eventType" :description="new Date(item.createTime).toLocaleString()"/><pre class="event-data">{{ item.data?.text || JSON.stringify(item.data, null, 2) }}</pre></List.Item></template>
    </List>
  </Drawer>
</template>

<style scoped>.run-meta{display:flex;align-items:center;gap:10px;margin-bottom:14px;color:#8c8c8c;font-size:12px}.run-meta a{margin-left:auto;cursor:pointer}.event-data{max-height:260px;overflow:auto;margin:0;padding:10px;border-radius:8px;white-space:pre-wrap;background:#f7f7f5;font:12px/1.6 monospace}</style>

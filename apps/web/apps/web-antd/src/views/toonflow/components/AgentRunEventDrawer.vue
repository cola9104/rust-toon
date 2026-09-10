<script setup lang="ts">
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onBeforeUnmount, watch } from 'vue';
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
const stateLabel = computed(() => ({ running: '运行中', success: '已完成', completed: '已完成', failed: '失败', canceled: '已取消', interrupted: '已中断' }[props.state?.toLowerCase() ?? ''] ?? props.state ?? '未知'));
const stateColor = computed(() => ({ running: 'processing', success: 'success', completed: 'success', failed: 'error', canceled: 'warning', interrupted: 'warning' }[props.state?.toLowerCase() ?? ''] ?? 'default'));
const eventLabel = (type?: string) => ({ started: '已启动', memory_retrieval: '已完成记忆检索', knowledge_retrieval: '已完成知识检索', thinking: '思考中', retry: '重试中', tool_call: '调用工具', tool_result: '工具返回', completed: '已完成', failed: '执行失败' }[type ?? ''] ?? type ?? '运行事件');
const eventText = (data?: Record<string, any>) => data?.text || data?.message || (data?.tool ? `${data.tool}${data.success === false ? '：执行失败' : ''}` : data?.error) || JSON.stringify(data, null, 2);
let refreshTimer: number | undefined;
const stopPolling = () => { if (refreshTimer) window.clearInterval(refreshTimer); refreshTimer = undefined; };
const syncPolling = () => {
  stopPolling();
  if (props.open && props.state?.toLowerCase() === 'running') {
    refreshTimer = window.setInterval(() => emit('refresh'), 2000);
  }
};
watch(() => [props.open, props.state], syncPolling, { immediate: true });
onBeforeUnmount(stopPolling);
</script>

<template>
  <Drawer root-class-name="toon-overlay" :open="open" :title="title" width="560" @close="emit('close')">
    <div class="run-meta"><Tag :color="stateColor">{{ stateLabel }}</Tag><span v-if="state === 'running'">Agent 正在执行，可继续等待</span><span v-else>事件 {{ events.length }} 条</span><a @click="emit('refresh')">刷新状态</a></div>
    <Empty v-if="!loading && events.length === 0" :description="state === 'running' ? 'Agent 已启动，等待第一条运行事件…' : '暂无运行事件'" />
    <List v-else :data-source="events" :loading="loading" item-layout="vertical">
      <template #renderItem="{ item }"><List.Item><List.Item.Meta :title="eventLabel(item.eventType)" :description="new Date(item.createTime).toLocaleString()"/><pre class="event-data">{{ eventText(item.data) }}</pre></List.Item></template>
    </List>
  </Drawer>
</template>

<style scoped>.run-meta{display:flex;align-items:center;gap:10px;margin-bottom:14px;color:var(--ant-color-text-tertiary);font-size:12px}.run-meta a{margin-left:auto;cursor:pointer}.event-data{max-height:260px;overflow:auto;margin:0;padding:10px;border-radius:8px;white-space:pre-wrap;background:var(--toon-canvas);font:12px/1.6 monospace}</style>

<script lang="ts" setup>
import type { InfraApiAccessLogApi } from '#/api/infra/api-access-log';

import { computed, ref } from 'vue';

import { useVbenModal } from '@vben/common-ui';
import { Button, message, RadioButton, RadioGroup, Tag } from 'ant-design-vue';

import { useDescription } from '#/components/description';

import { useDetailSchema } from '../data';

const formData = ref<InfraApiAccessLogApi.ApiAccessLog>();
const mode = ref('pretty');

function displayPayload(value?: string) {
  if (!value) return '未采集正文';
  if (mode.value === 'raw') return value;
  // Format only the JSON body, leaving the recorded headers intact.
  const lines = value.split(/\r?\n/);
  const bodyIndex = lines.findIndex((line) => /^[\[{]/.test(line.trim()));
  if (bodyIndex < 0) return value;
  try {
    const body = JSON.stringify(JSON.parse(lines.slice(bodyIndex).join('\n')), null, 2);
    return `${lines.slice(0, bodyIndex).join('\n')}\n\n${body}`.trimStart();
  } catch {
    return value;
  }
}

async function copyPayload(value?: string) {
  if (!value) return;
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(value);
    } else {
      const input = document.createElement('textarea');
      input.value = value;
      input.style.position = 'fixed';
      input.style.opacity = '0';
      document.body.append(input);
      input.select();
      try {
        if (!document.execCommand('copy')) throw new Error('Copy failed');
      } finally { input.remove(); }
    }
    message.success('已复制原文');
  } catch { message.error('复制失败，请选择文本手动复制'); }
}

const requestPreview = computed(() => {
  const data = formData.value;
  if (!data) return '';
  return displayPayload(data.requestParams);
});

const responsePreview = computed(() => {
  const data = formData.value;
  if (!data) return '';
  return displayPayload(data.responseBody);
});

const [Descriptions] = useDescription({
  bordered: true,
  column: { xs: 1, sm: 1, md: 2, lg: 2, xl: 2, xxl: 2 },
  schema: (() => {
    const fields = useDetailSchema().filter((item) =>
      !['requestParams', 'responseBody', 'requestMethod'].includes(item.field),
    );
    const fullWidth = new Set(['traceId', 'userAgent', 'beginTime']);
    const paired = fields.filter((item) => !fullWidth.has(item.field));
    const wide = fields.filter((item) => fullWidth.has(item.field));
    return [
      ...paired.map((item, index) => ({
        ...item,
        span: paired.length % 2 === 1 && index === paired.length - 1 ? 2 : 1,
      })),
      ...wide.map((item) => ({ ...item, span: 2 })),
    ];
  })(),
});

const [Modal, modalApi] = useVbenModal({
  async onOpenChange(isOpen: boolean) {
    if (!isOpen) {
      formData.value = undefined;
      return;
    }
    // 加载数据
    const data = modalApi.getData<InfraApiAccessLogApi.ApiAccessLog>();
    if (!data || !data.id) {
      return;
    }
    modalApi.lock();
    try {
      formData.value = data;
      mode.value = 'pretty';
    } finally {
      modalApi.unlock();
    }
  },
});
</script>

<template>
  <Modal
    title="API 访问日志详情"
    class="w-[min(1200px,calc(100vw-32px))]"
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="mb-4 flex flex-wrap items-center gap-2 rounded-lg bg-muted p-3">
      <Tag color="blue">{{ formData?.requestMethod }}</Tag>
      <code class="min-w-0 flex-1 break-all text-sm">{{ formData?.requestUrl }}</code>
      <Tag>{{ formData?.resultCode ?? '未知状态' }}</Tag>
      <span class="text-sm text-muted-foreground">{{ formData?.duration ?? 0 }} ms</span>
    </div>
    <div class="log-detail-fields">
      <Descriptions :data="formData" />
    </div>
    <div class="mt-5 flex items-center justify-between gap-3">
      <span class="font-medium">请求与响应</span>
      <RadioGroup v-model:value="mode" size="small">
        <RadioButton value="pretty">格式化</RadioButton>
        <RadioButton value="raw">原文</RadioButton>
      </RadioGroup>
    </div>
    <div class="mt-5 grid grid-cols-1 gap-4 md:grid-cols-2">
      <section class="min-w-0 rounded-lg border border-border">
        <div class="flex items-center justify-between border-b border-border px-3 py-2 text-sm font-medium">请求 Request <Button size="small" :disabled="!formData?.requestParams" @click="copyPayload(formData?.requestParams)">复制</Button></div>
        <pre class="request-preview">{{ requestPreview }}</pre>
      </section>
      <section class="min-w-0 rounded-lg border border-border">
        <div class="flex items-center justify-between border-b border-border px-3 py-2 text-sm font-medium">响应 Response <Button size="small" :disabled="!formData?.responseBody" @click="copyPayload(formData?.responseBody)">复制</Button></div>
        <pre class="response-preview">{{ responsePreview }}</pre>
      </section>
    </div>
  </Modal>
</template>

<style scoped>
.log-detail-fields :deep(.ant-descriptions-view > table) {
  width: 100%;
  table-layout: fixed;
}

.log-detail-fields :deep(.ant-descriptions-item-label) {
  width: 112px;
}

.log-detail-fields :deep(.ant-descriptions-item-content) {
  overflow-wrap: anywhere;
  word-break: break-word;
}

@media (min-width: 768px) {
  .log-detail-fields :deep(.ant-descriptions-item-content[colspan='1']) {
    width: calc(50% - 112px);
  }
}

.request-preview,
.response-preview {
  min-height: 220px;
  max-height: 420px;
  overflow: auto;
  border-radius: 8px;
  padding: 14px;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
  line-height: 1.6;
  margin: 0;
}

.request-preview {
  background: hsl(var(--muted));
  color: hsl(var(--foreground));
}

.response-preview {
  background: hsl(var(--muted));
  color: hsl(var(--foreground));
}
</style>

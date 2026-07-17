<script lang="ts" setup>
import type { InfraMonitorApi } from '#/api/infra/monitor';
import { onMounted, ref } from 'vue';
import { Page } from '@vben/common-ui';
import { Button, Card, Descriptions, Progress, Statistic, Tag } from 'ant-design-vue';
import { getRustMonitor } from '#/api/infra/monitor';

const data = ref<InfraMonitorApi.RustMonitor>();
const loading = ref(false);
const mb = (value = 0) => (value / 1024 / 1024).toFixed(2);
const uptime = (value = 0) => `${Math.floor(value / 86400)}天 ${Math.floor(value % 86400 / 3600)}小时 ${Math.floor(value % 3600 / 60)}分`;
async function load() { loading.value = true; try { data.value = await getRustMonitor(); } finally { loading.value = false; } }
onMounted(load);
</script>

<template>
  <Page auto-content-height>
    <div class="mb-4 flex justify-end"><Button :loading="loading" @click="load">刷新监控</Button></div>
    <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
      <Card><Statistic title="运行时间" :value="uptime(data?.uptimeSeconds)" /></Card>
      <Card><Statistic title="常驻内存" :value="mb(data?.memory.residentBytes)" suffix="MB" /></Card>
      <Card><Statistic title="线程数" :value="data?.threads || 0" /></Card>
      <Card><Statistic title="文件描述符" :value="data?.fileDescriptors || 0" /></Card>
    </div>
    <Card class="mt-4" title="Rust 服务实例">
      <Descriptions bordered :column="2">
        <Descriptions.Item label="服务">{{ data?.service }}</Descriptions.Item>
        <Descriptions.Item label="状态"><Tag :color="data?.healthy ? 'green' : 'red'">{{ data?.healthy ? '健康' : '异常' }}</Tag></Descriptions.Item>
        <Descriptions.Item label="应用版本">{{ data?.version }}</Descriptions.Item>
        <Descriptions.Item label="运行环境">{{ data?.environment }}</Descriptions.Item>
        <Descriptions.Item label="进程 ID">{{ data?.processId }}</Descriptions.Item>
        <Descriptions.Item label="CPU 核数">{{ data?.cpuCores }}</Descriptions.Item>
        <Descriptions.Item label="Rust 运行时">{{ data?.rust }}</Descriptions.Item>
        <Descriptions.Item label="虚拟内存">{{ mb(data?.memory.virtualBytes) }} MB</Descriptions.Item>
      </Descriptions>
      <div class="mt-6"><div class="mb-2">常驻内存 / 峰值内存</div><Progress :percent="data?.memory.peakResidentBytes ? Number(((data.memory.residentBytes / data.memory.peakResidentBytes) * 100).toFixed(2)) : 0" /></div>
    </Card>
  </Page>
</template>

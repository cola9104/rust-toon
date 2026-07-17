<script lang="ts" setup>
import type { InfraMonitorApi } from '#/api/infra/monitor';
import { onMounted, ref } from 'vue';
import { Page } from '@vben/common-ui';
import { Button, Card, Descriptions, Space, Statistic, Table, Tag } from 'ant-design-vue';
import { getPostgreSqlMonitor } from '#/api/infra/monitor';

const data = ref<InfraMonitorApi.PostgreSqlMonitor>();
const loading = ref(false);
const formatBytes = (value = 0) => `${(value / 1024 / 1024).toFixed(2)} MB`;
async function load() { loading.value = true; try { data.value = await getPostgreSqlMonitor(); } finally { loading.value = false; } }
onMounted(load);
</script>

<template>
  <Page auto-content-height>
    <div class="mb-4 flex justify-end"><Button :loading="loading" @click="load">刷新监控</Button></div>
    <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
      <Card><Statistic title="数据库大小" :value="formatBytes(data?.databaseSize)" /></Card>
      <Card><Statistic title="连接数" :value="data?.connections || 0" :suffix="`/ ${data?.maxConnections || 0}`" /></Card>
      <Card><Statistic title="缓存命中率" :precision="2" :value="data?.cacheHitRatio || 0" suffix="%" /></Card>
      <Card><Statistic title="死锁数" :value="data?.deadlocks || 0" /></Card>
    </div>
    <Card class="mt-4" title="PostgreSQL 实例">
      <Descriptions bordered :column="2">
        <Descriptions.Item label="数据库">{{ data?.databaseName }}</Descriptions.Item>
        <Descriptions.Item label="启动时间">{{ data?.startedAt }}</Descriptions.Item>
        <Descriptions.Item label="已提交事务">{{ data?.transactions.committed || 0 }}</Descriptions.Item>
        <Descriptions.Item label="回滚事务">{{ data?.transactions.rolledBack || 0 }}</Descriptions.Item>
        <Descriptions.Item label="连接状态" :span="2"><Space><Tag v-for="item in data?.connectionStates" :key="item.state">{{ item.state }}: {{ item.count }}</Tag></Space></Descriptions.Item>
        <Descriptions.Item label="版本" :span="2">{{ data?.version }}</Descriptions.Item>
      </Descriptions>
    </Card>
    <Card class="mt-4" title="数据表占用">
      <Table :data-source="data?.tables || []" :loading="loading" :pagination="false" row-key="table" size="small">
        <Table.Column key="table" title="数据表"><template #default="{ record }">{{ record.schema }}.{{ record.table }}</template></Table.Column>
        <Table.Column data-index="liveRows" title="有效行" /><Table.Column data-index="deadRows" title="死元组" />
        <Table.Column key="totalSize" title="占用"><template #default="{ record }">{{ formatBytes(record.totalSize) }}</template></Table.Column>
        <Table.Column data-index="indexScans" title="索引扫描" /><Table.Column data-index="sequentialScans" title="顺序扫描" />
      </Table>
    </Card>
    <Card class="mt-4" title="活动 SQL">
      <Table :data-source="data?.activeQueries || []" :pagination="false" row-key="pid" size="small">
        <Table.Column data-index="pid" title="PID" width="90" /><Table.Column data-index="user" title="用户" width="120" />
        <Table.Column data-index="state" title="状态" width="120" /><Table.Column data-index="durationMs" title="耗时(ms)" width="120" />
        <Table.Column data-index="query" title="SQL" />
      </Table>
    </Card>
  </Page>
</template>

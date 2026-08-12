<script lang="ts" setup>
import { Page } from '@vben/common-ui';

import { Button, Card, Col, Row, Space, Statistic, Tag, Typography } from 'ant-design-vue';

import StageNav from '../components/StageNav.vue';
import { useProjectDetail } from './detail/useProjectDetail';

import '../shared/page-card.css';
import '../styles/toon-theme.css';

defineOptions({ name: 'ToonflowProjectDetail' });
const view = useProjectDetail();
</script>

<template>
  <Page auto-content-height class="toon-page">
    <Card :bordered="false" :loading="view.loading" class="toonflow-page-card h-full toon-surface">
      <template #title>
        <Space><Button @click="view.router.back()">返回</Button><Typography.Text strong>{{ view.project?.name || '项目详情' }}</Typography.Text><Tag>{{ view.project?.videoRatio || '16:9' }}</Tag></Space>
      </template>
      <template #extra><Button @click="view.loadAll">刷新</Button></template>

      <Row :gutter="16" class="mb-4">
        <Col :span="6"><Card size="small"><Statistic title="角色资产" :value="view.statistics.roleCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="剧本" :value="view.statistics.scriptCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="分镜" :value="view.statistics.storyboardCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="视频" :value="view.statistics.videoCount" /></Card></Col>
      </Row>

      <StageNav v-model="view.activeTab" :stages="view.stages" />
      <component :is="view.activePanelComponent" :context="view.panelContext" />
    </Card>
  </Page>
</template>

<style src="./project-detail.css"></style>

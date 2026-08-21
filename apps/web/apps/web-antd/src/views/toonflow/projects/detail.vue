<script lang="ts" setup>
import { Page } from '@vben/common-ui';

import { Button, Card, Col, Row, Space, Statistic, Typography } from 'ant-design-vue';

import StageNav from '../components/StageNav.vue';
import { useProjectDetail } from './detail/useProjectDetail';

import '../shared/page-card.css';
import '../styles/toon-theme.css';

defineOptions({ name: 'ToonflowProjectDetail' });
const view = useProjectDetail();
</script>

<template>
  <Page auto-content-height class="toon-page">
    <div class="toonflow-detail-shell" :class="{ loading: view.loading }">
      <header class="detail-header">
        <Space><Button @click="view.router.back()">返回</Button><Typography.Text strong>{{ view.project?.name || '项目详情' }}</Typography.Text><span class="detail-ratio-badge">{{ view.project?.videoRatio || '16:9' }}</span></Space>
        <Button @click="view.loadAll">刷新</Button>
      </header>

      <Row :gutter="16" class="mb-4">
        <Col :span="6"><Card size="small"><Statistic title="角色资产" :value="view.statistics.roleCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="剧本" :value="view.statistics.scriptCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="分镜" :value="view.statistics.storyboardCount" /></Card></Col>
        <Col :span="6"><Card size="small"><Statistic title="视频" :value="view.statistics.videoCount" /></Card></Col>
      </Row>

      <StageNav v-model="view.activeTab" :stages="view.stages" />
      <component :is="view.activePanelComponent" :context="view.panelContext" />
    </div>
  </Page>
</template>

<style src="./project-detail.css"></style>

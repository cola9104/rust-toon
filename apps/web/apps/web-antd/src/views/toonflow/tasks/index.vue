<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Card, Table, Tag } from 'ant-design-vue';

import { getTasks } from '#/api/toonflow';

import '../shared/page-card.css';
const loading=ref(false); const tasks=ref<ToonflowApi.Task[]>([]);
const columns=[{title:'任务',dataIndex:'description',width:260},{title:'项目',dataIndex:'projectName',width:180},{title:'类型',dataIndex:'taskClass',width:150},{title:'模型',dataIndex:'model',width:240},{title:'关联章节/对象',dataIndex:'relatedObjects'},{title:'开始时间',key:'startTime',width:180},{title:'状态',dataIndex:'state',width:110},{title:'失败原因',dataIndex:'reason'}];
const color=(state:string)=>({success:'green',completed:'green',running:'blue',failed:'red',error:'red'}[state?.toLowerCase()]??'default');
const typeLabel=(type:string)=>({novelEvent:'章节事件提取',videoExport:'成片导出','工作流图片生成':'工作流图片生成'}[type]??type);
const stateLabel=(state:string)=>({success:'成功',completed:'已完成',running:'处理中',failed:'失败',error:'失败'}[state?.toLowerCase()]??state??'未知');
async function load(){loading.value=true;try{tasks.value=await getTasks()}finally{loading.value=false}} onMounted(load);
</script>
<template><Page auto-content-height><Card :bordered="false" class="toonflow-page-card h-full"><template #title>任务中心</template><template #extra><Button @click="load">刷新</Button></template><Table :columns="columns" :data-source="tasks" :loading="loading" row-key="id"><template #bodyCell="{column,record}"><template v-if="column.dataIndex === 'taskClass'"><Tag>{{ typeLabel(record.taskClass) }}</Tag></template><template v-else-if="column.dataIndex === 'state'"><Tag :color="color(record.state)">{{ stateLabel(record.state) }}</Tag></template><template v-else-if="column.key === 'startTime'">{{ record.startTime ? new Date(record.startTime).toLocaleString() : '—' }}</template></template></Table></Card></Page></template>

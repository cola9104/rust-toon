<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';
import { onMounted, ref } from 'vue';
import { Page } from '@vben/common-ui';
import { Button, Card, Table, Tag } from 'ant-design-vue';
import { getTasks } from '#/api/toonflow';
const loading=ref(false),tasks=ref<ToonflowApi.Task[]>([]);
const columns=[{title:'任务',dataIndex:'description',width:260},{title:'项目',dataIndex:'projectName',width:180},{title:'类型',dataIndex:'taskClass',width:150},{title:'模型',dataIndex:'model',width:150},{title:'关联对象',dataIndex:'relatedObjects'},{title:'开始时间',key:'startTime',width:180},{title:'状态',dataIndex:'state',width:110},{title:'失败原因',dataIndex:'reason'}];
const color=(state:string)=>({success:'green',completed:'green',running:'blue',failed:'red',error:'red'}[state?.toLowerCase()]??'default');
async function load(){loading.value=true;try{tasks.value=await getTasks()}finally{loading.value=false}} onMounted(load);
</script>
<template><Page auto-content-height><Card :bordered="false"><template #title>任务中心</template><template #extra><Button @click="load">刷新</Button></template><Table :columns="columns" :data-source="tasks" :loading="loading" row-key="id"><template #bodyCell="{column,record}"><template v-if="column.dataIndex==='state'"><Tag :color="color(record.state)">{{record.state||'未知'}}</Tag></template><template v-if="column.key==='startTime'">{{record.startTime?new Date(record.startTime).toLocaleString():'—'}}</template></template></Table></Card></Page></template>

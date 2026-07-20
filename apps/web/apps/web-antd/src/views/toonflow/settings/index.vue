<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';
import { AiModelTypeEnum } from '@vben/constants';

import { Button, Card, InputNumber, message, Select, Switch, Table, Tag } from 'ant-design-vue';

import { getModelSimpleList } from '#/api/ai/model/model';
import { getAgentDeployments, updateAgentDeployment } from '#/api/toonflow';

import '../shared/page-card.css';

type ModelType=ToonflowApi.AgentDeployment['modelType'];
type ModelOption={label:string;value:number};
const loading=ref(false);const saving=ref(false);const agents=ref<ToonflowApi.AgentDeployment[]>([]);const baseline=ref<Record<number,string>>({});
const models=ref<Record<ModelType,ModelOption[]>>({chat:[],image:[],speech:[],video:[]});
const typeLabels:Record<ModelType,string>={chat:'文本',image:'图片',speech:'语音',video:'视频'};
const columns=[{title:'配置项',dataIndex:'name'},{title:'类型',key:'type',width:90},{title:'用途',dataIndex:'description'},{title:'统一模型',key:'model',width:280},{title:'温度',key:'temperature',width:130},{title:'最大 Token',key:'tokens',width:150},{title:'启用',key:'enabled',width:90}];
function options(agent:{modelType?:ModelType}){return models.value[agent.modelType??'chat']}
function toOptions(items:Array<{id:number;name:string;platform:string}>){return items.map(x=>({label:`${x.name} (${x.platform})`,value:x.id}))}
function editable(row:ToonflowApi.AgentDeployment){return JSON.stringify([row.modelConfigId,row.temperature,row.maxOutputTokens,row.disabled])}
const changedRows=computed(()=>agents.value.filter(row=>baseline.value[row.id]!==editable(row)));
async function load(){loading.value=true;try{const[a,c,i,v,s]=await Promise.all([getAgentDeployments(),getModelSimpleList(AiModelTypeEnum.CHAT),getModelSimpleList(AiModelTypeEnum.IMAGE),getModelSimpleList(AiModelTypeEnum.VIDEO),getModelSimpleList(AiModelTypeEnum.VOICE)]);agents.value=a;baseline.value=Object.fromEntries(a.map(row=>[row.id,editable(row)]));models.value={chat:toOptions(c),image:toOptions(i),video:toOptions(v),speech:toOptions(s)}}finally{loading.value=false}}
async function saveAll(){const rows=changedRows.value;if(!rows.length)return;if(rows.some(row=>!row.modelConfigId))return message.warning('变更项必须选择对应类型的模型');saving.value=true;try{await Promise.all(rows.map(row=>updateAgentDeployment({id:row.id,modelConfigId:row.modelConfigId,temperature:row.temperature,maxOutputTokens:row.maxOutputTokens,disabled:row.disabled})));message.success(`已保存 ${rows.length} 项模型配置`);await load()}finally{saving.value=false}}
onMounted(load);
</script>
<template><Page auto-content-height><Card :bordered="false" class="toonflow-page-card h-full" title="Toonflow 模型配置"><template #extra><Button type="primary" :disabled="changedRows.length === 0" :loading="saving" @click="saveAll">保存</Button></template><Table :columns="columns" :data-source="agents" :loading="loading" :pagination="false" row-key="id"><template #bodyCell="{column,record}"><Tag v-if="column.key === 'type'">{{ typeLabels[record.modelType as ModelType] }}</Tag><Select v-else-if="column.key === 'model'" v-model:value="record.modelConfigId" class="w-full" :options="options(record)" :placeholder="`选择${typeLabels[record.modelType as ModelType]}模型`" /><InputNumber v-else-if="column.key === 'temperature' && record.modelType === 'chat'" v-model:value="record.temperature" :min="0" :max="2" /><InputNumber v-else-if="column.key === 'tokens' && record.modelType === 'chat'" v-model:value="record.maxOutputTokens" :min="1" /><span v-else-if="column.key === 'temperature' || column.key === 'tokens'">—</span><Switch v-else-if="column.key === 'enabled'" :checked="!record.disabled" @update:checked="record.disabled = !$event" /></template></Table></Card></Page></template>

<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';
import { onMounted, ref } from 'vue';
import { Page } from '@vben/common-ui';
import { Button, Card, InputNumber, Select, Space, Switch, Table, message } from 'ant-design-vue';
import { AiModelTypeEnum } from '@vben/constants';
import { getModelSimpleList } from '#/api/ai/model/model';
import { getAgentDeployments, updateAgentDeployment } from '#/api/toonflow';

const loading=ref(false);const agents=ref<ToonflowApi.AgentDeployment[]>([]);const chatModels=ref<{label:string;value:number}[]>([]);const speechModels=ref<{label:string;value:number}[]>([]);
const columns=[{title:'Agent',dataIndex:'name'},{title:'用途',dataIndex:'description'},{title:'统一模型',key:'model',width:260},{title:'温度',key:'temperature',width:130},{title:'最大 Token',key:'tokens',width:150},{title:'停用',key:'disabled',width:90},{title:'操作',key:'action',width:100}];
function options(agent:any){return agent.key==='ttsDubbing'?speechModels.value:chatModels.value}
async function load(){loading.value=true;try{const[a,c,s]=await Promise.all([getAgentDeployments(),getModelSimpleList(AiModelTypeEnum.CHAT),getModelSimpleList(AiModelTypeEnum.VOICE)]);agents.value=a;chatModels.value=c.map(x=>({label:`${x.name} (${x.platform})`,value:x.id}));speechModels.value=s.map(x=>({label:`${x.name} (${x.platform})`,value:x.id}))}finally{loading.value=false}}
async function save(row:any){if(!row.modelConfigId)return message.warning('必须选择统一模型');await updateAgentDeployment({id:row.id,modelConfigId:row.modelConfigId,temperature:row.temperature,maxOutputTokens:row.maxOutputTokens,disabled:row.disabled});message.success('Agent 配置已保存');await load()}
onMounted(load);
</script>
<template><Page auto-content-height><Card title="Toonflow Agent 模型配置"><Table :columns="columns" :data-source="agents" :loading="loading" :pagination="false" row-key="id"><template #bodyCell="{column,record}"><Select v-if="column.key==='model'" v-model:value="record.modelConfigId" class="w-full" :options="options(record)" placeholder="选择统一 AI 模型"/><InputNumber v-else-if="column.key==='temperature'" v-model:value="record.temperature" :min="0" :max="2"/><InputNumber v-else-if="column.key==='tokens'" v-model:value="record.maxOutputTokens" :min="1"/><Switch v-else-if="column.key==='disabled'" v-model:checked="record.disabled"/><Space v-else-if="column.key==='action'"><Button type="link" @click="save(record)">保存</Button></Space></template></Table></Card></Page></template>

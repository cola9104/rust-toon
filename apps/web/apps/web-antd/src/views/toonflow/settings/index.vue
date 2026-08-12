<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';
import { AiModelTypeEnum } from '@vben/constants';

import { Alert, Button, Card, Empty, Input, InputNumber, List, message, Popconfirm, Select, Space, Switch, Table, Tabs, Tag } from 'ant-design-vue';

import { getModelSimpleList } from '#/api/ai/model/model';
import { clearAgentMemory, getAgentDeployments, getAgentMemories, updateAgentDeployment } from '#/api/toonflow';

import '../shared/page-card.css';
import '../styles/toon-theme.css';

type ModelType=ToonflowApi.AgentDeployment['modelType'];
type ModelOption={label:string;value:number};
const loading=ref(false);const saving=ref(false);const agents=ref<ToonflowApi.AgentDeployment[]>([]);const baseline=ref<Record<number,string>>({});
const router=useRouter();
const memoryAgent=ref<'productionAgent'|'scriptAgent'>('scriptAgent');const isolationKey=ref('scriptAgent:1:project');const memories=ref<ToonflowApi.AgentMemory[]>([]);const memoryLoading=ref(false);
const models=ref<Record<ModelType,ModelOption[]>>({chat:[],image:[],speech:[],video:[]});
const typeLabels:Record<ModelType,string>={chat:'文本',image:'图片',speech:'语音',video:'视频'};
const columns=[{title:'配置项',dataIndex:'name'},{title:'类型',key:'type',width:90},{title:'用途',dataIndex:'description'},{title:'统一模型',key:'model',width:280},{title:'温度',key:'temperature',width:130},{title:'最大 Token',key:'tokens',width:150},{title:'启用',key:'enabled',width:90}];
function options(agent:{modelType?:ModelType}){return models.value[agent.modelType??'chat']}
function toOptions(items:Array<{id:number;name:string;platform:string}>){return items.map(x=>({label:`${x.name} (${x.platform})`,value:x.id}))}
function editable(row:ToonflowApi.AgentDeployment){return JSON.stringify([row.modelConfigId,row.temperature,row.maxOutputTokens,row.disabled])}
const changedRows=computed(()=>agents.value.filter(row=>baseline.value[row.id]!==editable(row)));
async function load(){loading.value=true;try{const[a,c,i,v,s]=await Promise.all([getAgentDeployments(),getModelSimpleList(AiModelTypeEnum.CHAT),getModelSimpleList(AiModelTypeEnum.IMAGE),getModelSimpleList(AiModelTypeEnum.VIDEO),getModelSimpleList(AiModelTypeEnum.VOICE)]);agents.value=a;baseline.value=Object.fromEntries(a.map(row=>[row.id,editable(row)]));models.value={chat:toOptions(c),image:toOptions(i),video:toOptions(v),speech:toOptions(s)}}finally{loading.value=false}}
async function saveAll(){const rows=changedRows.value;if(!rows.length)return;if(rows.some(row=>!row.modelConfigId))return message.warning('变更项必须选择对应类型的模型');saving.value=true;try{await Promise.all(rows.map(row=>updateAgentDeployment({id:row.id,modelConfigId:row.modelConfigId,temperature:row.temperature,maxOutputTokens:row.maxOutputTokens,disabled:row.disabled})));message.success(`已保存 ${rows.length} 项模型配置`);await load()}finally{saving.value=false}}
async function loadMemories(){if(!isolationKey.value.trim())return message.warning('请输入隔离键');memoryLoading.value=true;try{memories.value=await getAgentMemories(memoryAgent.value,isolationKey.value.trim())}finally{memoryLoading.value=false}}
async function clearMemories(type:'all'|'message'|'summary'){await clearAgentMemory(memoryAgent.value,isolationKey.value.trim(),type);message.success('记忆已清除');await loadMemories()}
onMounted(load);
</script>
<template><Page auto-content-height class="toon-page"><Card :bordered="false" class="toonflow-page-card h-full toon-surface"><div class="toon-header"><div><h1 class="toon-title">Toonflow 设置</h1><p class="toon-subtitle">统一管理创作模型、提示词入口与 Agent 记忆。</p></div></div><Tabs>
<Tabs.TabPane key="models" tab="模型映射"><div class="section-heading"><div><h3>Agent 模型</h3><p>每种能力只展示匹配类型的系统模型。</p></div><Button class="toon-primary" type="primary" :disabled="changedRows.length === 0" :loading="saving" @click="saveAll">保存 {{ changedRows.length || '' }}</Button></div><Table :columns="columns" :data-source="agents" :loading="loading" :pagination="false" row-key="id"><template #bodyCell="{column,record}"><Tag v-if="column.key === 'type'">{{ typeLabels[record.modelType as ModelType] }}</Tag><Select v-else-if="column.key === 'model'" v-model:value="record.modelConfigId" class="w-full" :options="options(record)" :placeholder="`选择${typeLabels[record.modelType as ModelType]}模型`" /><InputNumber v-else-if="column.key === 'temperature' && record.modelType === 'chat'" v-model:value="record.temperature" :min="0" :max="2" /><InputNumber v-else-if="column.key === 'tokens' && record.modelType === 'chat'" v-model:value="record.maxOutputTokens" :min="1" /><span v-else-if="column.key === 'temperature' || column.key === 'tokens'">—</span><Switch v-else-if="column.key === 'enabled'" :checked="!record.disabled" @update:checked="record.disabled = !$event" /></template></Table><Alert class="mt-4" message="提示词绑定" description="当前后端未提供模型与提示词绑定关系端点；此处不创建虚假配置。提示词内容可前往提示词中心维护。" show-icon type="info" /><Button class="mt-3" @click="router.push('/toonflow/prompts')">打开提示词中心</Button></Tabs.TabPane>
<Tabs.TabPane key="memory" tab="Agent 记忆"><div class="memory-toolbar"><Select v-model:value="memoryAgent" :options="[{label:'剧本 Agent',value:'scriptAgent'},{label:'生产 Agent',value:'productionAgent'}]" style="width:160px" /><Input v-model:value="isolationKey" placeholder="隔离键，例如 scriptAgent:1:project" style="max-width:360px" /><Button :loading="memoryLoading" @click="loadMemories">查看记忆</Button><Popconfirm title="确认清除当前隔离键的全部记忆？" @confirm="clearMemories('all')"><Button danger>清空全部</Button></Popconfirm></div><Empty v-if="!memoryLoading && memories.length===0" description="暂无记忆，输入隔离键后查询" /><List v-else :data-source="memories" :loading="memoryLoading"><template #renderItem="{item}"><List.Item><template #actions><Popconfirm title="清除此类型的记忆？" @confirm="clearMemories(item.memoryType)"><Button danger type="link">清除此类</Button></Popconfirm></template><List.Item.Meta :description="new Date(item.createTime).toLocaleString()"><template #title><Tag>{{ item.memoryType==='summary'?'摘要':'消息' }}</Tag> {{ item.role }}</template></List.Item.Meta><pre class="memory-content">{{ item.content }}</pre></List.Item></template></List></Tabs.TabPane>
<Tabs.TabPane key="providers" tab="供应商"><Alert message="供应商由系统 AI 模块统一管理" description="Toonflow 只读使用已配置的厂商和模型，不在业务页面在线编写供应商代码。" show-icon /><Space class="mt-4"><Button type="primary" @click="router.push('/ai/model')">前往 AI 模型配置</Button><Button @click="load">重新读取模型</Button></Space></Tabs.TabPane>
</Tabs></Card></Page></template>
<style scoped>.section-heading,.memory-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:16px}.section-heading h3{margin:0}.section-heading p{margin:4px 0 0;color:#8c8c8c;font-size:12px}.memory-toolbar{justify-content:flex-start;flex-wrap:wrap}.memory-content{max-width:70%;margin:0;padding:10px;border-radius:8px;white-space:pre-wrap;background:#f7f7f7}</style>

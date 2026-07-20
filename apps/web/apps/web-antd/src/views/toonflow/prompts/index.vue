<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Card, Form, Input, message, Modal, Popconfirm, Space, Table, Tabs, Tag } from 'ant-design-vue';

import { deletePrompt, getPrompts, getSkillContent, getSkills, savePrompt, saveSkillContent } from '#/api/toonflow';

import '../shared/page-card.css';
const loading=ref(false); const open=ref(false); const prompts=ref<ToonflowApi.Prompt[]>([]); const skills=ref<ToonflowApi.Skill[]>([]);
const form=reactive({id:undefined as number|undefined,name:'',type:'system',sourceKey:'',data:'',useData:''});
const skillOpen=ref(false); const skillSaving=ref(false); const skillPath=ref(''); const skillText=ref('');
const promptColumns=[{title:'名称',dataIndex:'name',width:200},{title:'固定 Key',dataIndex:'sourceKey',width:220},{title:'类型',dataIndex:'type',width:130},{title:'提示词内容',dataIndex:'data'},{title:'使用说明',dataIndex:'useData',width:260},{title:'操作',key:'action',width:150}];
const skillColumns=[{title:'名称',dataIndex:'name',width:200},{title:'类型',dataIndex:'type',width:120},{title:'说明',dataIndex:'description'},{title:'路径',dataIndex:'path',width:300},{title:'状态',dataIndex:'state',width:100},{title:'更新时间',key:'updateTime',width:180},{title:'操作',key:'skillAction',width:100}];
async function load(){loading.value=true;try{[prompts.value,skills.value]=await Promise.all([getPrompts(),getSkills()])}finally{loading.value=false}}
function edit(row?:Record<string, any>){Object.assign(form,row??{id:undefined,name:'',type:'system',sourceKey:'',data:'',useData:''});open.value=true}
async function save(){if(!form.name.trim())return message.warning('请输入提示词名称');await savePrompt(form);open.value=false;message.success('提示词已保存');await load()}
async function remove(id:number){await deletePrompt(id);message.success('提示词已删除');await load()}
async function editSkill(row:Record<string,any>){skillPath.value=row.path;skillText.value=await getSkillContent(row.path);skillOpen.value=true}
async function saveSkill(){skillSaving.value=true;try{await saveSkillContent(skillPath.value,skillText.value);skillOpen.value=false;message.success('Skill 已保存');await load()}finally{skillSaving.value=false}}
onMounted(load);
</script>
<template><Page auto-content-height><Card :bordered="false" class="toonflow-page-card h-full"><template #title>提示词与 Skill</template><template #extra><Space><Button @click="load">刷新</Button><Button type="primary" @click="edit()">新建提示词</Button></Space></template><Tabs><Tabs.TabPane key="prompts" tab="提示词"><Table :columns="promptColumns" :data-source="prompts" :loading="loading" row-key="id"><template #bodyCell="{column,record}"><template v-if="column.dataIndex === 'type'"><Tag>{{ record.type }}</Tag></template><template v-if="column.key === 'action'"><Button type="link" @click="edit(record)">编辑</Button><Popconfirm title="确认删除该提示词？" @confirm="remove(record.id)"><Button danger type="link">删除</Button></Popconfirm></template></template></Table></Tabs.TabPane><Tabs.TabPane key="skills" tab="Skill"><Table :columns="skillColumns" :data-source="skills" :loading="loading" row-key="id"><template #bodyCell="{column,record}"><template v-if="column.dataIndex === 'state'"><Tag :color="record.state === 1 ? 'green' : 'default'">{{ record.state === 1 ? '可用' : '停用' }}</Tag></template><template v-if="column.key === 'updateTime'">{{ new Date(record.updateTime).toLocaleString() }}</template><template v-if="column.key === 'skillAction'"><Button type="link" @click="editSkill(record)">编辑内容</Button></template></template></Table></Tabs.TabPane></Tabs></Card><Modal v-model:open="open" :title="form.id ? '编辑提示词' : '新建提示词'" width="760px" @ok="save"><Form layout="vertical"><Form.Item label="名称" required><Input v-model:value="form.name" /></Form.Item><Form.Item label="固定 Key"><Input v-model:value="form.sourceKey" placeholder="后端读取使用，保存后请勿随意修改" /></Form.Item><Form.Item label="类型" required><Input v-model:value="form.type" placeholder="system / agent / production" /></Form.Item><Form.Item label="提示词内容"><Input.TextArea v-model:value="form.data" :rows="10" /></Form.Item><Form.Item label="使用说明"><Input.TextArea v-model:value="form.useData" :rows="3" /></Form.Item></Form></Modal><Modal v-model:open="skillOpen" :confirm-loading="skillSaving" :title="`编辑 Skill：${skillPath}`" width="900px" @ok="saveSkill"><Input.TextArea v-model:value="skillText" :rows="24" class="font-mono" /></Modal></Page></template>

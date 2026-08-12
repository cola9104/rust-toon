<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Card, Empty, Form, Input, message, Modal, Popconfirm, Space, Tabs, Tag } from 'ant-design-vue';

import { deletePrompt, getPrompts, getSkillContent, getSkills, savePrompt, saveSkillContent } from '#/api/toonflow';

import '../shared/page-card.css';
import '../styles/toon-theme.css';
const loading=ref(false); const open=ref(false); const prompts=ref<ToonflowApi.Prompt[]>([]); const skills=ref<ToonflowApi.Skill[]>([]);
const form=reactive({id:undefined as number|undefined,name:'',type:'system',sourceKey:'',data:'',useData:''});
const skillOpen=ref(false); const skillSaving=ref(false); const skillPath=ref(''); const skillText=ref('');
async function load(){loading.value=true;try{[prompts.value,skills.value]=await Promise.all([getPrompts(),getSkills()])}finally{loading.value=false}}
function edit(row?:Record<string, any>){Object.assign(form,row??{id:undefined,name:'',type:'system',sourceKey:'',data:'',useData:''});open.value=true}
async function save(){if(!form.name.trim())return message.warning('请输入提示词名称');await savePrompt(form);open.value=false;message.success('提示词已保存');await load()}
async function remove(id:number){await deletePrompt(id);message.success('提示词已删除');await load()}
async function editSkill(row:Record<string,any>){skillPath.value=row.path;skillText.value=await getSkillContent(row.path);skillOpen.value=true}
async function saveSkill(){skillSaving.value=true;try{await saveSkillContent(skillPath.value,skillText.value);skillOpen.value=false;message.success('Skill 已保存');await load()}finally{skillSaving.value=false}}
onMounted(load);
</script>
<template><Page auto-content-height class="toon-page"><Card :bordered="false" class="toonflow-page-card h-full toon-surface"><div class="toon-header"><div><h1 class="toon-title">提示词与 Skill</h1><p class="toon-subtitle">管理 Agent 的固定提示词与可复用技能。</p></div><Space><Button @click="load">刷新</Button><Button class="toon-primary" type="primary" @click="edit()">＋ 新建提示词</Button></Space></div><Tabs><Tabs.TabPane key="prompts" tab="提示词"><Empty v-if="!loading&&prompts.length===0" description="暂无提示词"/><div v-else class="toon-grid"><article v-for="record in prompts" :key="record.id" class="prompt-card"><div class="prompt-card__head"><span>⌘</span><div><h3>{{record.name}}</h3><code>{{record.sourceKey||'未设置固定 Key'}}</code></div><Tag>{{record.type}}</Tag></div><p>{{record.data||'暂无提示词内容'}}</p><small>{{record.useData||'暂无使用说明'}}</small><Space><Button type="link" @click="edit(record)">编辑</Button><Popconfirm title="确认删除该提示词？" @confirm="remove(record.id)"><Button danger type="link">删除</Button></Popconfirm></Space></article></div></Tabs.TabPane><Tabs.TabPane key="skills" tab="Skill"><Empty v-if="!loading&&skills.length===0" description="暂无 Skill"/><div v-else class="toon-grid"><article v-for="record in skills" :key="record.id" class="prompt-card skill-card"><div class="prompt-card__head"><span>⚙</span><div><h3>{{record.name}}</h3><code>{{record.path}}</code></div><Tag :color="record.state===1?'green':'default'">{{record.state===1?'可用':'停用'}}</Tag></div><p>{{record.description||'暂无说明'}}</p><small>{{record.type}} · {{new Date(record.updateTime).toLocaleString()}}</small><Button type="link" @click="editSkill(record)">编辑内容</Button></article></div></Tabs.TabPane></Tabs></Card><Modal v-model:open="open" :title="form.id?'编辑提示词':'新建提示词'" width="760px" @ok="save"><Form layout="vertical"><Form.Item label="名称" required><Input v-model:value="form.name"/></Form.Item><Form.Item label="固定 Key"><Input v-model:value="form.sourceKey" placeholder="后端读取使用，保存后请勿随意修改"/></Form.Item><Form.Item label="类型" required><Input v-model:value="form.type" placeholder="system / agent / production"/></Form.Item><Form.Item label="提示词内容"><Input.TextArea v-model:value="form.data" :rows="10"/></Form.Item><Form.Item label="使用说明"><Input.TextArea v-model:value="form.useData" :rows="3"/></Form.Item></Form></Modal><Modal v-model:open="skillOpen" :confirm-loading="skillSaving" :title="`编辑 Skill：${skillPath}`" width="900px" @ok="saveSkill"><Input.TextArea v-model:value="skillText" :rows="24" class="font-mono"/></Modal></Page></template>
<style scoped>.prompt-card{padding:17px;border:1px solid var(--toon-line);border-radius:17px;background:#fff}.prompt-card__head{display:grid;align-items:center;gap:10px;grid-template-columns:40px minmax(0,1fr) auto}.prompt-card__head>span{display:grid;width:40px;height:40px;border-radius:12px;color:#fff;background:#171717;font-size:18px;place-items:center}.prompt-card h3{margin:0;font-size:15px}.prompt-card code{display:block;overflow:hidden;color:#999;font-size:10px;text-overflow:ellipsis;white-space:nowrap}.prompt-card>p{display:-webkit-box;height:80px;overflow:hidden;margin:14px 0 7px;padding:10px;border-radius:9px;color:#555;background:#f7f7f5;font-size:12px;line-height:20px;-webkit-box-orient:vertical;-webkit-line-clamp:3}.prompt-card>small{display:block;overflow:hidden;margin-bottom:7px;color:#999;text-overflow:ellipsis;white-space:nowrap}.skill-card>p{height:60px}</style>

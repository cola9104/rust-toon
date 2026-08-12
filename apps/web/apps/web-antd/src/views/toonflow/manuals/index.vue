<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { computed, onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Card, Empty, Form, Input, message, Modal, Popconfirm, Space, Tabs, Tag } from 'ant-design-vue';

import { deleteCreativeManual, getCreativeManuals, saveCreativeManual } from '#/api/toonflow';

import '../shared/page-card.css';
import '../styles/toon-theme.css';

const activeKind=ref<'director'|'visual'>('visual'); const loading=ref(false); const manuals=ref<ToonflowApi.CreativeManual[]>([]); const open=ref(false);
const form=reactive({id:undefined as number|undefined,kind:'visual' as 'director'|'visual',name:'',path:'',imagesText:'',data:[] as Array<{data:string;label:string;value:string;}>});
const visualFields=[['README','README'],['前缀','prefix'],['角色','art_character'],['角色衍生','art_character_derivative'],['道具','art_prop'],['道具衍生','art_prop_derivative'],['场景','art_scene'],['场景衍生','art_scene_derivative'],['分镜','director_storyboard'],['分镜视频','art_storyboard_video'],['技法-导演规划','director_planning_style'],['技法-分镜表设计','director_storyboard_table_style']];
const directorFields=[['README','README'],['导演规划','director_planning_narrative'],['分镜表','director_storyboard_table_narrative']];
const filtered=computed(()=>manuals.value.filter(item=>item.kind===activeKind.value));
async function load(){loading.value=true;try{manuals.value=await getCreativeManuals()}finally{loading.value=false}}
function defaults(kind:'director'|'visual'){return (kind==='visual'?visualFields:directorFields).map(([label,value])=>({label:label!,value:value!,data:''}))}
function edit(row?:Record<string,any>){const kind=(row?.kind??activeKind.value) as 'director'|'visual';Object.assign(form,{id:row?.id,kind,name:row?.name??'',path:row?.path??'',imagesText:(row?.images??[]).join('\n'),data:row?.data?.length?JSON.parse(JSON.stringify(row.data)):defaults(kind)});open.value=true}
async function save(){if(!form.name.trim()||!form.path.trim())return message.warning('请输入名称和标识');await saveCreativeManual({id:form.id,kind:form.kind,name:form.name,path:form.path,images:form.imagesText.split('\n').map(v=>v.trim()).filter(Boolean),data:form.data});open.value=false;message.success('创作手册已保存');await load()}
async function remove(row:Record<string,any>){await deleteCreativeManual(row.kind as 'director'|'visual',row.path);message.success('创作手册已删除');await load()}
onMounted(load);
</script>
<template><Page auto-content-height class="toon-page"><Card :bordered="false" class="toonflow-page-card h-full toon-surface"><div class="toon-header"><div><h1 class="toon-title">创作手册</h1><p class="toon-subtitle">沉淀视觉规范与导演方法，供 Agent 在生产中复用。</p></div><Space><Button @click="load">刷新</Button><Button class="toon-primary" type="primary" @click="edit()">＋ 新建{{activeKind==='visual'?'视觉':'导演'}}手册</Button></Space></div><Tabs v-model:active-key="activeKind"><Tabs.TabPane key="visual" tab="视觉手册"/><Tabs.TabPane key="director" tab="导演手册"/></Tabs><Empty v-if="!loading&&filtered.length===0" description="暂无手册"/><div v-else class="toon-grid"><article v-for="record in filtered" :key="record.id" class="manual-card"><div class="manual-card__top toon-dots"><img v-if="record.images?.[0]" :src="record.images[0]" :alt="record.name"/><span v-else>{{record.kind==='visual'?'视':'导'}}</span><Tag>{{record.kind==='visual'?'视觉':'导演'}}</Tag></div><div class="manual-card__body"><h3>{{record.name}}</h3><code>{{record.path}}</code><p>{{record.data?.find(item=>item.value==='README')?.data||'暂无手册说明'}}</p><div class="manual-meta"><span>{{record.data?.length??0}} 个内容项</span><span>{{record.images?.length??0}} 张参考图</span></div><Space><Button type="link" @click="edit(record)">编辑</Button><Popconfirm title="确认删除该创作手册？" @confirm="remove(record)"><Button danger type="link">删除</Button></Popconfirm></Space></div></article></div></Card><Modal v-model:open="open" :title="`${form.id?'编辑':'新建'}${form.kind==='visual'?'视觉':'导演'}手册`" width="900px" @ok="save"><Form layout="vertical"><div class="grid grid-cols-2 gap-4"><Form.Item label="显示名称" required><Input v-model:value="form.name"/></Form.Item><Form.Item label="唯一标识" required><Input v-model:value="form.path" :disabled="!!form.id" placeholder="英文或拼音，不能包含路径符号"/></Form.Item></div><Form.Item label="参考图 URL（每行一个）"><Input.TextArea v-model:value="form.imagesText" :rows="3"/></Form.Item><Tabs><Tabs.TabPane v-for="item in form.data" :key="item.value" :tab="item.label"><Input.TextArea v-model:value="item.data" :rows="12" :placeholder="`${item.label} Markdown 内容`"/></Tabs.TabPane></Tabs></Form></Modal></Page></template>
<style scoped>.manual-card{overflow:hidden;border:1px solid var(--toon-line);border-radius:17px;background:#fff}.manual-card__top{position:relative;display:grid;height:130px;place-items:center}.manual-card__top img{width:100%;height:100%;object-fit:cover}.manual-card__top>span{display:grid;width:52px;height:52px;border-radius:16px;color:#fff;background:#171717;font-size:22px;place-items:center}.manual-card__top>.ant-tag{position:absolute;top:12px;right:12px}.manual-card__body{padding:15px}.manual-card__body h3{margin:0 0 6px}.manual-card__body code{color:#8c8c8c;font-size:11px}.manual-card__body p{display:-webkit-box;height:40px;overflow:hidden;color:#666;font-size:12px;line-height:20px;-webkit-box-orient:vertical;-webkit-line-clamp:2}.manual-meta{display:flex;gap:12px;color:#999;font-size:11px}</style>

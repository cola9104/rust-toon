<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Card, Empty, Form, Input, message, Modal, Popconfirm, Space, Tag } from 'ant-design-vue';

import { deleteArtStyle, getArtStyles, saveArtStyle } from '#/api/toonflow';

import '../shared/page-card.css';
import '../styles/toon-theme.css';
const loading=ref(false); const open=ref(false); const styles=ref<ToonflowApi.ArtStyle[]>([]);
const form=reactive({id:undefined as number|undefined,name:'',label:'',fileUrl:'',prompt:''});
async function load(){loading.value=true;try{styles.value=await getArtStyles()}finally{loading.value=false}}
function edit(row?:Record<string, any>){Object.assign(form,row??{id:undefined,name:'',label:'',fileUrl:'',prompt:''});open.value=true}
async function save(){if(!form.name.trim())return message.warning('请输入风格名称');await saveArtStyle(form);open.value=false;message.success('风格已保存');await load()}
async function remove(id:number){await deleteArtStyle(id);message.success('风格已删除');await load()}
onMounted(load);
</script>
<template><Page auto-content-height class="toon-page"><Card :bordered="false" class="toonflow-page-card h-full toon-surface"><div class="toon-header"><div><h1 class="toon-title">风格库</h1><p class="toon-subtitle">用视觉参考和提示词保持项目画风一致。</p></div><Space><Button @click="load">刷新</Button><Button class="toon-primary" type="primary" @click="edit()">＋ 新建风格</Button></Space></div><Empty v-if="!loading&&styles.length===0" description="暂无风格"/><div v-else class="toon-grid"><article v-for="record in styles" :key="record.id" class="style-card"><div class="style-preview toon-dots"><img v-if="record.fileUrl" :src="record.fileUrl" :alt="record.name"/><span v-else>{{ record.name.slice(0,1) }}</span></div><div class="style-body"><h3>{{record.name}}</h3><div><Tag v-for="tag in record.label.split(',').filter(Boolean)" :key="tag">{{tag}}</Tag></div><p>{{record.prompt||'暂无风格提示词'}}</p><Space><Button type="link" @click="edit(record)">编辑</Button><Popconfirm title="确认删除该风格？" @confirm="remove(record.id)"><Button danger type="link">删除</Button></Popconfirm></Space></div></article></div></Card><Modal v-model:open="open" :title="form.id ? '编辑风格' : '新建风格'" @ok="save"><Form layout="vertical"><Form.Item label="名称" required><Input v-model:value="form.name" /></Form.Item><Form.Item label="标签（逗号分隔）"><Input v-model:value="form.label" /></Form.Item><Form.Item label="预览图 URL"><Input v-model:value="form.fileUrl" /></Form.Item><Form.Item label="风格提示词"><Input.TextArea v-model:value="form.prompt" :rows="6" /></Form.Item></Form></Modal></Page></template>
<style scoped>.style-card{overflow:hidden;border:1px solid var(--toon-line);border-radius:17px;background:#fff}.style-preview{display:grid;height:170px;place-items:center}.style-preview img{width:100%;height:100%;object-fit:cover}.style-preview span{display:grid;width:54px;height:54px;border-radius:16px;color:#fff;background:#171717;font-size:24px;place-items:center}.style-body{padding:15px}.style-body h3{margin:0 0 9px}.style-body p{display:-webkit-box;height:60px;overflow:hidden;color:#737373;font-size:12px;line-height:20px;-webkit-box-orient:vertical;-webkit-line-clamp:3}</style>

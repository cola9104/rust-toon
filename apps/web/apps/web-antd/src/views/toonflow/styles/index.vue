<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Empty, Form, Input, message, Modal, Popconfirm, Space, Tag } from 'ant-design-vue';

import { deleteArtStyle, getArtStyles, saveArtStyle } from '#/api/toonflow';
import { assetFileUrl } from '../assets/asset-types';

import '../shared/page-card.css';
import '../styles/toon-theme.css';
const loading=ref(false); const open=ref(false); const styles=ref<ToonflowApi.ArtStyle[]>([]);
const form=reactive({id:undefined as number|undefined,name:'',label:'',fileUrl:'',prompt:''});
async function load(){loading.value=true;try{styles.value=await getArtStyles()}finally{loading.value=false}}
function edit(row?:Record<string, any>){Object.assign(form,row??{id:undefined,name:'',label:'',fileUrl:'',prompt:''});open.value=true}
async function save(){if(!form.name.trim())return message.warning('请输入风格名称');await saveArtStyle(form);open.value=false;message.success('风格已保存');await load()}
async function remove(id:number){await deleteArtStyle(id);message.success('风格已删除');await load()}
function labels(value?: string){return (value ?? '').split(',').map((item)=>item.trim()).filter(Boolean)}
function previewUrl(value?: string){return assetFileUrl(value)}
onMounted(load);
</script>
<template><Page auto-content-height class="toon-page"><div class="toonflow-page-shell"><div class="toon-header"><div><h1 class="toon-title">风格库</h1><p class="toon-subtitle">用视觉参考和提示词保持项目画风一致。</p></div><Space><Button :loading="loading" @click="load">刷新</Button><Button class="toon-primary" type="primary" @click="edit()">＋ 新建风格</Button></Space></div><Empty v-if="!loading&&styles.length===0" description="暂无风格"/><div v-else class="toon-grid"><article v-for="record in styles" :key="record.id" class="style-card"><div class="style-preview toon-dots"><img v-if="record.fileUrl" :src="previewUrl(record.fileUrl)" :alt="record.name"/><span v-else>{{ (record.name || '风').slice(0,1) }}</span></div><div class="style-body"><div class="style-title-row"><h3>{{ record.name }}</h3><small>视觉风格</small></div><div class="style-tags"><Tag v-for="tag in labels(record.label)" :key="tag" :bordered="false">{{ tag }}</Tag><span v-if="!labels(record.label).length" class="muted">暂无标签</span></div><p>{{ record.prompt || '暂无风格提示词' }}</p><Space class="style-actions"><Button type="link" @click="edit(record)">编辑</Button><Popconfirm title="确认删除该风格？" @confirm="remove(record.id)"><Button danger type="link">删除</Button></Popconfirm></Space></div></article></div></div><Modal root-class-name="toon-overlay" v-model:open="open" :title="form.id ? '编辑风格' : '新建风格'" @ok="save"><Form layout="vertical"><Form.Item label="名称" required><Input v-model:value="form.name" /></Form.Item><Form.Item label="标签（逗号分隔）"><Input v-model:value="form.label" /></Form.Item><Form.Item label="预览图 URL"><Input v-model:value="form.fileUrl" /></Form.Item><Form.Item label="风格提示词"><Input.TextArea v-model:value="form.prompt" :rows="6" /></Form.Item></Form></Modal></Page></template>
<style scoped>.toonflow-page-shell{display:flex;min-width:0;height:100%;min-height:100%;flex-direction:column;overflow:auto;padding:4px 2px 20px}.style-card{display:flex;min-width:0;overflow:hidden;flex-direction:column;border:1px solid var(--toon-line);border-radius:14px;background:var(--toon-panel);box-shadow:0 2px 8px rgb(15 23 42 / 4%);transition:border-color .2s,box-shadow .2s}.style-card:hover{border-color:hsl(var(--primary) / 60%);box-shadow:0 8px 20px rgb(15 23 42 / 8%)}.style-preview{display:grid;height:170px;flex:none;place-items:center;background:var(--toon-canvas)}.style-preview img{width:100%;height:100%;object-fit:cover}.style-preview span{display:grid;width:56px;height:56px;border-radius:14px;color:#fff;background:var(--toon-preview-badge);font-size:24px;place-items:center}.style-body{display:flex;min-width:0;min-height:175px;flex:1;flex-direction:column;padding:15px}.style-title-row{display:flex;align-items:baseline;justify-content:space-between;gap:10px}.style-title-row h3{min-width:0;overflow:hidden;margin:0;color:var(--toon-ink);font-size:15px;font-weight:600;text-overflow:ellipsis;white-space:nowrap}.style-title-row small,.muted{color:var(--toon-muted);font-size:11px}.style-tags{display:flex;min-height:24px;flex-wrap:wrap;gap:5px;margin-top:8px}.style-tags .ant-tag{margin:0;border-radius:999px;color:hsl(var(--primary));background:hsl(var(--primary) / 12%)}.style-body p{display:-webkit-box;min-height:60px;overflow:hidden;margin:12px 0 0;color:var(--toon-muted);font-size:12px;line-height:20px;overflow-wrap:anywhere;-webkit-box-orient:vertical;-webkit-line-clamp:3}.style-actions{margin-top:auto;padding-top:10px;border-top:1px solid var(--toon-line)}</style>

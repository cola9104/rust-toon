<script lang="ts" setup>
import type { ToonflowApi } from '#/api/toonflow';

import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Card, Form, Image, Input, message, Modal, Popconfirm, Space, Table, Tag } from 'ant-design-vue';

import { deleteArtStyle, getArtStyles, saveArtStyle } from '#/api/toonflow';

import '../shared/page-card.css';
const loading=ref(false); const open=ref(false); const styles=ref<ToonflowApi.ArtStyle[]>([]);
const form=reactive({id:undefined as number|undefined,name:'',label:'',fileUrl:'',prompt:''});
const columns=[{title:'预览',key:'preview',width:90},{title:'名称',dataIndex:'name',width:180},{title:'标签',dataIndex:'label',width:160},{title:'风格提示词',dataIndex:'prompt'},{title:'操作',key:'action',width:150}];
async function load(){loading.value=true;try{styles.value=await getArtStyles()}finally{loading.value=false}}
function edit(row?:Record<string, any>){Object.assign(form,row??{id:undefined,name:'',label:'',fileUrl:'',prompt:''});open.value=true}
async function save(){if(!form.name.trim())return message.warning('请输入风格名称');await saveArtStyle(form);open.value=false;message.success('风格已保存');await load()}
async function remove(id:number){await deleteArtStyle(id);message.success('风格已删除');await load()}
onMounted(load);
</script>
<template><Page auto-content-height><Card :bordered="false" class="toonflow-page-card h-full"><template #title>风格库</template><template #extra><Space><Button @click="load">刷新</Button><Button type="primary" @click="edit()">新建风格</Button></Space></template><Table :columns="columns" :data-source="styles" :loading="loading" row-key="id"><template #bodyCell="{column,record}"><template v-if="column.key === 'preview'"><Image v-if="record.fileUrl" :src="record.fileUrl" :width="56" :height="56" class="object-cover" /><span v-else>—</span></template><template v-if="column.dataIndex === 'label'"><Tag v-for="tag in record.label.split(',').filter(Boolean)" :key="tag">{{ tag }}</Tag></template><template v-if="column.key === 'action'"><Button type="link" @click="edit(record)">编辑</Button><Popconfirm title="确认删除该风格？" @confirm="remove(record.id)"><Button danger type="link">删除</Button></Popconfirm></template></template></Table></Card><Modal v-model:open="open" :title="form.id ? '编辑风格' : '新建风格'" @ok="save"><Form layout="vertical"><Form.Item label="名称" required><Input v-model:value="form.name" /></Form.Item><Form.Item label="标签（逗号分隔）"><Input v-model:value="form.label" /></Form.Item><Form.Item label="预览图 URL"><Input v-model:value="form.fileUrl" /></Form.Item><Form.Item label="风格提示词"><Input.TextArea v-model:value="form.prompt" :rows="6" /></Form.Item></Form></Modal></Page></template>

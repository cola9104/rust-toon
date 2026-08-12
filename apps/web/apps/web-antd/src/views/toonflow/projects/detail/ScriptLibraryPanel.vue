<script setup lang="ts">
/* eslint-disable vue/no-mutating-props -- panel context is an intentionally shared reactive view model */
import { reactive, ref } from 'vue';

import { Button, Checkbox, Empty, Form, Input, message, Modal, Popconfirm, Select, Space, Tag } from 'ant-design-vue';

import { addScript, updateScript } from '#/api/toonflow';

const props = defineProps<{ context: any }>();
const expandedScripts = ref(new Set<number>());
const modalOpen = ref(false);
const form = reactive({ assets: [] as number[], content: '', id: undefined as number | undefined, name: '' });

function allAssetTokens(script: any) {
  return props.context.scriptAssetGroups(script).flatMap((group: any) => group.items.map((asset: any) => ({ ...asset, color: group.color, group: group.label })));
}
function assetTokens(script: any) {
  const tokens = allAssetTokens(script);
  return expandedScripts.value.has(script.id) ? tokens : tokens.slice(0, 6);
}
function hiddenAssetCount(script: any) {
  return Math.max(0, allAssetTokens(script).length - 6);
}
function toggleAssets(scriptId: number) {
  expandedScripts.value.has(scriptId) ? expandedScripts.value.delete(scriptId) : expandedScripts.value.add(scriptId);
}
function openScript(script?: any) {
  Object.assign(form, {
    assets: script?.relatedAssets?.map((item: { id: number }) => item.id) ?? [],
    content: script?.content ?? '',
    id: script?.id,
    name: script?.name ?? '',
  });
  modalOpen.value = true;
}
async function saveScript() {
  if (!form.name.trim()) return message.warning('请输入剧本名称');
  if (form.id) {
    await updateScript({ ...form, id: form.id });
  } else {
    const created = await addScript({ ...form, projectId: props.context.projectId });
    props.context.selectedScriptId = created.id;
  }
  modalOpen.value = false;
  await props.context.reloadScriptsAndFlow();
}
</script>
<template><section class="detail-panel detail-panel--library"><div class="script-library-header"><div><h2>剧本库</h2><p>集中管理剧本，并从文本提取角色、场景与道具。</p></div><Space wrap><Button @click="context.openAssets">基础资产（{{ context.assets.length }}）</Button><input :ref="context.setScriptUploadInput" accept=".txt,.md,text/plain,text/markdown" class="hidden" multiple type="file" @change="context.importScriptFiles" /><Button @click="context.chooseScriptFiles">批量上传</Button><Button class="toon-primary" type="primary" @click="openScript()">＋ 新建剧本</Button></Space></div><div class="script-library-toolbar"><Input.Search v-model:value="context.scriptSearch" allow-clear placeholder="搜索剧本或资产" style="max-width:320px" /><Space><Button @click="context.toggleAllScripts">全选 / 取消</Button><Button :disabled="!context.selectedScriptIds.size" @click="context.batchExportScripts">批量导出</Button><Button :disabled="!context.selectedScriptIds.size" @click="context.batchExtractScriptAssets">批量提取资产</Button><Popconfirm title="确认批量删除选中的剧本？" @confirm="context.batchRemoveScripts"><Button danger :disabled="!context.selectedScriptIds.size">批量删除</Button></Popconfirm></Space></div><Empty v-if="context.visibleScripts.length === 0" description="暂无匹配剧本" /><div v-else class="script-card-grid"><article v-for="item in context.visibleScripts" :key="item.id" class="script-library-card" :class="{selected:context.selectedScriptIds.has(item.id)}"><div class="script-cover toon-dots"><Checkbox :checked="context.selectedScriptIds.has(item.id)" @change="context.toggleScript(item.id,$event.target.checked)" /><span>剧</span><Tag :color="item.extractState === 1 ? 'green' : item.extractState === -1 ? 'red' : 'default'">{{ item.extractState === 1 ? '已提取' : item.extractState === -1 ? '提取失败' : '待提取' }}</Tag></div><div class="script-card-body"><div class="script-card-title"><h3>{{ item.name }}</h3><small>{{ new Date(item.createTime).toLocaleDateString() }}</small></div><p>{{ item.content }}</p><div class="script-assets"><Tag v-for="asset in assetTokens(item)" :key="asset.id" :color="asset.color"><b>{{ asset.group }}</b> · {{ asset.name }}</Tag><span v-if="!item.relatedAssets.length">尚未关联资产</span><button v-if="hiddenAssetCount(item)" type="button" class="script-assets-more" @click="toggleAssets(item.id)">{{ expandedScripts.has(item.id) ? '收起' : `更多 +${hiddenAssetCount(item)}` }}</button></div><div class="script-card-actions"><Button type="link" @click="openScript(item)">编辑</Button><Button type="link" @click="context.extractAssetsFromScript(item)">AI 提取资产</Button><Popconfirm title="确认删除剧本？" @confirm="context.removeScript(item)"><Button danger type="link">删除</Button></Popconfirm></div></div></article></div></section><Modal v-model:open="modalOpen" title="剧本" width="900px" @ok="saveScript"><Form :label-col="{span:3}"><Form.Item label="名称"><Input v-model:value="form.name" /></Form.Item><Form.Item label="关联资产"><Select v-model:value="form.assets" :options="context.assetOptions" mode="multiple" placeholder="选择剧本使用的角色、场景、道具" /></Form.Item><Form.Item label="内容"><Input.TextArea v-model:value="form.content" :rows="14" /></Form.Item></Form></Modal></template>

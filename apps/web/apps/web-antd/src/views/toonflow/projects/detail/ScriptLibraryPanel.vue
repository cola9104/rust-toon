<script setup lang="ts">
/* eslint-disable vue/no-mutating-props -- panel context is an intentionally shared reactive view model */
import { reactive, ref } from 'vue';

import {
  Button,
  Checkbox,
  Empty,
  Form,
  Input,
  message,
  Modal,
  Popconfirm,
  Select,
  Space,
  Tag,
} from 'ant-design-vue';

import { addScript, updateScript } from '#/api/toonflow';

const props = defineProps<{ context: any }>();
const expandedScripts = ref(new Set<number>());
const modalOpen = ref(false);
const form = reactive({
  assets: [] as number[],
  content: '',
  id: undefined as number | undefined,
  name: '',
});

function allAssetTokens(script: any) {
  return props.context
    .scriptAssetGroups(script)
    .flatMap((group: any) =>
      group.items.map((asset: any) => ({ ...asset, color: group.color, group: group.label })),
    );
}

function assetTokens(script: any) {
  const tokens = allAssetTokens(script);
  return expandedScripts.value.has(script.id) ? tokens : tokens.slice(0, 6);
}

function hiddenAssetCount(script: any) {
  return Math.max(0, allAssetTokens(script).length - 6);
}

function toggleAssets(scriptId: number) {
  expandedScripts.value.has(scriptId)
    ? expandedScripts.value.delete(scriptId)
    : expandedScripts.value.add(scriptId);
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

<template>
  <section class="detail-panel detail-panel--library script-library">
    <div class="script-library__hero">
      <div>
        <div class="eyebrow">SCRIPT LIBRARY</div>
        <h2>剧本与资产</h2>
        <p>管理剧本内容，提取并确认后续分镜制作需要的角色、场景与道具。</p>
      </div>
      <div class="script-library__actions">
        <Button @click="context.openAssets">基础资产 <b>{{ context.assets.length }}</b></Button>
        <input
          :ref="context.setScriptUploadInput"
          accept=".txt,.md,text/plain,text/markdown"
          class="hidden"
          multiple
          type="file"
          @change="context.importScriptFiles"
        />
        <Button @click="context.chooseScriptFiles">批量上传</Button>
        <Button class="toon-primary" type="primary" @click="openScript()">新建剧本</Button>
      </div>
    </div>

    <div class="script-library__toolbar">
      <Input.Search
        v-model:value="context.scriptSearch"
        allow-clear
        placeholder="搜索剧本名称、正文或资产"
        style="max-width: 360px"
      />
      <Space wrap>
        <Button @click="context.toggleAllScripts">全选 / 取消</Button>
        <Button :disabled="!context.selectedScriptIds.size" @click="context.batchExportScripts">
          批量导出
        </Button>
        <Button
          :disabled="!context.selectedScriptIds.size"
          type="primary"
          ghost
          @click="context.batchExtractScriptAssets"
        >
          批量提取资产
        </Button>
        <Popconfirm title="确认批量删除选中的剧本？" @confirm="context.batchRemoveScripts">
          <Button danger :disabled="!context.selectedScriptIds.size">批量删除</Button>
        </Popconfirm>
      </Space>
    </div>

    <Empty v-if="context.visibleScripts.length === 0" description="暂无匹配剧本" />
    <div v-else class="script-card-grid">
      <article
        v-for="item in context.visibleScripts"
        :key="item.id"
        class="script-library-card"
        :class="{ selected: context.selectedScriptIds.has(item.id) }"
      >
        <div class="script-card__topline">
          <Checkbox
            :checked="context.selectedScriptIds.has(item.id)"
            @change="context.toggleScript(item.id, $event.target.checked)"
          />
          <Tag :color="context.scriptExtractColor(item)" class="script-status">
            <span class="status-dot" />{{ context.scriptExtractLabel(item) }}
          </Tag>
          <small>{{ new Date(item.createTime).toLocaleDateString() }}</small>
        </div>

        <div class="script-card__title">
          <div class="script-index">剧</div>
          <div>
            <h3>{{ item.name }}</h3>
            <span>剧本 #{{ item.id }}</span>
          </div>
        </div>

        <p class="script-card__excerpt">{{ item.content || '暂无剧本正文' }}</p>

        <div class="script-card__stats">
          <span><b>{{ item.relatedAssets.length }}</b> 关联资产</span>
          <span><b>{{ allAssetTokens(item).length }}</b> 提取标签</span>
        </div>

        <div class="script-assets">
          <Tag v-for="asset in assetTokens(item)" :key="asset.id" :color="asset.color">
            <b>{{ asset.group }}</b> · {{ asset.name }}
          </Tag>
          <span v-if="!item.relatedAssets.length" class="empty-assets">尚未关联资产</span>
          <button
            v-if="hiddenAssetCount(item)"
            class="script-assets-more"
            type="button"
            @click="toggleAssets(item.id)"
          >
            {{ expandedScripts.has(item.id) ? '收起' : `更多 +${hiddenAssetCount(item)}` }}
          </button>
        </div>

        <div class="script-card__footer">
          <Button type="link" @click="openScript(item)">编辑剧本</Button>
          <Button
            :disabled="item.extractState === 0 || item.extractState === 2"
            :loading="item.extractState === 0 || item.extractState === 2"
            type="link"
            @click="context.extractAssetsFromScript(item)"
          >
            {{ item.extractState === -1 ? '重新提取' : 'AI 提取资产' }}
          </Button>
          <Popconfirm title="确认删除剧本？" @confirm="context.removeScript(item)">
            <Button danger type="link">删除</Button>
          </Popconfirm>
        </div>
      </article>
    </div>

    <Modal v-model:open="modalOpen" title="剧本" width="900px" @ok="saveScript">
      <Form :label-col="{ span: 3 }">
        <Form.Item label="名称"><Input v-model:value="form.name" /></Form.Item>
        <Form.Item label="关联资产">
          <Select
            v-model:value="form.assets"
            :options="context.assetOptions"
            mode="multiple"
            placeholder="选择剧本使用的角色、场景、道具"
          />
        </Form.Item>
        <Form.Item label="内容"><Input.TextArea v-model:value="form.content" :rows="14" /></Form.Item>
      </Form>
    </Modal>
  </section>
</template>

<style scoped>
.script-library { padding: 18px; }
.script-library__hero, .script-library__toolbar { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.script-library__hero { padding: 4px 2px 20px; }
.script-library__hero h2 { margin: 3px 0 4px; font-size: 22px; }
.script-library__hero p { margin: 0; color: var(--ant-color-text-tertiary); font-size: 13px; }
.eyebrow { color: var(--ant-color-primary); font-size: 10px; font-weight: 700; letter-spacing: .16em; }
.script-library__actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
.script-library__actions b { margin-left: 4px; color: var(--ant-color-primary); }
.script-library__toolbar { padding: 12px; border: 1px solid var(--toon-line); border-radius: 12px; background: var(--ant-color-fill-quaternary); }
.script-card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px; margin-top: 16px; }
.script-library-card { display: flex; min-height: 310px; flex-direction: column; padding: 16px; border: 1px solid var(--toon-line); border-radius: 16px; background: var(--ant-color-bg-container); box-shadow: 0 3px 12px rgb(15 23 42 / 4%); transition: border-color .2s, transform .2s, box-shadow .2s; }
.script-library-card:hover, .script-library-card.selected { border-color: var(--ant-color-primary-border); box-shadow: 0 10px 24px rgb(15 23 42 / 9%); transform: translateY(-2px); }
.script-card__topline { display: flex; align-items: center; gap: 9px; color: var(--ant-color-text-quaternary); }
.script-card__topline small { margin-left: auto; font-size: 11px; }
.script-status { margin: 0; border: 0; border-radius: 999px; font-size: 11px; }
.status-dot { display: inline-block; width: 6px; height: 6px; margin-right: 5px; border-radius: 50%; background: currentColor; }
.script-card__title { display: flex; align-items: center; gap: 11px; margin: 18px 0 12px; }
.script-index { display: grid; width: 38px; height: 38px; border-radius: 11px; color: var(--ant-color-primary); background: var(--ant-color-primary-bg); font-weight: 700; place-items: center; }
.script-card__title h3 { overflow: hidden; max-width: 220px; margin: 0; font-size: 15px; text-overflow: ellipsis; white-space: nowrap; }
.script-card__title span { color: var(--ant-color-text-quaternary); font-size: 11px; }
.script-card__excerpt { display: -webkit-box; height: 57px; overflow: hidden; margin: 0; color: var(--ant-color-text-secondary); font-size: 12px; line-height: 19px; -webkit-box-orient: vertical; -webkit-line-clamp: 3; }
.script-card__stats { display: flex; gap: 8px; margin: 14px 0 10px; }
.script-card__stats span { padding: 5px 8px; border-radius: 7px; color: var(--ant-color-text-tertiary); background: var(--ant-color-fill-quaternary); font-size: 11px; }
.script-card__stats b { color: var(--ant-color-text); font-size: 13px; }
.script-assets { display: flex; min-height: 40px; flex-wrap: wrap; align-content: flex-start; gap: 5px; }
.script-assets .ant-tag { margin: 0; border-radius: 6px; font-size: 11px; }
.empty-assets { align-self: center; color: var(--ant-color-text-quaternary); font-size: 12px; }
.script-assets-more { align-self: center; border: 0; color: var(--ant-color-primary); background: transparent; cursor: pointer; font-size: 11px; }
.script-card__footer { display: flex; align-items: center; gap: 2px; margin-top: auto; padding-top: 12px; border-top: 1px solid var(--ant-color-border-secondary); }
.script-card__footer .ant-btn { padding-inline: 6px; font-size: 12px; }
@media (max-width: 720px) { .script-library__hero, .script-library__toolbar { align-items: stretch; flex-direction: column; } .script-library__actions { justify-content: flex-start; } }
</style>

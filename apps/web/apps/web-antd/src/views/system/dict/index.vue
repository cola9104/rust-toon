<script lang="ts" setup>
import type { SystemDictTypeApi } from '#/api/system/dict/type';

import { computed, onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, message, Select } from 'ant-design-vue';

import { getSimpleDictTypeList } from '#/api/system/dict/type';

import DataGrid from './modules/data-grid.vue';
import TypeGrid from './modules/type-grid.vue';

type DictSummary = Pick<SystemDictTypeApi.DictType, 'name' | 'type'>;
const selectedDict = ref<DictSummary>();
const dictionaries = ref<DictSummary[]>([]);
const recentDicts = ref<DictSummary[]>([]);
const loadingDictionaries = ref(false);
const dictOptions = computed(() => {
  const choices = new Map(dictionaries.value.map((dict) => [dict.type, dict]));
  if (selectedDict.value) choices.set(selectedDict.value.type, selectedDict.value);
  return [...choices.values()].map((dict) => ({
    label: `${dict.name} · ${dict.type}`,
    value: dict.type,
  }));
});

function handleDictTypeSelect(dict: DictSummary) {
  selectedDict.value = dict;
  recentDicts.value = [dict, ...recentDicts.value.filter((item) => item.type !== dict.type)].slice(0, 5);
}

function switchDictionary(value: unknown) {
  const dict = dictionaries.value.find((item) => item.type === value);
  if (dict) handleDictTypeSelect(dict);
}

async function loadDictionaries() {
  if (loadingDictionaries.value) return;
  loadingDictionaries.value = true;
  try {
    dictionaries.value = await getSimpleDictTypeList();
    const byType = new Map(dictionaries.value.map((dict) => [dict.type, dict]));
    recentDicts.value = recentDicts.value.flatMap((dict) => {
      const current = byType.get(dict.type);
      return current ? [current] : [];
    });
    if (selectedDict.value && byType.has(selectedDict.value.type)) {
      selectedDict.value = byType.get(selectedDict.value.type);
    }
  } catch {
    message.error('字典列表加载失败，请重新打开切换框重试');
  } finally {
    loadingDictionaries.value = false;
  }
}

function backToList() {
  selectedDict.value = undefined;
}

onMounted(loadDictionaries);
</script>

<template>
  <Page auto-content-height>
    <div class="flex h-full min-h-0 min-w-0 flex-col gap-4">
      <header class="shrink-0">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="min-w-0">
            <h1 class="m-0 break-words text-xl font-semibold">
              {{ selectedDict ? selectedDict.name : '字典管理' }}
            </h1>
            <p class="mb-0 mt-1 break-words text-sm text-muted-foreground">
              {{ selectedDict ? `字典编码：${selectedDict.type}` : '管理系统中的选项与分类，点击字典名称查看字典项。' }}
            </p>
          </div>
          <div v-if="selectedDict" class="flex w-full flex-wrap items-center gap-3 sm:w-auto">
            <Select
              :value="selectedDict.type"
              :options="dictOptions"
              :loading="loadingDictionaries"
              show-search
              option-filter-prop="label"
              aria-label="切换字典"
              placeholder="搜索字典名称或编码"
              class="w-full sm:w-80"
              @change="switchDictionary"
              @dropdown-visible-change="(open) => open && loadDictionaries()"
            />
            <Button type="link" class="!h-auto !p-0" @click="backToList">返回全部字典</Button>
          </div>
        </div>
        <nav v-if="recentDicts.length" aria-label="最近使用的字典" class="mt-3 flex flex-wrap items-center gap-2">
          <span class="text-sm text-muted-foreground">最近使用</span>
          <Button
            v-for="dict in recentDicts"
            :key="dict.type"
            size="small"
            :type="selectedDict?.type === dict.type ? 'primary' : 'default'"
            :aria-pressed="selectedDict?.type === dict.type"
            :title="dict.type"
            @click="handleDictTypeSelect(dict)"
          >{{ dict.name }}</Button>
        </nav>
      </header>
      <!-- Keep the list mounted so search, pagination and selection survive returning. -->
      <div v-show="!selectedDict" class="min-h-0 min-w-0 flex-1">
        <TypeGrid @select="handleDictTypeSelect" />
      </div>
      <div v-show="selectedDict" class="min-h-0 min-w-0 flex-1">
        <KeepAlive>
          <DataGrid v-if="selectedDict" :key="selectedDict.type" :dict-type="selectedDict.type" />
        </KeepAlive>
      </div>
    </div>
  </Page>
</template>

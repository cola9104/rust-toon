<script setup lang="ts">
import type { ToonflowApi } from '#/api/toonflow';

import { computed, reactive, ref, watch } from 'vue';

import {
  Button,
  Card,
  Empty,
  Form,
  Image,
  Input,
  InputNumber,
  message,
  Modal,
  Select,
  Space,
  Spin,
  Tag,
} from 'ant-design-vue';

import {
  autoConfigureSceneConsistency,
  getSceneConsistencyCatalog,
  saveSceneMaster,
  saveSceneState,
} from '#/api/toonflow';

import { assetFileUrl } from '../assets/asset-types';
import {
  buildSceneKeyOptions,
  isValidSceneKey,
  nextSceneKey,
  normalizeSceneKey,
  sceneMasterForKey,
} from './scene-consistency';

const props = defineProps<{
  assets: ToonflowApi.Asset[];
  open: boolean;
  projectId: number;
  sceneKeys: string[];
  scriptId?: number;
}>();

const emit = defineEmits<{
  changed: [catalog: ToonflowApi.SceneConsistencyCatalog];
  'update:open': [open: boolean];
}>();

const loading = ref(false);
const autoConfiguring = ref(false);
const savingMaster = ref(false);
const savingState = ref(false);
const catalog = ref<ToonflowApi.SceneConsistencyCatalog>({ scenes: [] });
const selectedSceneKey = ref('sc1');
const stateModalOpen = ref(false);
const newSceneKey = ref('');
const pendingSceneKeys = ref<string[]>([]);
let catalogRequestVersion = 0;

const masterForm = reactive({
  layoutSpec: {} as Record<string, unknown>,
  name: '',
  sceneAssetId: undefined as number | undefined,
  spatialPrompt: '',
});

const stateForm = reactive({
  changeSummary: '',
  id: undefined as number | undefined,
  name: '',
  objectStatesText: '{}',
  parentStateId: undefined as number | undefined,
  referenceAssetIds: [] as number[],
  sequence: undefined as number | undefined,
  stateKey: '',
  statePrompt: '',
});

const sceneKeyOptions = computed(() => {
  const options = buildSceneKeyOptions(
    props.sceneKeys,
    catalog.value,
    pendingSceneKeys.value,
  );
  return options.length > 0
    ? options
    : [{ label: 'SC1 · 待配置', value: 'sc1' }];
});

const suggestedSceneKey = computed(() =>
  nextSceneKey(sceneKeyOptions.value.map((option) => option.value)),
);

const currentMaster = computed(() =>
  sceneMasterForKey(catalog.value, selectedSceneKey.value),
);

const masterPreviewUrl = computed(() => {
  const selectedAsset = props.assets.find(
    (asset) => asset.id === masterForm.sceneAssetId,
  );
  if (masterForm.sceneAssetId === currentMaster.value?.sceneAssetId) {
    return currentMaster.value?.referenceUrl ?? selectedAsset?.imageFilePath;
  }
  return selectedAsset?.imageFilePath;
});

const sceneAssetOptions = computed(() =>
  props.assets
    .filter((asset) => asset.type === 'scene')
    .map((asset) => ({
      disabled: !asset.imageFilePath,
      label: `${asset.name}${asset.imageFilePath ? '' : '（图片未就绪）'}`,
      value: asset.id,
    })),
);

const referenceAssetOptions = computed(() =>
  props.assets
    .filter(
      (asset) =>
        !!asset.imageFilePath &&
        (asset.type !== 'role' || !!asset.parentAssetId),
    )
    .map((asset) => ({
      label: `${asset.name}（${asset.type}）`,
      value: asset.id,
    })),
);

const parentStateOptions = computed(() =>
  (currentMaster.value?.states ?? [])
    .filter((state) => state.id !== stateForm.id)
    .map((state) => ({
      label: `S${state.sequence} · ${state.name}`,
      value: state.id,
    })),
);

function fillMasterForm() {
  const master = currentMaster.value;
  Object.assign(masterForm, {
    layoutSpec: master?.layoutSpec ?? {},
    name: master?.name ?? selectedSceneKey.value.toUpperCase(),
    sceneAssetId: master?.sceneAssetId,
    spatialPrompt: master?.spatialPrompt ?? '',
  });
}

async function loadCatalog() {
  const scriptId = props.scriptId;
  if (!scriptId) return;
  const projectId = props.projectId;
  const requestVersion = ++catalogRequestVersion;
  loading.value = true;
  try {
    const nextCatalog = await getSceneConsistencyCatalog(projectId, scriptId);
    if (requestVersion !== catalogRequestVersion) return;
    catalog.value = nextCatalog;
    const available = sceneKeyOptions.value.map((option) => option.value);
    if (!available.includes(selectedSceneKey.value)) {
      selectedSceneKey.value = available[0] ?? 'sc1';
    }
    fillMasterForm();
    emit('changed', catalog.value);
  } finally {
    if (requestVersion === catalogRequestVersion) loading.value = false;
  }
}

async function autoConfigure() {
  if (!props.scriptId) return message.warning('请先选择制作剧本');
  if (autoConfiguring.value) return;
  if (loading.value || savingMaster.value || savingState.value) {
    return message.warning('请等待当前场景操作完成');
  }
  const projectId = props.projectId;
  const scriptId = props.scriptId;
  autoConfiguring.value = true;
  try {
    const result = await autoConfigureSceneConsistency(projectId, scriptId);
    if (props.projectId !== projectId || props.scriptId !== scriptId) return;
    await loadCatalog();
    const stateSummary = result.statesCreated
      ? `，创建 ${result.statesCreated} 个场景状态`
      : '';
    message.success(
      `AI 已配置 ${result.sceneCount} 个场次，绑定 ${result.storyboardsBound} 条分镜${stateSummary}`,
    );
    if (result.storyboardsBound > 0) {
      message.info('已有分镜图会标记为待重生成，新图片将执行统一场景约束');
    }
    if (result.warnings.length > 0) {
      message.warning(result.warnings.slice(0, 3).join('；'));
    }
  } finally {
    autoConfiguring.value = false;
  }
}

watch(
  () => props.open,
  (open) => {
    if (open) void loadCatalog();
  },
);
watch(
  () => props.scriptId,
  () => {
    // Pending keys are editor-local drafts and must never leak into another
    // episode when the shared production panel changes scripts.
    catalogRequestVersion += 1;
    loading.value = false;
    pendingSceneKeys.value = [];
    newSceneKey.value = '';
    selectedSceneKey.value = 'sc1';
    catalog.value = { scenes: [] };
    fillMasterForm();
    if (props.open && props.scriptId) void loadCatalog();
  },
);
watch(selectedSceneKey, fillMasterForm);

function addSceneKey() {
  if (autoConfiguring.value) return message.warning('AI 自动配置完成后再编辑场次');
  const sceneKey = normalizeSceneKey(
    newSceneKey.value || suggestedSceneKey.value,
  );
  if (!isValidSceneKey(sceneKey)) {
    return message.warning('场次编号请使用 SC 加正整数，例如 SC2');
  }
  if (!sceneKeyOptions.value.some((option) => option.value === sceneKey)) {
    pendingSceneKeys.value = [...pendingSceneKeys.value, sceneKey];
  }
  selectedSceneKey.value = sceneKey;
  newSceneKey.value = '';
}

async function submitMaster() {
  if (!props.scriptId) return;
  if (autoConfiguring.value) return message.warning('AI 自动配置完成后再保存母版');
  if (!isValidSceneKey(selectedSceneKey.value)) {
    return message.warning('场次编号请使用 SC 加正整数，例如 SC2');
  }
  savingMaster.value = true;
  try {
    const pinnedImageId =
      masterForm.sceneAssetId === currentMaster.value?.sceneAssetId
        ? currentMaster.value?.pinnedImageId
        : undefined;
    await saveSceneMaster({
      ...masterForm,
      ...(pinnedImageId === undefined ? {} : { pinnedImageId }),
      projectId: props.projectId,
      sceneKey: selectedSceneKey.value,
      scriptId: props.scriptId,
    });
    await loadCatalog();
    message.success('场景母版已锁定');
  } finally {
    savingMaster.value = false;
  }
}

function openStateEditor(state?: ToonflowApi.SceneState) {
  if (autoConfiguring.value) return message.warning('AI 自动配置完成后再编辑状态');
  const states = currentMaster.value?.states ?? [];
  Object.assign(stateForm, {
    changeSummary: state?.changeSummary ?? '',
    id: state?.id,
    name: state?.name ?? '',
    objectStatesText: JSON.stringify(state?.objectStates ?? {}, null, 2),
    parentStateId:
      state?.parentStateId ??
      [...states].sort((left, right) => right.sequence - left.sequence)[0]?.id,
    referenceAssetIds:
      state?.references.map((reference) => reference.assetId) ?? [],
    sequence: state?.sequence,
    stateKey: state?.stateKey ?? '',
    statePrompt: state?.statePrompt ?? '',
  });
  stateModalOpen.value = true;
}

async function submitState() {
  if (autoConfiguring.value) return message.warning('AI 自动配置完成后再保存状态');
  const master = currentMaster.value;
  if (!master) return message.warning('请先保存场景母版');
  const stateKey = stateForm.stateKey.trim().toLowerCase();
  if (!/^[a-z][a-z0-9_-]{0,63}$/.test(stateKey)) {
    return message.warning(
      '状态键必须以小写字母开头，只能含字母、数字、_ 或 -',
    );
  }
  if (
    stateKey !== 'base' &&
    !stateForm.changeSummary.trim() &&
    !stateForm.statePrompt.trim()
  ) {
    return message.warning('非基础状态必须填写变化说明或累计状态约束');
  }
  let objectStates: Record<string, string>;
  try {
    const parsed = JSON.parse(stateForm.objectStatesText || '{}');
    if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object')
      throw new Error();
    objectStates = parsed;
  } catch {
    return message.warning('物件状态快照必须是 JSON 对象');
  }
  savingState.value = true;
  try {
    await saveSceneState({
      changeSummary: stateForm.changeSummary,
      id: stateForm.id,
      name: stateForm.name || stateKey,
      objectStates,
      parentStateId: stateKey === 'base' ? undefined : stateForm.parentStateId,
      referenceAssetIds: stateForm.referenceAssetIds,
      sceneMasterId: master.id,
      sequence: stateKey === 'base' ? 0 : stateForm.sequence,
      stateKey,
      statePrompt: stateForm.statePrompt,
    });
    stateModalOpen.value = false;
    await loadCatalog();
    message.success('场景状态已保存');
  } finally {
    savingState.value = false;
  }
}
</script>

<template>
  <Modal
    :open="open"
    title="场景一致性"
    width="980px"
    :footer="null"
    @cancel="emit('update:open', false)"
  >
    <Spin :spinning="loading">
      <div class="scene-consistency-layout">
        <Card size="small" title="场次（SC）">
          <template #extra>
            <Button
              data-testid="auto-configure-scenes"
              type="primary"
              :disabled="loading || savingMaster || savingState"
              :loading="autoConfiguring"
              @click="autoConfigure"
            >
              AI 自动识别并配置
            </Button>
          </template>
          <Select
            v-model:value="selectedSceneKey"
            :disabled="autoConfiguring"
            :options="sceneKeyOptions"
            option-filter-prop="label"
            show-search
            style="width: 100%"
          />
          <div class="scene-key-add">
            <Input
              v-model:value="newSceneKey"
              data-testid="new-scene-key-input"
              :disabled="autoConfiguring"
              :placeholder="`输入场次编号，建议 ${suggestedSceneKey.toUpperCase()}`"
              @press-enter="addSceneKey"
            />
            <Button
              data-testid="add-scene-key"
              :disabled="autoConfiguring"
              @click="addSceneKey"
            >
              新增场次
            </Button>
          </div>
          <p class="scene-help">
            SC1 表示第 1
            个场次，不是分镜或轨道编号。同一时间、同一地点仍属于同一场次；换地点或时间才新增
            SC2、SC3。AI 会优先按剧本场标题和分镜已关联的场景资产完成识别，人工新增仅用于修正例外。
          </p>
        </Card>

        <Card size="small" title="场景母版">
          <template #extra>
            <Tag :color="currentMaster?.status === 'ready' ? 'green' : 'red'">
              {{ currentMaster?.status === 'ready' ? '已锁定' : '待配置' }}
            </Tag>
          </template>
          <p class="master-help">
            选择现有场景图片只会把它锁定为空间参考，不会重新生成图片。后续分镜可改变机位和人物动作，但会继续参考相同布局。
          </p>
          <div class="master-grid">
            <div v-if="masterPreviewUrl" data-testid="scene-master-preview">
              <Image :src="assetFileUrl(masterPreviewUrl)" :width="220" />
            </div>
            <Empty
              v-else
              :image="Empty.PRESENTED_IMAGE_SIMPLE"
              description="请选择一张已有场景图"
            />
            <Form :disabled="autoConfiguring" layout="vertical">
              <Form.Item label="母版名称">
                <Input
                  v-model:value="masterForm.name"
                  data-testid="scene-master-name"
                  placeholder="例如 客厅 · 白天"
                />
              </Form.Item>
              <Form.Item label="场景资产">
                <Select
                  v-model:value="masterForm.sceneAssetId"
                  allow-clear
                  :options="sceneAssetOptions"
                  placeholder="选择一张稳定的场景资产图"
                />
              </Form.Item>
              <Form.Item label="空间布局约束（可选，AI 可自动识别）">
                <Input.TextArea
                  v-model:value="masterForm.spatialPrompt"
                  :rows="4"
                  placeholder="通常可以留空；仅在母版未拍到某些区域或固定物容易错位时补充，例如：门在北墙中央，长桌靠左墙"
                />
                <p class="scene-help">
                  AI
                  会优先从母版图识别空间。这里用于补充画外区域、门窗方向或必须保持的固定摆放，不需要重复描述图片中已经清楚的内容。
                </p>
              </Form.Item>
              <Button
                type="primary"
                data-testid="save-scene-master"
                :disabled="autoConfiguring"
                :loading="savingMaster"
                @click="submitMaster"
              >
                保存并锁定当前母版
              </Button>
            </Form>
          </div>
        </Card>

        <Card size="small" title="场景状态">
          <template #extra>
            <Button
              :disabled="!currentMaster || autoConfiguring"
              type="primary"
              @click="openStateEditor()"
            >
              新建状态
            </Button>
          </template>
          <p class="master-help">
            AI 会把门、桌子等持续性的破坏识别为同一场景的后续状态，并从首次明确出现结果的分镜开始沿用；短暂动作、人物走位和机位变化不会创建状态。
          </p>
          <Empty
            v-if="!currentMaster?.states.length"
            :image="Empty.PRESENTED_IMAGE_SIMPLE"
            description="保存母版后会自动创建初始状态"
          />
          <div v-else class="state-list">
            <Card
              v-for="state in currentMaster.states"
              :key="state.id"
              size="small"
              class="state-card"
            >
              <div class="state-card__header">
                <Space>
                  <Tag color="blue">S{{ state.sequence }}</Tag>
                  <strong>{{ state.name }}</strong>
                  <code>{{ state.stateKey }}</code>
                  <Tag>{{ state.storyboardCount }} 镜</Tag>
                </Space>
                <Button
                  :disabled="autoConfiguring"
                  size="small"
                  @click="openStateEditor(state)"
                  >编辑</Button
                >
              </div>
              <p>
                {{
                  state.changeSummary ||
                  (state.stateKey === 'base'
                    ? '以母版中的初始完好状态为准'
                    : '未填写变化说明')
                }}
              </p>
              <p v-if="state.statePrompt" class="scene-help">
                {{ state.statePrompt }}
              </p>
            </Card>
          </div>
        </Card>
      </div>
    </Spin>
  </Modal>

  <Modal
    v-model:open="stateModalOpen"
    :title="stateForm.id ? '编辑场景状态' : '新建场景状态'"
    width="720px"
    :confirm-loading="savingState"
    :ok-button-props="{ disabled: autoConfiguring }"
    @ok="submitState"
  >
    <Form :disabled="autoConfiguring" layout="vertical">
      <div class="state-form-grid">
        <Form.Item label="状态键">
          <Input
            v-model:value="stateForm.stateKey"
            :disabled="
              autoConfiguring ||
              (stateForm.id !== undefined && stateForm.stateKey === 'base')
            "
            placeholder="例如 door_broken"
          />
        </Form.Item>
        <Form.Item label="状态名称">
          <Input v-model:value="stateForm.name" placeholder="例如 门已损坏" />
        </Form.Item>
        <Form.Item label="基于状态">
          <Select
            v-model:value="stateForm.parentStateId"
            allow-clear
            :disabled="autoConfiguring || stateForm.stateKey === 'base'"
            :options="parentStateOptions"
          />
        </Form.Item>
        <Form.Item label="顺序">
          <InputNumber
            v-model:value="stateForm.sequence"
            :disabled="autoConfiguring || stateForm.stateKey === 'base'"
            :min="stateForm.stateKey === 'base' ? 0 : 1"
            style="width: 100%"
          />
        </Form.Item>
      </div>
      <Form.Item label="变化说明">
        <Input.TextArea
          v-model:value="stateForm.changeSummary"
          :rows="3"
          placeholder="门板断裂、碎木落在门内侧；桌椅和其他空间结构保持不变"
        />
      </Form.Item>
      <Form.Item label="累计状态约束">
        <Input.TextArea
          v-model:value="stateForm.statePrompt"
          :rows="3"
          placeholder="描述当前画面必须保持的完整状态，不只写本次动作"
        />
      </Form.Item>
      <Form.Item label="状态参考资产">
        <Select
          v-model:value="stateForm.referenceAssetIds"
          mode="multiple"
          :options="referenceAssetOptions"
          placeholder="可选：损坏后的场景图或物件细节图"
        />
      </Form.Item>
      <Form.Item label="物件状态快照（JSON）">
        <Input.TextArea
          v-model:value="stateForm.objectStatesText"
          :rows="4"
          placeholder='{"door":"broken","table":"intact"}'
        />
      </Form.Item>
    </Form>
  </Modal>
</template>

<style scoped>
.scene-consistency-layout,
.state-list {
  display: grid;
  gap: 12px;
}

.scene-help {
  margin: 8px 0 0;
  color: hsl(var(--muted-foreground));
  font-size: 12px;
}

.scene-key-add {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 8px;
  margin-top: 10px;
}

.master-help {
  padding: 10px 12px;
  margin: 0 0 16px;
  color: hsl(var(--muted-foreground));
  font-size: 13px;
  line-height: 1.6;
  background: hsl(var(--muted) / 0.45);
  border-radius: 6px;
}

.master-grid {
  display: grid;
  grid-template-columns: 240px minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.state-card__header {
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
}

.state-card p {
  margin: 8px 0 0;
}

.state-form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 16px;
}

@media (max-width: 720px) {
  .master-grid,
  .state-form-grid {
    grid-template-columns: 1fr;
  }

  .scene-key-add {
    grid-template-columns: 1fr;
  }
}
</style>

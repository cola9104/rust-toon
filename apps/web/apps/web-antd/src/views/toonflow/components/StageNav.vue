<script setup lang="ts">
export interface ToonStage {
  key: string;
  label: string;
  hint?: string;
  icon: string;
}

defineProps<{ modelValue: string; stages: ToonStage[] }>();
defineEmits<{ 'update:modelValue': [value: string] }>();
</script>

<template>
  <nav class="stage-nav" aria-label="创作阶段">
    <button
      v-for="(stage, index) in stages"
      :key="stage.key"
      class="stage-nav__item"
      :class="{ active: modelValue === stage.key }"
      type="button"
      @click="$emit('update:modelValue', stage.key)"
    >
      <span class="stage-nav__step">{{ index + 1 }}</span>
      <span class="stage-nav__icon" aria-hidden="true">{{ stage.icon }}</span>
      <span class="stage-nav__copy"><b>{{ stage.label }}</b><small>{{ stage.hint }}</small></span>
    </button>
  </nav>
</template>

<style scoped>
.stage-nav { display: flex; align-items: stretch; gap: 10px; overflow-x: auto; padding: 4px 2px 14px; }
.stage-nav__item { position: relative; display: flex; min-width: 164px; flex: 1; align-items: center; gap: 10px; padding: 12px 14px; border: 1px solid var(--toon-line, #e8e8e8); border-radius: 15px; color: #737373; text-align: left; background: #fff; cursor: pointer; transition: .18s ease; }
.stage-nav__item:hover { border-color: #bdbdbd; transform: translateY(-1px); }.stage-nav__item.active { border-color: #171717; color: #fff; background: #171717; box-shadow: 0 10px 24px rgb(0 0 0 / 14%); }
.stage-nav__step { position: absolute; top: 6px; right: 9px; font-size: 10px; opacity: .5; }.stage-nav__icon { display: grid; width: 35px; height: 35px; flex: 0 0 35px; border-radius: 11px; font-size: 18px; background: #f1f1ef; place-items: center; }.active .stage-nav__icon { color: #171717; background: #fff; }
.stage-nav__copy { display: grid; min-width: 0; }.stage-nav__copy b { color: inherit; font-size: 13px; }.stage-nav__copy small { overflow: hidden; margin-top: 2px; color: inherit; font-size: 10px; opacity: .68; text-overflow: ellipsis; white-space: nowrap; }
</style>

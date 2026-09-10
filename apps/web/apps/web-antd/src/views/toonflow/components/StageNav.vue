<script setup lang="ts">
export interface ToonStage {
  key: string;
  label: string;
  hint?: string;
  icon: string;
}

defineProps<{ modelValue: string; stages: readonly ToonStage[] }>();
defineEmits<{ 'update:modelValue': [value: string] }>();
</script>

<template>
  <nav class="stage-nav" aria-label="创作阶段">
    <button
      v-for="(stage, index) in stages"
      :key="stage.key"
      class="stage-nav__item"
      :class="{ 'is-active': modelValue === stage.key }"
      :aria-current="modelValue === stage.key ? 'step' : undefined"
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
.stage-nav {
  --menu-item-color: var(--toon-muted);
  --menu-item-background-color: var(--toon-panel);
  --menu-item-hover-color: var(--toon-ink);
  --menu-item-hover-background-color: var(--toon-canvas);
  --menu-item-active-color: var(--toon-primary);
  --menu-item-active-background-color: var(--ant-color-primary-bg);

  display: flex;
  gap: 8px;
  align-items: stretch;
  padding: 4px 2px 14px;
  overflow-x: auto;
}

.stage-nav__item {
  position: relative;
  display: flex;
  flex: 1;
  gap: 10px;
  align-items: center;
  min-width: 164px;
  padding: 10px 12px;
  color: var(--menu-item-color);
  text-align: left;
  cursor: pointer;
  background: var(--menu-item-background-color);
  border: 0;
  border-radius: 8px;
  transition:
    color 0.2s ease,
    background-color 0.2s ease;
}

.stage-nav__item:not(.is-active):hover {
  color: var(--menu-item-hover-color);
  background: var(--menu-item-hover-background-color);
}

.stage-nav__item.is-active {
  color: var(--menu-item-active-color);
  background: var(--menu-item-active-background-color);
}

.stage-nav__item:focus-visible {
  outline: 2px solid hsl(var(--primary) / 45%);
  outline-offset: 2px;
}

.stage-nav__step {
  position: absolute;
  top: 5px;
  right: 8px;
  font-size: 10px;
  color: inherit;
  opacity: 0.5;
}

.stage-nav__icon {
  display: grid;
  flex: 0 0 34px;
  place-items: center;
  width: 34px;
  height: 34px;
  font-size: 17px;
  color: inherit;
  background: hsl(var(--accent));
  border-radius: 8px;
}

.is-active .stage-nav__icon {
  background: hsl(var(--primary) / 12%);
}

.stage-nav__copy {
  display: grid;
  min-width: 0;
}

.stage-nav__copy b {
  font-size: 13px;
  color: inherit;
}

.stage-nav__copy small {
  margin-top: 2px;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 10px;
  color: inherit;
  white-space: nowrap;
  opacity: 0.68;
}
</style>

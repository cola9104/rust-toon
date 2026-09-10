<script setup lang="ts">
defineProps<{
  active?: boolean;
  clickable?: boolean;
  padding?: 'compact' | 'normal' | 'none';
}>();

defineEmits<{ click: [event: MouseEvent] }>();
</script>

<template>
  <article
    class="toon-card"
    :class="[
      { 'toon-card--active': active, 'toon-card--clickable': clickable },
      `toon-card--${padding || 'normal'}`,
    ]"
    @click="$emit('click', $event)"
  >
    <slot />
  </article>
</template>

<style scoped>
.toon-card { min-width: 0; border: 1px solid var(--toon-line); border-radius: 18px; background: var(--toon-panel, #fff); box-shadow: 0 8px 26px rgb(0 0 0 / 4%); transition: transform .18s ease, border-color .18s ease, box-shadow .18s ease; }
.toon-card--normal { padding: 18px; }.toon-card--compact { padding: 12px; }.toon-card--none { overflow: hidden; }
.toon-card--clickable { cursor: pointer; }.toon-card--clickable:hover { border-color: var(--ant-color-primary-border); box-shadow: 0 14px 34px rgb(0 0 0 / 8%); transform: translateY(-2px); }
.toon-card--active { border-color: var(--toon-ink); box-shadow: 0 0 0 1px var(--toon-ink); }
</style>

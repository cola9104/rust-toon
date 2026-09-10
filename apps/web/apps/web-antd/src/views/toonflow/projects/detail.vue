<script lang="ts" setup>
import { onActivated, onDeactivated, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import ProjectDetailWorkspace from './detail/ProjectDetailWorkspace.vue';
defineOptions({ name: 'ToonflowProjectDetail' });
const route = useRoute();
const active = ref(true);
onActivated(() => { active.value = true; });
onDeactivated(() => { active.value = false; });
const projectId = ref<number>();
// Cached/outgoing views still observe the global route during navigation.
// Never replace their workspace with another route's missing or unrelated ID.
watch(() => [route.name, route.params.id], () => {
  if (route.name !== 'ToonflowProjectDetail') return;
  const id = Number(route.params.id);
  if (Number.isSafeInteger(id) && id > 0) projectId.value = id;
}, { immediate: true });
</script>
<template><ProjectDetailWorkspace v-if="active && projectId" :key="projectId" :project-id="projectId" /></template>

<script lang="ts" setup>
import { computed, onActivated, onDeactivated, ref } from 'vue';
import { useRoute } from 'vue-router';
import ProjectDetailWorkspace from './detail/ProjectDetailWorkspace.vue';
defineOptions({ name: 'ToonflowProjectDetail' });
const route = useRoute();
const active = ref(true);
onActivated(() => { active.value = true; });
onDeactivated(() => { active.value = false; });
const projectId = computed(() => Number(route.params.id));
</script>
<template><ProjectDetailWorkspace v-if="active" :key="projectId" :project-id="projectId" /></template>

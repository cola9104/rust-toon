<script lang="ts" setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import ProjectDetailWorkspace from './detail/ProjectDetailWorkspace.vue';
defineOptions({ name: 'ToonflowProjectDetail' });
const route = useRoute();
const projectId = computed(() => Number(route.params.id));
</script>
<template><ProjectDetailWorkspace :key="projectId" :project-id="projectId" /></template>

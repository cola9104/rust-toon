<script setup lang="ts">
import { computed } from 'vue';
import { theme } from 'ant-design-vue';
import './page-card.css';
import '../styles/toon-theme.css';

const { token } = theme.useToken();
// Teleported drawers and modals need the same resolved tokens as the page.
const stylesheet = computed(() => `.toon-page, .toon-overlay {${Object.entries(token.value)
  .filter(([, value]) => typeof value === 'string')
  .map(([name, value]) => `--ant-${name.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`)}:${value};`).join('')}}`);
</script>
<template><slot /><component :is="'style'">{{ stylesheet }}</component></template>

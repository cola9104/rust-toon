<script setup lang="ts">
import type { Recordable } from '@vben/types';

import type { MusicSong } from './types';

import { provide, ref } from 'vue';
import { message } from 'ant-design-vue';

import { generateMusic as generateMusicApi } from '#/api/ai/music';

import { Col, Empty, Row, TabPane, Tabs } from 'ant-design-vue';

import audioBar from './audioBar/index.vue';
import songCard from './songCard/index.vue';
import songInfo from './songInfo/index.vue';
import { currentSongKey } from './types';

defineOptions({ name: 'AiMusicListIndex' });

const currentType = ref('mine');
const loading = ref(false); // loading 状态
const currentSong = ref<MusicSong>({}); // 当前音乐
const mySongList = ref<MusicSong[]>([]);
const squareSongList = ref<MusicSong[]>([]);

async function generateMusic(formData: Recordable<any>) {
  loading.value = true;
  try {
    await generateMusicApi({
      title: formData.name,
      lyric: formData.lyric,
      prompt: formData.desc || formData.lyric,
      tags: formData.style,
      generateMode: formData.lyric ? 1 : 2,
    });
    message.success('音乐任务已提交');
  } finally {
    loading.value = false;
  }
}

function setCurrentSong(music: MusicSong) {
  currentSong.value = music;
}

defineExpose({
  generateMusic,
});

provide(currentSongKey, currentSong);
</script>

<template>
  <div class="flex flex-col">
    <div class="flex flex-auto overflow-hidden">
      <Tabs
        v-model:active-key="currentType"
        class="flex-auto px-5"
        tab-position="bottom"
      >
        <!-- 我的创作 -->
        <TabPane key="mine" tab="我的创作" v-loading="loading">
          <Row v-if="mySongList.length > 0" :gutter="12">
            <Col v-for="song in mySongList" :key="song.id" :span="24">
              <songCard :song-info="song" @play="setCurrentSong(song)" />
            </Col>
          </Row>
          <Empty v-else description="暂无音乐" />
        </TabPane>

        <!-- 试听广场 -->
        <TabPane key="square" tab="试听广场" v-loading="loading">
          <Row v-if="squareSongList.length > 0" :gutter="12">
            <Col v-for="song in squareSongList" :key="song.id" :span="24">
              <songCard :song-info="song" @play="setCurrentSong(song)" />
            </Col>
          </Row>
          <Empty v-else description="暂无音乐" />
        </TabPane>
      </Tabs>
      <!-- songInfo -->
      <songInfo class="flex-none" />
    </div>
    <audioBar class="flex-none" />
  </div>
</template>
<style lang="scss" scoped>
:deep(.ant-tabs) {
  .ant-tabs__content {
    padding: 0 7px;
    overflow: auto;
  }
}
</style>

<script lang="ts" setup>
import type { EchartsUIType } from '@vben/plugins/echarts';

import type { InfraRedisApi } from '#/api/infra/redis';

import { onMounted, ref, watch } from 'vue';

import { EchartsUI, useEcharts } from '@vben/plugins/echarts';

const props = defineProps<{
  redisData?: InfraRedisApi.RedisMonitorInfo;
}>();

const chartRef = ref<EchartsUIType>();
const { renderEcharts } = useEcharts(chartRef);

/** 渲染命令统计图表 */
function renderCommandStats() {
  if (!props.redisData?.commandStats) {
    return;
  }

  // 处理数据
  const commandStats = [] as any[];
  const nameList = [] as string[];
  props.redisData.commandStats.forEach((row) => {
    commandStats.push({
      name: row.command,
      value: row.calls,
    });
    nameList.push(row.command);
  });

  // 渲染图表
  renderEcharts({
    title: {
      text: '命令统计',
      left: 'center',
    },
    tooltip: {
      trigger: 'item',
      formatter: '{a} <br/>{b} : {c} ({d}%)',
    },
    legend: {
      type: 'scroll',
      orient: 'vertical',
      right: 30,
      top: 10,
      bottom: 20,
      data: nameList,
      textStyle: {
        color: '#a1a1a1',
      },
    },
    series: [
      {
        name: '命令',
        type: 'pie',
        radius: [20, 120],
        center: ['40%', '60%'],
        data: commandStats,
        roseType: 'radius',
        label: {
          show: true,
        },
        emphasis: {
          label: {
            show: true,
          },
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
      },
    ],
  });
}

/** 监听数据变化，重新渲染图表 */
watch(
  () => props.redisData,
  (newVal) => {
    if (newVal) {
      renderCommandStats();
    }
  },
  { deep: true, flush: 'post' },
);

onMounted(() => {
  if (props.redisData) {
    renderCommandStats();
  }
});
</script>

<template>
  <div v-if="props.redisData?.commandStats?.length" class="command-stats">
    <EchartsUI ref="chartRef" height="360px" />
    <div class="command-table">
      <div class="command-row command-head">
        <span>命令</span><span>调用次数</span><span>平均耗时</span>
      </div>
      <div
        v-for="row in [...props.redisData.commandStats].sort((a, b) => b.calls - a.calls).slice(0, 12)"
        :key="row.command"
        class="command-row"
      >
        <span>{{ row.command }}</span>
        <span>{{ row.calls.toLocaleString() }}</span>
        <span>{{ row.usec !== undefined && row.calls > 0 ? `${(row.usec / row.calls).toFixed(2)} μs` : '-' }}</span>
      </div>
    </div>
  </div>
  <div v-else class="py-12 text-center text-muted-foreground">
    暂无命令统计数据
  </div>
</template>

<style scoped>
.command-table { overflow: auto; max-height: 250px; font-size: 12px; }
.command-row { display: grid; grid-template-columns: 1fr 100px 100px; gap: 12px; padding: 7px 10px; border-top: 1px solid hsl(var(--border)); }
.command-head { color: hsl(var(--muted-foreground)); font-weight: 600; border-top: 0; }
.command-row span:nth-child(n + 2) { text-align: right; }
</style>

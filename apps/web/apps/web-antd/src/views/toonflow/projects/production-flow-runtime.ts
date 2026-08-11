import type { ToonflowApi, WorkflowNodeRun } from '#/api/toonflow';

export interface ProductionNodeRuntimeInput {
  directorPlan: string;
  nodeId: string;
  nodeRun?: WorkflowNodeRun;
  script?: ToonflowApi.Script;
  storyboardPlan: string;
  storyboardRunState?: string;
  storyboards: ToonflowApi.Storyboard[];
  videoTracks: any[];
}

export function productionNodeRuntime(input: ProductionNodeRuntimeInput) {
  const { nodeRun } = input;
  if (nodeRun) {
    if (nodeRun.state === 'running') {
      const progress =
        nodeRun.progressTotal > 1
          ? ` ${nodeRun.progressCurrent}/${nodeRun.progressTotal}`
          : '';
      return { color: 'processing', label: `运行中${progress}`, state: 'running' };
    }
    if (nodeRun.state === 'failed') return { color: 'red', label: '失败', state: 'failed' };
    if (nodeRun.state === 'cancelled') return { color: 'orange', label: '已取消', state: 'cancelled' };
    if (nodeRun.state === 'success') return { color: 'green', label: '已完成', state: 'success' };
  }
  if (input.nodeId === 'script') {
    return input.script
      ? { color: 'green', label: '已就绪', state: 'success' }
      : { color: 'default', label: '等待输入', state: 'pending' };
  }
  if (input.nodeId === 'scriptPlan') {
    return input.directorPlan
      ? { color: 'green', label: '已完成', state: 'success' }
      : { color: 'default', label: '等待运行', state: 'pending' };
  }
  if (input.nodeId === 'storyboardTable') {
    return input.storyboardPlan
      ? { color: 'green', label: '已完成', state: 'success' }
      : { color: 'default', label: '等待运行', state: 'pending' };
  }
  if (input.nodeId === 'storyboard') {
    const state = input.storyboardRunState;
    if (state === 'running') return { color: 'processing', label: '运行中', state };
    if (state === 'failed') return { color: 'red', label: '失败', state };
    if (state === 'cancelled') return { color: 'orange', label: '已取消', state };
    if (state === 'success') return { color: 'green', label: '已完成', state };
    return input.storyboards.length > 0
      ? { color: 'blue', label: `${input.storyboards.length} 个分镜`, state: 'ready' }
      : { color: 'default', label: '等待输入', state: 'pending' };
  }
  if (input.nodeId === 'workbench') {
    const videoCount = input.videoTracks.reduce(
      (total, track) => total + (track.videoList ?? track.video_list ?? []).length,
      0,
    );
    return videoCount > 0
      ? { color: 'green', label: `${videoCount} 个视频`, state: 'success' }
      : { color: 'default', label: '等待输入', state: 'pending' };
  }
  return { color: 'default', label: '未运行', state: 'pending' };
}

export function selectedWorkbenchCover(videoTracks: any[]): string {
  for (const track of videoTracks) {
    const videos = track.videoList ?? track.video_list ?? [];
    const selectedId =
      track.selectVideoId ?? track.select_video_id ?? track.videoId ?? track.video_id;
    const selected = videos.find((video: any) => video.id === selectedId);
    const available = selected ?? videos.find((video: any) => video.src);
    if (available?.src) return available.src;
  }
  return '';
}

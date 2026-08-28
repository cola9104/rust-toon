import type { ToonflowApi } from '#/api/toonflow';

export const VIDEO_TRANSITION_TYPE_OPTIONS: Array<{
  label: string;
  value: ToonflowApi.VideoTransitionType;
}> = [
  { label: '硬切', value: 'cut' },
  { label: '连续镜头', value: 'continuous' },
  { label: '动作衔接', value: 'action_bridge' },
  { label: '空镜过渡', value: 'empty_shot' },
  { label: '叠化', value: 'dissolve' },
  { label: '声音桥接', value: 'audio_bridge' },
  { label: '匹配剪辑', value: 'match_cut' },
];

export const VIDEO_FRAME_POLICY_OPTIONS: Array<{
  label: string;
  value: ToonflowApi.VideoFramePolicy;
}> = [
  { label: '使用本轨分镜', value: 'own' },
  { label: '使用上一轨尾帧', value: 'previous_tail' },
];

const transitionTypes = new Set<ToonflowApi.VideoTransitionType>(
  VIDEO_TRANSITION_TYPE_OPTIONS.map((option) => option.value),
);
const framePolicies = new Set<ToonflowApi.VideoFramePolicy>(
  VIDEO_FRAME_POLICY_OPTIONS.map((option) => option.value),
);

export interface VideoTransitionTrackLike {
  framePolicy?: unknown;
  id: unknown;
  previousTrackId?: unknown;
  transitionType?: unknown;
}

export interface OrderedVideoTrackContext {
  sceneKey: string;
  sceneName: string;
  trackId: number;
  trackName: string;
}

export function normalizeVideoTransitionSettings(
  track: VideoTransitionTrackLike,
): Pick<
  ToonflowApi.UpdateVideoTransitionSettings,
  'framePolicy' | 'transitionType'
> {
  const transitionType = transitionTypes.has(
    track.transitionType as ToonflowApi.VideoTransitionType,
  )
    ? (track.transitionType as ToonflowApi.VideoTransitionType)
    : 'cut';
  const framePolicy = framePolicies.has(
    track.framePolicy as ToonflowApi.VideoFramePolicy,
  )
    ? (track.framePolicy as ToonflowApi.VideoFramePolicy)
    : 'own';

  return { framePolicy, transitionType };
}

export function previousVideoTrackContext(
  entries: readonly OrderedVideoTrackContext[],
  currentTrackId: unknown,
  preferredPreviousTrackId?: unknown,
) {
  const currentId = Number(currentTrackId);
  const currentIndex = entries.findIndex((entry) => entry.trackId === currentId);
  if (currentIndex <= 0) return undefined;

  const preferredId = Number(preferredPreviousTrackId);
  const preferredIndex = entries.findIndex(
    (entry) => entry.trackId === preferredId,
  );
  if (preferredIndex >= 0 && preferredIndex < currentIndex) {
    return entries[preferredIndex];
  }
  return entries[currentIndex - 1];
}

export function transitionSourceLabel(source: unknown) {
  if (source === 'director') return '导演规划';
  if (source === 'manual') return '手动设置';
  return '默认设置';
}

export interface VideoFrameApplication {
  actualSource: string;
  applied: boolean;
  fallbackReason?: string;
  previousTrackId?: number;
  previousVideoId?: number;
  requestedPolicy: string;
}

export function videoFrameApplication(
  video: unknown,
): VideoFrameApplication | undefined {
  if (!video || typeof video !== 'object') return undefined;
  const record = video as Record<string, unknown>;
  const context = record.generationContext ?? record.generation_context;
  if (!context || typeof context !== 'object') return undefined;
  const frame = (context as Record<string, unknown>).frame;
  if (!frame || typeof frame !== 'object') return undefined;
  const data = frame as Record<string, unknown>;
  if (typeof data.actualSource !== 'string') return undefined;

  const previousTrackId =
    data.previousTrackId === null || data.previousTrackId === undefined
      ? Number.NaN
      : Number(data.previousTrackId);
  const previousVideoId =
    data.previousVideoId === null || data.previousVideoId === undefined
      ? Number.NaN
      : Number(data.previousVideoId);
  return {
    actualSource: data.actualSource,
    applied: data.applied === true,
    ...(typeof data.fallbackReason === 'string'
      ? { fallbackReason: data.fallbackReason }
      : {}),
    ...(Number.isFinite(previousTrackId) ? { previousTrackId } : {}),
    ...(Number.isFinite(previousVideoId) ? { previousVideoId } : {}),
    requestedPolicy:
      typeof data.requestedPolicy === 'string' ? data.requestedPolicy : 'own',
  };
}

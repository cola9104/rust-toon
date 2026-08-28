import {
  groupStoryboardsBySceneAndTrack,
  type StoryboardSceneItem,
} from './storyboard-scene-groups';

export interface VideoTrackItem {
  id: unknown;
}

export interface SceneVideoTrack<T extends VideoTrackItem = VideoTrackItem> {
  name: string;
  track: T;
  trackId: number;
}

export interface VideoSceneGroup<
  TTrack extends VideoTrackItem = VideoTrackItem,
  TStoryboard extends StoryboardSceneItem = StoryboardSceneItem,
> {
  items: TStoryboard[];
  key: string;
  name: string;
  tracks: SceneVideoTrack<TTrack>[];
}

function numericTrackId(value: unknown) {
  const trackId = Number(value);
  return Number.isFinite(trackId) ? trackId : undefined;
}

export function groupVideoTracksByScene<
  TTrack extends VideoTrackItem,
  TStoryboard extends StoryboardSceneItem,
>(
  tracks: TTrack[],
  storyboards: TStoryboard[],
  storyboardPlan = '',
): VideoSceneGroup<TTrack, TStoryboard>[] {
  const tracksById = new Map<number, TTrack>();
  for (const track of tracks) {
    const trackId = numericTrackId(track.id);
    if (trackId !== undefined) tracksById.set(trackId, track);
  }

  const assignedTrackIds = new Set<number>();
  const scenes = groupStoryboardsBySceneAndTrack(
    storyboards,
    storyboardPlan,
  ).map((scene) => ({
    items: scene.items,
    key: scene.key,
    name: scene.name,
    tracks: scene.tracks.flatMap((storyboardTrack) => {
      const trackId = numericTrackId(storyboardTrack.items[0]?.trackId);
      if (trackId === undefined || assignedTrackIds.has(trackId)) return [];
      const track = tracksById.get(trackId);
      if (!track) return [];
      assignedTrackIds.add(trackId);
      return [{ name: storyboardTrack.name, track, trackId }];
    }),
  }));

  const unassignedTracks = tracks.flatMap((track) => {
    const trackId = numericTrackId(track.id);
    if (trackId === undefined || assignedTrackIds.has(trackId)) return [];
    assignedTrackIds.add(trackId);
    return [{ name: String(trackId), track, trackId }];
  });
  if (unassignedTracks.length > 0) {
    scenes.push({
      items: [],
      key: 'scene:unassigned-video-tracks',
      name: '未分场',
      tracks: unassignedTracks,
    });
  }

  return scenes;
}

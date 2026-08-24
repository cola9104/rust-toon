export interface StoryboardTrackItem {
  id: number;
  index?: number | null;
  track?: string | null;
  trackId?: number | null;
}

export interface StoryboardTrackGroup<T extends StoryboardTrackItem = StoryboardTrackItem> {
  key: string;
  name: string;
  items: T[];
}

function trackIdOf(item: StoryboardTrackItem) {
  if (item.trackId === undefined || item.trackId === null) return undefined;
  const trackId = Number(item.trackId);
  return Number.isFinite(trackId) ? trackId : undefined;
}

export function sortStoryboards<T extends StoryboardTrackItem>(items: T[]) {
  return [...items].sort((left, right) => {
    const indexDelta = Number(left.index ?? Number.MAX_SAFE_INTEGER) - Number(right.index ?? Number.MAX_SAFE_INTEGER);
    return indexDelta || Number(left.id) - Number(right.id);
  });
}

export function storyboardTrackKey(item: StoryboardTrackItem) {
  const trackId = trackIdOf(item);
  return trackId === undefined
    ? `label:${item.track?.trim() || '默认轨道'}`
    : `track:${trackId}`;
}

export function storyboardTrackName(item: StoryboardTrackItem) {
  return item.track?.trim() || '默认轨道';
}

export function groupStoryboardsByTrack<T extends StoryboardTrackItem>(
  items: T[],
  options: { preserveOrder?: boolean } = {},
): StoryboardTrackGroup<T>[] {
  const grouped = new Map<string, StoryboardTrackGroup<T>>();
  const source = options.preserveOrder ? items : sortStoryboards(items);
  for (const item of source) {
    const key = storyboardTrackKey(item);
    const group = grouped.get(key);
    if (group) {
      group.items.push(item);
      continue;
    }
    grouped.set(key, { key, name: storyboardTrackName(item), items: [item] });
  }
  return [...grouped.values()];
}

export function storyboardsForTrack<T extends StoryboardTrackItem>(items: T[], trackId: unknown) {
  const id = Number(trackId);
  if (!Number.isFinite(id)) return [];
  return sortStoryboards(items.filter((item) => trackIdOf(item) === id));
}

export const SINGLE_IMAGE_VIDEO_MODE = 'singleImage';
export const DEFAULT_VIDEO_MODE = 'startEndRequired';

/**
 * A track with one storyboard image has a usable start frame, but no end
 * frame. Prefer the single-image first-frame mode unless the track already
 * has an explicitly initialized mode.
 */
export function defaultVideoGenerationMode(storyboardCount: number, configuredMode?: string) {
  return storyboardCount === 1
    ? SINGLE_IMAGE_VIDEO_MODE
    : configuredMode || DEFAULT_VIDEO_MODE;
}

export type VideoFrameRole = 'first' | 'last' | 'firstLast' | 'reference';

export function videoFrameRole(index: number, count: number, mode?: string): VideoFrameRole {
  if (count === 1 && mode === 'startEndRequired') return 'firstLast';
  if (count === 1 && mode === 'endFrameOptional') return 'last';
  if ((mode === 'startEndRequired' || mode === 'endFrameOptional') && count > 1) {
    if (index === 0) return 'first';
    if (index === count - 1) return 'last';
    return 'reference';
  }
  return index === 0 && mode !== 'text' ? 'first' : 'reference';
}

export function videoFrameItems<T>(items: readonly T[], mode?: string): T[] {
  if (!items.length || mode === 'text') return [...items];

  const first = items[0];
  const last = items.at(-1);
  if (first === undefined || last === undefined) return [];
  if (mode === 'startEndRequired') return items.length === 1 ? [first, first] : [first, last];
  if (mode === 'endFrameOptional') return items.length === 1 ? [last] : [first, last];
  return [first];
}

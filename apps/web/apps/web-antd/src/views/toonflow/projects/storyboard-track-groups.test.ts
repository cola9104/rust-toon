import { describe, expect, it } from 'vitest';

import {
  groupStoryboardsByTrack,
  storyboardsForTrack,
} from './storyboard-track-groups';

describe('storyboard track groups', () => {
  const storyboards = [
    { id: 3, index: 2, track: 'main', trackId: 20 },
    { id: 1, index: 0, track: 'main', trackId: 10 },
    { id: 2, index: 1, track: 'main', trackId: 20 },
  ];

  it('groups storyboard images by their canonical video track id', () => {
    const groups = groupStoryboardsByTrack(storyboards);

    expect(groups.map((group) => group.items.map((item) => item.id))).toEqual([[1], [2, 3]]);
  });

  it('uses the same track-id lookup for track generation images', () => {
    expect(storyboardsForTrack(storyboards, 20).map((item) => item.id)).toEqual([2, 3]);
    expect(storyboardsForTrack(storyboards, 10).map((item) => item.id)).toEqual([1]);
  });

  it('can preserve the preview reorder without changing track membership', () => {
    const groups = groupStoryboardsByTrack([storyboards[2]!, storyboards[1]!, storyboards[0]!], { preserveOrder: true });

    expect(groups.map((group) => group.items.map((item) => item.id))).toEqual([[2, 3], [1]]);
  });
});

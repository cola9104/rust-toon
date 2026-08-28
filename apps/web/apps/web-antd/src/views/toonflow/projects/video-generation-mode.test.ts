import { describe, expect, it } from 'vitest';

import { defaultVideoGenerationMode, videoFrameItems, videoFrameRole } from './video-generation-mode';

describe('video generation mode defaults', () => {
  it('uses the single-image first-frame mode for one storyboard image', () => {
    expect(defaultVideoGenerationMode(1, 'startEndRequired')).toBe('singleImage');
  });

  it('keeps the configured mode when a track has multiple storyboard images', () => {
    expect(defaultVideoGenerationMode(2, 'startEndRequired')).toBe('startEndRequired');
  });

  it('assigns frame roles from the selected generation mode', () => {
    expect(videoFrameRole(0, 1, 'startEndRequired')).toBe('firstLast');
    expect(videoFrameRole(0, 2, 'startEndRequired')).toBe('first');
    expect(videoFrameRole(1, 2, 'startEndRequired')).toBe('last');
    expect(videoFrameRole(0, 2, 'startFrameOptional')).toBe('first');
    expect(videoFrameRole(1, 2, 'startFrameOptional')).toBe('last');
    expect(videoFrameRole(0, 1, 'startFrameOptional')).toBe('last');
    expect(videoFrameRole(0, 1, 'endFrameOptional')).toBe('first');
  });

  it('selects the same ordered media for generation as the mode label', () => {
    const frames = ['first', 'middle', 'last'];
    expect(videoFrameItems(frames, 'startFrameOptional')).toEqual([
      'first',
      'last',
    ]);
    expect(videoFrameItems(frames, 'endFrameOptional')).toEqual(['first', 'last']);
    expect(videoFrameItems(['only'], 'startFrameOptional')).toEqual(['only']);
    expect(videoFrameItems(['only'], 'endFrameOptional')).toEqual(['only']);
    expect(videoFrameItems(['only'], 'startEndRequired')).toEqual(['only', 'only']);
  });
});

import { describe, expect, it } from 'vitest';

import {
  normalizeVideoTransitionSettings,
  previousVideoTrackContext,
  transitionDurationApplies,
  transitionSourceLabel,
  videoFrameApplication,
} from './video-transition-settings';

describe('video transition settings', () => {
  it('defaults an uninitialized track to a cut with its own frame', () => {
    expect(normalizeVideoTransitionSettings({ id: 2 })).toEqual({
      framePolicy: 'own',
      transitionDurationMs: 600,
      transitionType: 'cut',
      trimEndMs: null,
      trimStartMs: 0,
    });
  });

  it('keeps supported structured values and rejects legacy continuity values', () => {
    expect(
      normalizeVideoTransitionSettings({
        framePolicy: 'previous_tail',
        id: 2,
        transitionType: 'dissolve',
      }),
    ).toEqual({
      framePolicy: 'previous_tail',
      transitionDurationMs: 600,
      transitionType: 'dissolve',
      trimEndMs: null,
      trimStartMs: 0,
    });
    expect(
      normalizeVideoTransitionSettings({
        framePolicy: 'always',
        id: 2,
        transitionType: 'unknown',
      }),
    ).toEqual({
      framePolicy: 'own',
      transitionDurationMs: 600,
      transitionType: 'cut',
      trimEndMs: null,
      trimStartMs: 0,
    });
  });

  it('normalizes export timeline fields with defaults and bounds', () => {
    expect(
      normalizeVideoTransitionSettings({
        id: 3,
        transitionDurationMs: 800,
        transitionType: 'dissolve',
        trimEndMs: 4200,
        trimStartMs: 250,
      }),
    ).toEqual({
      framePolicy: 'own',
      transitionDurationMs: 800,
      transitionType: 'dissolve',
      trimEndMs: 4200,
      trimStartMs: 250,
    });

    expect(
      normalizeVideoTransitionSettings({
        id: 3,
        transitionDurationMs: 99_999,
        trimEndMs: null,
        trimStartMs: -5,
      }),
    ).toEqual({
      framePolicy: 'own',
      transitionDurationMs: 10_000,
      transitionType: 'cut',
      trimEndMs: null,
      trimStartMs: 0,
    });

    expect(
      normalizeVideoTransitionSettings({
        id: 3,
        transitionDurationMs: 'fast',
        trimEndMs: 'end',
        trimStartMs: 'start',
      }),
    ).toEqual({
      framePolicy: 'own',
      transitionDurationMs: 600,
      transitionType: 'cut',
      trimEndMs: null,
      trimStartMs: 0,
    });
  });

  it('marks dissolve and audio bridge as the only duration-aware transitions', () => {
    expect(transitionDurationApplies('dissolve')).toBe(true);
    expect(transitionDurationApplies('audio_bridge')).toBe(true);
    expect(transitionDurationApplies('cut')).toBe(false);
    expect(transitionDurationApplies('continuous')).toBe(false);
  });

  it('resolves an explicit earlier source or the immediately preceding track', () => {
    const tracks = [
      { sceneKey: 'scene-1', sceneName: '场1', trackId: 10, trackName: '1' },
      { sceneKey: 'scene-1', sceneName: '场1', trackId: 11, trackName: '2' },
      { sceneKey: 'scene-2', sceneName: '场2', trackId: 12, trackName: '3' },
    ];

    expect(previousVideoTrackContext(tracks, 12, 10)?.trackId).toBe(10);
    expect(previousVideoTrackContext(tracks, 12)?.trackId).toBe(11);
    expect(previousVideoTrackContext(tracks, 10)).toBeUndefined();
    expect(previousVideoTrackContext(tracks, 11, 12)?.trackId).toBe(10);
  });

  it('labels the origin of track-level transition settings', () => {
    expect(transitionSourceLabel('director')).toBe('导演规划');
    expect(transitionSourceLabel('manual')).toBe('手动设置');
    expect(transitionSourceLabel(undefined)).toBe('默认设置');
  });

  it('reads the actual frame application from generated video metadata', () => {
    expect(
      videoFrameApplication({
        generationContext: {
          frame: {
            actualSource: 'previous_video_tail',
            applied: true,
            previousTrackId: 8,
            previousVideoId: 19,
            requestedPolicy: 'previous_tail',
          },
        },
      }),
    ).toEqual({
      actualSource: 'previous_video_tail',
      applied: true,
      previousTrackId: 8,
      previousVideoId: 19,
      requestedPolicy: 'previous_tail',
    });

    expect(
      videoFrameApplication({
        generationContext: {
          frame: {
            actualSource: 'storyboard',
            applied: false,
            fallbackReason: '上一轨道没有成功视频',
            requestedPolicy: 'previous_tail',
          },
        },
      }),
    ).toEqual({
      actualSource: 'storyboard',
      applied: false,
      fallbackReason: '上一轨道没有成功视频',
      requestedPolicy: 'previous_tail',
    });
  });
});

import { describe, expect, it } from 'vitest';

import { groupVideoTracksByScene } from './video-scene-groups';

const storyboardPlan = `
## 场1：病房·真相
## 场2：武馆·重逢
`;

describe('video scene groups', () => {
  it('orders canonical video tracks under their storyboard scenes', () => {
    const tracks = [{ id: 30 }, { id: 20 }, { id: 10 }];
    const storyboards = [
      {
        id: 1,
        index: 0,
        track: '1',
        trackId: 10,
        videoDesc: '场景：病房；',
      },
      {
        id: 2,
        index: 1,
        track: '2',
        trackId: 20,
        videoDesc: '场景：病房；',
      },
      {
        id: 3,
        index: 2,
        track: '3',
        trackId: 30,
        videoDesc: '场景：武馆；',
      },
    ];

    const scenes = groupVideoTracksByScene(tracks, storyboards, storyboardPlan);

    expect(scenes.map((scene) => scene.name)).toEqual([
      '场1 · 病房·真相',
      '场2 · 武馆·重逢',
    ]);
    expect(
      scenes.map((scene) => scene.tracks.map((entry) => entry.track.id)),
    ).toEqual([[10, 20], [30]]);
  });

  it('keeps tracks without storyboards available in an unassigned group', () => {
    const scenes = groupVideoTracksByScene(
      [{ id: 10 }, { id: 99 }],
      [
        {
          id: 1,
          track: '1',
          trackId: 10,
          videoDesc: '场景：病房；',
        },
      ],
      storyboardPlan,
    );

    expect(scenes.at(-1)?.name).toBe('未分场');
    expect(scenes.at(-1)?.tracks.map((entry) => entry.trackId)).toEqual([99]);
  });
});

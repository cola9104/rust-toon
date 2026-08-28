import { describe, expect, it } from 'vitest';

import { groupStoryboardsBySceneAndTrack } from './storyboard-scene-groups';

const storyboardPlan = `
## 场1：病房·真相揭晓 | 参演角色：甲、乙
| 序号 | 画面描述 | 时长 |
|---|---|---|
| 1 | 甲躺在病床上。 | 4 |
| 2 | 乙放下苹果。 | 5 |

## 场2：武馆软垫·重逢 | 参演角色：甲
| 序号 | 画面描述 | 时长 |
|---|---|---|
| 1 | 甲从软垫上坐起。 | 4 |
`;

describe('storyboard scene groups', () => {
  it('keeps video tracks nested under their storyboard scenes', () => {
    const storyboards = [
      {
        id: 3,
        index: 2,
        track: '3',
        trackId: 30,
        videoDesc: '画面描述：甲从软垫上坐起。；场景：武馆软垫；',
      },
      {
        id: 2,
        index: 1,
        track: '1',
        trackId: 10,
        videoDesc: '画面描述：乙放下苹果。；场景：病房；',
      },
      {
        id: 1,
        index: 0,
        track: '1',
        trackId: 10,
        videoDesc: '画面描述：甲躺在病床上。；场景：病房；',
      },
    ];

    const scenes = groupStoryboardsBySceneAndTrack(storyboards, storyboardPlan);

    expect(scenes.map((scene) => scene.name)).toEqual([
      '场1 · 病房·真相揭晓',
      '场2 · 武馆软垫·重逢',
    ]);
    expect(
      scenes.map((scene) =>
        scene.tracks.map((track) => track.items.map((item) => item.id)),
      ),
    ).toEqual([[[1, 2]], [[3]]]);
  });

  it('uses explicit scene names for cached rows that predate the current table', () => {
    const scenes = groupStoryboardsBySceneAndTrack(
      [
        {
          id: 11,
          index: 0,
          track: '1',
          trackId: 10,
          videoDesc: '场景：病房；画面描述：旧版病房镜头',
        },
        {
          id: 12,
          index: 1,
          track: '2',
          trackId: 20,
          videoDesc: '场景：武馆软垫；画面描述：旧版武馆镜头',
        },
      ],
      storyboardPlan,
    );

    expect(scenes.map((scene) => scene.items.map((item) => item.id))).toEqual([
      [11],
      [12],
    ]);
  });

  it('uses the persisted canonical scene key before text heuristics', () => {
    const scenes = groupStoryboardsBySceneAndTrack(
      [
        {
          id: 21,
          index: 0,
          sceneKey: 'sc2',
          track: '1',
          trackId: 20,
          videoDesc: '场景：病房；这里保留了上一场名称作为对白语境',
        },
      ],
      storyboardPlan,
    );

    expect(scenes).toHaveLength(1);
    expect(scenes[0]?.key).toBe('sc2');
    expect(scenes[0]?.name).toBe('场2 · 武馆软垫·重逢');
  });

  it('falls back to numbered scene blocks while retaining tracks without a table', () => {
    const scenes = groupStoryboardsBySceneAndTrack([
      {
        id: 1,
        index: 0,
        track: 'main',
        trackId: 10,
        videoDesc: '场景：天台；画面描述：角色远眺',
      },
    ]);

    expect(scenes[0]?.name).toBe('场1 · 天台');
    expect(scenes[0]?.tracks[0]?.items[0]?.id).toBe(1);
  });
});

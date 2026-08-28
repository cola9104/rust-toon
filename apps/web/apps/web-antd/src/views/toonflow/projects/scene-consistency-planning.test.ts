import { describe, expect, it } from 'vitest';

import { buildPlannedScenes } from './scene-consistency-planning';

describe('scene consistency planning', () => {
  it('uses director-table membership and order while binding scene assets deterministically', () => {
    const scriptPlan = String.raw`
### 分场汇总表

| 场次 | 场景名 | 情绪基调 |
|---|---|---|
| Sc1 | 纯白病房\|深夜 | 压抑 |
| SC2 | 北拳武馆软垫 | 狂喜 |
| 场3 | 18号按摩房 | 克制 |
`;
    const storyboardTable = `
## 场1：纯白病房
**引用资产ID**：[101, 201]

## SC2 - 北拳武馆软垫
**引用资产ID**：[102, 103, 202]

## 场3：18号按摩房
**引用资产ID**：[999]

## 场4：导演规划中不存在的场次
**引用资产ID**：[104]
`;
    const assets = [
      { id: 101, type: 'scene' },
      { id: 102, type: 'scene' },
      { id: 103, type: 'scene' },
      { id: 104, type: 'scene' },
      { id: 201, type: 'role' },
      { id: 202, type: 'props' },
    ];

    expect(buildPlannedScenes(scriptPlan, storyboardTable, assets)).toEqual([
      {
        assetMatch: 'unique',
        defaultSceneAssetId: 101,
        name: '纯白病房|深夜',
        order: 0,
        sceneKey: 'sc1',
      },
      {
        assetMatch: 'ambiguous',
        name: '北拳武馆软垫',
        order: 1,
        sceneKey: 'sc2',
      },
      {
        assetMatch: 'missing',
        name: '18号按摩房',
        order: 2,
        sceneKey: 'sc3',
      },
    ]);
  });

  it('deduplicates repeated references and supports reference-id table columns', () => {
    const scriptPlan = `
| 场景名称 | 场次编号 |
|---|---|
| 天台 | 第1场 |
| 地下室 | scene2 |
`;
    const storyboardTable = `
## 场1：天台
| 分镜 | **引用资产ID** |
|---|---|
| 1 | [301, 401] |
| 2 | [301] |

## Scene2：地下室
引用资产 ID：[302]
`;

    expect(
      buildPlannedScenes(scriptPlan, storyboardTable, [
        { id: 301, type: 'scene' },
        { id: 302, type: 'scene' },
        { id: 401, type: 'role' },
      ]),
    ).toEqual([
      {
        assetMatch: 'unique',
        defaultSceneAssetId: 301,
        name: '天台',
        order: 0,
        sceneKey: 'sc1',
      },
      {
        assetMatch: 'unique',
        defaultSceneAssetId: 302,
        name: '地下室',
        order: 1,
        sceneKey: 'sc2',
      },
    ]);
  });

  it('does not infer scene membership from storyboard-only data', () => {
    const storyboardTable = `
## 场1：病房
**引用资产ID**：[101]
`;

    expect(
      buildPlannedScenes('导演备注：采用冷色调。', storyboardTable, [
        { id: 101, type: 'scene' },
      ]),
    ).toEqual([]);
    expect(
      buildPlannedScenes('', storyboardTable, [{ id: 101, type: 'scene' }]),
    ).toEqual([]);
  });

  it('stops collecting references when a non-scene level-two section starts', () => {
    const scriptPlan = `
| 场次 | 场景名 |
|---|---|
| sc1 | 病房 |
`;
    const storyboardTable = `
## 场1：病房
**引用资产ID**：[101]

## 附录
**引用资产ID**：[102]
`;

    expect(
      buildPlannedScenes(scriptPlan, storyboardTable, [
        { id: 101, type: 'scene' },
        { id: 102, type: 'scene' },
      ]),
    ).toEqual([
      {
        assetMatch: 'unique',
        defaultSceneAssetId: 101,
        name: '病房',
        order: 0,
        sceneKey: 'sc1',
      },
    ]);
  });
});

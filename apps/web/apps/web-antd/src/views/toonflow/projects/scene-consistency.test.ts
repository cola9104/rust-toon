import { describe, expect, it } from 'vitest';

import {
  defaultSceneStateId,
  isStateValidForScene,
  sceneConsistencyIssues,
  sceneStateOptions,
  sceneStateTimelineViolation,
} from './scene-consistency';

const catalog = {
  scenes: [
    {
      id: 1,
      sceneKey: 'sc1',
      status: 'ready',
      states: [
        { id: 10, name: '初始完好', sequence: 0, stateKey: 'base' },
        {
          id: 11,
          name: '门已损坏',
          parentStateId: 10,
          sequence: 1,
          stateKey: 'door_broken',
        },
        {
          id: 12,
          name: '断电',
          parentStateId: 11,
          sequence: 2,
          stateKey: 'lights_out',
        },
        {
          id: 13,
          name: '门已修复',
          parentStateId: 11,
          sequence: 3,
          stateKey: 'door_repaired',
        },
      ],
    },
    { id: 2, sceneKey: 'sc2', status: 'needs_review', states: [] },
  ],
} as any;

describe('scene consistency helpers', () => {
  it('filters states by scene and resolves the base state', () => {
    expect(sceneStateOptions(catalog, 'SC1')).toEqual([
      { label: 'S0 · 初始完好', value: 10 },
      { label: 'S1 · 门已损坏', value: 11 },
      { label: 'S2 · 断电', value: 12 },
      { label: 'S3 · 门已修复', value: 13 },
    ]);
    expect(defaultSceneStateId(catalog, 'sc1')).toBe(10);
    expect(isStateValidForScene(catalog, 'sc1', 11)).toBe(true);
    expect(isStateValidForScene(catalog, 'sc2', 11)).toBe(false);
  });

  it('counts missing masters, unbound boards, and stale images separately', () => {
    expect(
      sceneConsistencyIssues(catalog, [
        { id: 1, sceneKey: 'sc1', sceneStateId: 10, sceneConsistencyStatus: 'ready' },
        { id: 2, sceneKey: 'sc1', sceneStateId: 11, sceneConsistencyStatus: 'stale' },
        { id: 3, sceneKey: 'sc2', sceneConsistencyStatus: 'missing_master' },
      ] as any),
    ).toEqual({ missingMasters: 1, staleStoryboards: 1, unboundStoryboards: 1 });
  });

  it('blocks returning from a lasting changed state to base', () => {
    const violation = sceneStateTimelineViolation(
      catalog,
      [
        { id: 1, sceneKey: 'sc1', sceneStateId: 11 },
        { id: 2, sceneKey: 'sc1', sceneStateId: 10 },
      ] as any,
      { id: 2, sceneKey: 'sc1', sceneStateId: 10 },
    );

    expect(violation).toEqual({
      earlierStateName: '门已损坏',
      laterStateName: '初始完好',
      sceneKey: 'sc1',
    });
  });

  it('checks the following same-scene board when inserting between scenes', () => {
    const violation = sceneStateTimelineViolation(
      catalog,
      [
        { id: 1, sceneKey: 'sc1', sceneStateId: 10 },
        { id: 2, sceneKey: 'sc2' },
        { id: 3, sceneKey: 'sc1', sceneStateId: 10 },
      ] as any,
      { sceneKey: 'sc1', sceneStateId: 11 },
      1,
    );

    expect(violation?.earlierStateName).toBe('门已损坏');
    expect(violation?.laterStateName).toBe('初始完好');
  });

  it('allows the same state, descendants, and an explicit descendant repair state', () => {
    const storyboards = [
      { id: 1, sceneKey: 'sc1', sceneStateId: 10 },
      { id: 2, sceneKey: 'sc1', sceneStateId: 11 },
      { id: 3, sceneKey: 'sc1', sceneStateId: 13 },
    ] as any;

    expect(
      sceneStateTimelineViolation(
        catalog,
        storyboards,
        { id: 2, sceneKey: 'sc1', sceneStateId: 11 },
      ),
    ).toBeUndefined();
    expect(
      sceneStateTimelineViolation(
        catalog,
        storyboards,
        { id: 3, sceneKey: 'sc1', sceneStateId: 13 },
      ),
    ).toBeUndefined();
  });
});

import { describe, expect, it } from 'vitest';

import { productionNodeRuntime, selectedWorkbenchCover } from './production-flow-runtime';

describe('production flow runtime presentation', () => {
  it('reports workflow progress and completed documents', () => {
    expect(productionNodeRuntime({
      directorPlan: '', nodeId: 'storyboard', storyboardPlan: '', storyboards: [], videoTracks: [],
      nodeRun: { id: 1, nodeId: 'storyboard', state: 'running', progressCurrent: 2, progressTotal: 5 } as any,
    }).label).toBe('运行中 2/5');
    expect(productionNodeRuntime({
      directorPlan: 'ready', nodeId: 'scriptPlan', storyboardPlan: '', storyboards: [], videoTracks: [],
    }).state).toBe('success');
  });

  it('prefers the selected video as the workbench cover', () => {
    expect(selectedWorkbenchCover([{ selectVideoId: 2, videoList: [{ id: 1, src: 'a' }, { id: 2, src: 'b' }] }])).toBe('b');
  });
});

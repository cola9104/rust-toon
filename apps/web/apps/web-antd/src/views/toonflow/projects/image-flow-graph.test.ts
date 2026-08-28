import { describe, expect, it } from 'vitest';

import { defaultImageFlowEdges, directUpstreamNodeIds, upstreamNodeIds } from './image-flow-graph';

describe('image flow graph', () => {
  it('collects transitive upstream nodes without looping', () => {
    const edges = [
      { id: '1', source: 'upload', target: 'prompt' },
      { id: '2', source: 'prompt', target: 'generated' },
      { id: '3', source: 'generated', target: 'prompt' },
    ];
    expect([...upstreamNodeIds(edges, 'generated')].sort()).toEqual(['prompt', 'upload']);
  });

  it('restores prompt and upload edges to the generated node', () => {
    expect(defaultImageFlowEdges([
      { id: 'upload', type: 'upload' }, { id: 'prompt', type: 'prompt' }, { id: 'output', type: 'generated' },
    ])).toHaveLength(2);
  });

  it('uses only direct inputs for one edit generation step', () => {
    const edges = [
      { id: '1', source: 'old-output', target: 'repair-base' },
      { id: '2', source: 'repair-base', target: 'next-output' },
      { id: '3', source: 'instruction', target: 'next-output' },
    ];

    expect([...directUpstreamNodeIds(edges, 'next-output')].sort()).toEqual([
      'instruction',
      'repair-base',
    ]);
  });
});

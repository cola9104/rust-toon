import { describe, expect, it } from 'vitest';

import {
  projectDetailPanelComponents,
  projectDetailStages,
} from './project-detail-panels';

describe('project detail panels', () => {
  it('keeps every stage behind an async component boundary', () => {
    const stageKeys = projectDetailStages.map((stage) => stage.key);

    expect(stageKeys).toEqual([
      'novel',
      'script-agent',
      'script',
      'production',
      'archive',
    ]);
    expect(Object.keys(projectDetailPanelComponents).sort()).toEqual(
      [...stageKeys].sort(),
    );
    for (const panel of Object.values(projectDetailPanelComponents)) {
      expect(
        (panel as { __asyncLoader?: () => Promise<unknown> }).__asyncLoader,
      ).toBeTypeOf('function');
    }
  });
});

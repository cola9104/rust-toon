import { describe, expect, it } from 'vitest';

import {
  createProjectDefaults,
  projectTemplateDescription,
  projectTemplateLabel,
} from './project-templates';

describe('toonflow project templates', () => {
  it('creates a time travel project without inventing story facts', () => {
    const project = createProjectDefaults('time_travel');

    expect(project.projectType).toBe('time_travel');
    expect(project.type).toBe('穿越');
    expect(project.intro).toBe('');
    expect(project.imageQuality).toBe('2K');
    expect(projectTemplateLabel(project.projectType)).toBe('穿越剧场');
    expect(projectTemplateDescription(project.projectType)).toContain(
      '古今元素各自年代',
    );
  });

  it('keeps existing projects on the standard template fallback', () => {
    expect(projectTemplateLabel('legacy')).toBe('标准剧场');
  });
});

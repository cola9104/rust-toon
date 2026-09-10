import type { ToonflowApi } from '#/api/toonflow';
import { describe, expect, it } from 'vitest';
import { buildProjectSummary, countFinishedEpisodes, failureMessage, summarizeFailures, taskState } from './toonflow-dashboard';

const project = { id: 1, name: '黄巾起义', chatModel: 1, imageModel: 2, videoModel: 3 } as ToonflowApi.Project;
const stats = { scriptCount: 0, roleCount: 0, storyboardCount: 0, videoCount: 0 };

describe('dashboard data semantics', () => {
  it('does not ask users to reimport existing chapters', () => {
    const result = buildProjectSummary(project, stats, 800, 0);
    expect(result.nextAction).toBe('处理原文章节');
    expect(result.nextHint).toContain('800');
    expect(buildProjectSummary(project, stats, 0, 0).nextAction).toBe('导入原文');
  });
  it('does not confuse video attempts with completed episodes', () => {
    const result = buildProjectSummary(project, { ...stats, videoCount: 20 }, 800, 0);
    expect(result.nextStage).toBe('production');
    expect(result.renders).toBe(0);
    expect(buildProjectSummary(project, stats, 800, 2).nextStage).toBe('archive');
  });
  it('distinguishes missing data from zero, without inventing progress', () => {
    const unknown = buildProjectSummary(project);
    expect(unknown.statistics).toBeUndefined();
    expect(unknown.nextAction).toBe('打开项目');
    expect(unknown).not.toHaveProperty('progress');
  });
  it('counts only successful episodes once, regardless of version count', () => {
    const render = (state: string, url: string) => ({ state, url }) as ToonflowApi.EpisodeRender;
    const archive = { projectId: 1, episodes: [
      { scriptId: 1, scriptName: 'one', renders: [render('completed', '/one'), render('completed', '/two')] },
      { scriptId: 2, scriptName: 'two', renders: [render('failed', '/failed')] },
      { scriptId: 3, scriptName: 'three', renders: [render('completed', '')] },
    ] };
    expect(countFinishedEpisodes(archive)).toBe(1);
  });
  it('groups structured errors by their readable message', () => {
    const tasks = [1, 2].map((id) => ({ id: String(id), state: 'failed', reason: JSON.stringify({ message: '模型鉴权失败', requestId: id }) }) as ToonflowApi.Task);
    expect(summarizeFailures(tasks)).toMatchObject([{ message: '模型鉴权失败', count: 2 }]);
    expect(failureMessage('plain error')).toBe('plain error');
    expect(taskState('cancelled')).toMatchObject({ label: '已取消', key: 'other' });
  });
});

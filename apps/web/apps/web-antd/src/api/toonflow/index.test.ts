import { beforeEach, describe, expect, it, vi } from 'vitest';

const requestClient = vi.hoisted(() => ({
  get: vi.fn(),
  post: vi.fn(),
  request: vi.fn(),
}));

vi.mock('#/api/request', () => ({ requestClient }));

import {
  getEpisodeRenders,
  getNovelPage,
  getProjectVideoArchive,
  getSceneConsistencyCatalog,
  saveSceneMaster,
  saveSceneState,
  setEpisodeRenderCurrent,
  updateVideoTransitionSettings,
} from './index';

describe('toonflow video archive api', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads the project archive and one episode through REST paths', async () => {
    requestClient.get.mockResolvedValue({ episodes: [], projectId: 12 });

    await getProjectVideoArchive(12);
    await getEpisodeRenders(12, 34);

    expect(requestClient.get).toHaveBeenNthCalledWith(
      1,
      '/toonflow/projects/12/video-archive',
    );
    expect(requestClient.get).toHaveBeenNthCalledWith(
      2,
      '/toonflow/projects/12/episodes/34/renders',
    );
  });

  it('selects a current render with PATCH', async () => {
    requestClient.request.mockResolvedValue({ id: 56, isCurrent: true });

    await setEpisodeRenderCurrent(56);

    expect(requestClient.request).toHaveBeenCalledWith(
      '/toonflow/episode-renders/56/current',
      { data: {}, method: 'PATCH' },
    );
  });
});

describe('toonflow scene consistency api', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads the scene master and state catalog for one script', async () => {
    requestClient.post.mockResolvedValue({ scenes: [] });

    await getSceneConsistencyCatalog(12, 34);

    expect(requestClient.post).toHaveBeenCalledWith(
      '/toonflow/production/sceneConsistency/catalog',
      { projectId: 12, scriptId: 34 },
    );
  });

  it('pins a master and persists a cumulative damaged state', async () => {
    requestClient.post.mockResolvedValue({ id: 7 });

    await saveSceneMaster({
      name: '客厅',
      projectId: 12,
      sceneAssetId: 90,
      sceneKey: 'sc1',
      scriptId: 34,
      spatialPrompt: '门在北墙，桌在左侧',
    });
    await saveSceneState({
      changeSummary: '门被砸断，其他布局不变',
      name: '门已损坏',
      referenceAssetIds: [91],
      sceneMasterId: 7,
      stateKey: 'door_broken',
      statePrompt: '门板断裂，碎木在门内侧；桌仍在左侧',
    });

    expect(requestClient.post).toHaveBeenNthCalledWith(
      1,
      '/toonflow/production/sceneConsistency/saveMaster',
      expect.objectContaining({ sceneAssetId: 90, sceneKey: 'sc1' }),
    );
    expect(requestClient.post).toHaveBeenNthCalledWith(
      2,
      '/toonflow/production/sceneConsistency/saveState',
      expect.objectContaining({ sceneMasterId: 7, stateKey: 'door_broken' }),
    );
  });
});

describe('toonflow novel api', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads only the requested novel page', async () => {
    requestClient.post.mockResolvedValue({ data: [], total: 42 });

    await getNovelPage(12, 3, 10);

    expect(requestClient.post).toHaveBeenCalledWith(
      '/toonflow/novel/getNovel',
      { limit: 10, page: 3, projectId: 12 },
    );
  });

  it('does not request a page for an invalid project id', async () => {
    await expect(getNovelPage(Number.NaN)).resolves.toEqual({
      data: [],
      total: 0,
    });
    expect(requestClient.post).not.toHaveBeenCalled();
  });
});

describe('toonflow video transition api', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('persists the structured transition and frame-source settings', async () => {
    requestClient.post.mockResolvedValue(undefined);

    await updateVideoTransitionSettings({
      framePolicy: 'previous_tail',
      id: 23,
      previousTrackId: 22,
      transitionType: 'action_bridge',
    });

    expect(requestClient.post).toHaveBeenCalledWith(
      '/production/workbench/updateVideoTransitionSettings',
      {
        framePolicy: 'previous_tail',
        id: 23,
        previousTrackId: 22,
        transitionType: 'action_bridge',
      },
    );
  });
});

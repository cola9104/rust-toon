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
  setEpisodeRenderCurrent,
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

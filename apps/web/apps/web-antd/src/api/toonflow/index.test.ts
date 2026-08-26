import { beforeEach, describe, expect, it, vi } from 'vitest';

const requestClient = vi.hoisted(() => ({
  get: vi.fn(),
  request: vi.fn(),
}));

vi.mock('#/api/request', () => ({ requestClient }));

import {
  getEpisodeRenders,
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

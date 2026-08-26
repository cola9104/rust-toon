import type { ToonflowApi } from '#/api/toonflow';

import { describe, expect, it } from 'vitest';

import {
  orderedEpisodeRenders,
  presentEpisodeArchive,
  renderVersionLabel,
} from './video-archive';

function render(
  id: number,
  version: number,
  isCurrent = false,
): ToonflowApi.EpisodeRender {
  return {
    createdAt: `2026-08-0${version}T00:00:00Z`,
    createdBy: '00000000-0000-0000-0000-000000000001',
    filePath: `episode-${id}.mp4`,
    id,
    isCurrent,
    metadata: {},
    objectPath: `episode-${id}.mp4`,
    projectId: 1,
    scriptId: 10,
    sourceVideoIds: [],
    state: 'completed',
    updatedAt: `2026-08-0${version}T00:00:00Z`,
    url: `/episode-${id}.mp4`,
    version,
  };
}

describe('video archive presentation', () => {
  it('features an older current render without labeling it as latest', () => {
    const episode = presentEpisodeArchive({
      episodeNo: 3,
      renders: [render(1, 1, true), render(3, 3), render(2, 2)],
      scriptId: 30,
      scriptName: '第 3 集',
    });

    expect(episode.featured?.id).toBe(1);
    expect(episode.featuredIsLatest).toBe(false);
    expect(episode.current?.id).toBe(1);
    expect(episode.latest?.id).toBe(3);
    expect(episode.history.map((item) => item.id)).toEqual([3, 2]);
    expect(
      episode.history.find((item) => item.id === episode.latest?.id)?.id,
    ).toBe(3);
  });

  it('uses the latest render when no current version is selected', () => {
    const source = [render(1, 1), render(2, 2)];
    const episode = presentEpisodeArchive({
      episodeNo: 1,
      renders: source,
      scriptId: 10,
      scriptName: '第 1 集',
    });

    expect(episode.featured?.id).toBe(2);
    expect(episode.featuredIsLatest).toBe(true);
    expect(orderedEpisodeRenders(source).map((item) => item.id)).toEqual([
      2, 1,
    ]);
    expect(source.map((item) => item.id)).toEqual([1, 2]);
    expect(renderVersionLabel(source[0]!)).toBe('V1');
  });
});

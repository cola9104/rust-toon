import type { ToonflowApi } from '#/api/toonflow';

function renderTime(render: ToonflowApi.EpisodeRender) {
  const value = render.updatedAt || render.createdAt;
  if (typeof value === 'number') return value;
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

export function orderedEpisodeRenders(renders: ToonflowApi.EpisodeRender[]) {
  return [...renders].sort(
    (left, right) =>
      right.version - left.version ||
      renderTime(right) - renderTime(left) ||
      right.id - left.id,
  );
}

export function presentEpisodeArchive(
  episode: ToonflowApi.VideoArchiveEpisode,
) {
  const renders = orderedEpisodeRenders(episode.renders);
  const current = renders.find((render) => render.isCurrent);
  const latest = renders[0];
  const featured = current ?? latest;
  const featuredIsLatest = Boolean(
    featured && latest && featured.id === latest.id,
  );

  return {
    ...episode,
    current,
    featured,
    featuredIsLatest,
    history: featured
      ? renders.filter((render) => render.id !== featured.id)
      : renders,
    latest,
    renders,
  };
}

export function renderVersionLabel(render: ToonflowApi.EpisodeRender) {
  return `V${Math.max(1, render.version)}`;
}

import type { PlannedScene } from './scene-consistency-planning';

import type { ToonflowApi } from '#/api/toonflow';

export interface SceneConsistencyIssues {
  missingMasters: number;
  staleStoryboards: number;
  unboundStoryboards: number;
}

export interface SceneStateTimelineCandidate {
  id?: number;
  sceneKey?: string;
  sceneStateId?: number;
}

export interface SceneStateTimelineViolation {
  earlierStateName: string;
  laterStateName: string;
  sceneKey: string;
}

export interface SceneKeyOption {
  label: string;
  value: string;
}

const SCENE_KEY_PATTERN = /^sc[1-9]\d*$/;

export function normalizeSceneKey(value?: string) {
  return (value ?? '').trim().toLowerCase();
}

export function isValidSceneKey(value?: string) {
  return SCENE_KEY_PATTERN.test(normalizeSceneKey(value));
}

/**
 * Builds the scene picker exclusively from the director plan. Persisted
 * masters neither add scenes nor rename what the director planned.
 */
export function buildSceneKeyOptions(
  plannedScenes: PlannedScene[],
): SceneKeyOption[] {
  const seen = new Set<string>();
  return plannedScenes
    .map((plannedScene) => ({
      ...plannedScene,
      sceneKey: normalizeSceneKey(plannedScene.sceneKey),
    }))
    .filter(({ sceneKey }) => {
      if (!isValidSceneKey(sceneKey) || seen.has(sceneKey)) return false;
      seen.add(sceneKey);
      return true;
    })
    .map(({ name, sceneKey: value }) => {
      const displayName = name.trim();
      return {
        label: `${value.toUpperCase()}${displayName ? ` · ${displayName}` : ''}`,
        value,
      };
    });
}

export function sceneMasterForKey(
  catalog: ToonflowApi.SceneConsistencyCatalog | undefined,
  sceneKey?: string,
) {
  const key = normalizeSceneKey(sceneKey);
  return catalog?.scenes.find((scene) => scene.sceneKey === key);
}

export function sceneStateOptions(
  catalog: ToonflowApi.SceneConsistencyCatalog | undefined,
  sceneKey?: string,
) {
  const master = sceneMasterForKey(catalog, sceneKey);
  return (master?.states ?? []).map((state) => ({
    label: `${state.sequence === 0 ? 'S0' : `S${state.sequence}`} · ${state.name}`,
    value: state.id,
  }));
}

export function defaultSceneStateId(
  catalog: ToonflowApi.SceneConsistencyCatalog | undefined,
  sceneKey?: string,
) {
  const states = sceneMasterForKey(catalog, sceneKey)?.states ?? [];
  return (
    states.find((state) => state.stateKey === 'base')?.id ??
    (states.length === 1 ? states[0]?.id : undefined)
  );
}

export function isStateValidForScene(
  catalog: ToonflowApi.SceneConsistencyCatalog | undefined,
  sceneKey: string | undefined,
  stateId: number | undefined,
) {
  if (!stateId) return false;
  return (
    sceneMasterForKey(catalog, sceneKey)?.states.some(
      (state) => state.id === stateId,
    ) ?? false
  );
}

function isSameOrDescendantState(
  states: ToonflowApi.SceneState[],
  descendantStateId: number,
  ancestorStateId: number,
) {
  const statesById = new Map(states.map((state) => [state.id, state]));
  const visited = new Set<number>();
  let currentStateId: number | undefined = descendantStateId;
  while (currentStateId !== undefined && !visited.has(currentStateId)) {
    if (currentStateId === ancestorStateId) return true;
    visited.add(currentStateId);
    currentStateId = statesById.get(currentStateId)?.parentStateId;
  }
  return false;
}

/**
 * Checks only the two same-scene boundaries touched by one storyboard save. A lasting physical
 * change must keep using the same state or move to a descendant; returning to base/another branch
 * would silently repair or replace established objects.
 */
export function sceneStateTimelineViolation(
  catalog: ToonflowApi.SceneConsistencyCatalog | undefined,
  storyboards: ToonflowApi.Storyboard[],
  candidate: SceneStateTimelineCandidate,
  insertAfterStoryboardId?: number,
): SceneStateTimelineViolation | undefined {
  const sceneKey = normalizeSceneKey(candidate.sceneKey);
  const sceneStateId = candidate.sceneStateId;
  const master = sceneMasterForKey(catalog, sceneKey);
  if (!sceneKey || !sceneStateId || !master) return undefined;

  const candidateEntry = { ...candidate, sceneKey, sceneStateId };
  const existingIndex = candidate.id
    ? storyboards.findIndex((storyboard) => storyboard.id === candidate.id)
    : -1;
  const ordered = storyboards.filter(
    (storyboard) =>
      candidate.id === undefined || storyboard.id !== candidate.id,
  );
  const insertAfterIndex = insertAfterStoryboardId
    ? ordered.findIndex(
        (storyboard) => storyboard.id === insertAfterStoryboardId,
      )
    : -1;
  const insertionIndex =
    existingIndex >= 0
      ? Math.min(existingIndex, ordered.length)
      : insertAfterIndex >= 0
        ? insertAfterIndex + 1
        : ordered.length;
  ordered.splice(insertionIndex, 0, candidateEntry as ToonflowApi.Storyboard);

  const sameScene = ordered.filter(
    (storyboard) => normalizeSceneKey(storyboard.sceneKey) === sceneKey,
  );
  const candidateIndex = sameScene.indexOf(
    candidateEntry as ToonflowApi.Storyboard,
  );
  const boundaries = [
    [sameScene[candidateIndex - 1], candidateEntry],
    [candidateEntry, sameScene[candidateIndex + 1]],
  ] as const;
  const statesById = new Map(master.states.map((state) => [state.id, state]));

  for (const [earlier, later] of boundaries) {
    const earlierStateId = earlier?.sceneStateId;
    const laterStateId = later?.sceneStateId;
    if (!earlierStateId || !laterStateId) continue;
    const earlierState = statesById.get(earlierStateId);
    const laterState = statesById.get(laterStateId);
    if (!earlierState || !laterState) continue;
    if (!isSameOrDescendantState(master.states, laterStateId, earlierStateId)) {
      return {
        earlierStateName: earlierState.name || earlierState.stateKey,
        laterStateName: laterState.name || laterState.stateKey,
        sceneKey,
      };
    }
  }
  return undefined;
}

export function sceneConsistencyIssues(
  catalog: ToonflowApi.SceneConsistencyCatalog | undefined,
  storyboards: ToonflowApi.Storyboard[],
): SceneConsistencyIssues {
  const usedSceneKeys = new Set(
    storyboards
      .map((storyboard) => normalizeSceneKey(storyboard.sceneKey))
      .filter(Boolean),
  );
  let missingMasters = 0;
  for (const sceneKey of usedSceneKeys) {
    const master = sceneMasterForKey(catalog, sceneKey);
    if (!master || master.status !== 'ready') missingMasters += 1;
  }
  return {
    missingMasters,
    staleStoryboards: storyboards.filter(
      (storyboard) => storyboard.sceneConsistencyStatus === 'stale',
    ).length,
    unboundStoryboards: storyboards.filter((storyboard) => {
      return (
        !storyboard.sceneKey ||
        !storyboard.sceneStateId ||
        ['missing_master', 'missing_scene_key', 'unconfigured'].includes(
          storyboard.sceneConsistencyStatus ?? 'unconfigured',
        )
      );
    }).length,
  };
}

export function sceneConsistencyStatusLabel(
  status?: ToonflowApi.Storyboard['sceneConsistencyStatus'],
) {
  const labels: Record<string, string> = {
    missing_master: '母版未就绪',
    missing_scene_key: '缺少场次',
    ready: '场景已锁定',
    stale: '状态已变更，需重生',
    unconfigured: '未绑定状态',
  };
  return labels[status ?? 'unconfigured'] ?? '未绑定状态';
}

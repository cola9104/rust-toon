import {
  groupStoryboardsByTrack,
  sortStoryboards,
  type StoryboardTrackGroup,
  type StoryboardTrackItem,
} from './storyboard-track-groups';

export interface StoryboardSceneItem extends StoryboardTrackItem {
  prompt?: null | string;
  videoDesc?: null | string;
}

export interface StoryboardSceneGroup<
  T extends StoryboardSceneItem = StoryboardSceneItem,
> {
  items: T[];
  key: string;
  name: string;
  tracks: StoryboardTrackGroup<T>[];
}

interface StoryboardSceneDefinition {
  key: string;
  name: string;
  order: number;
  title: string;
  visuals: string[];
}

function normalizeSceneText(value: string) {
  return value
    .normalize('NFKC')
    .toLocaleLowerCase()
    .replace(/[\s·•:：|｜，,。；;（）()[\]【】_'“”‘’"-]/gu, '');
}

function markdownCells(line: string) {
  const source = line.trim().replace(/^\|/u, '').replace(/\|$/u, '');
  const cells: string[] = [];
  let cell = '';
  for (let index = 0; index < source.length; index += 1) {
    const character = source[index];
    if (character === '\\' && source[index + 1] === '|') {
      cell += '|';
      index += 1;
    } else if (character === '|') {
      cells.push(cell.trim());
      cell = '';
    } else {
      cell += character;
    }
  }
  cells.push(cell.trim());
  return cells;
}

function parseSceneDefinitions(storyboardPlan: string) {
  const scenes: StoryboardSceneDefinition[] = [];
  let current: StoryboardSceneDefinition | undefined;

  for (const rawLine of storyboardPlan.split(/\r?\n/u)) {
    const line = rawLine.trim();
    const header = line.match(
      /^##\s*场\s*([0-9一二三四五六七八九十百]+)\s*[：:]\s*(.+)$/u,
    );
    if (header) {
      const sceneNumber = header[1]!;
      const title = header[2]!
        .replace(/\s*[|｜]\s*参演角色[：:].*$/u, '')
        .trim();
      current = {
        key: `scene:${scenes.length}:${sceneNumber}`,
        name: `场${sceneNumber} · ${title}`,
        order: scenes.length,
        title,
        visuals: [],
      };
      scenes.push(current);
      continue;
    }

    if (!current || !line.startsWith('|')) continue;
    const cells = markdownCells(line);
    if (!/^\d+$/u.test(cells[0] || '') || !cells[1]) continue;
    current.visuals.push(cells[1]);
  }

  return scenes;
}

function storyboardDescription(item: StoryboardSceneItem) {
  return [item.videoDesc, item.prompt].filter(Boolean).join('\n');
}

function storyboardSceneName(item: StoryboardSceneItem) {
  const description = storyboardDescription(item);
  const explicit = description.match(/场景\s*[：:]\s*([^；;|\n]+)/u)?.[1];
  if (explicit) return explicit.trim().replace(/[。，,.]+$/u, '');

  const structured = description.trim().match(/^[（(]([^）)]+)[）)]/u)?.[1];
  const fields = structured?.split('、').map((field) => field.trim());
  return fields && fields.length >= 2 ? fields[1] : undefined;
}

function matchingDefinition(
  item: StoryboardSceneItem,
  definitions: StoryboardSceneDefinition[],
) {
  const description = storyboardDescription(item);
  const visualMatch = definitions.find((definition) =>
    definition.visuals.some(
      (visual) => visual.length >= 4 && description.includes(visual),
    ),
  );
  if (visualMatch) return visualMatch;

  const sceneName = storyboardSceneName(item);
  if (!sceneName) return undefined;
  const normalizedName = normalizeSceneText(sceneName);
  if (!normalizedName) return undefined;
  const matches = definitions.filter((definition) => {
    const normalizedTitle = normalizeSceneText(definition.title);
    return (
      normalizedTitle.includes(normalizedName) ||
      normalizedName.includes(normalizedTitle)
    );
  });
  return matches.length === 1 ? matches[0] : undefined;
}

export function groupStoryboardsBySceneAndTrack<T extends StoryboardSceneItem>(
  items: T[],
  storyboardPlan = '',
): StoryboardSceneGroup<T>[] {
  const definitions = parseSceneDefinitions(storyboardPlan);
  const groups = new Map<
    string,
    Omit<StoryboardSceneGroup<T>, 'tracks'> & { order: number }
  >();
  const unknownSceneOrders = new Map<string, number>();

  for (const item of sortStoryboards(items)) {
    const definition = matchingDefinition(item, definitions);
    const explicitSceneName = storyboardSceneName(item);
    const normalizedSceneName = explicitSceneName
      ? normalizeSceneText(explicitSceneName)
      : '';
    const fallbackKey = normalizedSceneName
      ? `scene-name:${normalizedSceneName}`
      : 'scene:unassigned';
    const key = definition?.key || fallbackKey;
    let group = groups.get(key);
    if (!group) {
      let order = definition?.order;
      if (order === undefined) {
        if (!unknownSceneOrders.has(key)) {
          unknownSceneOrders.set(key, unknownSceneOrders.size);
        }
        order = definitions.length + unknownSceneOrders.get(key)!;
      }
      const fallbackNumber = definitions.length + unknownSceneOrders.size;
      group = {
        items: [],
        key,
        name:
          definition?.name ||
          (explicitSceneName
            ? `场${fallbackNumber} · ${explicitSceneName}`
            : '未分场'),
        order,
      };
      groups.set(key, group);
    }
    group.items.push(item);
  }

  return [...groups.values()]
    .sort((left, right) => left.order - right.order)
    .map(({ order: _order, ...group }) => ({
      ...group,
      tracks: groupStoryboardsByTrack(group.items, { preserveOrder: true }),
    }));
}

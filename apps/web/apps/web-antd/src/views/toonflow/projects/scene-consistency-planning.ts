export type PlannedSceneAssetMatch = 'ambiguous' | 'missing' | 'unique';

export interface PlannedScene {
  assetMatch: PlannedSceneAssetMatch;
  defaultSceneAssetId?: number;
  name: string;
  order: number;
  sceneKey: string;
}

interface SceneAssetCandidate {
  id: number;
  type?: null | string;
}

interface DirectorScene {
  name: string;
  order: number;
  sceneKey: string;
}

function markdownCells(line: string) {
  const source = line
    .trim()
    .replace(/^[|｜]/u, '')
    .replace(/[|｜]$/u, '');
  const cells: string[] = [];
  let cell = '';

  for (let index = 0; index < source.length; index += 1) {
    const character = source[index];
    const nextCharacter = source[index + 1];
    if (character === '\\' && nextCharacter === '|') {
      cell += '|';
      index += 1;
    } else if (character === '|' || character === '｜') {
      cells.push(cell.trim());
      cell = '';
    } else {
      cell += character;
    }
  }
  cells.push(cell.trim());
  return cells;
}

function plainMarkdown(value: string) {
  let result = value.normalize('NFKC').trim();
  for (const marker of ['**', '__', '~~', '`']) {
    if (result.startsWith(marker) && result.endsWith(marker)) {
      result = result.slice(marker.length, -marker.length).trim();
    }
  }
  return result;
}

function normalizedLabel(value: string) {
  return plainMarkdown(value)
    .toLocaleLowerCase()
    .replace(/[\s:：_\-—–·.、]/gu, '');
}

function canonicalSceneKey(value: string) {
  const compact = plainMarkdown(value).toLocaleLowerCase().replace(/\s+/gu, '');
  const match = compact.match(/^(?:scene|sc|场景|场|第)?0*(\d+)(?:场)?$/u);
  if (!match) return undefined;
  const number = Number(match[1]);
  return Number.isSafeInteger(number) && number > 0 ? `sc${number}` : undefined;
}

function isSeparatorRow(cells: string[]) {
  return cells.every((cell) => /^\s*:?-+:?\s*$/u.test(cell));
}

function directorTableColumns(cells: string[]) {
  const labels = cells.map(normalizedLabel);
  const sceneKeyColumn = labels.findIndex((label) =>
    ['sc', 'scene', 'sceneid', '场次', '场次编号'].includes(label),
  );
  const nameColumn = labels.findIndex((label) =>
    ['场名', '场景', '场景名', '场景名称'].includes(label),
  );
  return sceneKeyColumn >= 0 && nameColumn >= 0
    ? { nameColumn, sceneKeyColumn }
    : undefined;
}

function parseDirectorScenes(scriptPlan: string) {
  const scenes: DirectorScene[] = [];
  const seen = new Set<string>();
  let columns: ReturnType<typeof directorTableColumns>;

  for (const rawLine of scriptPlan.split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (!line.includes('|') && !line.includes('｜')) {
      if (line) columns = undefined;
      continue;
    }

    const cells = markdownCells(line);
    const discoveredColumns = directorTableColumns(cells);
    if (discoveredColumns) {
      columns = discoveredColumns;
      continue;
    }
    if (!columns || isSeparatorRow(cells)) continue;

    const sceneKey = canonicalSceneKey(cells[columns.sceneKeyColumn] ?? '');
    if (!sceneKey || seen.has(sceneKey)) continue;
    seen.add(sceneKey);
    scenes.push({
      name: plainMarkdown(cells[columns.nameColumn] ?? ''),
      order: scenes.length,
      sceneKey,
    });
  }
  return scenes;
}

function sceneKeyFromHeading(line: string) {
  const heading = line
    .normalize('NFKC')
    .trim()
    .match(/^(#{2,6})\s*(.*?)\s*#*$/u);
  if (!heading?.[2]) return undefined;

  const match = plainMarkdown(heading[2]).match(
    /^(?:scene|sc|场景|场|第)\s*0*(\d+)\s*(?:场)?(?=\s*(?:$|[:：|｜.、·\-—–]))/iu,
  );
  if (!match) return undefined;
  const number = Number(match[1]);
  return Number.isSafeInteger(number) && number > 0 ? `sc${number}` : undefined;
}

function positiveIds(value: string) {
  return [...value.normalize('NFKC').matchAll(/\d+/gu)]
    .map((match) => Number(match[0]))
    .filter((id) => Number.isSafeInteger(id) && id > 0);
}

function referenceText(line: string) {
  const match = line
    .normalize('NFKC')
    .match(/引用资产\s*id\s*\**\s*[:：]?\s*(.*)$/iu);
  return match?.[1];
}

function parseStoryboardSceneAssetIds(storyboardTable: string) {
  const sceneAssetIds = new Map<string, Set<number>>();
  let currentSceneKey: string | undefined;
  let referenceColumn: number | undefined;

  for (const rawLine of storyboardTable.split(/\r?\n/u)) {
    const line = rawLine.trim();
    const headingMatch = line.match(/^(#{2,6})\s*/u);
    if (headingMatch) {
      const sceneKey = sceneKeyFromHeading(line);
      if (sceneKey) {
        currentSceneKey = sceneKey;
        if (!sceneAssetIds.has(sceneKey))
          sceneAssetIds.set(sceneKey, new Set());
        referenceColumn = undefined;
      } else if (headingMatch[1]?.length === 2) {
        currentSceneKey = undefined;
        referenceColumn = undefined;
      }
      continue;
    }
    if (!currentSceneKey) continue;

    if (line.includes('|') || line.includes('｜')) {
      const cells = markdownCells(line);
      const discoveredColumn = cells.findIndex((cell) =>
        normalizedLabel(cell).includes('引用资产id'),
      );
      if (discoveredColumn >= 0) {
        referenceColumn = discoveredColumn;
        continue;
      }
      if (referenceColumn !== undefined && !isSeparatorRow(cells)) {
        for (const id of positiveIds(cells[referenceColumn] ?? '')) {
          sceneAssetIds.get(currentSceneKey)?.add(id);
        }
        continue;
      }
    }

    const referenced = referenceText(line);
    if (!referenced) continue;
    for (const id of positiveIds(referenced)) {
      sceneAssetIds.get(currentSceneKey)?.add(id);
    }
  }
  return sceneAssetIds;
}

/**
 * Builds the scene-consistency picker from deterministic production data.
 * The director table exclusively owns scene membership, names, and order;
 * storyboard references can only supply a default scene asset for those rows.
 */
export function buildPlannedScenes(
  scriptPlan: string,
  storyboardTable: string,
  assets: readonly SceneAssetCandidate[],
): PlannedScene[] {
  const directorScenes = parseDirectorScenes(scriptPlan);
  const referencesByScene = parseStoryboardSceneAssetIds(storyboardTable);
  const availableSceneAssetIds = new Set(
    assets
      .filter((asset) => asset.type === 'scene')
      .map((asset) => asset.id)
      .filter((id) => Number.isSafeInteger(id) && id > 0),
  );

  return directorScenes.map((scene) => {
    const matchingAssetIds = [
      ...(referencesByScene.get(scene.sceneKey) ?? []),
    ].filter((id) => availableSceneAssetIds.has(id));

    if (matchingAssetIds.length === 1) {
      return {
        ...scene,
        assetMatch: 'unique',
        defaultSceneAssetId: matchingAssetIds[0],
      };
    }
    return {
      ...scene,
      assetMatch: matchingAssetIds.length === 0 ? 'missing' : 'ambiguous',
    };
  });
}

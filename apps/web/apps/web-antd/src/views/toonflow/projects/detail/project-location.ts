export interface ProjectLocation {
  stage: string;
  scriptId?: number;
  nodes: Record<string, string>;
}
const stages = new Set(['novel', 'script-agent', 'script', 'production', 'archive']);
function positiveId(value: unknown) { const id = Number(value); return Number.isSafeInteger(id) && id > 0 ? id : undefined; }

export function createProjectLocationStore(userId: string, storage: Pick<Storage, 'getItem' | 'setItem'>) {
  const key = (projectId: number) => `toonflow:location:v1:${encodeURIComponent(userId)}:${projectId}`;
  function read(projectId: number): ProjectLocation {
    try {
      const value = JSON.parse(storage.getItem(key(projectId)) ?? '{}');
      const nodes = Object.fromEntries(Object.entries(value.nodes ?? {}).filter(([id, node]) => positiveId(id) && typeof node === 'string' && node.length < 200)) as Record<string, string>;
      return { stage: stages.has(value.stage) ? value.stage : 'novel', scriptId: positiveId(value.scriptId), nodes };
    } catch { return { stage: 'novel', nodes: {} }; }
  }
  function write(projectId: number, location: ProjectLocation) {
    try { if (positiveId(projectId)) storage.setItem(key(projectId), JSON.stringify(location)); } catch { /* Storage may be full or disabled; navigation still works. */ }
  }
  return { read, write };
}

export function resolveProjectScript(ids: number[], savedId?: number, requestedId?: unknown) {
  const requested = positiveId(requestedId);
  return (requested && ids.includes(requested) ? requested : undefined)
    ?? (savedId && ids.includes(savedId) ? savedId : undefined) ?? ids[0];
}

import type { ToonflowApi } from '#/api/toonflow';
import { computed, ref } from 'vue';
import { updateAgentDeployment } from '#/api/toonflow';

function fields(row: ToonflowApi.AgentDeployment) {
  return { id: row.id, modelConfigId: row.modelConfigId, temperature: row.temperature,
    maxOutputTokens: row.maxOutputTokens, disabled: row.disabled,
    promptSourceKey: row.promptSourceKey ?? '', memoryScope: row.memoryScope };
}

export function useDeploymentDrafts() {
  const agents = ref<ToonflowApi.AgentDeployment[]>([]);
  const baseline = ref<Record<number, ToonflowApi.AgentDeployment>>({});
  const saving = ref(false);
  const changedRows = computed(() => agents.value.filter((row) =>
    JSON.stringify(fields(row)) !== JSON.stringify(fields(baseline.value[row.id] ?? row))));
  function replace(rows: ToonflowApi.AgentDeployment[]) {
    agents.value = rows.map((row) => ({ ...row }));
    baseline.value = Object.fromEntries(rows.map((row) => [row.id, { ...row }]));
  }
  function undo() {
    if (saving.value) return;
    agents.value = agents.value.map((row) => ({ ...(baseline.value[row.id] ?? row) }));
  }
  async function save() {
    if (saving.value) return { saved: 0, failed: 0 };
    const snapshots = changedRows.value.map((row) => ({ ...row }));
    saving.value = true;
    try {
      const results = await Promise.allSettled(snapshots.map((row) => updateAgentDeployment(fields(row))));
      let saved = 0;
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          const row = snapshots[index]!;
          baseline.value[row.id] = row;
          saved += 1;
        }
      });
      // Advance only the successfully saved snapshots: edits made while saving remain dirty.
      return { saved, failed: snapshots.length - saved };
    } finally { saving.value = false; }
  }
  return { agents, saving, changedRows, replace, undo, save };
}

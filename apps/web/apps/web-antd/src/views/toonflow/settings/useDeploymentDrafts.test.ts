import type { ToonflowApi } from '#/api/toonflow';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { useDeploymentDrafts } from './useDeploymentDrafts';
const { update } = vi.hoisted(() => ({ update: vi.fn() }));
vi.mock('#/api/toonflow', () => ({ updateAgentDeployment: update }));
const rows = () => [1, 2].map((id) => ({ id, modelConfigId: id, temperature: 1, promptSourceKey: 'original', memoryScope: 'project', disabled: false }) as ToonflowApi.AgentDeployment);
beforeEach(() => update.mockReset());
describe('configuration drafts', () => {
  it('counts runtime and model edits once per Agent and undoes them locally', () => {
    const drafts = useDeploymentDrafts(); drafts.replace(rows());
    drafts.agents.value[0]!.temperature = 0.4; drafts.agents.value[0]!.memoryScope = 'script';
    drafts.agents.value[1]!.promptSourceKey = 'new';
    expect(drafts.changedRows.value).toHaveLength(2); drafts.undo();
    expect(drafts.changedRows.value).toHaveLength(0); expect(drafts.agents.value).toEqual(rows()); expect(update).not.toHaveBeenCalled();
  });
  it('retains failed rows and retries only the changes that were not saved', async () => {
    const drafts = useDeploymentDrafts(); drafts.replace(rows());
    drafts.agents.value.forEach((row) => { row.temperature = 0.2; });
    update.mockResolvedValueOnce({}).mockRejectedValueOnce(new Error('offline'));
    expect(await drafts.save()).toEqual({ saved: 1, failed: 1 });
    expect(drafts.changedRows.value.map((row) => row.id)).toEqual([2]);
    update.mockResolvedValueOnce({}); await drafts.save(); expect(drafts.changedRows.value).toHaveLength(0);
  });
  it('does not discard edits made while a save is in flight', async () => {
    let finish!: () => void; update.mockReturnValue(new Promise<void>((resolve) => { finish = resolve; }));
    const drafts = useDeploymentDrafts(); drafts.replace(rows()); drafts.agents.value[0]!.temperature = 0.2;
    const pending = drafts.save(); drafts.agents.value[0]!.temperature = 0.7;
    finish(); await pending;
    expect(drafts.changedRows.value).toHaveLength(1); expect(drafts.agents.value[0]!.temperature).toBe(0.7);
    drafts.undo(); expect(drafts.agents.value[0]!.temperature).toBe(0.2);
  });
  it('sends an explicit empty override when clearing a Prompt', async () => {
    const drafts = useDeploymentDrafts(); drafts.replace(rows()); drafts.agents.value[0]!.promptSourceKey = undefined;
    update.mockResolvedValue({}); await drafts.save();
    expect(update).toHaveBeenCalledWith(expect.objectContaining({ promptSourceKey: '' }));
  });
});

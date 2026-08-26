import { describe, expect, it, vi } from 'vitest';

import { requestProductionScriptSwitch } from './production-script-switch';

describe('production script switch', () => {
  it('defers a script change until a running Agent switch is confirmed', () => {
    let approve: undefined | (() => void);
    let currentScriptId = 1;
    const onCommit = vi.fn((scriptId: number) => {
      currentScriptId = scriptId;
    });

    requestProductionScriptSwitch({
      confirm: (commit) => {
        approve = commit;
      },
      getCurrentScriptId: () => currentScriptId,
      messages: [{ status: 'streaming' }],
      onCommit,
      targetScriptId: 2,
    });

    expect(onCommit).not.toHaveBeenCalled();
    expect(currentScriptId).toBe(1);

    approve?.();

    expect(onCommit).toHaveBeenCalledWith(2, true);
    expect(currentScriptId).toBe(2);
  });

  it('commits immediately when no Agent is running', () => {
    const confirm = vi.fn();
    const onCommit = vi.fn();

    requestProductionScriptSwitch({
      confirm,
      getCurrentScriptId: () => 1,
      messages: [{ status: 'completed' }],
      onCommit,
      targetScriptId: 2,
    });

    expect(confirm).not.toHaveBeenCalled();
    expect(onCommit).toHaveBeenCalledWith(2, true);
  });

  it('reopens the current script without an unnecessary confirmation', () => {
    const confirm = vi.fn();
    const onCommit = vi.fn();

    requestProductionScriptSwitch({
      confirm,
      getCurrentScriptId: () => 2,
      messages: [{ status: 'pending' }],
      onCommit,
      targetScriptId: 2,
    });

    expect(confirm).not.toHaveBeenCalled();
    expect(onCommit).toHaveBeenCalledWith(2, false);
  });
});

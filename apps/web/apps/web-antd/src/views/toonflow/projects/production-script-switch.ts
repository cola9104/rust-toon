interface ProductionAgentMessage {
  status?: string;
}

interface ProductionScriptSwitchOptions {
  confirm: (commit: () => void) => void;
  getCurrentScriptId: () => number | undefined;
  messages: readonly ProductionAgentMessage[];
  onCommit: (scriptId: number, scriptChanged: boolean) => void;
  targetScriptId: number;
}

export function requestProductionScriptSwitch({
  confirm,
  getCurrentScriptId,
  messages,
  onCommit,
  targetScriptId,
}: ProductionScriptSwitchOptions) {
  const commit = () => {
    onCommit(targetScriptId, getCurrentScriptId() !== targetScriptId);
  };
  const scriptChanged = getCurrentScriptId() !== targetScriptId;
  const agentRunning = messages.some(
    ({ status }) => status === 'pending' || status === 'streaming',
  );

  if (scriptChanged && agentRunning) {
    confirm(commit);
    return;
  }
  commit();
}

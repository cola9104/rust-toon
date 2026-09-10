import { describe, expect, it } from 'vitest';

import { useAgentChatRun } from './agent-chat-run';

describe('Agent send/stop state', () => {
  it('keeps the welcome message and history idle', () => {
    const run = useAgentChatRun();
    run.message('welcome', 'assistant');
    expect(run.active.value).toBe(false);
    run.update('welcome', 'complete');
    run.message('history', 'assistant');
    run.update('history', 'pending');
    expect(run.active.value).toBe(false);
  });

  it.each(['complete', 'error', 'canceled', 'interrupted'])(
    'restores send when the actual reply becomes %s', (status) => {
      const run = useAgentChatRun();
      run.begin();
      // A welcome frame can still arrive just after sending.
      run.message('welcome', 'assistant');
      run.update('welcome', 'complete');
      expect(run.active.value).toBe(true);
      run.message('user', 'user');
      run.update('user', 'complete');
      run.message('reply', 'assistant');
      run.message('sub-agent', 'assistant');
      run.update('sub-agent', 'complete');
      expect(run.active.value).toBe(true);
      run.update('reply', status);
      expect(run.active.value).toBe(false);
    },
  );

  it('clears execution on disconnect or project switch', () => {
    const run = useAgentChatRun();
    run.begin();
    run.message('user', 'user');
    run.message('reply', 'assistant');
    run.reset();
    run.update('reply', 'streaming');
    expect(run.active.value).toBe(false);
  });

  it('stops immediately and only resumes for a new submission', () => {
    const run = useAgentChatRun();
    run.begin();
    run.message('user-1', 'user');
    run.message('reply-1', 'assistant');
    run.reset();
    expect(run.active.value).toBe(false);
    run.update('reply-1', 'streaming');
    expect(run.active.value).toBe(false);
    run.begin();
    run.message('user-2', 'user');
    run.message('reply-2', 'assistant');
    run.update('reply-1', 'canceled');
    expect(run.active.value).toBe(true);
    run.update('reply-2', 'complete');
    expect(run.active.value).toBe(false);
  });
});

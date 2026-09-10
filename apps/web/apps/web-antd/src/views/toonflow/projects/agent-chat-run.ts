import { ref } from 'vue';

// Welcome/history messages are not executions. Track only the root reply to
// a request submitted through this socket; sub-agent replies cannot end it.
export function useAgentChatRun() {
  const active = ref(false);
  let replyId: string | undefined;
  let receivedUserMessage = false;
  return {
    active,
    begin() {
      replyId = undefined;
      receivedUserMessage = false;
      active.value = true;
    },
    message(id: string, role: string) {
      if (!active.value) return;
      if (role === 'user') receivedUserMessage = true;
      if (receivedUserMessage && !replyId && role === 'assistant') replyId = id;
    },
    update(id: string, status: string) {
      if (id === replyId && ['complete', 'error', 'canceled', 'interrupted'].includes(status)) {
        replyId = undefined;
        active.value = false;
      }
    },
    reset() {
      replyId = undefined;
      receivedUserMessage = false;
      active.value = false;
    },
  };
}

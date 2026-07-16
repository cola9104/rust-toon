ALTER TABLE ai.chat_conversations
    ADD COLUMN IF NOT EXISTS knowledge_ids BIGINT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_ai_chat_conversation_knowledge_ids
    ON ai.chat_conversations USING GIN (knowledge_ids);

CREATE SCHEMA IF NOT EXISTS ai;

CREATE TABLE IF NOT EXISTS ai.chat_conversations (
    id BIGINT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    pinned BOOLEAN NOT NULL DEFAULT FALSE,
    role_id BIGINT,
    model_id BIGINT NOT NULL REFERENCES ai.model_configs(id),
    temperature DOUBLE PRECISION NOT NULL DEFAULT 0.7,
    max_tokens INTEGER NOT NULL DEFAULT 4096,
    max_contexts INTEGER NOT NULL DEFAULT 20,
    system_message TEXT,
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ai_chat_conversation_user ON ai.chat_conversations(user_id, pinned DESC, update_time DESC);

CREATE TABLE IF NOT EXISTS ai.chat_messages (
    id BIGINT PRIMARY KEY,
    conversation_id BIGINT NOT NULL REFERENCES ai.chat_conversations(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('system','user','assistant','tool')),
    model_id BIGINT REFERENCES ai.model_configs(id),
    content TEXT NOT NULL DEFAULT '',
    reasoning_content TEXT,
    tokens INTEGER NOT NULL DEFAULT 0,
    segment_ids BIGINT[] NOT NULL DEFAULT '{}',
    attachment_urls TEXT[] NOT NULL DEFAULT '{}',
    tool_calls JSONB NOT NULL DEFAULT '[]',
    create_time BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ai_chat_message_conversation ON ai.chat_messages(conversation_id, id);

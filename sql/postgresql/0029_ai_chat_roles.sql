CREATE TABLE IF NOT EXISTS ai.chat_roles (
    id BIGINT PRIMARY KEY,
    user_id TEXT,
    model_id BIGINT NOT NULL REFERENCES ai.model_configs(id),
    name TEXT NOT NULL,
    avatar TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT '通用',
    sort INTEGER NOT NULL DEFAULT 0,
    description TEXT NOT NULL DEFAULT '',
    system_message TEXT NOT NULL DEFAULT '',
    welcome_message TEXT NOT NULL DEFAULT '',
    public_status BOOLEAN NOT NULL DEFAULT FALSE,
    status INTEGER NOT NULL DEFAULT 1,
    knowledge_ids BIGINT[] NOT NULL DEFAULT '{}',
    tool_ids BIGINT[] NOT NULL DEFAULT '{}',
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ai_chat_roles_public ON ai.chat_roles(public_status,status,sort,id DESC);
CREATE INDEX IF NOT EXISTS idx_ai_chat_roles_user ON ai.chat_roles(user_id,id DESC);

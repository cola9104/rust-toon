CREATE TABLE IF NOT EXISTS ai.tools (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    status INTEGER NOT NULL DEFAULT 1,
    input_schema JSONB NOT NULL DEFAULT '{"type":"object","properties":{}}',
    executor JSONB NOT NULL DEFAULT '{}',
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL
);
ALTER TABLE ai.chat_conversations ADD COLUMN IF NOT EXISTS tool_ids BIGINT[] NOT NULL DEFAULT '{}';
INSERT INTO ai.tools(id,name,description,status,input_schema,executor,create_time,update_time) VALUES
(1,'current_time','获取指定时区的当前时间',1,'{"type":"object","properties":{"utcOffset":{"type":"string"}},"required":["utcOffset"]}','{"kind":"builtin"}',0,0),
(2,'weather_query','查询指定地点的天气',1,'{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}','{"kind":"builtin"}',0,0)
ON CONFLICT(name) DO NOTHING;

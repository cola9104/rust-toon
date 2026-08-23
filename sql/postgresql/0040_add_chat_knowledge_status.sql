ALTER TABLE ai.chat_messages
    ADD COLUMN IF NOT EXISTS knowledge_status jsonb NOT NULL DEFAULT '{"state":"disabled","segmentCount":0}'::jsonb;

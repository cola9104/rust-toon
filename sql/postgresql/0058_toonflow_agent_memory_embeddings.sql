ALTER TABLE toonflow.agent_memories
    ADD COLUMN IF NOT EXISTS embedding jsonb;

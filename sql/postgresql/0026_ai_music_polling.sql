ALTER TABLE ai.music ADD COLUMN IF NOT EXISTS poll_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE ai.music ADD COLUMN IF NOT EXISTS last_poll_time BIGINT;
CREATE INDEX IF NOT EXISTS idx_ai_music_pending ON ai.music(status,last_poll_time) WHERE status=10;

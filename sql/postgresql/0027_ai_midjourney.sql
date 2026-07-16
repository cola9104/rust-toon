ALTER TABLE ai.images ADD COLUMN IF NOT EXISTS parent_id BIGINT REFERENCES ai.images(id) ON DELETE SET NULL;
ALTER TABLE ai.images ADD COLUMN IF NOT EXISTS action_custom_id TEXT;
ALTER TABLE ai.images ADD COLUMN IF NOT EXISTS poll_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE ai.images ADD COLUMN IF NOT EXISTS last_poll_time BIGINT;

CREATE INDEX IF NOT EXISTS idx_ai_images_pending_task
    ON ai.images (COALESCE(last_poll_time, 0), id)
    WHERE status = 10 AND task_id IS NOT NULL;

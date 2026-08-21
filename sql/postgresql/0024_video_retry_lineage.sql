ALTER TABLE toonflow.videos
    ADD COLUMN IF NOT EXISTS retry_of_id bigint REFERENCES toonflow.videos(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_toonflow_videos_retry_of ON toonflow.videos(retry_of_id);

ALTER TABLE toonflow.tasks
    ADD COLUMN IF NOT EXISTS input jsonb NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS retry_of_id bigint REFERENCES toonflow.tasks(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS progress_current integer,
    ADD COLUMN IF NOT EXISTS progress_total integer;

CREATE INDEX IF NOT EXISTS idx_toonflow_tasks_retry_of ON toonflow.tasks(retry_of_id);

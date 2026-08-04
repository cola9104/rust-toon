ALTER TABLE toonflow.workflow_node_runs
    ADD COLUMN IF NOT EXISTS progress_current integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS progress_total integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS retry_of_id bigint
        REFERENCES toonflow.workflow_node_runs(id) ON DELETE SET NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'workflow_node_runs_progress_check'
          AND conrelid = 'toonflow.workflow_node_runs'::regclass
    ) THEN
        ALTER TABLE toonflow.workflow_node_runs
            ADD CONSTRAINT workflow_node_runs_progress_check
            CHECK (
                progress_current >= 0
                AND progress_total >= 0
                AND progress_current <= progress_total
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_toonflow_workflow_node_runs_retry
    ON toonflow.workflow_node_runs(retry_of_id)
    WHERE retry_of_id IS NOT NULL;

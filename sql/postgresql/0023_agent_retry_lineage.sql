ALTER TABLE toonflow.agent_runs
    ADD COLUMN IF NOT EXISTS retry_of_id bigint REFERENCES toonflow.agent_runs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_toonflow_agent_runs_retry_of ON toonflow.agent_runs(retry_of_id);

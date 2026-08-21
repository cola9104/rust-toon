-- Link workflow node executions to the Agent run that performs the work.
ALTER TABLE toonflow.workflow_node_runs
    ADD COLUMN IF NOT EXISTS agent_run_id bigint
        REFERENCES toonflow.agent_runs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_toonflow_workflow_node_runs_agent
    ON toonflow.workflow_node_runs(agent_run_id);

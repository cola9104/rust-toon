ALTER TABLE toonflow.agent_deployments
    ADD COLUMN IF NOT EXISTS prompt_source_key text,
    ADD COLUMN IF NOT EXISTS skill_path text,
    ADD COLUMN IF NOT EXISTS memory_scope text NOT NULL DEFAULT 'project',
    ADD COLUMN IF NOT EXISTS write_permissions jsonb NOT NULL DEFAULT '[]'::jsonb;

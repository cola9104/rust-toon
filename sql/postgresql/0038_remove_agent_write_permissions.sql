-- The reference Toonflow-app does not expose per-agent write permissions.
ALTER TABLE toonflow.agent_deployments
    DROP COLUMN IF EXISTS write_permissions;

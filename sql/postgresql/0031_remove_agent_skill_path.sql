-- Skills are loaded dynamically by Agent type and project context, as in
-- Toonflow-app. They are not an Agent deployment column.
ALTER TABLE toonflow.agent_deployments
  DROP COLUMN IF EXISTS skill_path;

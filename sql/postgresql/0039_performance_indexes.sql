CREATE INDEX IF NOT EXISTS idx_system_oauth2_access_token_active_user
    ON system_oauth2_access_token (user_id, deleted, expires_time);

CREATE INDEX IF NOT EXISTS idx_system_user_role_role
    ON system_user_role (role_id, user_id)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_system_role_tenant_active
    ON system_role (tenant_id, status, id)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_system_menu_tree_active
    ON system_menu (parent_id, sort, id)
    WHERE deleted = 0 AND status = 0;

CREATE INDEX IF NOT EXISTS idx_system_role_menu_active_menu
    ON system_role_menu (menu_id, role_id)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_infra_job_active
    ON infra_job (status, id)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_infra_job_log_job_time
    ON infra_job_log (job_id, create_time DESC)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_infra_api_access_log_time
    ON infra_api_access_log (create_time DESC)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_infra_api_error_log_status_time
    ON infra_api_error_log (process_status, create_time DESC)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_infra_codegen_column_table
    ON infra_codegen_column (table_id, ordinal_position, id)
    WHERE deleted = 0;

CREATE INDEX IF NOT EXISTS idx_toonflow_tasks_state_time
    ON toonflow.tasks (state, start_time DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_toonflow_assets_project_type
    ON toonflow.assets (project_id, type, id DESC);

CREATE INDEX IF NOT EXISTS idx_ai_tools_status_name
    ON ai.tools (status, name);

CREATE INDEX IF NOT EXISTS idx_ai_writes_user_time
    ON ai.writes (user_id, id DESC);

CREATE INDEX IF NOT EXISTS idx_ai_music_user_status
    ON ai.music (user_id, status, id DESC);

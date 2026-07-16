alter table toonflow.agent_deployments
    add column if not exists model_config_id bigint references ai.model_configs(id) on delete set null;
create index if not exists idx_toonflow_agent_model_config on toonflow.agent_deployments(model_config_id);

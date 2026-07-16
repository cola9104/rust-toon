alter table toonflow.agent_work_data alter column episodes_id drop not null;

create unique index if not exists uq_toonflow_agent_project_data
    on toonflow.agent_work_data(project_id, key)
    where episodes_id is null;

create table if not exists toonflow.agent_tool_calls (
    id bigint primary key,
    run_id bigint references toonflow.agent_runs(id) on delete cascade,
    agent_type varchar(64) not null,
    tool_name varchar(128) not null,
    arguments jsonb not null default '{}'::jsonb,
    result jsonb,
    state varchar(32) not null,
    error_reason text,
    create_time bigint not null,
    finish_time bigint
);

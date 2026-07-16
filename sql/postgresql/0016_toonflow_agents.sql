create table if not exists toonflow.agent_memories (
    id bigint primary key,
    agent_type varchar(64) not null,
    isolation_key varchar(255) not null,
    role varchar(64) not null,
    content text not null,
    memory_type varchar(32) not null default 'message',
    summarized boolean not null default false,
    related_message_ids jsonb not null default '[]'::jsonb,
    create_time bigint not null
);
create index if not exists idx_toonflow_agent_memories_session on toonflow.agent_memories(agent_type,isolation_key,create_time desc);
create table if not exists toonflow.agent_runs (
    id bigint primary key,
    agent_type varchar(64) not null,
    isolation_key varchar(255) not null,
    project_id bigint not null references toonflow.projects(id) on delete cascade,
    script_id bigint references toonflow.scripts(id) on delete cascade,
    input text not null,
    output text,
    state varchar(32) not null,
    error_reason text,
    think boolean not null default false,
    think_level integer not null default 0,
    start_time bigint not null,
    finish_time bigint
);
create index if not exists idx_toonflow_agent_runs_session on toonflow.agent_runs(agent_type,isolation_key,start_time desc);

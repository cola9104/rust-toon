create schema if not exists ai;
create table if not exists ai.model_configs (
    id bigint primary key,
    name varchar(255) not null,
    key varchar(255) not null unique,
    platform varchar(64) not null,
    type varchar(32) not null,
    model varchar(255) not null,
    api_key text not null default '',
    url text not null default '',
    status integer not null default 1,
    config jsonb not null default '{}'::jsonb,
    create_time bigint not null,
    update_time bigint not null
);
create index if not exists idx_ai_model_platform_type on ai.model_configs(platform,type,status);

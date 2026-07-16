create table if not exists system.audit_logs (
    id uuid primary key,
    actor_user_id uuid references system.users(id) on delete set null,
    actor_username varchar(64),
    action varchar(64) not null,
    target_type varchar(64) not null,
    target_id varchar(128),
    detail jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_created_at on system.audit_logs(created_at desc);
create index if not exists idx_audit_logs_actor on system.audit_logs(actor_user_id);
create index if not exists idx_audit_logs_target on system.audit_logs(target_type, target_id);

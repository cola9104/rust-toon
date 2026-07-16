create table if not exists system.auth_sessions (
    id uuid primary key,
    user_id uuid not null references system.users(id) on delete cascade,
    refresh_token_hash text not null,
    user_agent text,
    ip_address inet,
    revoked_at timestamptz,
    expires_at timestamptz not null,
    last_used_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists idx_auth_sessions_user on system.auth_sessions(user_id);
create index if not exists idx_auth_sessions_active
    on system.auth_sessions(user_id, expires_at)
    where revoked_at is null;

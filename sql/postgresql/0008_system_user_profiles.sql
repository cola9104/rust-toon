create table if not exists system.core_user_profiles (
    user_id uuid primary key references system.users(id) on delete cascade,
    dept_id bigint references system.core_depts(id),
    post_ids bigint[] not null default '{}',
    email varchar(128) not null default '',
    mobile varchar(32) not null default '',
    sex smallint not null default 1,
    avatar varchar(500) not null default '',
    remark varchar(500) not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

insert into system.core_user_profiles (user_id)
select id
from system.users
on conflict (user_id) do nothing;

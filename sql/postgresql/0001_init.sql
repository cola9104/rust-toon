create schema if not exists system;
create schema if not exists infra;
create schema if not exists toon;
create schema if not exists media;

create table if not exists system.users (
    id uuid primary key,
    username varchar(64) not null unique,
    display_name varchar(128) not null,
    password_hash text not null,
    tenant_id uuid,
    organization_id uuid,
    department_id uuid,
    status varchar(16) not null default 'active',
    failed_login_attempts integer not null default 0,
    locked_until timestamptz,
    updated_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    check (status in ('active', 'disabled', 'locked'))
);

create table if not exists system.roles (
    id uuid primary key,
    tenant_id uuid,
    code varchar(64) not null,
    name varchar(128) not null,
    data_scope varchar(32) not null default 'all',
    is_system boolean not null default false,
    enabled boolean not null default true,
    created_at timestamptz not null default now(),
    unique nulls not distinct (tenant_id, code),
    check (data_scope in ('self_only', 'department', 'organization', 'all'))
);

create table if not exists system.permissions (
    id uuid primary key,
    code varchar(128) not null unique,
    name varchar(128) not null,
    description text,
    created_at timestamptz not null default now(),
    check (code ~ '^(\\*|[a-z0-9_-]+(:[a-z0-9_*-]+)*)$')
);

create table if not exists system.user_roles (
    user_id uuid not null references system.users(id) on delete cascade,
    role_id uuid not null references system.roles(id) on delete cascade,
    primary key (user_id, role_id)
);

create table if not exists system.role_permissions (
    role_id uuid not null references system.roles(id) on delete cascade,
    permission_id uuid not null references system.permissions(id) on delete cascade,
    primary key (role_id, permission_id)
);

create index if not exists idx_roles_tenant on system.roles(tenant_id);
create index if not exists idx_user_roles_role on system.user_roles(role_id);
create index if not exists idx_role_permissions_permission on system.role_permissions(permission_id);

insert into system.permissions (id, code, name, description) values
    (gen_random_uuid(), 'system:user:*', '用户管理', '查看及管理用户'),
    (gen_random_uuid(), 'system:role:*', '角色管理', '查看及管理角色'),
    (gen_random_uuid(), 'system:permission:*', '权限管理', '查看及分配权限'),
    (gen_random_uuid(), 'system:audit:read', '审计日志', '查看审计日志'),
    (gen_random_uuid(), 'toon:*:*', '内容管理', '管理作品、剧集、场景和发布'),
    (gen_random_uuid(), 'media:*:*', '媒体管理', '管理素材、上传、转码和存储')
on conflict (code) do nothing;

insert into system.roles (id, tenant_id, code, name, data_scope, is_system)
values (gen_random_uuid(), null, 'system-admin', '系统管理员', 'all', true)
on conflict (tenant_id, code) do nothing;

insert into system.role_permissions (role_id, permission_id)
select role.id, permission.id
from system.roles role
cross join system.permissions permission
where role.tenant_id is null and role.code = 'system-admin'
on conflict do nothing;

create table if not exists toon.projects (
    id uuid primary key,
    name varchar(128) not null,
    owner_user_id uuid not null,
    created_at timestamptz not null default now()
);

create table if not exists media.assets (
    id uuid primary key,
    object_key varchar(512) not null,
    content_type varchar(128) not null,
    size_bytes bigint not null,
    created_at timestamptz not null default now()
);

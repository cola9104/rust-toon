create sequence if not exists system.core_menu_id_seq start 1000;
create sequence if not exists system.core_dept_id_seq start 1000;
create sequence if not exists system.core_post_id_seq start 1000;
create sequence if not exists system.core_dict_type_id_seq start 1000;
create sequence if not exists system.core_dict_data_id_seq start 1000;
create sequence if not exists system.core_tenant_id_seq start 1000;
create sequence if not exists system.core_tenant_package_id_seq start 1000;

create table if not exists system.core_menus (
    id bigint primary key default nextval('system.core_menu_id_seq'),
    name varchar(50) not null,
    permission varchar(100) not null default '',
    type smallint not null,
    sort integer not null default 0,
    parent_id bigint not null default 0,
    path varchar(200) default '',
    icon varchar(100) default '#',
    component varchar(255),
    component_name varchar(255),
    status smallint not null default 0,
    visible boolean not null default true,
    keep_alive boolean not null default true,
    always_show boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false
);

create table if not exists system.core_depts (
    id bigint primary key default nextval('system.core_dept_id_seq'),
    name varchar(30) not null,
    parent_id bigint not null default 0,
    sort integer not null default 0,
    leader_user_id uuid,
    phone varchar(32),
    email varchar(128),
    status smallint not null default 0,
    tenant_id uuid,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false
);

create table if not exists system.core_posts (
    id bigint primary key default nextval('system.core_post_id_seq'),
    code varchar(64) not null,
    name varchar(50) not null,
    sort integer not null default 0,
    status smallint not null default 0,
    remark varchar(500),
    tenant_id uuid,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false,
    unique nulls not distinct (tenant_id, code)
);

create table if not exists system.core_dict_types (
    id bigint primary key default nextval('system.core_dict_type_id_seq'),
    name varchar(100) not null,
    type varchar(100) not null,
    status smallint not null default 0,
    remark varchar(500),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false,
    unique (type)
);

create table if not exists system.core_dict_data (
    id bigint primary key default nextval('system.core_dict_data_id_seq'),
    sort integer not null default 0,
    label varchar(100) not null,
    value varchar(100) not null,
    dict_type varchar(100) not null,
    status smallint not null default 0,
    color_type varchar(100) default '',
    css_class varchar(100) default '',
    remark varchar(500),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false
);

create table if not exists system.core_tenant_packages (
    id bigint primary key default nextval('system.core_tenant_package_id_seq'),
    name varchar(30) not null,
    status smallint not null default 0,
    remark varchar(256) default '',
    menu_ids jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false
);

create table if not exists system.core_tenants (
    id bigint primary key default nextval('system.core_tenant_id_seq'),
    name varchar(30) not null,
    contact_user_id uuid,
    contact_name varchar(30) not null,
    contact_mobile varchar(64),
    status smallint not null default 0,
    websites jsonb not null default '[]'::jsonb,
    package_id bigint,
    expire_time timestamptz not null default '2099-12-31 23:59:59+00',
    account_count integer not null default 100,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false
);

create table if not exists system.core_role_menus (
    role_id uuid not null references system.roles(id) on delete cascade,
    menu_id bigint not null references system.core_menus(id) on delete cascade,
    tenant_id uuid,
    created_at timestamptz not null default now(),
    primary key (role_id, menu_id)
);

insert into system.core_menus
    (id, name, permission, type, sort, parent_id, path, icon, component, component_name, status, visible, keep_alive, always_show)
values
    (1, '系统功能', '', 1, 10, 0, '/system', 'lucide:settings', null, null, 0, true, true, true),
    (100, '用户管理', 'system:user:*', 2, 1, 1, 'user', 'lucide:users', 'system/user/index', 'SystemUser', 0, true, true, true),
    (101, '角色管理', 'system:role:*', 2, 2, 1, 'role', 'lucide:user-cog', 'system/role/index', 'SystemRole', 0, true, true, true),
    (102, '菜单管理', 'system:menu:*', 2, 3, 1, 'menu', 'lucide:list-tree', 'system/menu/index', 'SystemMenu', 0, true, true, true),
    (103, '部门管理', 'system:dept:*', 2, 4, 1, 'dept', 'lucide:network', 'system/dept/index', 'SystemDept', 0, true, true, true),
    (104, '岗位管理', 'system:post:*', 2, 5, 1, 'post', 'lucide:briefcase-business', 'system/post/index', 'SystemPost', 0, true, true, true),
    (105, '字典管理', 'system:dict:*', 2, 6, 1, 'dict', 'lucide:book-open', 'system/dict/index', 'SystemDict', 0, true, true, true),
    (2, '基础设置', '', 1, 20, 0, '/system/basic', 'lucide:sliders-horizontal', null, null, 0, true, true, true),
    (200, '租户管理', 'system:tenant:*', 2, 1, 2, '/system/tenant', 'lucide:building-2', 'system/tenant/index', 'SystemTenant', 0, true, true, true),
    (201, '租户套餐', 'system:tenant-package:*', 2, 2, 2, '/system/tenant-package', 'lucide:package', 'system/tenantPackage/index', 'SystemTenantPackage', 0, true, true, true),
    (202, '地区管理', 'system:area:*', 2, 3, 2, '/system/area', 'lucide:map', 'system/area/index', 'SystemArea', 0, true, true, true)
on conflict (id) do update set
    name = excluded.name,
    permission = excluded.permission,
    type = excluded.type,
    sort = excluded.sort,
    parent_id = excluded.parent_id,
    path = excluded.path,
    icon = excluded.icon,
    component = excluded.component,
    component_name = excluded.component_name,
    status = excluded.status,
    visible = excluded.visible,
    keep_alive = excluded.keep_alive,
    always_show = excluded.always_show,
    updated_at = now();

insert into system.core_depts (name, parent_id, sort, status)
select payload->>'name',
       coalesce((payload->>'parentId')::bigint, 0),
       coalesce((payload->>'sort')::integer, 0),
       coalesce((payload->>'status')::smallint, 0)
from system.management_items
where kind = 'dept'
  and not exists (select 1 from system.core_depts where deleted = false);

insert into system.core_posts (code, name, sort, status, remark)
select coalesce(payload->>'code', payload->>'name', 'post'),
       payload->>'name',
       coalesce((payload->>'sort')::integer, 0),
       coalesce((payload->>'status')::smallint, 0),
       payload->>'remark'
from system.management_items
where kind = 'post'
  and not exists (select 1 from system.core_posts where deleted = false);

insert into system.core_dict_types (name, type, status, remark)
select payload->>'name',
       coalesce(payload->>'type', payload->>'dictType'),
       coalesce((payload->>'status')::smallint, 0),
       payload->>'remark'
from system.management_items
where kind = 'dict_type'
  and not exists (select 1 from system.core_dict_types where deleted = false)
on conflict (type) do nothing;

insert into system.core_dict_data (sort, label, value, dict_type, status, color_type, css_class, remark)
select coalesce((payload->>'sort')::integer, 0),
       payload->>'label',
       payload->>'value',
       coalesce(payload->>'dictType', payload->>'dict_type'),
       coalesce((payload->>'status')::smallint, 0),
       coalesce(payload->>'colorType', ''),
       coalesce(payload->>'cssClass', ''),
       payload->>'remark'
from system.management_items
where kind = 'dict_data'
  and not exists (select 1 from system.core_dict_data where deleted = false);

insert into system.core_tenant_packages (name, status, remark, menu_ids)
select payload->>'name',
       coalesce((payload->>'status')::smallint, 0),
       payload->>'remark',
       coalesce(payload->'menuIds', '[]'::jsonb)
from system.management_items
where kind = 'tenant_package'
  and not exists (select 1 from system.core_tenant_packages where deleted = false);

insert into system.core_tenants (name, contact_name, contact_mobile, status, websites, package_id, expire_time, account_count)
select payload->>'name',
       coalesce(payload->>'contactName', '管理员'),
       payload->>'contactMobile',
       coalesce((payload->>'status')::smallint, 0),
       coalesce(payload->'websites', '[]'::jsonb),
       nullif(payload->>'packageId', '')::bigint,
       coalesce(nullif(payload->>'expireTime', '')::timestamptz, '2099-12-31 23:59:59+00'),
       coalesce((payload->>'accountCount')::integer, 100)
from system.management_items
where kind = 'tenant'
  and not exists (select 1 from system.core_tenants where deleted = false);

select setval('system.core_menu_id_seq', greatest((select coalesce(max(id), 999) from system.core_menus), 999));
select setval('system.core_dept_id_seq', greatest((select coalesce(max(id), 999) from system.core_depts), 999));
select setval('system.core_post_id_seq', greatest((select coalesce(max(id), 999) from system.core_posts), 999));
select setval('system.core_dict_type_id_seq', greatest((select coalesce(max(id), 999) from system.core_dict_types), 999));
select setval('system.core_dict_data_id_seq', greatest((select coalesce(max(id), 999) from system.core_dict_data), 999));
select setval('system.core_tenant_id_seq', greatest((select coalesce(max(id), 999) from system.core_tenants), 999));
select setval('system.core_tenant_package_id_seq', greatest((select coalesce(max(id), 999) from system.core_tenant_packages), 999));
-- Yudao-compatible tables used by the system management module.
-- These mirror the new system.core_* tables with the old naming convention.

-- sequences
create sequence if not exists system_menu_seq start 1000;
create sequence if not exists system_dept_seq start 1000;
create sequence if not exists system_post_seq start 1000;
create sequence if not exists system_dict_type_seq start 1000;
create sequence if not exists system_role_seq start 100;
create sequence if not exists system_role_menu_seq start 1000;

-- system_menu (Yudao compat)
create table if not exists system_menu (
    id bigint primary key default nextval('system_menu_seq'),
    name varchar(50) not null,
    permission varchar(100) not null default '',
    type smallint not null,
    sort integer not null default 0,
    parent_id bigint not null default 0,
    path varchar(200) default '',
    icon varchar(100) default '#',
    component varchar(255),
    component_name varchar(255),
    status smallint not null default 0,
    visible boolean not null default true,
    keep_alive boolean not null default true,
    always_show boolean not null default true,
    creator varchar(64) default '',
    updater varchar(64) default '',
    create_time timestamptz not null default now(),
    update_time timestamptz not null default now(),
    deleted boolean not null default false
);

create unique index if not exists idx_system_menu_id on system_menu(id);

-- system_dept (Yudao compat)
create table if not exists system_dept (
    id bigint primary key default nextval('system_dept_seq'),
    name varchar(30) not null,
    parent_id bigint not null default 0,
    sort integer not null default 0,
    leader_user_id uuid,
    phone varchar(32),
    email varchar(128),
    status smallint not null default 0,
    create_time timestamptz not null default now(),
    update_time timestamptz not null default now(),
    deleted boolean not null default false
);

-- system_post (Yudao compat)
create table if not exists system_post (
    id bigint primary key default nextval('system_post_seq'),
    code varchar(64) not null,
    name varchar(50) not null,
    sort integer not null default 0,
    status smallint not null default 0,
    remark varchar(500),
    create_time timestamptz not null default now(),
    update_time timestamptz not null default now(),
    deleted boolean not null default false
);

-- system_dict_type (Yudao compat)
create table if not exists system_dict_type (
    id bigint primary key default nextval('system_dict_type_seq'),
    name varchar(100) not null,
    type varchar(100) not null,
    status smallint not null default 0,
    remark varchar(500),
    create_time timestamptz not null default now(),
    update_time timestamptz not null default now(),
    deleted boolean not null default false
);

-- system_role (Yudao compat)
create table if not exists system_role (
    id bigint primary key default nextval('system_role_seq'),
    code varchar(64) not null,
    name varchar(128) not null,
    sort integer not null default 0,
    data_scope smallint not null default 1,
    status smallint not null default 0,
    type smallint not null default 2,
    remark varchar(500),
    create_time timestamptz not null default now(),
    update_time timestamptz not null default now(),
    deleted boolean not null default false
);
create unique index if not exists idx_system_role_code on system_role(code);

-- system_role_menu (Yudao compat)
create table if not exists system_role_menu (
    id bigint primary key default nextval('system_role_menu_seq'),
    role_id bigint not null,
    menu_id bigint not null,
    creator varchar(64) default '',
    updater varchar(64) default '',
    tenant_id uuid,
    create_time timestamptz not null default now(),
    update_time timestamptz not null default now(),
    deleted boolean not null default false
);

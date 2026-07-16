-- The Yudao public.system_* tables are the single source of truth.
-- Preserve UUID ownership used by Rust business tables with a deterministic
-- projection of the Yudao bigint user id, then remove the legacy duplicate
-- identity, RBAC and core-management tables.

alter table system.auth_sessions drop constraint if exists auth_sessions_user_id_fkey;
alter table system.audit_logs drop constraint if exists audit_logs_actor_user_id_fkey;
alter table media.assets drop constraint if exists assets_owner_user_id_fkey;
alter table toonflow.projects drop constraint if exists projects_user_id_fkey;
alter table toon.publications drop constraint if exists publications_created_by_fkey;

do $$
begin
if to_regclass('system.users') is not null then
update system.auth_sessions session
set user_id = md5('yudao-user:' || source.id::text)::uuid
from system.users legacy
join system_users source on lower(source.username) = lower(legacy.username)
where session.user_id = legacy.id;

update system.audit_logs audit
set actor_user_id = md5('yudao-user:' || source.id::text)::uuid
from system.users legacy
join system_users source on lower(source.username) = lower(legacy.username)
where audit.actor_user_id = legacy.id;

update media.assets asset
set owner_user_id = md5('yudao-user:' || source.id::text)::uuid
from system.users legacy
join system_users source on lower(source.username) = lower(legacy.username)
where asset.owner_user_id = legacy.id;

update toonflow.projects project
set user_id = md5('yudao-user:' || source.id::text)::uuid
from system.users legacy
join system_users source on lower(source.username) = lower(legacy.username)
where project.user_id = legacy.id;

update toon.publications publication
set created_by = md5('yudao-user:' || source.id::text)::uuid
from system.users legacy
join system_users source on lower(source.username) = lower(legacy.username)
where publication.created_by = legacy.id;
end if;
end
$$;

drop table if exists system.core_role_menus cascade;
drop table if exists system.role_permissions cascade;
drop table if exists system.user_roles cascade;
drop table if exists system.core_user_profiles cascade;
drop table if exists system.core_menus cascade;
drop table if exists system.core_depts cascade;
drop table if exists system.core_posts cascade;
drop table if exists system.core_dict_data cascade;
drop table if exists system.core_dict_types cascade;
drop table if exists system.core_tenants cascade;
drop table if exists system.core_tenant_packages cascade;
drop table if exists system.permissions cascade;
drop table if exists system.roles cascade;
drop table if exists system.users cascade;
drop table if exists system.management_items cascade;

drop sequence if exists system.core_menu_id_seq;
drop sequence if exists system.core_dept_id_seq;
drop sequence if exists system.core_post_id_seq;
drop sequence if exists system.core_dict_type_id_seq;
drop sequence if exists system.core_dict_data_id_seq;
drop sequence if exists system.core_tenant_id_seq;
drop sequence if exists system.core_tenant_package_id_seq;

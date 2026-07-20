insert into system_menu (
    id, name, permission, type, sort, parent_id, path, icon, component,
    component_name, status, visible, keep_alive, always_show, creator, updater, deleted
) values (
    20007, '资产库', 'toon:project:read', 2, 2, 20000, 'assets',
    'lucide:library-big', 'toonflow/assets/index', 'ToonflowAssets',
    0, true, true, true, 'system', 'system', 0
)
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
    updater = 'system',
    update_time = current_timestamp,
    deleted = 0;

with entitled_roles as (
    select distinct role_id
    from system_role_menu
    where menu_id = 20001 and deleted = 0
), missing as (
    select role_id, row_number() over (order by role_id) as row_number
    from entitled_roles role
    where not exists (
        select 1
        from system_role_menu existing
        where existing.role_id = role.role_id
          and existing.menu_id = 20007
          and existing.deleted = 0
    )
), current_max as (
    select coalesce(max(id), 0) as max_id from system_role_menu
)
insert into system_role_menu (id, role_id, menu_id, creator, updater, tenant_id)
select current_max.max_id + missing.row_number,
       missing.role_id,
       20007,
       'system',
       'system',
       null
from missing
cross join current_max;

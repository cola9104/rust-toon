-- Keep the runtime navigation and 菜单管理 records in sync for existing databases.
insert into system_menu (
    id, name, permission, type, sort, parent_id, path, icon, component,
    component_name, status, visible, keep_alive, always_show, creator, updater
) values
    (20000, '短剧工厂', '', 1, 30, 0, '/toonflow', 'lucide:clapperboard', '', 'Toonflow', 0, true, true, true, 'system', 'system'),
    (20001, '项目工作台', 'toon:project:read', 2, 1, 20000, 'projects', 'lucide:layout-dashboard', 'toonflow/projects/index', 'ToonflowProjects', 0, true, true, true, 'system', 'system'),
    (20002, '风格库', 'toon:project:read', 2, 2, 20000, 'styles', 'lucide:palette', 'toonflow/styles/index', 'ToonflowStyles', 0, true, true, true, 'system', 'system'),
    (20003, '任务中心', 'toon:project:read', 2, 3, 20000, 'tasks', 'lucide:list-checks', 'toonflow/tasks/index', 'ToonflowTasks', 0, true, true, true, 'system', 'system'),
    (20004, '提示词与 Skill', 'toon:project:read', 2, 4, 20000, 'prompts', 'lucide:wand-sparkles', 'toonflow/prompts/index', 'ToonflowPrompts', 0, true, true, true, 'system', 'system'),
    (20005, '模型与 Agent', 'toon:project:read', 2, 5, 20000, 'settings', 'lucide:bot', 'toonflow/settings/index', 'ToonflowSettings', 0, true, true, true, 'system', 'system'),
    (20006, '项目详情', 'toon:project:read', 2, 6, 20000, 'projects/:id', 'lucide:file-stack', 'toonflow/projects/detail', 'ToonflowProjectDetail', 0, false, false, false, 'system', 'system')
on conflict (id) do update set
    name=excluded.name, permission=excluded.permission, type=excluded.type, sort=excluded.sort,
    parent_id=excluded.parent_id, path=excluded.path, icon=excluded.icon,
    component=excluded.component, component_name=excluded.component_name,
    status=excluded.status, visible=excluded.visible, keep_alive=excluded.keep_alive,
    always_show=excluded.always_show, updater='system', update_time=current_timestamp, deleted=false;

insert into system_role_menu (id, role_id, menu_id, creator, updater, tenant_id)
select 200000 + menu.id, role.id, menu.id, 'system', 'system', NULL
from system_role role cross join system_menu menu
where role.code='super_admin' and menu.id between 20000 and 20006
and not exists (select 1 from system_role_menu existing where existing.role_id=role.id and existing.menu_id=menu.id and existing.deleted=false);

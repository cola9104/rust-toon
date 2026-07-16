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
    (20006, '项目详情', 'toon:project:read', 2, 6, 20000, 'projects/:id', 'lucide:file-stack', 'toonflow/projects/detail', 'ToonflowProjectDetail', 0, false, false, false, 'system', 'system'),
    (20010, '项目创建', 'toon:project:create', 3, 1, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20011, '项目更新', 'toon:project:update', 3, 2, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20012, '项目删除', 'toon:project:delete', 3, 3, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20013, '剧本读取', 'toon:episode:read', 3, 4, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20014, '剧本创建', 'toon:episode:create', 3, 5, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20015, '剧本更新', 'toon:episode:update', 3, 6, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20016, '剧本删除', 'toon:episode:delete', 3, 7, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20017, '分镜读取', 'toon:scene:read', 3, 8, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20018, '分镜创建', 'toon:scene:create', 3, 9, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20019, '分镜更新', 'toon:scene:update', 3, 10, 20001, '', '', '', '', 0, true, true, true, 'system', 'system'),
    (20020, '分镜删除', 'toon:scene:delete', 3, 11, 20001, '', '', '', '', 0, true, true, true, 'system', 'system')
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
    update_time = current_timestamp,
    deleted = false;

insert into system_role_menu (id, role_id, menu_id, creator, updater, tenant_id)
select 200000 + menu.id, role.id, menu.id, 'system', 'system', NULL
from system_role role
cross join system_menu menu
where role.code = 'super_admin'
  and menu.id between 20000 and 20020
  and not exists (
      select 1 from system_role_menu existing
      where existing.role_id = role.id
        and existing.menu_id = menu.id
        and existing.deleted = false
  );

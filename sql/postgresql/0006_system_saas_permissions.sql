insert into system.permissions (id, code, name, description) values
    (gen_random_uuid(), 'system:menu:*', '菜单管理', '查看及管理菜单'),
    (gen_random_uuid(), 'system:dept:*', '部门管理', '查看及管理部门'),
    (gen_random_uuid(), 'system:post:*', '岗位管理', '查看及管理岗位'),
    (gen_random_uuid(), 'system:dict:*', '字典管理', '查看及管理字典'),
    (gen_random_uuid(), 'system:tenant:*', '租户管理', '查看及管理租户'),
    (gen_random_uuid(), 'system:tenant:visit', '租户访问', '切换访问租户'),
    (gen_random_uuid(), 'system:tenant:create', '租户创建', '创建租户'),
    (gen_random_uuid(), 'system:tenant:update', '租户更新', '更新租户'),
    (gen_random_uuid(), 'system:tenant:delete', '租户删除', '删除租户'),
    (gen_random_uuid(), 'system:tenant:export', '租户导出', '导出租户'),
    (gen_random_uuid(), 'system:tenant-package:*', '租户套餐管理', '查看及管理租户套餐'),
    (gen_random_uuid(), 'system:tenant-package:create', '租户套餐创建', '创建租户套餐'),
    (gen_random_uuid(), 'system:tenant-package:update', '租户套餐更新', '更新租户套餐'),
    (gen_random_uuid(), 'system:tenant-package:delete', '租户套餐删除', '删除租户套餐')
on conflict (code) do nothing;

insert into system.role_permissions (role_id, permission_id)
select role.id, permission.id
from system.roles role
cross join system.permissions permission
where role.tenant_id is null
  and role.code = 'system-admin'
  and permission.code in (
      'system:menu:*',
      'system:dept:*',
      'system:post:*',
      'system:dict:*',
      'system:tenant:*',
      'system:tenant:visit',
      'system:tenant:create',
      'system:tenant:update',
      'system:tenant:delete',
      'system:tenant:export',
      'system:tenant-package:*',
      'system:tenant-package:create',
      'system:tenant-package:update',
      'system:tenant-package:delete'
  )
on conflict do nothing;

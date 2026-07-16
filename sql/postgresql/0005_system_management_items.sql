create table if not exists system.management_items (
    id uuid primary key,
    kind varchar(64) not null,
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_management_items_kind on system.management_items(kind);

insert into system.management_items (id, kind, payload)
values
    (gen_random_uuid(), 'dept', '{"name":"总部","parentId":"0","status":0,"sort":0,"leaderUserId":null,"phone":"","email":""}'::jsonb),
    (gen_random_uuid(), 'post', '{"name":"管理员","code":"admin","sort":0,"status":0,"remark":"系统默认岗位"}'::jsonb),
    (gen_random_uuid(), 'dict_type', '{"name":"通用状态","type":"common_status","status":0,"remark":"通用启停状态"}'::jsonb),
    (gen_random_uuid(), 'dict_data', '{"label":"开启","value":"0","dictType":"common_status","status":0,"colorType":"success","cssClass":"","sort":0,"remark":""}'::jsonb),
    (gen_random_uuid(), 'dict_data', '{"label":"关闭","value":"1","dictType":"common_status","status":0,"colorType":"danger","cssClass":"","sort":1,"remark":""}'::jsonb),
    (gen_random_uuid(), 'dict_type', '{"name":"用户性别","type":"system_user_sex","status":0,"remark":"用户性别"}'::jsonb),
    (gen_random_uuid(), 'dict_data', '{"label":"男","value":"1","dictType":"system_user_sex","status":0,"colorType":"primary","cssClass":"","sort":0,"remark":""}'::jsonb),
    (gen_random_uuid(), 'dict_data', '{"label":"女","value":"2","dictType":"system_user_sex","status":0,"colorType":"success","cssClass":"","sort":1,"remark":""}'::jsonb),
    (gen_random_uuid(), 'tenant_package', '{"name":"默认套餐","status":0,"remark":"系统默认套餐","menuIds":[],"creator":"system","updater":"system"}'::jsonb),
    (gen_random_uuid(), 'tenant', '{"name":"默认租户","packageId":null,"contactName":"管理员","contactMobile":"","accountCount":100,"expireTime":"2099-12-31 23:59:59","websites":[],"status":0}'::jsonb)
on conflict (id) do nothing;

-- The application runs in backend access mode. Keep system_menu aligned with
-- the current navigation layout instead of the legacy nested Yudao catalog.

INSERT INTO system_menu
    (id,name,permission,type,sort,parent_id,path,icon,component,component_name,
     status,visible,keep_alive,always_show,creator,updater,deleted)
VALUES
    (30240,'基础设置','',1,11,0,'/system/basic','lucide:sliders-horizontal','',
     'SystemBasic',0,true,true,true,'system','system',0),
    (30241,'信息中心','',1,12,0,'/system/message','lucide:mail','',
     'SystemMessage',0,true,true,true,'system','system',0)
ON CONFLICT(id) DO UPDATE SET
    name=EXCLUDED.name,permission=EXCLUDED.permission,type=EXCLUDED.type,
    sort=EXCLUDED.sort,parent_id=EXCLUDED.parent_id,path=EXCLUDED.path,
    icon=EXCLUDED.icon,component=EXCLUDED.component,
    component_name=EXCLUDED.component_name,status=EXCLUDED.status,
    visible=EXCLUDED.visible,keep_alive=EXCLUDED.keep_alive,
    always_show=EXCLUDED.always_show,updater='system',
    update_time=CURRENT_TIMESTAMP,deleted=0;

-- Top-level names and positions follow the route-module layout.
UPDATE system_menu SET name='系统功能', sort=10, path='/system',
    icon='lucide:settings', component_name='System', update_time=CURRENT_TIMESTAMP
WHERE id=1;
UPDATE system_menu SET name='短剧工厂', sort=20, update_time=CURRENT_TIMESTAMP
WHERE id=20000;
UPDATE system_menu SET name='基础功能', sort=21, icon='lucide:blocks',
    component_name='Infra', update_time=CURRENT_TIMESTAMP WHERE id=2;
UPDATE system_menu SET sort=22, update_time=CURRENT_TIMESTAMP WHERE id=6100;
UPDATE system_menu SET name='AI 大模型', sort=30, component_name='Ai',
    update_time=CURRENT_TIMESTAMP WHERE id=2758;
UPDATE system_menu SET name='工作流', sort=50, component_name='bpm',
    update_time=CURRENT_TIMESTAMP WHERE id=1185;

-- System functionality is a flat group in the current UI.
UPDATE system_menu SET parent_id=1, path='operatelog', sort=8,
    name='操作日志', update_time=CURRENT_TIMESTAMP WHERE id=500;
UPDATE system_menu SET parent_id=1, path='loginlog', sort=9,
    name='登录日志', update_time=CURRENT_TIMESTAMP WHERE id=501;
UPDATE system_menu SET parent_id=1, path='notice', sort=7,
    name='通知公告', update_time=CURRENT_TIMESTAMP WHERE id=107;

-- Basic settings is a top-level navigation group.
UPDATE system_menu SET parent_id=30240, path='/system/tenant', sort=1,
    name='租户管理', update_time=CURRENT_TIMESTAMP WHERE id=1138;
UPDATE system_menu SET parent_id=30240, path='/system/tenant-package', sort=2,
    name='租户套餐', update_time=CURRENT_TIMESTAMP WHERE id=1225;
UPDATE system_menu SET parent_id=30240, path='/system/area', sort=3,
    name='地区管理', update_time=CURRENT_TIMESTAMP WHERE id=2083;
UPDATE system_menu SET parent_id=30240, path='/system/social-client', sort=4,
    name='社交客户端', component_name='SystemSocialClient',
    component='system/social/client/index.vue', update_time=CURRENT_TIMESTAMP WHERE id=2448;
UPDATE system_menu SET parent_id=30240, path='/system/social-user', sort=5,
    name='社交用户', component_name='SystemSocialUser',
    component='system/social/user/index.vue', update_time=CURRENT_TIMESTAMP WHERE id=2453;
UPDATE system_menu SET parent_id=30240, path='/system/oauth2-client', sort=6,
    name='OAuth2 客户端', component_name='SystemOauth2Client',
    update_time=CURRENT_TIMESTAMP WHERE id=1263;
UPDATE system_menu SET parent_id=30240, path='/system/oauth2-token', sort=7,
    name='OAuth2 令牌', component_name='SystemOauth2Token',
    update_time=CURRENT_TIMESTAMP WHERE id=109;

-- Information center is a top-level navigation group.
UPDATE system_menu SET parent_id=30241, path='/system/notify-template', sort=1,
    name='站内信模板', update_time=CURRENT_TIMESTAMP WHERE id=2145;
UPDATE system_menu SET parent_id=30241, path='/system/notify-message-list', sort=2,
    name='站内信消息', update_time=CURRENT_TIMESTAMP WHERE id=2151;
UPDATE system_menu SET parent_id=30241, path='/system/mail-account', sort=3,
    name='邮箱账号', update_time=CURRENT_TIMESTAMP WHERE id=2131;
UPDATE system_menu SET parent_id=30241, path='/system/mail-template', sort=4,
    name='邮件模板', update_time=CURRENT_TIMESTAMP WHERE id=2136;
UPDATE system_menu SET parent_id=30241, path='/system/mail-log', sort=5,
    name='邮件日志', update_time=CURRENT_TIMESTAMP WHERE id=2141;
UPDATE system_menu SET parent_id=30241, path='/system/sms-channel', sort=6,
    name='短信渠道', update_time=CURRENT_TIMESTAMP WHERE id=1094;
UPDATE system_menu SET parent_id=30241, path='/system/sms-template', sort=7,
    name='短信模板', update_time=CURRENT_TIMESTAMP WHERE id=1100;
UPDATE system_menu SET parent_id=30241, path='/system/sms-log', sort=8,
    name='短信日志', update_time=CURRENT_TIMESTAMP WHERE id=1107;

-- Retire empty legacy grouping nodes so menu management shows the same
-- navigation structure as the sidebar.
UPDATE system_menu SET deleted=1, update_time=CURRENT_TIMESTAMP
WHERE id IN (108,1224,1261,2447,2739,1093,2130,2144);

-- Preserve role visibility for the two new parent menus. Roles that could see
-- any of their children receive the corresponding parent automatically.
WITH entitled_roles AS (
    SELECT DISTINCT role_id
    FROM system_role_menu
    WHERE deleted=0 AND menu_id IN (1138,1225,2083,2448,2453,1263,109,1224)
), missing AS (
    SELECT role_id, row_number() OVER (ORDER BY role_id) AS rn
    FROM entitled_roles r
    WHERE NOT EXISTS (
        SELECT 1 FROM system_role_menu rm
        WHERE rm.role_id=r.role_id AND rm.menu_id=30240 AND rm.deleted=0
    )
), base AS (
    SELECT COALESCE(MAX(id),0) AS max_id FROM system_role_menu
)
INSERT INTO system_role_menu
    (id,role_id,menu_id,creator,updater,deleted,tenant_id)
SELECT base.max_id + missing.rn, missing.role_id, 30240,
       'system','system',0,0
FROM missing CROSS JOIN base;

WITH entitled_roles AS (
    SELECT DISTINCT role_id
    FROM system_role_menu
    WHERE deleted=0 AND menu_id IN (2145,2151,2131,2136,2141,1094,1100,1107,2739)
), missing AS (
    SELECT role_id, row_number() OVER (ORDER BY role_id) AS rn
    FROM entitled_roles r
    WHERE NOT EXISTS (
        SELECT 1 FROM system_role_menu rm
        WHERE rm.role_id=r.role_id AND rm.menu_id=30241 AND rm.deleted=0
    )
), base AS (
    SELECT COALESCE(MAX(id),0) AS max_id FROM system_role_menu
)
INSERT INTO system_role_menu
    (id,role_id,menu_id,creator,updater,deleted,tenant_id)
SELECT base.max_id + missing.rn, missing.role_id, 30241,
       'system','system',0,0
FROM missing CROSS JOIN base;

SELECT setval('system_menu_seq', GREATEST((SELECT MAX(id) FROM system_menu), 30241));
SELECT setval('system_role_menu_seq', GREATEST((SELECT MAX(id) FROM system_role_menu), 1));

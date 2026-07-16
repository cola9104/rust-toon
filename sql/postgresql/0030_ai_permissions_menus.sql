INSERT INTO system_menu (
    id,name,permission,type,sort,parent_id,path,icon,component,component_name,
    status,visible,keep_alive,always_show,creator,updater
) VALUES
    (30000,'AI 大模型','',1,40,0,'/ai','tabler:ai','','Ai',0,true,true,true,'system','system'),
    (30001,'AI 对话','',2,1,30000,'chat','lucide:message-circle','ai/chat/index/index','AiChat',0,true,true,true,'system','system'),
    (30002,'AI 绘图','',2,2,30000,'image','lucide:image','ai/image/index/index','AiImage',0,true,true,true,'system','system'),
    (30003,'AI 写作','',2,3,30000,'write','lucide:pen-line','ai/write/index/index','AiWrite',0,true,true,true,'system','system'),
    (30004,'AI 音乐','',2,4,30000,'music','lucide:music','ai/music/index/index','AiMusic',0,true,true,true,'system','system'),
    (30005,'知识库','ai:knowledge:query',2,5,30000,'knowledge','lucide:database','ai/knowledge/knowledge/index','AiKnowledge',0,true,true,true,'system','system'),
    (30006,'模型管理','ai:model:query',2,6,30000,'model','lucide:brain-circuit','ai/model/model/index','AiModel',0,true,true,true,'system','system'),
    (30007,'聊天角色','ai:chat-role:query',2,7,30000,'model/chat-role','lucide:bot','ai/model/chatRole/index','AiModelChatRole',0,true,true,true,'system','system'),
    (30008,'工具管理','ai:tool:query',2,8,30000,'model/tool','lucide:wrench','ai/model/tool/index','AiModelTool',0,true,true,true,'system','system'),
    (30101,'模型查询','ai:model:query',3,1,30006,'','','','',0,true,true,true,'system','system'),
    (30102,'模型创建','ai:model:create',3,2,30006,'','','','',0,true,true,true,'system','system'),
    (30103,'模型更新','ai:model:update',3,3,30006,'','','','',0,true,true,true,'system','system'),
    (30104,'模型删除','ai:model:delete',3,4,30006,'','','','',0,true,true,true,'system','system'),
    (30111,'知识库创建','ai:knowledge:create',3,1,30005,'','','','',0,true,true,true,'system','system'),
    (30112,'知识库更新','ai:knowledge:update',3,2,30005,'','','','',0,true,true,true,'system','system'),
    (30113,'知识库删除','ai:knowledge:delete',3,3,30005,'','','','',0,true,true,true,'system','system'),
    (30121,'角色创建','ai:chat-role:create',3,1,30007,'','','','',0,true,true,true,'system','system'),
    (30122,'角色更新','ai:chat-role:update',3,2,30007,'','','','',0,true,true,true,'system','system'),
    (30123,'角色删除','ai:chat-role:delete',3,3,30007,'','','','',0,true,true,true,'system','system'),
    (30131,'工具创建','ai:tool:create',3,1,30008,'','','','',0,true,true,true,'system','system'),
    (30132,'工具更新','ai:tool:update',3,2,30008,'','','','',0,true,true,true,'system','system'),
    (30133,'工具删除','ai:tool:delete',3,3,30008,'','','','',0,true,true,true,'system','system')
ON CONFLICT(id) DO UPDATE SET name=excluded.name,permission=excluded.permission,type=excluded.type,
sort=excluded.sort,parent_id=excluded.parent_id,path=excluded.path,icon=excluded.icon,
component=excluded.component,component_name=excluded.component_name,status=excluded.status,
visible=excluded.visible,keep_alive=excluded.keep_alive,always_show=excluded.always_show,
updater='system',update_time=current_timestamp,deleted=false;

INSERT INTO system_role_menu(id,role_id,menu_id,creator,updater,tenant_id)
SELECT 300000+menu.id,role.id,menu.id,'system','system',NULL
FROM system_role role CROSS JOIN system_menu menu
WHERE role.code='super_admin' AND menu.id BETWEEN 30000 AND 30199
AND NOT EXISTS(SELECT 1 FROM system_role_menu existing WHERE existing.role_id=role.id AND existing.menu_id=menu.id AND existing.deleted=false);

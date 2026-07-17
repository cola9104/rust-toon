-- Keep navigation and routable detail pages in the backend menu catalog.
-- Hidden pages remain authorized routes but never occupy sidebar entries.
INSERT INTO system_menu
    (id,name,permission,type,sort,parent_id,path,icon,component,component_name,
     status,visible,keep_alive,always_show,creator,updater,deleted)
VALUES
    (30200,'仪表盘','',1,-10,0,'/dashboard','lucide:layout-dashboard','','Dashboard',0,true,true,true,'system','system',0),
    (30201,'工作台','',2,1,30200,'/workspace','carbon:workspace','dashboard/workspace/index','Workspace',0,true,true,true,'system','system',0),
    (30202,'分析页','',2,2,30200,'/analytics','lucide:area-chart','dashboard/analytics/index','Analytics',0,true,true,true,'system','system',0),
    (30203,'个人中心','',2,99,1,'/profile','lucide:user-round','_core/profile/index','Profile',0,false,false,false,'system','system',0),

    (30210,'绘图作品','ai:image:query',2,90,2758,'image/square','lucide:images','ai/image/square/index','AiImageSquare',0,false,false,false,'system','system',0),
    (30211,'知识库文档','ai:knowledge:query',2,91,2758,'knowledge/document','lucide:files','ai/knowledge/document/index','AiKnowledgeDocument',0,false,false,false,'system','system',0),
    (30212,'创建文档','ai:knowledge:create',2,92,2758,'knowledge/document/create','lucide:file-plus-2','ai/knowledge/document/form/index','AiKnowledgeDocumentCreate',0,false,false,false,'system','system',0),
    (30213,'修改文档','ai:knowledge:update',2,93,2758,'knowledge/document/update','lucide:file-pen-line','ai/knowledge/document/form/index','AiKnowledgeDocumentUpdate',0,false,false,false,'system','system',0),
    (30214,'文档召回测试','ai:knowledge:query',2,94,2758,'knowledge/retrieval','lucide:search-check','ai/knowledge/knowledge/retrieval/index','AiKnowledgeRetrieval',0,false,false,false,'system','system',0),
    (30215,'知识库分段','ai:knowledge:query',2,95,2758,'knowledge/segment','lucide:blocks','ai/knowledge/segment/index','AiKnowledgeSegment',0,false,false,false,'system','system',0),

    (30220,'流程详情','bpm:process-instance:query',2,90,1185,'process-instance/detail','lucide:file-search','bpm/processInstance/detail/index','BpmProcessInstanceDetail',0,false,false,false,'system','system',0),
    (30221,'设计流程表单','bpm:form:update',2,91,1185,'manager/form/edit','lucide:file-pen-line','bpm/form/designer/index','BpmFormEditor',0,false,false,false,'system','system',0),
    (30222,'创建流程','bpm:model:create',2,92,1185,'manager/model/create','lucide:workflow','bpm/model/form/index','BpmModelCreate',0,false,false,false,'system','system',0),
    (30223,'修改流程','bpm:model:update',2,93,1185,'manager/model/:type/:id','lucide:workflow','bpm/model/form/index','BpmModelUpdate',0,false,false,false,'system','system',0),
    (30224,'流程定义','bpm:definition:query',2,94,1185,'manager/definition','lucide:file-cog','bpm/model/definition/index','BpmProcessDefinition',0,false,false,false,'system','system',0),
    (30225,'流程数据报表','bpm:process-instance:query',2,95,1185,'process-instance/report','lucide:chart-no-axes-combined','bpm/processInstance/report/index','BpmProcessInstanceReport',0,false,false,false,'system','system',0),

    (30230,'调度日志','infra:job:query',2,90,2,'/infra/job/log','lucide:scroll-text','infra/job/logger/index','InfraJobLog',0,false,false,false,'system','system',0),
    (30231,'生成配置修改','infra:codegen:update',2,91,2,'/infra/codegen/edit','lucide:file-cog','infra/codegen/edit/index','InfraCodegenEdit',0,false,false,false,'system','system',0),
    (30232,'我的站内信','system:notify-message:query',2,90,1,'/system/notify-message','lucide:mail','system/notify/my/index','MyNotifyMessage',0,false,false,false,'system','system',0)
ON CONFLICT(id) DO UPDATE SET
    name=EXCLUDED.name,permission=EXCLUDED.permission,type=EXCLUDED.type,
    sort=EXCLUDED.sort,parent_id=EXCLUDED.parent_id,path=EXCLUDED.path,
    icon=EXCLUDED.icon,component=EXCLUDED.component,
    component_name=EXCLUDED.component_name,status=EXCLUDED.status,
    visible=EXCLUDED.visible,keep_alive=EXCLUDED.keep_alive,
    always_show=EXCLUDED.always_show,updater='system',update_time=CURRENT_TIMESTAMP,
    deleted=0;

SELECT setval('system_menu_seq', GREATEST((SELECT MAX(id) FROM system_menu), 30232));

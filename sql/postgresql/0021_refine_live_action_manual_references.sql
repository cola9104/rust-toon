-- Add reference usage and task-specific execution rules without replacing edits.
WITH additions(key, content) AS (VALUES
('README', $m$参考图仅展示摄影质感，不是角色身份、服装、地点或时代的默认设定。不得把示例人物加入剧本。项目基底固定成像方式，镜头世界层来自当前剧本，不限定只有古代和现代两种。画幅、人数与构图服从当前任务。$m$),
('prefix', $m$提示词组合顺序：当前主体与动作 → 场景和世界事实 → 真人摄影基底 → 当前镜头构图与光源 → 必要的一致性约束。只加入本次画面相关的词，空镜不加入皮肤和面部词。支持独立负向栏时才把质量规避词放入负向栏；否则以清晰正向描述为主，不机械粘贴整段负向清单。光源须符合场景设定，高光柔和过渡，暗部保留层次，不强制胶片颗粒、浅景深或固定冷暖色调。$m$),
('art_character', $m$优先采用已确认的角色身份与服装。年龄、肤色、体型和五官不得统一成同一种审美模板，儿童和老年角色按真实年龄呈现。设定图构图服从生成任务的指定视图、人数和画幅，全身视图须完整呈现头脚；不要额外添加特写或四视图。使用均匀柔光保持身份细节可读，避免以戏剧性暗影遮住面部。$m$),
('art_character_derivative', $m$将不可变身份特征与可变妆发服饰分开。普通换装保持骨相、面部标志和身体比例；明确的年龄变化或变身允许相应变化，同时保留可识别身份线索。不因换装自动上浓妆、美白或修改发色。参考图中的站姿、背景及其他人物不得自动继承。$m$),
('art_scene', $m$空间参考优先展示入口、主要通道、固定家具和前后层次，采用足够景深使空间关系可读；避免浅景深遮挡布局。材质新旧程度由输入决定，真实不等于脏乱或破败。默认无人仅适用于场景资产，不能沿用到明确要求人物出镜的分镜。$m$),
('art_scene_derivative', $m$先列出保持不变的空间锚点，再描述本次唯一变化。日夜变化调整光源而不移动门窗家具；损坏、积水等持久状态只在明确要求时增加，并保持先前已确认状态。临时动作与人物活动留给分镜。$m$),
('art_prop', $m$优先保证物件完整、比例可信、关键功能结构可辨。磨损只按输入添加，新品允许干净完好；具有奇幻或未来能力的道具按世界设定保留，以可信材质和摄影光线表现。文字按当前生成任务规则处理，不擅自加入品牌、水印或说明标签。$m$),
('art_prop_derivative', $m$用基础物件作为结构参照，明确“保持项”和“变化项”。开合和破损应具有连贯结构；奇幻道具按已确认的世界规则变化，不能因真人基底删除其超自然能力。多个状态分别生成，不在单图中无故拼接时间序列。$m$),
('director_storyboard', $m$绑定参考图时区分用途：角色参考锁定身份，场景参考锁定空间，道具参考锁定结构，风格示例只参考成像。当前分镜决定姿态、位置、服装和人数，不能把示例人物混入画面。焦段与景深服务于景别，不照搬设定图构图；所有要求出镜的主体保持可辨。奇幻特效须有可信的遮挡、反射与环境光交互。$m$),
('art_storyboard_video', $m$描述顺序为主体初始状态、主要动作、摄影机运动和结束状态；动作数量与时长匹配。默认维持同镜头服化道和空间连续，只有剧本明确指定变装或转场时才发生变化。快慢节奏由情节决定，不强制缓慢。曝光可以随明确光源变化自然调整，避免无原因闪烁。$m$),
('director_planning_style', $m$按场确定世界事实、主要光源、空间锚点与角色造型，并明确哪些会在下一场变化。统一肤色还原和材质尺度，不要求全片使用相同色温、焦距或灯光。参考图是质感示例，不构成全片选角或场景限定；视觉手册不指定叙事类型、音乐流派或时代乐器。$m$),
('director_storyboard_table_style', $m$沿用现有分镜表字段，不自造必须新增的系统字段。每镜明确可见主体、位置、动作与衔接状态；世界事实写入现有场景或画面描述。遵守当前分镜表模板对光影描述的要求，不因本手册重复塞入摄影参数。自查人物身份、服装、物件状态和空间位置是否连续，转场前后差异是否有剧情依据。$m$)
), updated AS (
 SELECT manual.id, jsonb_agg(
   CASE WHEN additions.content IS NOT NULL
          AND position('## 执行补充 v2' IN COALESCE(entry.item->>'data', '')) = 0
     THEN jsonb_set(entry.item, '{data}', to_jsonb(COALESCE(entry.item->>'data', '') || E'\n\n## 执行补充 v2\n\n' || additions.content))
     ELSE entry.item END ORDER BY entry.ordinality) AS data
 FROM toonflow.creative_manuals manual
 CROSS JOIN LATERAL jsonb_array_elements(manual.data) WITH ORDINALITY entry(item, ordinality)
 LEFT JOIN additions ON additions.key = entry.item->>'value'
 WHERE manual.kind='visual' AND manual.path='realpeople_cinematic_base'
 GROUP BY manual.id
)
UPDATE toonflow.creative_manuals manual SET data=updated.data
FROM updated WHERE manual.id=updated.id AND manual.data IS DISTINCT FROM updated.data;

UPDATE toonflow.creative_manuals
SET images='["/toonflow-resources/art_skills/realpeople_cinematic_base/reference-v1.png"]'::jsonb
WHERE kind='visual' AND path='realpeople_cinematic_base' AND images='[]'::jsonb;

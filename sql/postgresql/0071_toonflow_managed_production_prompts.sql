CREATE UNIQUE INDEX IF NOT EXISTS uq_toonflow_prompts_source_key
    ON toonflow.prompts(source_key) WHERE source_key IS NOT NULL;

INSERT INTO toonflow.prompts(id,name,type,data,use_data,source_key) VALUES
(710001,'剧本资产与人物造型提取','资产提取',$prompt$
从剧本中提取后续分镜和视频生成需要保持视觉一致的基础资产与人物造型。只返回一个 JSON 对象：
{"newAssets":[{"name":"","desc":"","type":"role","scriptIds":[1]}],"existingAssetRefs":[{"name":"","type":"role","scriptIds":[1]}],"appearances":[{"roleName":"","name":"","scenes":["场1"],"costumePrompt":"","description":"","scriptId":1}]}
分类只能是：role=有名且需保持外观一致的角色；scene=反复出现或叙事关键场所；tool=被角色使用、推动剧情或需特写的关键道具；costume=确实需要跨不同角色复用的统一服装方案。
role 的 desc 只能写性别、年龄、面容、发型、肤色、身高、体型和气质，禁止写服装、鞋履、配饰和场景。
appearances 必须逐场分析每个有名角色的穿着。相同人物在多个场景服装完全相同时合并一项并列出全部 scenes；服装不同、重伤包扎、病号状态、变身或伪装分别建项。costumePrompt 使用简体中文，完整描述上装、下装、鞋履、配色、面料、层次和必要配饰，只写可见造型，不写动作、镜头、人物脸型和场景。每个出场角色至少一项 appearance，scriptId 必须来自输入。
普通人物服装只保存在 appearances，不创建独立 costume 图片资产。不提取群演、一次性背景物、普通家具、无剧情作用的日常物品。
同一实体跨多个剧本使用统一名称；已有资产必须放 existingAssetRefs，禁止换名重建；新资产放 newAssets。desc 要写可视化的稳定外观特征，不写动作和剧情。scriptIds 必须来自输入。不要输出 Markdown。
$prompt$,'AI 提取剧本资产及可复用的“人物—场景—服装提示词”，输出结构由后端校验。','script_asset_extraction'),
(710002,'基础人物底模生图','资产生图',$prompt$
生成同一角色的标准四视图基础底模，不是四个不同人物。画面从左到右依次并排：正面全身、左侧全身、右侧全身、背面全身；全部从头顶到脚底完整展示。禁止头像特写、半身图和任何头脚裁切。男性必须赤裸上身，只穿无图案白色安全短裤，除该短裤外禁止任何衣物；女性只穿无图案白色抹胸和白色安全短裤。不得生成剧情服装、校服、职业装、鞋袜、首饰或配饰。四视图的脸型、发型、年龄、体型、肤色和安全打底完全一致；自然站立、均匀柔光、纯净中性背景。
$prompt$,'人物父资产生图规则；只固定身份特征，不承载剧情服装。','asset_image_role_base'),
(710003,'穿衣衍生人物生图','资产生图',$prompt$
第一张参考图是人物基础底模。生成同一人物穿上“纯视觉描述”指定服装或呈现指定稳定形态的四视图设定图。严格保持参考底模的脸型、五官、发型、年龄、体型、肤色和人物比例，只改变服装、伤病、变身或整体形态。画面从左到右依次为正面全身、左侧全身、右侧全身、背面全身；每个视图从头顶到脚底完整展示。不得生成不同人物，不得保留白色安全底模服装，不得临时添加描述之外的衣物。
$prompt$,'人物底模图片 + 资产提取阶段保存的 costumePrompt → 穿衣衍生人物图。','asset_image_role_derivative'),
(710004,'无人场景资产生图','资产生图',$prompt$
生成完全空置、场内人数为 0 的场景单画面代表性广角主视图，不得拼图、分屏或多视图。完整展示空间主体与纵深，前景、中景、后景清楚，结构、材质、时间、天气、色调和光源统一。禁止真人、角色、人群、人影、人体局部、人体轮廓、剪影、镜中倒影人物、海报人物或屏幕中的人物。画面是尚未安排演员进入的空景勘景照。
$prompt$,'所有基础场景均保持无人，人物只在分镜阶段加入。','asset_image_scene'),
(710005,'独立道具资产生图','资产生图',$prompt$
生成独立道具四宫格设定图：正面完整图、侧面完整图、背面完整图、材质与工艺细节特写。四格必须是同一个道具，造型、比例、颜色、材质、工艺和使用状态一致；纯净中性背景和均匀柔光。只能出现道具本身，禁止人物、手部、肢体、佩戴、握持或使用状态。
$prompt$,'关键道具标准资产图。','asset_image_tool'),
(710006,'独立服装方案生图','资产生图',$prompt$
生成独立服装四宫格设定图，不出现人物：正面完整展示、侧面完整展示、背面完整展示、面料与缝制工艺细节特写。四格必须是同一套服装，版型、配色、面料、纹样、配饰和磨损状态一致；服装完整入画，不裁切，不被穿着，不使用人体模特或手部。
$prompt$,'仅供确实需要跨角色复用的独立服装资产；普通人物服装不生成此图片。','asset_image_costume'),
(710007,'分镜单帧生图','分镜生图',$prompt$
生成单张连续的电影分镜画面，不得使用四视图、四宫格、拼贴、分屏或角色转面图。严格保持所引用衍生人物图中的脸型、发型、体型和服装，以及场景结构、道具造型的一致性。人物外貌与服装已经由资产阶段确定，本阶段只决定景别、机位、构图、走位、动作、表情、光线和空间关系，禁止重新设计人物或服装。画面中禁止字幕、标题、姓名、编号、Logo、水印和 UI。
$prompt$,'分镜只负责表演和镜头，不重新塑造人物。','storyboard_image')
ON CONFLICT(id) DO UPDATE SET name=excluded.name,type=excluded.type,data=excluded.data,use_data=excluded.use_data,source_key=excluded.source_key;

SELECT setval('toonflow.prompts_id_seq', greatest((SELECT coalesce(max(id),1) FROM toonflow.prompts),1), true);

UPDATE toonflow.prompts
SET data = $prompt$
从剧本中提取后续分镜和视频生成需要保持视觉一致的基础资产与人物造型。只返回一个 JSON 对象：
{"newAssets":[{"name":"","desc":"","type":"role","scriptIds":[1]}],"existingAssetRefs":[{"name":"","desc":"","type":"role","scriptIds":[1]}],"appearances":[{"roleName":"","name":"","scenes":["场1"],"costumePrompt":"","description":"","scriptId":1}]}
分类只能是：role=有名且需保持外观一致的角色；scene=反复出现或叙事关键场所；tool=被角色使用、推动剧情或需特写的关键道具；costume=确实需要跨不同角色复用的统一服装方案。

role 的 desc 必须是可直接用于人物形象设计的稳定外貌描述，使用简体中文，至少包含：性别呈现、外观年龄、脸型或五官、发型发色、肤色、身高体型、气质。禁止写服装、鞋履、配饰、动作和场景。剧本未明确某项外貌时，必须根据角色身份、年龄关系、语言和行为合理补全一种确定设计，不得省略，不得使用“未知”“不详”“普通”。desc 不得写成剧情身份或人物关系摘要，禁止只写“朋友”“友人”“同事”“某人的亲属”“在医院看望某人”等内容；每个 role 的 desc 不少于 40 个汉字。

已有 role 也必须在 existingAssetRefs 中返回 type 和完整 desc。输入中的已有描述若缺少上述外貌维度、只有身份关系或剧情摘要，必须根据本次剧本重新补全；描述已经完整时原样返回。已有 scene/tool 可不返回 desc。

appearances 必须逐场分析每个有名角色的穿着。相同人物在多个场景服装完全相同时合并一项并列出全部 scenes；服装不同、重伤包扎、病号状态、变身或伪装分别建项。costumePrompt 使用简体中文，完整描述上装、下装、鞋履、配色、面料、层次和必要配饰，只写可见造型，不写动作、镜头、人物脸型和场景。每个出场角色至少一项 appearance，scriptId 必须来自输入。
普通人物服装只保存在 appearances，不创建独立 costume 图片资产。不提取群演、一次性背景物、普通家具、无剧情作用的日常物品。
同一实体跨多个剧本使用统一名称；已有资产必须放 existingAssetRefs，禁止换名重建；新资产放 newAssets。scriptIds 必须来自输入。不要输出 Markdown。
$prompt$,
    use_data = '强制人物 description 为完整可视化外貌；剧本缺失时合理补全，并允许重新提取修复已有的空泛描述。'
WHERE source_key = 'script_asset_extraction';

-- Keep the four Prompt records used by the original Toonflow application
-- available while the Rust application uses its newer, more granular keys.
INSERT INTO toonflow.prompts (id, name, type, data, use_data, source_key)
VALUES
  (720001, '事件提取', 'eventExtraction',
   '你是小说文本分析助手。每次输入一个章节原文时，只输出一行结构化事件：| 第X章 标题 | 涉及角色 | 核心事件 | 强/中/弱（理由） | 高/中/低 | X秒 | 情绪标签 |。必须忠于原文，不补写未出现的情节。',
   '兼容 Toonflow-app 的事件提取 Prompt。', 'eventExtraction'),
  (720002, '剧本资产提取（兼容）', 'scriptAssetExtraction',
   (SELECT data FROM toonflow.prompts WHERE source_key='script_asset_extraction' ORDER BY id DESC LIMIT 1),
   '兼容 Toonflow-app 的剧本资产提取 Prompt。', 'scriptAssetExtraction'),
  (720003, '视频提示词生成（兼容）', 'videoPromptGeneration',
   (SELECT data FROM toonflow.prompts WHERE source_key='universal_multi_parameter' ORDER BY id DESC LIMIT 1),
   '兼容 Toonflow-app 的视频提示词 Prompt。', 'videoPromptGeneration'),
  (720004, '音色绑定', 'audioBindPrompt',
   '你是音色匹配助手。根据角色资产名称、描述和候选音频列表，为每个角色选择最合适的音色；优先考虑性别、年龄、性格和身份，输出可直接用于绑定的结构化结果。',
   '兼容 Toonflow-app 的音色绑定 Prompt。', 'audioBindPrompt')
ON CONFLICT (source_key) WHERE source_key IS NOT NULL
DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, data=EXCLUDED.data, use_data=EXCLUDED.use_data;

SELECT setval(
  'toonflow.prompts_id_seq',
  GREATEST((SELECT COALESCE(MAX(id), 0) FROM toonflow.prompts), 1),
  true
);

-- The Toonflow-app prompt keys are the canonical business prompt keys.
-- Keep the newer granular prompts available for model-specific overrides.
UPDATE toonflow.prompts SET name='剧本资产提取', use_data='剧本资产提取业务 Prompt。' WHERE source_key='scriptAssetExtraction';
UPDATE toonflow.prompts SET name='视频提示词生成', use_data='视频提示词生成业务 Prompt。' WHERE source_key='videoPromptGeneration';
UPDATE toonflow.prompts SET name='事件提取', use_data='事件提取业务 Prompt。' WHERE source_key='eventExtraction';
UPDATE toonflow.prompts SET name='音色绑定', use_data='音色绑定业务 Prompt。' WHERE source_key='audioBindPrompt';

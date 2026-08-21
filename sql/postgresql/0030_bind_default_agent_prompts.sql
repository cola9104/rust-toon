-- Agent 编排是默认业务流程；高级 Prompt 仍可覆盖这些绑定。
UPDATE toonflow.agent_deployments
SET prompt_source_key = CASE key
  WHEN 'universalAi' THEN 'eventExtraction'
  WHEN 'scriptAgent' THEN 'scriptAssetExtraction'
  WHEN 'videoGeneration' THEN 'videoPromptGeneration'
  WHEN 'ttsDubbing' THEN 'audioBindPrompt'
  ELSE prompt_source_key
END
WHERE key IN ('universalAi', 'scriptAgent', 'videoGeneration', 'ttsDubbing');

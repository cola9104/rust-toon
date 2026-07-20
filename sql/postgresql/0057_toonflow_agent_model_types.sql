ALTER TABLE toonflow.agent_deployments
    ADD COLUMN IF NOT EXISTS model_type varchar(32) NOT NULL DEFAULT 'chat';

UPDATE toonflow.agent_deployments
SET model_type = CASE WHEN key = 'ttsDubbing' THEN 'speech' ELSE 'chat' END;

INSERT INTO toonflow.agent_deployments
    (key, name, description, disabled, temperature, max_output_tokens, model_type)
VALUES
    ('imageGeneration', '图片生成', '用于资产图、分镜图和图片工作流，只能绑定已启用的图片模型', false, 1, 0, 'image'),
    ('videoGeneration', '视频生成', '用于分镜视频生成，只能绑定已启用的视频模型', false, 1, 0, 'video')
ON CONFLICT (key) DO UPDATE SET
    name = excluded.name,
    description = excluded.description,
    model_type = excluded.model_type;

ALTER TABLE toonflow.agent_deployments
    DROP CONSTRAINT IF EXISTS agent_deployments_model_type_check;
ALTER TABLE toonflow.agent_deployments
    ADD CONSTRAINT agent_deployments_model_type_check
    CHECK (model_type IN ('chat', 'image', 'video', 'speech'));

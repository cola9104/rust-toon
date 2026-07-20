UPDATE toonflow.prompts
SET data = '生成单人角色标准设定图，突出稳定的面部、发型、体型与服饰特征。',
    use_data = '恢复 GitCode origin/main 的角色标准设定图规则。'
WHERE source_key IN ('asset_image_role_base', 'asset_image_role_derivative');

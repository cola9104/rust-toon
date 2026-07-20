UPDATE toonflow.prompts
SET data = '生成角色标准四视图，完整展示人物稳定的面部、发型、体型与服饰特征。',
    use_data = '对齐 Toonflow-app：角色标准四视图。'
WHERE source_key = 'asset_image_role_base';

UPDATE toonflow.prompts
SET data = '生成同一角色的标准四视图，保持参考图中的人物身份、面部、发型和体型一致，并应用提示词指定的服装或形态。',
    use_data = '对齐 Toonflow-app：参考基础角色生成衍生角色标准四视图。'
WHERE source_key = 'asset_image_role_derivative';

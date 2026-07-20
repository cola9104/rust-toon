CREATE TABLE toonflow.character_appearances (
    id bigint PRIMARY KEY,
    project_id bigint NOT NULL REFERENCES toonflow.projects(id) ON DELETE CASCADE,
    script_id bigint NOT NULL REFERENCES toonflow.scripts(id) ON DELETE CASCADE,
    role_asset_id bigint NOT NULL REFERENCES toonflow.assets(id) ON DELETE CASCADE,
    name text NOT NULL,
    scenes jsonb NOT NULL DEFAULT '[]'::jsonb,
    costume_prompt text NOT NULL,
    description text NOT NULL DEFAULT '',
    create_time bigint NOT NULL,
    update_time bigint NOT NULL,
    UNIQUE(script_id, role_asset_id, name)
);

CREATE INDEX idx_toonflow_character_appearances_script
    ON toonflow.character_appearances(script_id, role_asset_id);

ALTER TABLE toonflow.assets
    ADD COLUMN appearance_id bigint REFERENCES toonflow.character_appearances(id) ON DELETE SET NULL;

CREATE INDEX idx_toonflow_assets_appearance ON toonflow.assets(appearance_id);

UPDATE toonflow.skill_list
SET content = $skill$
---
name: production_execution_derive_assets.md
description: 将资产提取阶段保存的人物场景造型转换为可生成的衍生人物资产。
---
# 人物造型衍生写入

1. 调用 `get_flowData("assets")`。每个人物父资产包含 `appearances`，其中 `id` 是造型ID，`name` 是造型名称，`scenes` 是适用场景，`costumePrompt` 是已经在资产提取阶段确定的服装提示词。
2. 逐一遍历所有人物的全部 appearances，不得重新设计、改写或遗漏服装。
3. 若该 appearance 尚无对应 derive，调用：
   `add_deriveAsset({assetsId, appearanceId, id:null, name, desc:costumePrompt})`。
4. 同一 appearance 只创建一条 derive，并在其 scenes 中跨场景复用。
5. 剧本明确需要但 appearances 中缺失的造型必须报告为“资产提取不完整”，停止并要求返回剧本资产提取阶段，禁止临时编造。
6. 已有重伤、变身等 derive 若没有 appearanceId 可以保留，但不能代替 appearances 中的服装造型。
7. 完成后展示“人物—场景—造型—衍生资产”完整映射，暂不生成图片。
$skill$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_execution_derive_assets.md';

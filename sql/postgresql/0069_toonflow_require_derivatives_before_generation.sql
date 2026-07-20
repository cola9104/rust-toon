UPDATE toonflow.skill_list
SET content = content || $rule$

## 生成前完整性门禁（最高优先级）

- 若 assets 中任一当前剧本出场人物的 `derive` 为空，说明场景服装衍生分析未完成；必须报告缺失人物并停止，禁止声称图片生成完成。
- “没有待生成图片”只有在每个出场人物都有至少一条 derive，且所有 derive 都已有 `imageFilePath` 时，才表示全部完成。
- 不得把“无衍生资产”显示为成功结果，不得在存在无衍生人物时进入导演规划。
$rule$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_execution_generate_assets.md';

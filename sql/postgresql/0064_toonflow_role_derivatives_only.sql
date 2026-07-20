UPDATE toonflow.skill_list
SET content = content || $rule$

## 当前项目衍生资产覆盖规则（最高优先级）

- 只有 `type=role` 的人物基础资产允许创建衍生资产。
- 人物衍生仅用于换装、变身特效或稳定的整体形态变化。
- `scene` 场景不创建衍生资产；时段、天气、角度变化在分镜图阶段表达。
- `tool` 道具不创建衍生资产，也不得把基础道具 ID 交给 `generate_deriveAsset`。
- 调用 `generate_deriveAsset` 前必须确认每个 ID 都来自人物资产的 `derive` 数组，禁止传入任何基础资产 ID。
$rule$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path IN (
    'production_execution_derive_assets.md',
    'production_execution_generate_assets.md'
);

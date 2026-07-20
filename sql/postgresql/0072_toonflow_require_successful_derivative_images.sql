UPDATE toonflow.skill_list
SET content = content || $rule$

## 衍生图片强制完成门禁（最高优先级）

- 当前剧本只要存在人物衍生资产，衍生图片生成就是必做阶段，不是可选阶段；禁止建议跳过、部分生成或仅使用文字提示词继续。
- `run_sub_agent_generate_assets` 返回错误、超时或任一图片没有 `filePath` 时，必须停止流水线，明确报告失败原因；禁止询问是否进入导演规划或后续阶段。
- 图片服务恢复后，必须重新派发全部尚无 `imageFilePath` 的衍生资产。只有全部衍生图片实际生成成功并写入后，才能进入导演规划。
- 只有衍生资产分析明确得出当前剧本无需任何人物换装或形态变化，才可直接进入导演规划。
$rule$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_agent_decision.md';

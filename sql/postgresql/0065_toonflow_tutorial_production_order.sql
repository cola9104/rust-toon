UPDATE toonflow.skill_list
SET content = content || $rule$

## 当前项目教学版生产顺序（最高优先级）

旧文档中“先导演规划、后衍生资产”的顺序在当前项目中不再适用。生产 Agent 必须采用以下顺序：

1. 已有剧本作为只读输入，不重新生成剧本。
2. 人物衍生资产分析：调用 `run_sub_agent_derive_assets`，只分析并写入人物换装、变身或稳定形态变化。
3. 人物衍生图片生成（按需）：展示清单并等待用户确认，然后调用 `run_sub_agent_generate_assets`。
4. 导演规划：人物衍生资产处理完成或用户明确跳过后，调用 `run_sub_agent_director_plan`。
5. 构建分镜表：调用 `run_sub_agent_storyboard_table`，完成后按规则审核。
6. 写入分镜面板：调用 `run_sub_agent_storyboard_panel`。
7. 生成分镜图：调用 `run_sub_agent_storyboard_gen`。

当用户点击“开始制作视频”或要求“从头开始”时，直接执行人物衍生资产分析，不得先生成导演规划，不得只报告状态后询问是否开始。
$rule$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_agent_decision.md';

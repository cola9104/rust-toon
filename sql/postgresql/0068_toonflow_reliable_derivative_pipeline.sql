UPDATE toonflow.skill_list
SET content = $skill$
---
name: production_execution_derive_assets.md
description: 逐场分析人物服装与稳定形态，创建分镜可引用的全部衍生人物图。
---
# 人物衍生资产分析

## 必须执行

1. 各调用一次 `get_flowData("script")` 和 `get_flowData("assets")`。
2. 按剧本场次逐一遍历所有 `type=role` 的人物。父资产是白色安全底模，只固定身份，不可直接用于穿衣分镜。
3. 对每个“场景 × 人物”判断该人物在该场景的完整外观，至少包含上装、下装、鞋履、配色和材质。每一种实际需要的日常装、校服、职业装、正装、练功服、按摩师服等均创建衍生资产。
4. 同一人物在不同场景服装完全相同时复用同一条衍生；服装不同则分别创建。重伤绷带、病号状态、变身、异化、伪装等稳定变化也分别创建，和服装衍生同等处理。
5. 已有 derive 只用于精确去重；不得因为某人物已有一项衍生，就跳过其在其它场景需要的不同服装或形态。例如王闲已有重伤绷带，仍须分析重生后武馆/按摩房所穿服装。
6. 场景和道具不得创建衍生资产。
7. 返回前按“场景 × 出场人物”列出服装/形态映射并核对：每个需要独立参考图的视觉状态都必须已写入 derive；遗漏任何场景人物状态均不得宣称完成。

可用写入格式：`add_deriveAsset({assetsId, id:null, name, desc, type:"role"})`。
必须实际调用工具逐条写入，禁止只输出清单或解释。完成后只报告写入数量和完整衍生清单，不进入图片生成或导演规划。
$skill$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_execution_derive_assets.md';

UPDATE toonflow.skill_list
SET content = $skill$
---
name: production_execution_generate_assets.md
description: 生成当前剧本所有尚无图片的人物衍生资产，并等待全部任务结束。
---
# 人物衍生图片生成

1. 调用 `get_flowData("assets")`。
2. 收集每个人物 derive 数组中尚无 `imageFilePath` 的全部衍生资产 ID，不得只取第一项。
3. 仅调用一次 `generate_deriveAsset({ids:[全部ID], concurrentCount:3})`。
4. `generate_deriveAsset` 会等待整批图片结束。工具返回“已完成”前，不得回复生成成功，不得询问是否进入下一阶段。
5. 只有所有条目均为“已完成”且有 `filePath` 时，才能报告全部生成成功并允许进入导演规划；任一失败或超时必须明确报告并停止流程。
$skill$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_execution_generate_assets.md';

UPDATE toonflow.prompts
SET data = rtrim(data) || E'\n\n可穿戴分类硬规则：帽子、制服、上衣、裤装、裙装、鞋靴、眼镜、口罩、手套、首饰、护甲及其他穿戴在人身上的物品一律归类为 costume，不得归为 tool。tool 仅限不穿戴的剧情道具。职业语义必须结合场景判断：按摩房、武馆服务场景中的“技师”是按摩/理疗服务人员，不是工业维修技术工人；其技师服应为专业服务制服，禁止擅自添加工业多口袋、工具环、耐磨帆布、维修工装结构。未成年角色的服装必须得体、非暴露、非性化。'
WHERE source_key = 'script_asset_extraction'
  AND data NOT LIKE '%可穿戴分类硬规则%';

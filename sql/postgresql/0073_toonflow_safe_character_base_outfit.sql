UPDATE toonflow.prompts
SET data = $prompt$
生成同一角色的标准四视图基础底模，不是四个不同人物。画面从左到右依次并排：正面全身、左侧全身、右侧全身、背面全身；全部从头顶到脚底完整展示。禁止头像特写、半身图和任何头脚裁切。
所有性别统一穿安全中性训练服：浅灰色无图案圆领短袖T恤、同色及膝直筒运动短裤、浅灰色无标识低帮运动鞋。服装宽松合体、完全不透明，完整覆盖胸部、腹部、臀部和大腿上部。禁止赤裸上身、抹胸、内衣、泳装、贴身衣、暴露服装及可见乳头。
不得生成剧情服装、校服、职业装、首饰或配饰。四视图的脸型、发型、年龄、体型、肤色和安全训练服完全一致；自然站立、均匀柔光、纯净中性背景。
$prompt$,
    use_data = '安全中性训练服人物父资产；只固定身份和体型特征，不承载剧情服装，并避免参考图触发内容审核。'
WHERE source_key = 'asset_image_role_base';

UPDATE toonflow.prompts
SET data = replace(
        data,
        '不得保留白色安全底模服装',
        '必须完全替换浅灰色安全中性训练服，不得在成片中保留底模T恤、运动短裤或运动鞋'
    )
WHERE source_key = 'asset_image_role_derivative';

UPDATE toonflow.skill_list
SET content = content || $rule$

## 安全中性人物底模规则（最高优先级）

- 人物父资产统一使用浅灰色不透明短袖训练服、及膝运动短裤和无标识运动鞋；旧规则中的赤裸上身、抹胸或白色安全短裤不再适用。
- 剧本正式服装仍全部作为人物衍生资产；生成衍生图时必须完全替换安全训练服，不得将底模服保留到衍生人物图中。
- 旧人物父资产若仍为裸上身、抹胸或类似内衣造型，必须先重新生成安全底图，否则图片服务可能拒绝其作为参考图。
$rule$,
    update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path IN ('production_execution_derive_assets.md', 'production_execution_generate_assets.md');

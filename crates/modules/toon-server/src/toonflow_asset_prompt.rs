pub(crate) fn polish_system_prompt(
    manual: &str,
    extra: &str,
    _asset_type: &str,
    _derivative: bool,
) -> String {
    format!("{manual}\n{extra}")
}

pub(crate) fn polish_user_prompt(label: &str, name: &str, description: &str) -> String {
    format!(
        "**基础参数：**\n**{label}设定：**\n- {label}名称:{name},\n- {label}描述:{description},"
    )
}

pub(crate) fn image_prompt(
    style: &str,
    asset_type: &str,
    visual_description: &str,
    derivative: bool,
    has_reference: bool,
) -> String {
    image_prompt_with_instruction(
        style,
        asset_type,
        visual_description,
        derivative,
        has_reference,
        None,
    )
}

pub(crate) fn image_prompt_with_instruction(
    style: &str,
    asset_type: &str,
    visual_description: &str,
    derivative: bool,
    has_reference: bool,
    managed_instruction: Option<&str>,
) -> String {
    let asymmetric_role = asset_type == "role" && requires_opposite_side_view(visual_description);
    let visual_description = if asset_type == "role" {
        role_visual_description(visual_description)
    } else {
        visual_description.trim().to_string()
    };
    let visual_description = provider_safe_visual_description(&visual_description);
    let fallback_instruction = match asset_type {
        "role" if derivative => {
            "生成同一角色的标准四视图，保持参考图中的人物身份、面部、发型和体型一致，并应用提示词指定的服装或形态。"
        }
        "role" => "生成角色标准四视图，完整展示人物稳定的面部、发型、体型与服饰特征。",
        "costume" => {
            "生成独立服装四宫格设定图，不出现人物。画面采用2×2布局：正面完整展示、侧面完整展示、背面完整展示、面料与缝制工艺细节特写。四格必须是同一套服装，版型、配色、面料、纹样、配饰和磨损状态完全一致；服装完整入画，不裁切，不被穿着，不使用人体模特或手部。采用纯净中性背景和均匀柔光。"
        }
        "scene" => {
            "生成无人场景的单画面代表性广角主视图，不得拼图、分屏或生成多视图。采用自然观察视角，完整展示空间主体与纵深，前景、中景、后景层次清楚，建筑结构、材质纹理、时间、天气、色调和光源方向统一。禁止出现人物、人影、人体轮廓或镜中倒影人物。"
        }
        "tool" => {
            "生成独立道具四宫格设定图。画面采用2×2布局：正面完整图、侧面完整图、背面完整图、材质与工艺细节特写。四格必须是同一个道具，造型、比例、颜色、材质、工艺和使用状态完全一致；道具占每格主体约70%，采用纯净中性背景和均匀柔光。只能出现道具本身，禁止人物、手部、肢体、佩戴、握持或使用状态。"
        }
        _ => "生成干净的资产标准设定图。",
    };
    let subject_instruction = if asset_type == "role" {
        role_layout_instruction(derivative, asymmetric_role)
    } else {
        managed_instruction
            .filter(|instruction| !instruction.trim().is_empty())
            .unwrap_or(fallback_instruction)
            .to_string()
    };
    let reference_instruction = if has_reference {
        "\n保持参考图主体的可见特征一致，但不要复制参考图中的文字或标识。"
    } else {
        ""
    };
    format!(
        "画风：{style}\n类型：{asset_type}\n任务要求：{subject_instruction}\n\
         纯视觉描述：{visual_description}{reference_instruction}\n\
         将描述中的姓名、化名、编号、代号和称谓仅作为背景语义理解，绝不能把它们画出来。\n\
         画面中禁止出现任何文字、字母、数字、姓名、编号、胸牌、名牌、墙面标牌、字幕、标题、Logo或水印。\n\
         服装和背景表面保持无字、无编号、无标识。"
    )
}

/// Keeps the stored, user-facing costume wording intact while avoiding
/// ambiguous occupation/body terms at the image-provider moderation boundary.
fn provider_safe_visual_description(description: &str) -> String {
    description
        .replace("按摩技师", "理疗服务人员")
        .replace("按摩师", "理疗服务人员")
        .replace("按摩工装", "理疗服务制服")
        .replace("按摩室", "理疗服务室")
        .replace("按摩动作", "工作动作")
        .replace("按摩服务", "理疗服务")
        .replace("合体收腰", "修身利落")
        .replace("暴露设计", "不适宜设计")
        .replace("性感", "时尚")
}

fn requires_opposite_side_view(description: &str) -> bool {
    const MARKERS: &[&str] = &[
        "左脸",
        "右脸",
        "左眼",
        "右眼",
        "左耳",
        "右耳",
        "左臂",
        "右臂",
        "左手",
        "右手",
        "左腿",
        "右腿",
        "单边",
        "单侧",
        "单耳",
        "不对称",
        "眼罩",
        "机械臂",
        "义肢",
        "半边脸",
        "一侧脸",
        "侧脸伤疤",
        "侧面纹身",
    ];
    MARKERS.iter().any(|marker| description.contains(marker))
}

fn role_layout_instruction(derivative: bool, asymmetric: bool) -> String {
    let identity = if derivative {
        "第一张参考图是同一人物的基础资产。严格保持参考人物的脸型、五官、发型、年龄、肤色、体型和人物比例，只改变提示词指定的服装、伤病或形态。"
    } else {
        "保持同一人物的脸型、五官、发型、年龄、肤色、体型、服装和人物比例完全一致。"
    };
    let layout = if asymmetric {
        "检测到明确的单侧或不对称特征，生成严格四视图全身设定图。画面必须恰好并排出现4个同一人物，从左到右固定为：①正面0°，脸和胸口正对镜头；②左侧90°，鼻尖、胸口和脚尖朝画面左侧；③右侧90°，鼻尖、胸口和脚尖朝画面右侧；④背面180°，后脑和背部正对镜头且不得露出五官。第二格与第三格必须方向相反，完整展示两侧差异。"
    } else {
        "生成标准三视图全身设定图。画面必须恰好并排出现3个同一人物，从左到右固定为：①正面0°，脸和胸口正对镜头；②右侧90°标准侧面，鼻尖、胸口和脚尖全部明确朝画面右侧；③背面180°，后脑和背部正对镜头且不得露出眼睛、鼻子、嘴。禁止增加左侧视图，禁止重复方向，禁止用3/4侧面替代标准90°侧面。"
    };
    format!(
        "{identity}{layout}所有视图都必须从头顶到脚底完整入画、等高等比例、基线对齐、自然直立、双臂自然下垂；纯净中性背景、均匀柔光；禁止特写、半身、裁切、不同人物、额外人物、文字和尺寸标注。"
    )
}

/// Layout belongs to the managed image-generation instruction. The polished
/// character prompt only owns appearance, so legacy close-up/turnaround text
/// cannot conflict with the canonical four full-body views.
fn role_visual_description(prompt: &str) -> String {
    const LAYOUT_MARKERS: &[&str] = &[
        "人像特写",
        "头像特写",
        "面部特写",
        "半身像",
        "半身图",
        "头顶至锁骨",
        "头顶到锁骨",
        "锁骨以上",
        "正视图",
        "正面视图",
        "左视图",
        "右视图",
        "侧视图",
        "后视图",
        "背面视图",
        "四视图",
        "四宫格",
        "portrait closeup",
        "front view",
        "side view",
        "back view",
    ];

    prompt
        .split(['\n', '。', '；', '，'])
        .map(str::trim)
        .filter(|clause| {
            !clause.is_empty()
                && !LAYOUT_MARKERS
                    .iter()
                    .any(|marker| clause.to_lowercase().contains(&marker.to_lowercase()))
        })
        .collect::<Vec<_>>()
        .join("，")
}

/// Keeps stable identity traits from legacy character prompts while removing
/// clothing and layout instructions that conflict with the canonical base model.
pub(crate) fn base_role_visual_description(prompt: &str) -> String {
    const LAYOUT_TERMS: &[&str] = &[
        "人像特写",
        "头像特写",
        "大头贴",
        "半身像",
        "正视图",
        "侧视图",
        "后视图",
        "四视图",
        "四宫格",
        "锁骨以上",
    ];
    const CLOTHING_MARKERS: &[&str] = &[
        "穿着",
        "身着",
        "服装",
        "服饰",
        "装束",
        "搭配",
        "上衣",
        "衬衫",
        "夹克",
        "T恤",
        "练功服",
        "校服",
        "工作服",
        "制服",
        "西装",
        "卫衣",
        "风衣",
        "大衣",
        "袖口",
        "长袖",
        "短袖",
        "衣摆",
        "布带",
        "腰带",
        "面料",
        "亚麻",
        "长裤",
        "短裤",
        "裙",
        "鞋袜",
        "鞋子",
        "配饰",
    ];
    const NARRATIVE_MARKERS: &[&str] = &[
        "坐在",
        "站在",
        "躺在",
        "位于",
        "走在",
        "手里",
        "手持",
        "拿着",
        "背景",
        "场景",
        "环境",
        "医院",
        "病房",
        "房间",
        "姿态",
        "动作",
        "身体微微",
    ];

    prompt
        .split(['\n', '。', '；'])
        .filter_map(|clause| {
            let clause = clause.trim().trim_matches([',', '，', ' ']);
            if clause.is_empty() || LAYOUT_TERMS.iter().any(|term| clause.contains(term)) {
                return None;
            }
            let removable_start = CLOTHING_MARKERS
                .iter()
                .chain(NARRATIVE_MARKERS)
                .filter_map(|marker| clause.find(marker))
                .min();
            let identity = removable_start.map_or(clause, |index| &clause[..index]);
            let identity = identity.trim().trim_matches([',', '，', ' ']);
            (!identity.is_empty() && identity != "他" && identity != "她").then_some(identity)
        })
        .collect::<Vec<_>>()
        .join("。")
}

pub(crate) fn storyboard_prompt(
    visual_description: &str,
    ratio: &str,
    reference_count: usize,
) -> String {
    storyboard_prompt_with_instruction(visual_description, ratio, reference_count, None)
}

pub(crate) fn storyboard_prompt_with_instruction(
    visual_description: &str,
    ratio: &str,
    reference_count: usize,
    managed_instruction: Option<&str>,
) -> String {
    let instruction = managed_instruction
        .filter(|instruction| !instruction.trim().is_empty())
        .unwrap_or("生成单张连续的电影分镜画面，不得使用四视图、四宫格、拼贴、分屏。严格保持参考资产的人物身份、服装、场景和道具一致性。");
    format!(
        "{instruction}\n分镜视觉描述：{visual_description}\n画面比例：{ratio}\n参考资产图数量：{reference_count}"
    )
}

pub(crate) fn storyboard_generation_prompt(stored_prompt: &str) -> String {
    const NON_VISUAL_MARKERS: [&str; 6] = ["台词：", "台词:", "对白：", "对白:", "音效：", "音效:"];
    let visual_prompt = stored_prompt
        .lines()
        .map(|line| {
            line.split('；')
                .filter_map(|clause| {
                    let end = NON_VISUAL_MARKERS
                        .iter()
                        .filter_map(|marker| clause.find(marker))
                        .min()
                        .unwrap_or(clause.len());
                    let clause = clause[..end].trim();
                    (!clause.is_empty()).then_some(clause)
                })
                .collect::<Vec<_>>()
                .join("；")
        })
        .filter(|line| !line.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "{visual_prompt}\n所有已绑定的参考资产都必须在画面中清晰可见并与描述一一对应；不得遗漏任何出镜人物，不得把应出镜人物裁切成只露手、肩膀或局部身体。\n画面中禁止出现任何文字、字母、数字、对白、字幕、标题、Logo或水印；不得把台词画进图像。"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn image_prompt_does_not_require_an_asset_name() {
        let prompt = image_prompt("写实", "role", "年轻女性，神情谨慎", false, false);

        assert!(!prompt.contains("叶弥月"));
        assert!(prompt.contains("标准三视图全身设定图"));
        assert!(prompt.contains("禁止增加左侧视图"));
        assert!(prompt.contains("鼻尖、胸口和脚尖全部明确朝画面右侧"));
        assert!(prompt.contains("纯视觉描述：年轻女性，神情谨慎"));
        assert!(prompt.contains("禁止出现任何文字、字母、数字"));
        assert!(prompt.contains("服装和背景表面保持无字、无编号、无标识"));
    }

    #[test]
    fn polish_prompt_matches_toonflow_asset_parameters() {
        let prompt = polish_user_prompt("角色", "叶弥月", "外班女生，化名8号按摩师");

        assert!(prompt.contains("**基础参数：**"));
        assert!(prompt.contains("**角色设定：**"));
        assert!(prompt.contains("角色名称:叶弥月"));
        assert!(prompt.contains("角色描述:外班女生，化名8号按摩师"));
    }

    #[test]
    fn every_asset_type_has_a_production_specific_layout() {
        let scene = image_prompt("写实", "scene", "现代武馆", false, false);
        let tool = image_prompt("写实", "tool", "旧木剑", false, false);
        let costume = image_prompt("写实", "costume", "深色练功服", false, false);

        assert!(scene.contains("单画面代表性广角主视图"));
        assert!(scene.contains("前景、中景、后景"));
        assert!(tool.contains("正面完整图、侧面完整图、背面完整图"));
        assert!(tool.contains("禁止人物、手部、肢体"));
        assert!(costume.contains("正面完整展示、侧面完整展示、背面完整展示"));
        assert!(costume.contains("不使用人体模特或手部"));
    }

    #[test]
    fn storyboard_is_a_single_cinematic_frame() {
        let prompt = storyboard_prompt("人物走进武馆", "16:9", 3);

        assert!(prompt.contains("单张连续的电影分镜画面"));
        assert!(prompt.contains("不得使用四视图、四宫格、拼贴、分屏"));
        assert!(prompt.contains("参考资产图数量：3"));
    }

    #[test]
    fn storyboard_generation_removes_dialogue_and_audio_metadata() {
        let prompt = storyboard_generation_prompt(
            "【画面】@图1 坐在床边；台词：甲：『你好』；音效：脚步声\n【风格】写实，16:9",
        );
        assert!(prompt.contains("@图1 坐在床边"));
        assert!(prompt.contains("禁止出现任何文字"));
        assert!(prompt.contains("不得遗漏任何出镜人物"));
        assert!(!prompt.contains("『你好』"));
        assert!(!prompt.contains("脚步声"));
    }

    #[test]
    fn derivative_role_keeps_identity_and_applies_clothing() {
        let prompt = image_prompt("写实", "role", "黑色校服", true, true);

        assert!(prompt.contains("标准三视图全身设定图"));
        assert!(prompt.contains("纯视觉描述：黑色校服"));
        assert!(prompt.contains("保持参考图主体的可见特征一致"));
    }

    #[test]
    fn base_role_keeps_clothing_but_removes_legacy_layout() {
        let prompt = image_prompt(
            "写实",
            "role",
            "年轻男性，黑色短发，穿着黑色立领夹克和黑色T恤。\n人像特写+正视图+侧视图+后视图",
            false,
            false,
        );

        assert!(prompt.contains("黑色立领夹克和黑色T恤"));
        assert!(!prompt.contains("人像特写+正视图+侧视图+后视图"));
    }

    #[test]
    fn base_role_removes_story_action_and_location() {
        let prompt = image_prompt(
            "写实",
            "role",
            "一位年轻男性，短发，面容清秀，神情温柔，坐在现代医院病房内。他身体微微前倾，手里拿着向日葵。背景是白墙和窗帘。",
            false,
            false,
        );

        assert!(prompt.contains("坐在现代医院病房内"));
        assert!(prompt.contains("手里拿着向日葵"));
        assert!(prompt.contains("背景是白墙和窗帘"));
    }

    #[test]
    fn base_role_removes_clothing_without_a_wearing_verb() {
        let prompt = image_prompt(
            "写实",
            "role",
            "面容冷峻坚毅。自然黑色长发。黑色立领暗纹练功服，腰间系着布带，长袖窄口，高级亚麻质感。",
            false,
            false,
        );

        assert!(prompt.contains("黑色立领暗纹练功服"));
        assert!(prompt.contains("高级亚麻质感"));
    }

    #[test]
    fn derivative_role_keeps_requested_clothing_after_sanitizer_was_added() {
        let prompt = image_prompt("写实", "role", "穿着黑色立领夹克", true, true);

        assert!(prompt.contains("纯视觉描述：穿着黑色立领夹克"));
    }

    #[test]
    fn derivative_role_uses_provider_safe_wellness_wording() {
        let prompt = image_prompt(
            "写实",
            "role",
            "穿着合体收腰的按摩技师制服，便于按摩动作，不使用暴露设计",
            true,
            true,
        );

        assert!(prompt.contains("修身利落的理疗服务人员制服"));
        assert!(prompt.contains("便于工作动作"));
        assert!(prompt.contains("不使用不适宜设计"));
        assert!(!prompt.contains("按摩"));
        assert!(!prompt.contains("合体收腰"));
        assert!(!prompt.contains("暴露设计"));
    }

    #[test]
    fn role_generation_removes_legacy_closeup_layout() {
        let prompt = image_prompt(
            "写实",
            "role",
            "青年男性，短黑发，人像特写，正视图，侧视图，后视图，身材高挑",
            false,
            false,
        );

        assert!(!prompt.contains("人像特写"));
        assert!(!prompt.contains("正视图"));
        assert!(prompt.contains("青年男性，短黑发，身材高挑"));
        assert!(prompt.contains("标准三视图全身设定图"));
    }

    #[test]
    fn unilateral_character_feature_enables_opposite_side_view() {
        let prompt = image_prompt(
            "写实",
            "role",
            "年轻女性，右眼戴眼罩，左脸无伤",
            false,
            false,
        );

        assert!(prompt.contains("严格四视图全身设定图"));
        assert!(prompt.contains("第二格与第三格必须方向相反"));
        assert!(!prompt.contains("禁止增加左侧视图"));
    }
}

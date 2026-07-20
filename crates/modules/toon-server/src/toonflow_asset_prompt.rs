pub(crate) fn polish_system_prompt(manual: &str, extra: &str) -> String {
    format!(
        "{manual}\n{extra}\n\
         将剧情身份信息转换为可见的外貌、发型、体型、服装、材质、色彩、姿态或环境特征。\
         姓名、化名、编号、代号、称谓仅用于理解主体，不得作为画面文字、胸牌、名牌、标牌或印花输出。\
         不要虚构输入中没有明确要求的文字、Logo、水印和标识。"
    )
}

pub(crate) fn polish_user_prompt(label: &str, name: &str, description: &str) -> String {
    format!(
        "内部{label}标识：{name}\n剧情描述：{description}\n\
         内部标识不得出现在最终提示词中。只输出可直接用于图片生成的纯视觉提示词，不要解释。"
    )
}

pub(crate) fn image_prompt(
    style: &str,
    asset_type: &str,
    visual_description: &str,
    has_reference: bool,
) -> String {
    let subject_instruction = match asset_type {
        "role" => "生成单人角色标准设定图，突出稳定的面部、发型、体型与服饰特征。",
        "costume" => "生成独立服装设定图，完整展示版型、配色、材质和细节，不出现人物姓名。",
        "scene" => "生成无人场景标准设定图，突出空间结构、材质和光线特征。",
        "tool" => "生成独立道具设定图，完整展示造型、材质和关键细节。",
        _ => "生成干净的资产标准设定图。",
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn image_prompt_does_not_require_an_asset_name() {
        let prompt = image_prompt("写实", "role", "年轻按摩师，神情谨慎", false);

        assert!(!prompt.contains("叶弥月"));
        assert!(prompt.contains("纯视觉描述：年轻按摩师，神情谨慎"));
        assert!(prompt.contains("禁止出现任何文字、字母、数字"));
        assert!(prompt.contains("服装和背景表面保持无字、无编号、无标识"));
    }

    #[test]
    fn polish_prompt_marks_names_as_internal_only() {
        let prompt = polish_user_prompt("角色", "叶弥月", "外班女生，化名8号按摩师");

        assert!(prompt.contains("内部角色标识：叶弥月"));
        assert!(prompt.contains("内部标识不得出现在最终提示词中"));
        assert!(prompt.contains("只输出可直接用于图片生成的纯视觉提示词"));
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum ImageEditTarget {
    Role,
    Costume,
    Scene,
    Tool,
    #[default]
    Storyboard,
}

impl ImageEditTarget {
    pub fn parse(value: &str) -> Self {
        match value {
            "role" => Self::Role,
            "costume" => Self::Costume,
            "scene" => Self::Scene,
            "tool" => Self::Tool,
            _ => Self::Storyboard,
        }
    }

    fn preservation(self) -> &'static str {
        match self {
            Self::Role => "严格保持人物身份、脸部五官、发型、年龄、体型和画风一致",
            Self::Costume => {
                "严格保持同一套独立服装的版型、层次和未指定修改的细节，禁止加入人物或人体模特"
            }
            Self::Scene => "保持原镜头构图、透视、空间关系和项目画风，只修改明确指定的环境内容",
            Self::Tool => "保持道具轮廓、比例和结构，只修改明确指定的材质、状态或局部细节",
            Self::Storyboard => "保持人物身份、景别、机位、构图和叙事动作，只修正明确指定的内容",
        }
    }
}

pub fn build(
    target: ImageEditTarget,
    instruction: &str,
    ratio: &str,
    reference_count: usize,
) -> String {
    if matches!(
        target,
        ImageEditTarget::Role | ImageEditTarget::Costume | ImageEditTarget::Tool
    ) {
        let kind = match target {
            ImageEditTarget::Role => "role",
            ImageEditTarget::Costume => "costume",
            _ => "tool",
        };
        let asset_prompt = crate::toonflow_asset_prompt::image_prompt_with_instruction(
            "沿用参考图画风",
            kind,
            instruction,
            target == ImageEditTarget::Role,
            reference_count > 0,
            None,
        );
        return format!(
            "影视资产图片编辑。编辑要求：{instruction}\n一致性要求：{}（用户明确要求修改的特征除外）。\n共 {reference_count} 张参考图，第一张是主要编辑底图，其余仅作外观参考。\n{asset_prompt}\n输出一张宽高比 {ratio} 的资产设定图；参考图即使存在裁切，也必须补全主体并按以上布局输出。",
            target.preservation()
        );
    }
    let identity_rule = if matches!(target, ImageEditTarget::Role | ImageEditTarget::Storyboard) {
        format!(
            "\n{}",
            crate::toonflow_asset_prompt::CHARACTER_IDENTITY_RULE
        )
    } else {
        String::new()
    };
    format!(
        "你正在执行影视生产图片编辑任务。\n编辑要求：{instruction}\n一致性要求：{}（用户明确要求修改的特征除外）。{identity_rule}\n参考图规则：共 {reference_count} 张，第一张是主要编辑底图，其余图片仅用于身份、服装、道具或美术风格一致性参考。不得擅自改变用户未指定的区域。\n输出要求：输出一张 {ratio} 的完整单画面；不得生成拼图、多视图、对比图、角色设定板、姓名、文字、字幕、数字、标签、边框或水印；不得擅自增加或删除人物。",
        target.preservation()
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn role_edit_preserves_identity_and_full_body_sheet() {
        let prompt = build(ImageEditTarget::Role, "把外套改成黑色", "3:2", 2);
        assert!(prompt.contains("保持人物身份"));
        assert!(prompt.contains("标准三视图全身设定图"));
        assert!(prompt.contains("补全主体"));
        assert!(!prompt.contains("不得生成拼图"));
        assert!(prompt.contains("共 2 张"));
    }

    #[test]
    fn standalone_costume_edit_does_not_introduce_a_person() {
        let prompt = build(ImageEditTarget::Costume, "改为蓝色", "1:1", 1);
        assert!(prompt.contains("独立服装四宫格"));
        assert!(prompt.contains("禁止加入人物"));
        assert!(!prompt.contains("保持人物身份"));
    }

    #[test]
    fn storyboard_edit_still_preserves_single_frame() {
        let prompt = build(ImageEditTarget::Storyboard, "修正光照", "9:16", 1);
        assert!(prompt.contains("不得生成拼图"));
        assert!(!prompt.contains("三视图全身"));
    }
}

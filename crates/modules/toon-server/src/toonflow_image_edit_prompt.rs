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
            Self::Costume => "严格保持人物身份、脸部、姿势和构图，只修改明确指定的服装部分",
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
    format!(
        "你正在执行影视生产图片编辑任务。\n编辑要求：{instruction}\n一致性要求：{}。\n参考图规则：共 {reference_count} 张，第一张是主要编辑底图，其余图片仅用于身份、服装、道具或美术风格一致性参考。不得擅自改变用户未指定的区域。\n输出要求：输出一张 {ratio} 的完整单画面；不得生成拼图、多视图、对比图、角色设定板、姓名、文字、字幕、数字、标签、边框或水印；不得擅自增加或删除人物。",
        target.preservation()
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn role_edit_preserves_identity_and_forbids_collage() {
        let prompt = build(ImageEditTarget::Role, "把外套改成黑色", "16:9", 2);
        assert!(prompt.contains("保持人物身份"));
        assert!(prompt.contains("不得生成拼图"));
        assert!(prompt.contains("共 2 张"));
    }
}

const VISUAL_MARKERS: &[&str] = &[
    "男性", "女性", "少年", "少女", "青年", "中年", "老年", "岁", "面", "脸", "五官", "眼", "眉",
    "鼻", "唇", "发", "肤", "身高", "高挑", "矮", "体型", "身材", "健壮", "清瘦", "匀称", "气质",
    "神情",
];

const RELATION_ONLY_MARKERS: &[&str] = &[
    "朋友",
    "友人",
    "同事",
    "同学",
    "亲属",
    "哥哥",
    "弟弟",
    "姐姐",
    "妹妹",
    "父亲",
    "母亲",
    "看望",
    "陪伴",
    "认识",
    "与主角",
    "王闲的",
];

pub(crate) fn validate_role_description(description: &str) -> Result<(), String> {
    let description = description.trim();
    let visual_count = VISUAL_MARKERS
        .iter()
        .filter(|marker| description.contains(**marker))
        .count();
    let relation_count = RELATION_ONLY_MARKERS
        .iter()
        .filter(|marker| description.contains(**marker))
        .count();

    if description.chars().count() < 28 || visual_count < 3 || relation_count > visual_count {
        return Err(format!(
            "角色描述不是合格的可视化外貌描述：{description}。请重新提取资产"
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_relationship_summary() {
        assert!(validate_role_description("在医院看望王闲的朋友").is_err());
    }

    #[test]
    fn accepts_complete_visual_description() {
        assert!(
            validate_role_description(
                "二十多岁青年男性，短黑发，方脸浓眉，肤色偏小麦色，身材高瘦，气质沉稳克制"
            )
            .is_ok()
        );
    }
}

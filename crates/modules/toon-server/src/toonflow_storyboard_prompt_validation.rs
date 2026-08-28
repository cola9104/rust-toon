use crate::toonflow_asset_context::StoryboardPromptAsset;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum CharacterPose {
    Crouching,
    Floating,
    Kneeling,
    Lying,
    Running,
    Sitting,
    Standing,
    Walking,
}

impl CharacterPose {
    pub(crate) fn label(self) -> &'static str {
        match self {
            Self::Crouching => "蹲姿",
            Self::Floating => "悬空/飞行",
            Self::Kneeling => "跪姿",
            Self::Lying => "躺姿",
            Self::Running => "奔跑",
            Self::Sitting => "坐姿",
            Self::Standing => "站姿",
            Self::Walking => "行走",
        }
    }
}

const POSE_PATTERNS: &[(CharacterPose, &[&str])] = &[
    (
        CharacterPose::Lying,
        &[
            "仰躺",
            "平躺",
            "侧躺",
            "躺",
            "仰卧",
            "平卧",
            "侧卧",
            "俯卧",
            "趴在",
            "倒在",
            "倒地",
            "lying",
            "reclining",
            "supine",
            "prone",
        ],
    ),
    (
        CharacterPose::Sitting,
        &[
            "坐在", "坐着", "坐姿", "坐起", "坐下", "落座", "seated", "sitting",
        ],
    ),
    (
        CharacterPose::Standing,
        &[
            "站在", "站着", "站立", "站姿", "站起", "立于", "直立", "起身", "下床", "standing",
            "upright",
        ],
    ),
    (
        CharacterPose::Kneeling,
        &["跪", "半跪", "kneeling", "on one knee"],
    ),
    (
        CharacterPose::Crouching,
        &["蹲", "蹲伏", "crouching", "squatting"],
    ),
    (
        CharacterPose::Running,
        &["奔跑", "跑向", "跑到", "快跑", "running", "sprinting"],
    ),
    (
        CharacterPose::Walking,
        &[
            "行走", "走向", "走到", "走进", "走出", "迈步", "快步", "步行", "walking",
        ],
    ),
    (
        CharacterPose::Floating,
        &["悬浮", "漂浮", "飞行", "飞在", "floating", "flying"],
    ),
];

pub(crate) fn validate_storyboard_prompt(
    prompt: &str,
    assets: &[StoryboardPromptAsset],
) -> Result<(), String> {
    if prompt.trim().is_empty() {
        return Err("分镜图片提示词为空，请先按首位帧模式重新写入分镜面板".to_string());
    }
    for (index, asset) in assets.iter().enumerate() {
        let marker = format!("@图{}", index + 1);
        if exact_marker_positions(prompt, &marker).next().is_none() {
            return Err(format!(
                "分镜图片已绑定参考资产 {marker}（{}），但画面提示词未描述该资产；请补充其位置和姿态，或从当前分镜解除绑定",
                asset.name
            ));
        }
        if asset.kind == "role" && marker_poses(prompt, &marker).is_empty() {
            return Err(format!(
                "角色参考资产 {marker}（{}）缺少自身姿态描述；其他角色“看向/盯着 {marker}”不算描述该角色。请在 {marker} 后明确写出躺、坐、站、跪、蹲或行走等姿态，并写明病床、椅子等承托关系",
                asset.name
            ));
        }
    }
    Ok(())
}

pub(crate) fn pose_after_subject(
    text: &str,
    subjects: &[String],
    other_subjects: &[String],
) -> Option<CharacterPose> {
    subjects
        .iter()
        .flat_map(|subject| {
            text.match_indices(subject)
                .map(move |match_| (subject, match_))
        })
        .filter_map(|(subject, (position, _))| {
            let start = position + subject.len();
            let suffix = &text[start..];
            let end = subject_window_end(suffix, other_subjects);
            detect_pose(&suffix[..end])
        })
        .next()
}

pub(crate) fn marker_poses(prompt: &str, marker: &str) -> Vec<CharacterPose> {
    exact_marker_positions(prompt, marker)
        .filter_map(|position| {
            let suffix = &prompt[position + marker.len()..];
            let end = marker_window_end(suffix);
            detect_pose(&suffix[..end])
        })
        .collect()
}

fn detect_pose(text: &str) -> Option<CharacterPose> {
    let lower = text.to_ascii_lowercase();
    POSE_PATTERNS
        .iter()
        .flat_map(|(pose, patterns)| {
            patterns.iter().filter_map(|pattern| {
                lower
                    .find(&pattern.to_ascii_lowercase())
                    .map(|position| (position, *pose))
            })
        })
        .min_by_key(|(position, _)| *position)
        .map(|(_, pose)| pose)
}

fn exact_marker_positions<'a>(
    prompt: &'a str,
    marker: &'a str,
) -> impl Iterator<Item = usize> + 'a {
    prompt
        .match_indices(marker)
        .filter_map(move |(position, _)| {
            prompt[position + marker.len()..]
                .chars()
                .next()
                .is_none_or(|character| !character.is_ascii_digit())
                .then_some(position)
        })
}

fn subject_window_end(suffix: &str, other_subjects: &[String]) -> usize {
    let other_subject = other_subjects
        .iter()
        .filter_map(|subject| suffix.find(subject))
        .min();
    window_end(suffix, other_subject)
}

fn marker_window_end(suffix: &str) -> usize {
    window_end(suffix, suffix.find("@图"))
}

fn window_end(text: &str, semantic_boundary: Option<usize>) -> usize {
    let punctuation = ['；', ';', '。', '.']
        .into_iter()
        .filter_map(|delimiter| text.find(delimiter))
        .min();
    let character_limit = text.char_indices().nth(400).map(|(position, _)| position);
    [semantic_boundary, punctuation, character_limit]
        .into_iter()
        .flatten()
        .min()
        .unwrap_or(text.len())
}

#[cfg(test)]
mod tests {
    use super::{CharacterPose, marker_poses, pose_after_subject, validate_storyboard_prompt};
    use crate::toonflow_asset_context::StoryboardPromptAsset;

    fn asset(name: &str, kind: &str) -> StoryboardPromptAsset {
        StoryboardPromptAsset {
            name: name.to_string(),
            kind: kind.to_string(),
        }
    }

    #[test]
    fn rejects_a_role_that_is_only_another_roles_gaze_target() {
        let assets = vec![asset("濒死武神装", "role"), asset("床边陪伴装", "role")];
        let error = validate_storyboard_prompt(
            "【画面】@图2 坐在病床边，身体前倾，盯着 @图1；【风格】写实",
            &assets,
        )
        .unwrap_err();

        assert!(error.contains("@图1"));
        assert!(error.contains("缺少自身姿态"));
    }

    #[test]
    fn accepts_an_explicit_pose_for_every_bound_role() {
        let assets = vec![
            asset("濒死武神装", "role"),
            asset("床边陪伴装", "role"),
            asset("重症监护室", "scene"),
        ];

        assert!(
            validate_storyboard_prompt(
                "【画面】@图1 仰躺在 @图3 的病床上；@图2 坐在床边并盯着 @图1；【风格】写实",
                &assets,
            )
            .is_ok()
        );
    }

    #[test]
    fn marker_one_is_not_satisfied_by_marker_ten() {
        let assets = vec![asset("甲", "role")];
        let error = validate_storyboard_prompt("@图10 站在门边", &assets).unwrap_err();

        assert!(error.contains("@图1"));
    }

    #[test]
    fn extracts_pose_only_after_the_named_subject() {
        let subjects = vec!["王闲".to_string(), "濒死武神装".to_string()];
        let others = vec!["鸭舌帽兄弟".to_string(), "床边陪伴装".to_string()];

        assert_eq!(
            pose_after_subject(
                "王闲（濒死武神装）躺在病床上，鸭舌帽兄弟坐在床边。",
                &subjects,
                &others,
            ),
            Some(CharacterPose::Lying)
        );
        assert_eq!(
            pose_after_subject("鸭舌帽兄弟坐在床边盯着王闲。", &subjects, &others),
            None
        );
    }

    #[test]
    fn reads_the_pose_from_the_markers_own_clause() {
        assert_eq!(
            marker_poses("@图2 坐在床边盯着 @图1；@图1 仰躺在病床上", "@图1"),
            vec![CharacterPose::Lying]
        );
    }
}

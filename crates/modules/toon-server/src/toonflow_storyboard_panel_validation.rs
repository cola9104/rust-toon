use std::collections::{HashMap, HashSet};

use crate::toonflow_storyboard_prompt_validation::{
    CharacterPose, marker_poses, pose_after_subject,
};

#[derive(Clone, Debug, PartialEq)]
pub struct ExpectedPanelItem {
    pub duration: f64,
    pub asset_ids: Vec<i64>,
    pub asset_names: Vec<String>,
    pub role_poses: HashMap<i64, CharacterPose>,
    pub scene: usize,
    pub shots: Vec<ExpectedShot>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ExpectedShot {
    pub visual: String,
    pub shot_size: String,
}

#[derive(Debug)]
pub struct ActualPanelItem {
    pub prompt: String,
    pub video_desc: String,
    pub track: String,
    pub duration: f64,
    pub should_generate_image: bool,
    pub asset_ids: Vec<i64>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PromptFormat {
    Generic,
    Nanobanana,
    Seedream,
}

pub fn prompt_format(model: &str) -> PromptFormat {
    let model = model.to_ascii_lowercase();
    if model.contains("seedream") || model.contains("豆包") {
        PromptFormat::Seedream
    } else if model.contains("nano") || model.contains("gemini") {
        PromptFormat::Nanobanana
    } else {
        PromptFormat::Generic
    }
}

#[cfg(test)]
pub fn expected_items(table: &str, first_frame: bool) -> Vec<ExpectedPanelItem> {
    expected_items_with_aliases(table, first_frame, &HashMap::new())
}

/// Parses the storyboard table into the exact rows that the panel agent must create.
///
/// A derived role is commonly named after an appearance (for example, `病房造型`) while the
/// storyboard correctly refers to the character by their canonical name (`王闲`). `asset_aliases`
/// connects the derived asset id to that canonical role name, so visible roles are not discarded
/// merely because the two display names differ.
pub fn expected_items_with_aliases(
    table: &str,
    first_frame: bool,
    asset_aliases: &HashMap<i64, Vec<String>>,
) -> Vec<ExpectedPanelItem> {
    let mut result = Vec::new();
    let mut segment_duration = None;
    let mut asset_ids = Vec::new();
    let mut asset_names = Vec::new();
    let mut scene = 0;
    let mut rows: Vec<(f64, ExpectedShot)> = Vec::new();
    let mut active_role_ids = HashSet::new();
    let mut scene_role_poses = HashMap::new();

    let flush = |result: &mut Vec<ExpectedPanelItem>,
                 rows: &mut Vec<(f64, ExpectedShot)>,
                 segment_duration: Option<f64>,
                 asset_ids: &[i64],
                 asset_names: &[String],
                 scene: usize,
                 active_role_ids: &mut HashSet<i64>,
                 scene_role_poses: &mut HashMap<i64, CharacterPose>| {
        if first_frame {
            for (duration, shot) in rows.drain(..) {
                let mut visible_assets = asset_ids
                    .iter()
                    .copied()
                    .zip(asset_names.iter().cloned())
                    .filter(|(id, name)| {
                        asset_is_visible(name, &shot.visual)
                            || asset_aliases
                                .get(id)
                                .into_iter()
                                .flatten()
                                .any(|alias| asset_is_visible(alias, &shot.visual))
                    })
                    .collect::<Vec<_>>();
                if inherits_scene_roles(&shot) {
                    for (id, name) in asset_ids.iter().copied().zip(asset_names.iter().cloned()) {
                        if asset_aliases.contains_key(&id)
                            && active_role_ids.contains(&id)
                            && !visible_assets
                                .iter()
                                .any(|(visible_id, _)| *visible_id == id)
                        {
                            visible_assets.push((id, name));
                        }
                    }
                }
                let visible_role_names = visible_assets
                    .iter()
                    .filter(|(id, _)| asset_aliases.contains_key(id))
                    .map(|(id, name)| {
                        let mut names = vec![name.clone()];
                        names.extend(asset_aliases.get(id).into_iter().flatten().cloned());
                        (*id, names)
                    })
                    .collect::<Vec<_>>();
                for (id, names) in &visible_role_names {
                    let other_names = visible_role_names
                        .iter()
                        .filter(|(other_id, _)| other_id != id)
                        .flat_map(|(_, names)| names.iter().cloned())
                        .collect::<Vec<_>>();
                    if let Some(pose) = pose_after_subject(&shot.visual, names, &other_names) {
                        scene_role_poses.insert(*id, pose);
                    }
                }
                let role_poses = visible_role_names
                    .iter()
                    .filter_map(|(id, _)| scene_role_poses.get(id).map(|pose| (*id, *pose)))
                    .collect();
                for (id, _) in &visible_assets {
                    if asset_aliases.contains_key(id) {
                        active_role_ids.insert(*id);
                    }
                }
                let exiting_role_ids = asset_aliases
                    .iter()
                    .filter(|(_, aliases)| {
                        aliases.iter().any(|alias| role_exits(alias, &shot.visual))
                    })
                    .map(|(id, _)| *id)
                    .collect::<Vec<_>>();
                result.push(ExpectedPanelItem {
                    duration,
                    asset_ids: visible_assets.iter().map(|(id, _)| *id).collect(),
                    asset_names: visible_assets.into_iter().map(|(_, name)| name).collect(),
                    role_poses,
                    scene,
                    shots: vec![shot],
                });
                for id in exiting_role_ids {
                    active_role_ids.remove(&id);
                    scene_role_poses.remove(&id);
                }
            }
        } else {
            if let Some(duration) = segment_duration {
                let shots = rows.drain(..).map(|(_, shot)| shot).collect();
                result.push(ExpectedPanelItem {
                    duration,
                    asset_ids: asset_ids.to_vec(),
                    asset_names: asset_names.to_vec(),
                    role_poses: HashMap::new(),
                    scene,
                    shots,
                });
            } else {
                rows.clear();
            }
        }
    };

    for raw_line in table.lines() {
        let line = raw_line.trim();
        if line.starts_with("### ") {
            flush(
                &mut result,
                &mut rows,
                segment_duration,
                &asset_ids,
                &asset_names,
                scene,
                &mut active_role_ids,
                &mut scene_role_poses,
            );
            segment_duration = declared_duration(line);
            asset_ids.clear();
            asset_names.clear();
        } else if line.starts_with("## ") {
            flush(
                &mut result,
                &mut rows,
                segment_duration,
                &asset_ids,
                &asset_names,
                scene,
                &mut active_role_ids,
                &mut scene_role_poses,
            );
            active_role_ids.clear();
            scene_role_poses.clear();
            scene += 1;
            segment_duration = None;
            asset_ids.clear();
            asset_names.clear();
        } else if line.starts_with("**引用资产名称**") {
            asset_names = bracket_strings(line);
        } else if line.starts_with("**引用资产ID**") || line.starts_with("**引用资产 Id**")
        {
            asset_ids = bracket_ids(line);
        } else if let Some(row) = storyboard_row(line) {
            rows.push(row);
        }
    }
    flush(
        &mut result,
        &mut rows,
        segment_duration,
        &asset_ids,
        &asset_names,
        scene,
        &mut active_role_ids,
        &mut scene_role_poses,
    );
    result
}

fn inherits_scene_roles(shot: &ExpectedShot) -> bool {
    const INDEPENDENT_SHOT_TERMS: &[&str] = &[
        "特写",
        "大特写",
        "空镜",
        "反打",
        "主观镜头",
        "画外",
        "另一个空间",
        "切到",
    ];
    !INDEPENDENT_SHOT_TERMS
        .iter()
        .any(|term| shot.shot_size.contains(term) || shot.visual.contains(term))
}

fn role_exits(name: &str, visual: &str) -> bool {
    const EXIT_TERMS: &[&str] = &["离开", "走出", "退出", "出门", "消失在", "退到画外"];
    visual.contains(name) && EXIT_TERMS.iter().any(|term| visual.contains(term))
}

fn asset_is_visible(name: &str, visual: &str) -> bool {
    if visual.contains(name) {
        return true;
    }
    let suffix = name.chars().rev().take(2).collect::<Vec<_>>();
    let suffix = suffix.into_iter().rev().collect::<String>();
    suffix.chars().count() == 2 && visual.contains(&suffix)
}

pub fn validate(
    expected: &[ExpectedPanelItem],
    actual: &[ActualPanelItem],
    first_frame: bool,
    format: PromptFormat,
    role_asset_ids: &HashSet<i64>,
) -> Vec<String> {
    let mut issues = Vec::new();
    let mut continuity: HashMap<i64, Vec<&'static str>> = HashMap::new();
    let mut current_scene = 0;
    if actual.len() != expected.len() {
        issues.push(format!(
            "写入数量应为{}条，实际为{}条",
            expected.len(),
            actual.len()
        ));
    }
    for (index, (expected, actual)) in expected.iter().zip(actual).enumerate() {
        let position = index + 1;
        if expected.scene != current_scene {
            current_scene = expected.scene;
            continuity.clear();
        }
        if actual.track != position.to_string() {
            issues.push(format!(
                "第{position}条 track 应为{position}，实际为{}",
                actual.track
            ));
        }
        if (actual.duration - expected.duration).abs() > 0.1 {
            issues.push(format!(
                "第{position}条时长应为{:.1}s，实际为{:.1}s",
                expected.duration, actual.duration
            ));
        }
        if actual.asset_ids != expected.asset_ids {
            issues.push(format!(
                "第{position}条关联资产ID顺序不一致，应为{:?}，实际为{:?}",
                expected.asset_ids, actual.asset_ids
            ));
        }
        for shot in &expected.shots {
            if !actual.video_desc.contains(&shot.visual) {
                issues.push(format!(
                    "第{position}条 videoDesc 未完整保留分镜表画面描述：{}",
                    shot.visual
                ));
            }
        }
        if first_frame {
            if !actual.should_generate_image {
                issues.push(format!("第{position}条首位帧分镜未开启图片生成"));
            }
            if actual.prompt.trim().is_empty() {
                issues.push(format!("第{position}条首位帧 prompt 为空"));
            }
            for marker in 1..=actual.asset_ids.len() {
                let marker = format!("@图{marker}");
                let occurrences = actual.prompt.matches(&marker).count();
                if occurrences == 0 {
                    issues.push(format!("第{position}条 prompt 缺少 @图{marker} 绑定"));
                } else if occurrences < 2 {
                    issues.push(format!(
                        "第{position}条 prompt 仅声明了 {marker}，画面正文未再次引用"
                    ));
                }
            }
            if let Some(shot) = expected.shots.first() {
                if !shot_size_matches(&actual.prompt, &shot.shot_size) {
                    issues.push(format!(
                        "第{position}条 prompt 未体现景别“{}”",
                        shot.shot_size
                    ));
                }
                for anchor in spatial_anchors(&shot.visual) {
                    if !actual.prompt.contains(anchor) {
                        issues.push(format!("第{position}条 prompt 遗漏位置/朝向锚点“{anchor}”"));
                    }
                }
                validate_role_continuity(
                    &mut issues,
                    position,
                    expected,
                    &actual.prompt,
                    role_asset_ids,
                    &mut continuity,
                );
            }
            validate_prompt_format(&mut issues, position, &actual.prompt, format);
        } else if actual.should_generate_image || !actual.prompt.trim().is_empty() {
            issues.push(format!(
                "第{position}条纯文本多参分镜不应生成图片或携带图片 prompt"
            ));
        }
    }
    issues
}

fn validate_role_continuity(
    issues: &mut Vec<String>,
    position: usize,
    expected: &ExpectedPanelItem,
    prompt: &str,
    role_asset_ids: &HashSet<i64>,
    continuity: &mut HashMap<i64, Vec<&'static str>>,
) {
    let Some(shot) = expected.shots.first() else {
        return;
    };
    for (asset_index, asset_id) in expected.asset_ids.iter().enumerate() {
        if !role_asset_ids.contains(asset_id) {
            continue;
        }
        let name = expected.asset_names.get(asset_index).map(String::as_str);
        let marker = format!("@图{}", asset_index + 1);
        match expected.role_poses.get(asset_id) {
            Some(expected_pose) => {
                let actual_poses = marker_poses(prompt, &marker);
                if !actual_poses.contains(expected_pose) {
                    let actual = if actual_poses.is_empty() {
                        "未描述".to_string()
                    } else {
                        actual_poses
                            .iter()
                            .map(|pose| pose.label())
                            .collect::<Vec<_>>()
                            .join("/")
                    };
                    issues.push(format!(
                        "第{position}条角色{marker}姿态应继承“{}”，实际为{actual}",
                        expected_pose.label()
                    ));
                }
            }
            None => issues.push(format!(
                "第{position}条角色{marker}在本场首次出镜前没有明确姿态，无法建立人物姿态连续性"
            )),
        }
        let role_is_visible = name.is_some_and(|name| shot.visual.contains(name));
        if !role_is_visible {
            continue;
        }
        let explicit = spatial_anchors(&shot.visual).collect::<Vec<_>>();
        if !explicit.is_empty() {
            continuity.insert(*asset_id, explicit);
        }
        if let Some(anchors) = continuity.get(asset_id) {
            for anchor in anchors {
                if !prompt.contains(anchor) {
                    issues.push(format!(
                        "第{position}条角色{marker}未继承同场位置/朝向“{anchor}”"
                    ));
                }
            }
        }
    }
}

fn validate_prompt_format(
    issues: &mut Vec<String>,
    position: usize,
    prompt: &str,
    format: PromptFormat,
) {
    match format {
        PromptFormat::Seedream => {
            for section in ["【画面】", "【风格】"] {
                if !prompt.contains(section) {
                    issues.push(format!("第{position}条 Seedream prompt 缺少{section}段"));
                }
            }
            if prompt.trim_start().starts_with('{') || prompt.contains("\"character_reference\"") {
                issues.push(format!("第{position}条 Seedream prompt 错用了 JSON 模式"));
            }
        }
        PromptFormat::Nanobanana => {
            for field in [
                "\"character_reference\"",
                "\"continuity_rules\"",
                "\"shot\"",
                "\"negative\"",
            ] {
                if !prompt.contains(field) {
                    issues.push(format!(
                        "第{position}条 Nanobanana JSON prompt 缺少字段 {field}"
                    ));
                }
            }
        }
        PromptFormat::Generic => {}
    }
}

fn declared_duration(line: &str) -> Option<f64> {
    let (_, rest) = line.split_once('约')?;
    let (value, _) = rest.split_once('s')?;
    value.trim().parse().ok()
}

fn bracket_ids(line: &str) -> Vec<i64> {
    line.split_once('[')
        .and_then(|(_, rest)| rest.split_once(']'))
        .map(|(items, _)| {
            items
                .split([',', '，'])
                .filter_map(|item| item.trim().parse().ok())
                .collect()
        })
        .unwrap_or_default()
}

fn bracket_strings(line: &str) -> Vec<String> {
    line.split_once('[')
        .and_then(|(_, rest)| rest.split_once(']'))
        .map(|(items, _)| {
            items
                .split([',', '，'])
                .map(|item| item.trim().trim_matches(['"', '\'', '`']).to_string())
                .filter(|item| !item.is_empty())
                .collect()
        })
        .unwrap_or_default()
}

fn storyboard_row(line: &str) -> Option<(f64, ExpectedShot)> {
    if !line.starts_with('|') || line.contains("---") || line.contains("画面描述") {
        return None;
    }
    let cells = line.split('|').collect::<Vec<_>>();
    if cells.len() < 9 || cells.get(1)?.trim().parse::<usize>().is_err() {
        return None;
    }
    let duration = cells.get(3)?.trim().trim_end_matches('s').parse().ok()?;
    Some((
        duration,
        ExpectedShot {
            visual: cells.get(2)?.trim().to_string(),
            shot_size: cells.get(4)?.trim().to_string(),
        },
    ))
}

fn shot_size_matches(prompt: &str, shot_size: &str) -> bool {
    let alternatives: &[&str] = match shot_size {
        "大远景" | "大全景" => &["大远景", "大全景", "extreme wide", "establishing shot"],
        "远景" | "全景" => &["远景", "全景", "wide shot", "full shot"],
        "中景" => &["中景", "medium shot", "cowboy shot", "knee shot"],
        "近景" => &["近景", "medium close-up", "upper body"],
        "半身" => &["半身", "half body", "bust shot"],
        "特写" => &["特写", "close-up", "face focus"],
        "大特写" => &["大特写", "extreme close-up", "macro detail"],
        "过肩镜" => &["过肩", "over the shoulder", "two shot"],
        _ => return prompt.contains(shot_size),
    };
    let lower = prompt.to_ascii_lowercase();
    alternatives
        .iter()
        .any(|alternative| lower.contains(&alternative.to_ascii_lowercase()))
}

fn spatial_anchors(visual: &str) -> impl Iterator<Item = &'static str> {
    const ANCHORS: &[&str] = &[
        "左前",
        "中前",
        "右前",
        "左中",
        "中中",
        "右中",
        "左后",
        "中后",
        "右后",
        "朝左",
        "朝右",
        "面向左",
        "面向右",
        "背对",
        "正对",
        "侧对",
        "前景",
        "中景",
        "后景",
    ];
    ANCHORS
        .iter()
        .copied()
        .filter(move |anchor| visual.contains(anchor))
}

#[cfg(test)]
mod tests {
    use super::{
        ActualPanelItem, PromptFormat, expected_items, expected_items_with_aliases, prompt_format,
        validate,
    };
    use crate::toonflow_storyboard_prompt_validation::CharacterPose;
    use std::collections::HashMap;

    const TABLE: &str = r#"
## 场1：客厅 ｜ 参演角色：甲、乙
### 片段一（约9s）
**引用资产名称**：[甲, 乙]
**引用资产ID**：[11, 22]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 甲抬眼。 | 4 | 近景 | 固定 |  |  |
| 2 | 乙放下杯子。 | 5 | 中景 | 固定 |  | 杯声 |
"#;

    #[test]
    fn parses_units_for_both_toonflow_modes() {
        let frames = expected_items(TABLE, true);
        assert_eq!(frames.len(), 2);
        assert_eq!(frames[0].duration, 4.0);
        assert_eq!(frames[0].asset_ids, vec![11]);
        assert_eq!(frames[0].asset_names, vec!["甲"]);
        assert_eq!(frames[1].asset_ids, vec![22]);
        assert_eq!(frames[0].shots[0].visual, "甲抬眼。");
        let text = expected_items(TABLE, false);
        assert_eq!(text.len(), 1);
        assert_eq!(text[0].duration, 9.0);
        assert_eq!(text[0].asset_ids, vec![11, 22]);
    }

    #[test]
    fn excludes_non_visible_roles_from_an_empty_hospital_frame() {
        let table = r#"
## 场1：前世病房 ｜ 参演角色：王闲、友人
### 片段一（约4s）
**引用资产名称**：[王闲, 友人, 前世病房, 病床, 心电监护仪]
**引用资产ID**：[1, 2, 3, 4, 5]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 纯白病房内，心电监护仪紧邻病床。 | 4 | 中景 | 固定 |  |  |
"#;

        let frames = expected_items(table, true);
        assert_eq!(frames[0].asset_ids, vec![3, 4, 5]);
        assert_eq!(
            frames[0].asset_names,
            vec!["前世病房", "病床", "心电监护仪"]
        );
    }

    #[test]
    fn keeps_a_derived_role_when_the_frame_uses_the_canonical_character_name() {
        let table = r#"
## 场1：病房 ｜ 参演角色：王闲
### 片段一（约4s）
**引用资产名称**：[病号服造型]
**引用资产ID**：[19]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 王闲躺在病床上。 | 4 | 中景 | 固定 |  |  |
"#;
        let aliases = HashMap::from([(19, vec!["王闲".to_string()])]);

        let frames = expected_items_with_aliases(table, true, &aliases);

        assert_eq!(frames[0].asset_ids, vec![19]);
        assert_eq!(frames[0].asset_names, vec!["病号服造型"]);
    }

    #[test]
    fn carries_a_role_that_remains_in_the_same_segment_composition() {
        let table = r#"
## 场1：按摩房 ｜ 参演角色：王闲、叶弥月
### 片段一（约10s）
**引用资产名称**：[吊儿郎当高中生装, 8号按摩师伪装, 按摩房]
**引用资产ID**：[19, 20, 30]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 王闲从按摩床上坐起来。 | 3 | 中景 | 固定 |  |  |
| 2 | 叶弥月走进房间，来到床边。 | 7 | 中景 | 跟拍 |  |  |
"#;
        let aliases = HashMap::from([
            (19, vec!["王闲".to_string()]),
            (20, vec!["叶弥月".to_string()]),
        ]);

        let frames = expected_items_with_aliases(table, true, &aliases);

        assert_eq!(frames[0].asset_ids, vec![19]);
        assert_eq!(frames[1].asset_ids, vec![20, 19]);
    }

    #[test]
    fn carries_role_poses_across_segments_and_rejects_the_track_six_regression() {
        let table = r#"
## 场1：重症监护室 ｜ 参演角色：王闲、鸭舌帽兄弟
### 片段一（约4s）
**引用资产名称**：[濒死武神装, 床边陪伴装, 重症监护室]
**引用资产ID**：[19, 20, 30]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 王闲躺在病床上，鸭舌帽兄弟坐在床边。 | 4 | 中景 | 固定 |  |  |
### 片段二（约4s）
**引用资产名称**：[濒死武神装, 床边陪伴装, 重症监护室]
**引用资产ID**：[19, 20, 30]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 鸭舌帽兄弟身体前倾，盯着王闲。 | 4 | 中景 | 缓推 |  |  |
"#;
        let aliases = HashMap::from([
            (19, vec!["王闲".to_string()]),
            (20, vec!["鸭舌帽兄弟".to_string()]),
        ]);
        let expected = expected_items_with_aliases(table, true, &aliases);

        assert_eq!(expected[1].role_poses[&19], CharacterPose::Lying);
        assert_eq!(expected[1].role_poses[&20], CharacterPose::Sitting);

        let actual = vec![
            ActualPanelItem {
                prompt: "@图1 为王闲，@图2 为鸭舌帽兄弟，@图3 为场景；【画面】中景，@图1 躺在病床上，@图2 坐在床边。【风格】写实".into(),
                video_desc: "王闲躺在病床上，鸭舌帽兄弟坐在床边。".into(),
                track: "1".into(),
                duration: 4.0,
                should_generate_image: true,
                asset_ids: vec![19, 20, 30],
            },
            ActualPanelItem {
                prompt: "@图1 为王闲，@图2 为鸭舌帽兄弟，@图3 为场景；【画面】中景，@图2 身体前倾，盯着 @图1。【风格】写实".into(),
                video_desc: "鸭舌帽兄弟身体前倾，盯着王闲。".into(),
                track: "2".into(),
                duration: 4.0,
                should_generate_image: true,
                asset_ids: vec![19, 20, 30],
            },
        ];
        let issues = validate(
            &expected,
            &actual,
            true,
            PromptFormat::Seedream,
            &[19_i64, 20].into_iter().collect(),
        );

        assert!(
            issues
                .iter()
                .any(|issue| issue.contains("角色@图1姿态应继承“躺姿”"))
        );
        assert!(
            issues
                .iter()
                .any(|issue| issue.contains("角色@图2姿态应继承“坐姿”"))
        );
    }

    #[test]
    fn catches_panel_mapping_drift() {
        let expected = expected_items(TABLE, true);
        let actual = vec![ActualPanelItem {
            prompt: "@图1 为甲".into(),
            video_desc: "改写后的画面".into(),
            track: "2".into(),
            duration: 5.0,
            should_generate_image: false,
            asset_ids: vec![22, 11],
        }];
        let issues = validate(
            &expected,
            &actual,
            true,
            PromptFormat::Seedream,
            &[11_i64, 22].into_iter().collect(),
        );
        assert!(issues.iter().any(|issue| issue.contains("写入数量")));
        assert!(issues.iter().any(|issue| issue.contains("track")));
        assert!(issues.iter().any(|issue| issue.contains("资产ID顺序")));
        assert!(issues.iter().any(|issue| issue.contains("@图2")));
    }

    #[test]
    fn routes_and_validates_model_specific_prompt_formats() {
        assert_eq!(prompt_format("doubao-seedream-4.5"), PromptFormat::Seedream);
        assert_eq!(
            prompt_format("gemini-3-pro-image"),
            PromptFormat::Nanobanana
        );
        let mut issues = Vec::new();
        super::validate_prompt_format(
            &mut issues,
            1,
            "@图1 为角色，【画面】@图1 站立。【风格】写实",
            PromptFormat::Seedream,
        );
        assert!(issues.is_empty());
    }

    #[test]
    fn carries_explicit_role_position_within_a_scene() {
        let table = r#"
## 场1：客厅 ｜ 参演角色：甲
### 片段一（约8s）
**引用资产名称**：[甲]
**引用资产ID**：[11]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 甲站在左前，面向右。 | 4 | 中景 | 固定 |  |  |
| 2 | 甲抬起手。 | 4 | 中景 | 固定 |  |  |
"#;
        let expected = expected_items(table, true);
        let actual = vec![
            ActualPanelItem {
                prompt: "@图1 为甲，【画面】中景，@图1 位于左前，面向右。【风格】写实".into(),
                video_desc: "甲站在左前，面向右。".into(),
                track: "1".into(),
                duration: 4.0,
                should_generate_image: true,
                asset_ids: vec![11],
            },
            ActualPanelItem {
                prompt: "@图1 为甲，【画面】中景，@图1 抬起手。【风格】写实".into(),
                video_desc: "甲抬起手。".into(),
                track: "2".into(),
                duration: 4.0,
                should_generate_image: true,
                asset_ids: vec![11],
            },
        ];
        let issues = validate(
            &expected,
            &actual,
            true,
            PromptFormat::Seedream,
            &[11_i64].into_iter().collect(),
        );
        assert!(issues.iter().any(|issue| issue.contains("未继承")));
    }
}

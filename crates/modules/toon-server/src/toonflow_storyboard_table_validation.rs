use serde_json::Value;
use std::collections::BTreeSet;

const FORBIDDEN_VISUAL_TERMS: &[&str] = &[
    "光线", "打光", "逆光", "侧光", "顶光", "暖光", "冷光", "阳光", "日光", "灯光", "阴影", "色温",
    "明暗", "色调", "暖色", "冷色", "冷暖",
];
const APPEARANCE_TERMS: &[&str] = &[
    "穿着", "身穿", "服装", "夹克", "衬衫", "长袍", "短裙", "长裙", "浓眉", "白皙", "肤色", "五官",
    "长发", "短发", "发型", "卷发", "马尾",
];
const MULTI_SHOT_TERMS: &[&str] = &["蒙太奇", "快切", "定格画面", "多景别", "→"];

pub fn asset_names(assets: &Value) -> Vec<String> {
    let mut names = BTreeSet::new();
    for asset in assets.as_array().into_iter().flatten() {
        collect_name(asset, &mut names);
        for derived in asset
            .get("derive")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
        {
            collect_name(derived, &mut names);
        }
    }
    names
        .into_iter()
        .filter(|name| name.chars().count() >= 2)
        .collect()
}

fn collect_name(value: &Value, names: &mut BTreeSet<String>) {
    if let Some(name) = value
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
    {
        names.insert(name.to_string());
    }
}

pub fn validate(table: &str, known_asset_names: &[String]) -> Vec<String> {
    let mut issues = Vec::new();
    let mut referenced_names = BTreeSet::new();
    let mut location = "分镜表".to_string();
    let mut scene_count = 0;
    let mut segment_count = 0;
    let mut shot_count = 0;
    let mut segment_duration = 0.0;
    let mut declared_duration: Option<f64> = None;
    let mut expected_shot_number = 1;
    let mut segment_location: Option<String> = None;
    let mut segment_has_asset_names = false;
    let mut segment_has_asset_ids = false;
    for raw_line in table.lines() {
        let line = raw_line.trim();
        if line.starts_with("### ") {
            validate_segment(
                &mut issues,
                segment_location.as_deref(),
                segment_duration,
                declared_duration,
                segment_has_asset_names,
                segment_has_asset_ids,
            );
            location = line.trim_start_matches('#').trim().to_string();
            segment_location = Some(location.clone());
            segment_count += 1;
            segment_duration = 0.0;
            declared_duration = declared_segment_duration(line);
            expected_shot_number = 1;
            segment_has_asset_names = false;
            segment_has_asset_ids = false;
            referenced_names.clear();
            if let Some(declared) = declared_duration
                && declared > 15.0
            {
                issues.push(format!("{location} 标注时长{declared:.1}s，超过15s上限"));
            }
        } else if line.starts_with("## ") {
            validate_segment(
                &mut issues,
                segment_location.as_deref(),
                segment_duration,
                declared_duration,
                segment_has_asset_names,
                segment_has_asset_ids,
            );
            segment_location = None;
            segment_duration = 0.0;
            declared_duration = None;
            location = line.trim_start_matches('#').trim().to_string();
            scene_count += 1;
            if !line.contains("参演角色：") && !line.contains("参演角色:") {
                issues.push(format!("{location} 场头缺少参演角色"));
            }
        }
        if line.starts_with("**引用资产名称**") {
            referenced_names = bracket_items(line).into_iter().collect();
            segment_has_asset_names = true;
            continue;
        }
        if line.starts_with("**引用资产ID**") || line.starts_with("**引用资产 Id**") {
            segment_has_asset_ids = true;
            continue;
        }
        if !line.starts_with('|') || line.contains("---") || line.contains("画面描述") {
            continue;
        }
        let raw_cells = line.split('|').collect::<Vec<_>>();
        if raw_cells.len() < 9 {
            continue;
        }
        let cells = raw_cells[1..raw_cells.len() - 1]
            .iter()
            .map(|cell| cell.trim())
            .collect::<Vec<_>>();
        if cells.len() < 7 || cells[0].parse::<usize>().is_err() {
            continue;
        }
        let shot_number = cells[0].parse::<usize>().unwrap_or_default();
        let shot = format!("{}镜{shot_number}", location);
        shot_count += 1;
        if shot_number != expected_shot_number {
            issues.push(format!(
                "{location} 镜号应为{expected_shot_number}，实际为{shot_number}"
            ));
        }
        expected_shot_number = shot_number.saturating_add(1);
        let visual = cells[1];
        let duration = cells[2]
            .trim_end_matches('s')
            .trim()
            .parse::<f64>()
            .unwrap_or(0.0);
        let movement = cells[4];
        let dialogue = cells[5];
        let sound = cells[6];
        let inspected = format!("{visual} {movement} {sound}");
        segment_duration += duration;

        if visual.is_empty() || matches!(visual, "无" | "—" | "-") {
            issues.push(format!("{shot} 画面描述为空"));
        }
        if duration <= 0.0 {
            issues.push(format!("{shot} 时长必须是大于0的数字"));
        }
        if cells[3].is_empty() || matches!(cells[3], "无" | "—" | "-") {
            issues.push(format!("{shot} 缺少景别"));
        }
        if movement.is_empty() || matches!(movement, "无" | "—" | "-") {
            issues.push(format!("{shot} 缺少运镜；固定机位请明确写“固定”"));
        }

        let forbidden = FORBIDDEN_VISUAL_TERMS
            .iter()
            .filter(|term| inspected.contains(**term))
            .copied()
            .collect::<Vec<_>>();
        if !forbidden.is_empty() {
            issues.push(format!("{shot} 含禁用光影色调词：{}", forbidden.join("、")));
        }
        let appearance = APPEARANCE_TERMS
            .iter()
            .filter(|term| visual.contains(**term))
            .copied()
            .collect::<Vec<_>>();
        if !appearance.is_empty() {
            issues.push(format!(
                "{shot} 把人物固有外观写入画面描述：{}",
                appearance.join("、")
            ));
        }
        let multi_shot = MULTI_SHOT_TERMS
            .iter()
            .filter(|term| {
                visual.contains(**term) || cells[3].contains(**term) || movement.contains(**term)
            })
            .copied()
            .collect::<Vec<_>>();
        if !multi_shot.is_empty() {
            issues.push(format!(
                "{shot} 合并了多个画面或时间阶段，不适合作为单张分镜关键帧：{}",
                multi_shot.join("、")
            ));
        }
        for name in known_asset_names {
            if visual.contains(name) && !referenced_names.contains(name) {
                issues.push(format!(
                    "{shot} 出现资产角色/物件「{name}」，但当前片段引用资产名称未包含它"
                ));
            }
        }
        if has_dialogue(dialogue) {
            let (characters, punctuation) = dialogue_metrics(dialogue);
            let minimum = (characters as f64 / 4.0 + punctuation as f64 * 0.4 + 1.0).ceil();
            if duration + f64::EPSILON < minimum {
                issues.push(format!("{shot} 台词约{characters}字、{punctuation}处停顿，时长{duration:.1}s，按统一公式至少需要{minimum:.0}s"));
            }
        } else if duration > 6.0 {
            issues.push(format!("{shot} 无台词镜时长{duration:.1}s，超过6s上限"));
        }
    }
    validate_segment(
        &mut issues,
        segment_location.as_deref(),
        segment_duration,
        declared_duration,
        segment_has_asset_names,
        segment_has_asset_ids,
    );
    if scene_count == 0 {
        issues.push("分镜表缺少“## 场N：场景名 ｜ 参演角色：…”场头".to_string());
    }
    if segment_count == 0 {
        issues.push("分镜表缺少“### 片段N（约Xs）”结构".to_string());
    }
    if shot_count == 0 {
        issues.push("分镜表没有可识别的镜头表格行".to_string());
    }
    issues.sort();
    issues.dedup();
    issues
}

fn validate_segment(
    issues: &mut Vec<String>,
    location: Option<&str>,
    duration: f64,
    declared_duration: Option<f64>,
    has_asset_names: bool,
    has_asset_ids: bool,
) {
    let Some(location) = location else { return };
    if duration > 15.0 + f64::EPSILON {
        issues.push(format!(
            "{} 镜头合计{duration:.1}s，超过15s上限，必须拆分片段",
            location
        ));
    }
    match declared_duration {
        Some(declared) if (declared - duration).abs() > 0.1 => issues.push(format!(
            "{location} 标注时长{declared:.1}s与镜头合计{duration:.1}s不一致"
        )),
        None => issues.push(format!("{location} 标题缺少“约Xs”时长")),
        _ => {}
    }
    if !has_asset_names {
        issues.push(format!("{location} 缺少引用资产名称"));
    }
    if !has_asset_ids {
        issues.push(format!("{location} 缺少引用资产ID"));
    }
}

fn declared_segment_duration(line: &str) -> Option<f64> {
    let (_, rest) = line.split_once('约')?;
    let (value, _) = rest.split_once('s')?;
    value.trim().parse().ok()
}

fn bracket_items(line: &str) -> Vec<String> {
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

fn has_dialogue(dialogue: &str) -> bool {
    let value = dialogue.trim();
    !value.is_empty() && value != "无" && value != "无台词" && value != "—" && value != "-"
}

fn dialogue_metrics(dialogue: &str) -> (usize, usize) {
    let content = dialogue
        .rsplit_once(['：', ':'])
        .map(|(_, content)| content)
        .unwrap_or(dialogue);
    let punctuation_chars = "，。！？；：、,.!?;:";
    let punctuation = content
        .chars()
        .filter(|character| punctuation_chars.contains(*character))
        .count();
    let characters = content
        .chars()
        .filter(|character| {
            !character.is_whitespace()
                && !punctuation_chars.contains(*character)
                && !"『』“”\"'（）()【】[]".contains(*character)
        })
        .count();
    (characters, punctuation)
}

#[cfg(test)]
mod tests {
    use super::validate;

    #[test]
    fn rejects_the_mechanical_errors_before_persistence() {
        let table = r#"
### 片段三（约4s）
**引用资产名称**：[二哥]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 三叔和穿着白色衬衫的二哥在阳光下对视。 | 4 | 中景 | 静止 | 二哥说：你今天必须给我们一个明确的答复！ | 呼吸声 |
"#;
        let issues = validate(table, &["三叔".into(), "二哥".into()]);
        assert!(issues.iter().any(|issue| issue.contains("阳光")));
        assert!(issues.iter().any(|issue| issue.contains("衬衫")));
        assert!(issues.iter().any(|issue| issue.contains("三叔")));
        assert!(issues.iter().any(|issue| issue.contains("至少需要")));
    }

    #[test]
    fn accepts_a_clean_row() {
        let table = r#"
## 场1：客厅 ｜ 参演角色：三叔、二哥
### 片段一（约6s）
**引用资产名称**：[三叔, 二哥]
**引用资产ID**：[101, 102]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 三叔放下茶杯，二哥抬眼与他对视。 | 6 | 中景 | 静止 | 二哥说：你必须给我一个答复。 | 茶杯落桌声 |
"#;
        assert!(validate(table, &["三叔".into(), "二哥".into()]).is_empty());
    }

    #[test]
    fn rejects_oversized_segments_and_multi_shot_rows() {
        let table = r#"
## 场1：门厅 ｜ 参演角色：三叔
### 片段一（约17s）
**引用资产名称**：[三叔]
**引用资产ID**：[101]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 1 | 蒙太奇快切——三叔起身→走到门前。 | 6 | 多景别 | 快切 |  | 脚步声 |
| 2 | 三叔停在门前。 | 6 | 中景 | 固定 |  |  |
| 3 | 三叔抬手。 | 5 | 近景 | 固定 |  |  |
"#;
        let issues = validate(table, &["三叔".into()]);
        assert!(issues.iter().any(|issue| issue.contains("超过15s")));
        assert!(issues.iter().any(|issue| issue.contains("单张分镜关键帧")));
    }

    #[test]
    fn rejects_unusable_rows_and_inconsistent_segment_timing() {
        let table = r#"
## 场1：门厅 ｜ 参演角色：三叔
### 片段一（约8s）
**引用资产名称**：[三叔]
**引用资产ID**：[101]
| 序号 | 画面描述 | 时长 | 景别 | 运镜 | 台词 | 音效 |
|---|---|---|---|---|---|---|
| 2 |  | 0 |  |  |  |  |
"#;
        let issues = validate(table, &["三叔".into()]);
        assert!(issues.iter().any(|issue| issue.contains("镜号应为1")));
        assert!(issues.iter().any(|issue| issue.contains("画面描述为空")));
        assert!(issues.iter().any(|issue| issue.contains("时长必须")));
        assert!(issues.iter().any(|issue| issue.contains("缺少景别")));
        assert!(issues.iter().any(|issue| issue.contains("缺少运镜")));
        assert!(issues.iter().any(|issue| issue.contains("不一致")));
    }
}

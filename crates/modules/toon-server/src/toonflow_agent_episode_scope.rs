use rust_toon_framework_web::AppError;
use serde_json::Value;

pub(crate) fn episode_references(text: &str) -> Vec<u32> {
    let chars = text.chars().collect::<Vec<_>>();
    let mut references = Vec::new();
    let mut index = 0;
    while index < chars.len() {
        if chars[index] != '第' {
            index += 1;
            continue;
        }
        let mut cursor = index + 1;
        let first = cursor;
        while cursor < chars.len() && chars[cursor].is_ascii_digit() {
            cursor += 1;
        }
        if first == cursor {
            index += 1;
            continue;
        }
        let start = chars[first..cursor]
            .iter()
            .collect::<String>()
            .parse::<u32>()
            .ok();
        let mut end = None;
        if cursor < chars.len() && matches!(chars[cursor], '-' | '–' | '—' | '至' | '到') {
            cursor += 1;
            let second = cursor;
            while cursor < chars.len() && chars[cursor].is_ascii_digit() {
                cursor += 1;
            }
            if second < cursor {
                end = chars[second..cursor]
                    .iter()
                    .collect::<String>()
                    .parse::<u32>()
                    .ok();
            }
        }
        if cursor < chars.len() && chars[cursor] == '集' {
            if let Some(start) = start {
                references.push(start);
            }
            if let Some(end) = end {
                references.push(end);
            }
            index = cursor + 1;
        } else {
            index += 1;
        }
    }
    references
}

pub(crate) fn explicit_episode_limit(text: &str) -> Option<u32> {
    let chars = text.chars().collect::<Vec<_>>();
    let mut limits = episode_references(text);
    let mut index = 0;
    while index < chars.len() {
        if !chars[index].is_ascii_digit() {
            index += 1;
            continue;
        }
        let first = index;
        while index < chars.len() && chars[index].is_ascii_digit() {
            index += 1;
        }
        let first_number = chars[first..index]
            .iter()
            .collect::<String>()
            .parse::<u32>()
            .ok();
        let mut last_number = first_number;
        if index < chars.len() && matches!(chars[index], '-' | '/' | '–' | '—' | '至' | '到')
        {
            index += 1;
            if index < chars.len() && chars[index] == '第' {
                index += 1;
            }
            let second = index;
            while index < chars.len() && chars[index].is_ascii_digit() {
                index += 1;
            }
            if second < index {
                last_number = chars[second..index]
                    .iter()
                    .collect::<String>()
                    .parse::<u32>()
                    .ok();
            }
        }
        if index < chars.len()
            && chars[index] == '集'
            && let Some(limit) = last_number
        {
            limits.push(limit);
        }
    }
    limits.into_iter().max()
}

pub(crate) fn episode_limit(strategy: &str, prompt: &str) -> Option<u32> {
    match (
        explicit_episode_limit(strategy),
        explicit_episode_limit(prompt),
    ) {
        (Some(strategy), Some(request)) => Some(strategy.min(request)),
        (Some(strategy), None) => Some(strategy),
        (None, Some(request)) => Some(request),
        (None, None) => None,
    }
}

pub(crate) fn script_episode_number(name: &str) -> Option<u32> {
    if let Some(episode) = episode_references(name).into_iter().next() {
        return Some(episode);
    }
    let lower = name.to_ascii_lowercase();
    let bytes = lower.as_bytes();
    for index in 0..bytes.len().saturating_sub(1) {
        if bytes[index] != b'e' || bytes[index + 1] != b'p' {
            continue;
        }
        let mut cursor = index + 2;
        while cursor < bytes.len() && matches!(bytes[cursor], b' ' | b'-' | b'_' | b'#') {
            cursor += 1;
        }
        let start = cursor;
        while cursor < bytes.len() && bytes[cursor].is_ascii_digit() {
            cursor += 1;
        }
        if start < cursor {
            return lower[start..cursor].parse().ok();
        }
    }
    None
}

pub(crate) fn validate_generated_script(content: &str) -> Result<(), String> {
    const PLACEHOLDER_MARKERS: [&str; 5] = ["生成结果补充", "稍后补充", "待补充", "TODO", "TBD"];
    let character_count = content.chars().count();
    if character_count < 200 {
        return Err(format!("正文只有 {character_count} 字，少于最低 200 字"));
    }
    if let Some(marker) = PLACEHOLDER_MARKERS
        .iter()
        .find(|marker| content.contains(**marker))
    {
        return Err(format!("正文包含占位内容“{marker}”"));
    }
    if !content.lines().any(|line| line.trim().starts_with('△')) {
        return Err("正文缺少以 △ 开头的场景动作描述".into());
    }
    if !content.lines().any(valid_scene_heading) {
        return Err("正文缺少“集号-场号 场景名 日/内”格式的场景标题".into());
    }
    Ok(())
}

fn valid_scene_heading(line: &str) -> bool {
    let number = line.split_whitespace().next().unwrap_or_default();
    let mut parts = number.split('-');
    matches!((parts.next(), parts.next(), parts.next()), (Some(a), Some(b), None) if !a.is_empty() && !b.is_empty() && a.chars().all(|c| c.is_ascii_digit()) && b.chars().all(|c| c.is_ascii_digit()))
}

pub(crate) fn sanitize_script_content(content: &str) -> String {
    const META_MARKERS: &[&str] = &["预览", "概览", "字数统计", "总字数", "创作说明"];
    content
        .lines()
        .filter(|line| {
            let trimmed = line.trim().trim_start_matches(['#', '*', '-', ' ']);
            !META_MARKERS
                .iter()
                .any(|marker| trimmed.starts_with(marker))
        })
        .collect::<Vec<_>>()
        .join("\n")
        .trim()
        .to_string()
}

pub(crate) fn validate_script_for_episode(name: &str, content: &str) -> Result<(), String> {
    validate_generated_script(content)?;
    if let Some(expected) = script_episode_number(name)
        && let Some(actual) = content.lines().find_map(script_episode_number)
        && expected != actual
    {
        return Err(format!(
            "剧本名称为第{expected}集，但正文文件头为第{actual}集"
        ));
    }
    Ok(())
}

fn attribute_name(opening_tag: &str) -> Option<String> {
    let start = opening_tag.find("name=")? + "name=".len();
    let quote = opening_tag.as_bytes().get(start).copied()? as char;
    if quote != '\'' && quote != '"' {
        return None;
    }
    let value = &opening_tag[start + 1..];
    Some(value[..value.find(quote)?].trim().to_string())
}

pub(crate) fn parse_script_items(content: &str) -> Result<Vec<(String, String)>, String> {
    let mut rest = content;
    let mut items = Vec::new();
    while let Some(start) = rest.find("<scriptItem") {
        if !rest[..start].trim().is_empty() {
            return Err("<scriptItem> 标签外存在额外内容".into());
        }
        let tag_end = rest[start..]
            .find('>')
            .map(|offset| start + offset)
            .ok_or("scriptItem 开始标签不完整")?;
        let name = attribute_name(&rest[start..=tag_end]).ok_or("scriptItem 缺少合法 name 属性")?;
        let body_start = tag_end + 1;
        let close = rest[body_start..]
            .find("</scriptItem>")
            .map(|offset| body_start + offset)
            .ok_or("scriptItem 缺少结束标签")?;
        let body = sanitize_script_content(&rest[body_start..close]);
        if name.is_empty() || body.is_empty() {
            return Err("scriptItem 的 name 和正文不能为空".into());
        }
        let header = body
            .lines()
            .find(|line| !line.trim().is_empty())
            .map(|line| line.trim().trim_start_matches('#').trim())
            .unwrap_or_default();
        if header != name {
            return Err(format!(
                "scriptItem name“{name}”与正文首行标题“{header}”不一致"
            ));
        }
        items.push((name, body));
        rest = &rest[close + "</scriptItem>".len()..];
    }
    if items.is_empty() && content.contains("scriptItem") {
        return Err("无法解析 scriptItem XML，请重新传入完整标签".into());
    }
    if !rest.trim().is_empty() && !items.is_empty() {
        return Err("</scriptItem> 后存在额外内容".into());
    }
    Ok(items)
}

pub(crate) fn normalize_script_items(scripts: &[Value]) -> Result<Vec<(String, String)>, AppError> {
    let mut normalized = Vec::new();
    for script in scripts {
        let declared_name = script
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim();
        let raw = script
            .get("content")
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim();
        if raw.is_empty() {
            return Err(AppError::bad_request("剧本内容不能为空"));
        }
        let parsed = parse_script_items(raw).map_err(AppError::bad_request)?;
        if parsed.is_empty() {
            if declared_name.is_empty() {
                return Err(AppError::bad_request("剧本名称不能为空"));
            }
            normalized.push((declared_name.to_string(), sanitize_script_content(raw)));
        } else {
            if parsed.len() == 1 && !declared_name.is_empty() && parsed[0].0 != declared_name {
                return Err(AppError::bad_request(format!(
                    "剧本名称“{declared_name}”与 scriptItem name“{}”不一致",
                    parsed[0].0
                )));
            }
            normalized.extend(parsed);
        }
    }
    Ok(normalized)
}

#[cfg(test)]
mod tests {
    use super::{
        episode_limit, episode_references, explicit_episode_limit, script_episode_number,
        validate_generated_script,
    };

    #[test]
    fn parses_single_and_ranged_episode_references() {
        assert_eq!(
            episode_references("第1集、第4-6集、原著第10章"),
            vec![1, 4, 6]
        );
        assert_eq!(explicit_episode_limit("生成1-3集"), Some(3));
        assert_eq!(explicit_episode_limit("请编写第1/5集剧本"), Some(5));
    }

    #[test]
    fn current_request_can_narrow_the_workspace_scope() {
        let strategy = "#### 第1集\n#### 第2集\n#### 第3集\n#### 第4集\n#### 第5集";
        assert_eq!(episode_limit(strategy, "本次只生成1-3集"), Some(3));
        assert_eq!(episode_limit(strategy, "本次生成1-5集"), Some(5));
    }

    #[test]
    fn rejects_placeholder_or_truncated_scripts() {
        assert!(validate_generated_script("（根据第1集生成结果补充）").is_err());
        assert!(validate_generated_script("稍后补充完整剧本").is_err());
        assert!(
            validate_generated_script(&format!(
                "第1集\n1-1 客厅 日/内\n人物：甲\n△甲走进客厅。\n{}",
                "完整剧本正文".repeat(40)
            ))
            .is_ok()
        );
    }

    #[test]
    fn parses_episode_number_from_script_names() {
        assert_eq!(script_episode_number("作品 EP01：开端"), Some(1));
        assert_eq!(script_episode_number("作品 第12集"), Some(12));
        assert_eq!(script_episode_number("作品正文"), None);
    }

    #[test]
    fn parses_and_cleans_multiple_script_items() {
        let input = format!(
            "<scriptItem name=\"第1集\">第1集\n1-1 客厅 日/内\n△动作\n预览：删除\n{}</scriptItem><scriptItem name='第2集'>第2集\n2-1 街道 夜/外\n△动作\n{}</scriptItem>",
            "正文".repeat(100),
            "正文".repeat(100)
        );
        let items = super::parse_script_items(&input).unwrap();
        assert_eq!(items.len(), 2);
        assert!(!items[0].1.contains("预览"));
    }

    #[test]
    fn rejects_scene_and_episode_mismatches() {
        assert!(
            super::validate_script_for_episode(
                "第2集",
                &format!("第1集\n1-1 客厅 日/内\n△动作\n{}", "正文".repeat(100))
            )
            .is_err()
        );
        assert!(
            validate_generated_script(&format!(
                "第1集\n第一场 日/内\n△动作\n{}",
                "正文".repeat(100)
            ))
            .is_err()
        );
    }
}

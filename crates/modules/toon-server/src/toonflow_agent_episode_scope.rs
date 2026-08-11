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
        if index < chars.len() && chars[index] == '集' {
            if let Some(limit) = last_number {
                limits.push(limit);
            }
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
    Ok(())
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
        assert!(validate_generated_script(&"完整剧本正文".repeat(40)).is_ok());
    }

    #[test]
    fn parses_episode_number_from_script_names() {
        assert_eq!(script_episode_number("作品 EP01：开端"), Some(1));
        assert_eq!(script_episode_number("作品 第12集"), Some(12));
        assert_eq!(script_episode_number("作品正文"), None);
    }
}

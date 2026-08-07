const AGE_MARKERS: [(&str, &str); 9] = [
    ("小时候的", "child"),
    ("童年时期的", "child"),
    ("幼年时期的", "child"),
    ("童年", "child"),
    ("幼年", "child"),
    ("少年", "teen"),
    ("青年", "young_adult"),
    ("中年", "middle_aged"),
    ("老年", "senior"),
];

pub(crate) fn normalize_role_name(raw: &str) -> (String, Option<&'static str>) {
    let mut name = raw.trim().to_string();
    for (marker, stage) in AGE_MARKERS {
        if let Some(stripped) = name.strip_prefix(marker) {
            return (
                stripped.trim_start_matches('的').trim().to_string(),
                Some(stage),
            );
        }
        for suffix in [
            format!("（{marker}）"),
            format!("({marker})"),
            format!("·{marker}"),
            format!("-{marker}"),
            format!(" {marker}"),
        ] {
            if name.ends_with(&suffix) {
                name.truncate(name.len() - suffix.len());
                return (name.trim().to_string(), Some(stage));
            }
        }
    }
    (name, None)
}

pub(crate) fn normalize_age_stage(raw: &str) -> Option<&'static str> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "child" | "childhood" | "童年" | "幼年" => Some("child"),
        "teen" | "teenager" | "少年" => Some("teen"),
        "young_adult" | "youngadult" | "青年" => Some("young_adult"),
        "adult" | "成年" => Some("adult"),
        "middle_aged" | "middle-aged" | "中年" => Some("middle_aged"),
        "senior" | "elderly" | "老年" | "暮年" => Some("senior"),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::{normalize_age_stage, normalize_role_name};

    #[test]
    fn separates_age_marker_from_canonical_role() {
        assert_eq!(
            normalize_role_name("童年王闲"),
            ("王闲".into(), Some("child"))
        );
        assert_eq!(
            normalize_role_name("王闲（少年）"),
            ("王闲".into(), Some("teen"))
        );
        assert_eq!(normalize_role_name("王闲"), ("王闲".into(), None));
        assert_eq!(normalize_age_stage("老年"), Some("senior"));
    }
}

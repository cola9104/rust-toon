use serde_json::{Value, json};

pub(crate) fn manual_trigger() -> String {
    "manual".into()
}
pub(crate) fn empty_object() -> Value {
    json!({})
}
pub(crate) const fn default_concurrency() -> usize {
    5
}

pub(crate) fn merge_node_settings(base: &Value, override_value: Option<&Value>) -> Value {
    let mut merged = base.as_object().cloned().unwrap_or_default();
    if let Some(overrides) = override_value.and_then(Value::as_object) {
        merged.extend(overrides.clone());
    }
    Value::Object(merged)
}

#[cfg(test)]
mod tests {
    use super::{default_concurrency, empty_object, manual_trigger, merge_node_settings};
    use serde_json::json;

    #[test]
    fn workflow_defaults_and_overrides_are_stable() {
        assert_eq!(manual_trigger(), "manual");
        assert_eq!(empty_object(), json!({}));
        assert_eq!(default_concurrency(), 5);
        assert_eq!(
            merge_node_settings(&json!({"a": 1}), Some(&json!({"a": 2}))),
            json!({"a": 2})
        );
    }
}

use std::collections::HashMap;

use rust_toon_framework_web::AppError;
use serde_json::{Value, json};

pub(super) fn parse_i64_param(
    params: &HashMap<String, String>,
    key: &str,
) -> Result<i64, AppError> {
    params
        .get(key)
        .ok_or_else(|| AppError::bad_request(format!("{key} is required")))
        .and_then(|value| {
            value
                .parse::<i64>()
                .map_err(|_| AppError::bad_request(format!("{key} is invalid")))
        })
}

pub(super) fn parse_i64_value(value: &Value) -> Result<i64, AppError> {
    value
        .as_i64()
        .or_else(|| value.as_str().and_then(|value| value.parse::<i64>().ok()))
        .ok_or_else(|| AppError::bad_request("id is required"))
}

pub(super) fn split_i64_ids(params: &HashMap<String, String>) -> Vec<i64> {
    params
        .get("ids")
        .into_iter()
        .flat_map(|ids| ids.split(','))
        .filter_map(|id| id.parse::<i64>().ok())
        .collect()
}

pub(super) fn str_field(value: &Value, key: &str) -> String {
    str_field_default(value, key, "")
}

pub(super) fn str_field_default(value: &Value, key: &str, default: &str) -> String {
    value
        .get(key)
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .unwrap_or(default)
        .to_string()
}

pub(super) fn opt_str_field(value: &Value, key: &str) -> Option<String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

pub(super) fn i16_field(value: &Value, key: &str, default: i16) -> i16 {
    value
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|value| i16::try_from(value).ok())
        .unwrap_or(default)
}

pub(super) fn opt_i16_field(value: &Value, key: &str) -> Option<i16> {
    value
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|value| i16::try_from(value).ok())
}

pub(super) fn i32_field(value: &Value, key: &str, default: i32) -> i32 {
    value
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|value| i32::try_from(value).ok())
        .unwrap_or(default)
}

pub(super) fn i64_field(value: &Value, key: &str, default: i64) -> i64 {
    value
        .get(key)
        .and_then(Value::as_i64)
        .or_else(|| {
            value
                .get(key)
                .and_then(Value::as_str)
                .and_then(|value| value.parse::<i64>().ok())
        })
        .unwrap_or(default)
}

pub(super) fn opt_i64_field(value: &Value, key: &str) -> Option<i64> {
    value.get(key).and_then(|value| {
        value
            .as_i64()
            .or_else(|| value.as_str().and_then(|value| value.parse::<i64>().ok()))
    })
}

pub(super) fn i64_vec_field(value: &Value, key: &str) -> Vec<i64> {
    value
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|value| {
            value
                .as_i64()
                .or_else(|| value.as_str().and_then(|value| value.parse::<i64>().ok()))
        })
        .collect()
}

pub(super) fn string_list_field(value: &Value, key: &str) -> String {
    value
        .get(key)
        .and_then(Value::as_array)
        .map(|values| Value::Array(values.clone()).to_string())
        .or_else(|| {
            value
                .get(key)
                .and_then(Value::as_str)
                .map(|value| json!([value]).to_string())
        })
        .unwrap_or_else(|| json!([]).to_string())
}

pub(super) fn csv_list_field(value: &Value, key: &str) -> String {
    value
        .get(key)
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .collect::<Vec<_>>()
                .join(",")
        })
        .or_else(|| value.get(key).and_then(Value::as_str).map(str::to_owned))
        .unwrap_or_default()
}

pub(super) fn bool_field(value: &Value, key: &str, default: bool) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(default)
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use serde_json::json;

    use super::{i64_field, i64_vec_field, parse_i64_param, string_list_field};

    #[test]
    fn accepts_numeric_compatibility_values_from_strings_or_numbers() {
        let value = json!({"id": "42", "ids": [1, "2", "bad"]});
        assert_eq!(i64_field(&value, "id", 0), 42);
        assert_eq!(i64_vec_field(&value, "ids"), vec![1, 2]);

        let params = HashMap::from([("id".to_string(), "7".to_string())]);
        assert_eq!(parse_i64_param(&params, "id").unwrap(), 7);
    }

    #[test]
    fn serializes_single_or_multiple_list_values_consistently() {
        assert_eq!(
            string_list_field(&json!({"items": "one"}), "items"),
            r#"["one"]"#
        );
        assert_eq!(
            string_list_field(&json!({"items": ["one", "two"]}), "items"),
            r#"["one","two"]"#
        );
    }
}

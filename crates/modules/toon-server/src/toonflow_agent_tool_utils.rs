use rust_toon_framework_web::AppError;
use serde_json::{Value, json};
use sqlx::PgPool;
use std::time::{SystemTime, UNIX_EPOCH};
use std::{
    collections::HashMap,
    sync::{LazyLock, Mutex},
};

pub(crate) fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

static FLOW_DATA_CACHE: LazyLock<Mutex<HashMap<String, String>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub(crate) fn changed_flow_data(isolation_key: &str, key: &str, value: Value) -> Value {
    let cache_key = format!("{isolation_key}:{key}");
    let serialized = value.to_string();
    let mut cache = FLOW_DATA_CACHE
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    if cache
        .get(&cache_key)
        .is_some_and(|previous| previous == &serialized)
    {
        return json!(format!("{key} 数据未变化，无需更新"));
    }
    cache.insert(cache_key, serialized);
    value
}

pub(crate) async fn role_names_without_appearances(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
) -> Result<Vec<String>, AppError> {
    sqlx::query_scalar(
        "SELECT a.name FROM toonflow.script_assets sa JOIN toonflow.assets a ON a.id=sa.asset_id WHERE sa.script_id=$1 AND a.project_id=$2 AND a.type='role' AND a.parent_asset_id IS NULL AND NOT EXISTS (SELECT 1 FROM toonflow.character_appearances ca WHERE ca.script_id=$1 AND ca.role_asset_id=a.id) ORDER BY a.id",
    )
    .bind(script_id)
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to validate extracted character appearances"))
}

pub(crate) async fn missing_appearance_derivatives(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
) -> Result<Vec<String>, AppError> {
    sqlx::query_scalar(
        "SELECT a.name || ' / ' || ca.name FROM toonflow.character_appearances ca JOIN toonflow.assets a ON a.id=ca.role_asset_id WHERE ca.script_id=$1 AND ca.project_id=$2 AND NOT EXISTS (SELECT 1 FROM toonflow.assets d WHERE d.appearance_id=ca.id AND d.parent_asset_id=ca.role_asset_id) ORDER BY a.id,ca.id",
    )
    .bind(script_id)
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to validate appearance derivatives"))
}

pub(crate) fn tagged(text: &str, tag: &str) -> Option<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let start = text.find(&open)? + open.len();
    let end = text[start..].find(&close)? + start;
    Some(text[start..end].trim().to_string())
}

pub(crate) fn required_tagged(text: &str, tag: &str) -> Result<String, AppError> {
    tagged(text, tag).ok_or_else(|| {
        AppError::bad_request(format!(
            "子 Agent 未输出 <{tag}> 标签，请按要求重新派发该阶段任务"
        ))
    })
}

pub(crate) fn script_format_instruction() -> &'static str {
    "\n\n你必须只使用如下 XML 格式输出，不得添加其他 XML 标签：\n<scriptItem name=\"剧本名称\">剧本完整内容</scriptItem>。每集一个 scriptItem。"
}

pub(crate) fn workspace_format_instruction(tag: &str, label: &str) -> String {
    format!("\n\n你必须使用如下 XML 格式写入工作区：\n<{tag}>{label}内容</{tag}>")
}

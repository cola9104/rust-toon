use rust_toon_framework_database::PgPool;
use serde_json::Value;
use std::time::{SystemTime, UNIX_EPOCH};

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or_default()
}

pub(crate) async fn record(pool: &PgPool, run_id: i64, event_type: &str, data: Value) {
    sqlx::query(
        "INSERT INTO toonflow.agent_run_events(run_id,event_type,data,create_time) VALUES($1,$2,$3,$4)",
    )
    .bind(run_id)
    .bind(event_type)
    .bind(data)
    .bind(now_ms())
    .execute(pool)
    .await
    .ok();
}

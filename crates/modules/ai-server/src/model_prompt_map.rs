use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::Deserialize;
use serde_json::{Value, json};
use sqlx::Row;

use crate::{AiState, require};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListRequest {
    pub model_config_id: Option<i64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveRequest {
    pub id: Option<i64>,
    pub model_config_id: i64,
    pub prompt_key: String,
    pub enabled: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct DeleteRequest {
    pub id: i64,
}

pub async fn list(
    user: CurrentUser,
    State(state): State<AiState>,
    Json(request): Json<ListRequest>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "ai:model:query")?;
    let rows = sqlx::query(
        "SELECT map.id,map.model_config_id,map.prompt_key,map.enabled,m.name model_name,m.model FROM ai.model_prompt_maps map JOIN ai.model_configs m ON m.id=map.model_config_id WHERE ($1::bigint IS NULL OR map.model_config_id=$1) ORDER BY map.id DESC",
    )
    .bind(request.model_config_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list model prompt maps"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter()
            .map(|row| {
                json!({
                    "id": row.get::<i64, _>("id"),
                    "modelConfigId": row.get::<i64, _>("model_config_id"),
                    "promptKey": row.get::<String, _>("prompt_key"),
                    "enabled": row.get::<bool, _>("enabled"),
                    "modelName": row.get::<String, _>("model_name"),
                    "model": row.get::<String, _>("model"),
                })
            })
            .collect(),
    )))
}

pub async fn save(
    user: CurrentUser,
    State(state): State<AiState>,
    Json(request): Json<SaveRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "ai:model:update")?;
    if request.prompt_key.trim().is_empty() {
        return Err(AppError::bad_request("promptKey 不能为空"));
    }
    let exists: bool =
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM ai.model_configs WHERE id=$1)")
            .bind(request.model_config_id)
            .fetch_one(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to validate model"))?;
    if !exists {
        return Err(AppError::not_found("AI 模型不存在"));
    }
    let id = request
        .id
        .unwrap_or_else(|| chrono::Utc::now().timestamp_millis());
    let now = chrono::Utc::now().timestamp_millis();
    sqlx::query("INSERT INTO ai.model_prompt_maps(id,model_config_id,prompt_key,enabled,create_time,update_time) VALUES($1,$2,$3,$4,$5,$5) ON CONFLICT(model_config_id,prompt_key) DO UPDATE SET enabled=excluded.enabled,update_time=excluded.update_time")
        .bind(id).bind(request.model_config_id).bind(request.prompt_key.trim()).bind(request.enabled.unwrap_or(true)).bind(now)
        .execute(&state.pool).await.map_err(|error| if error.to_string().contains("duplicate") { AppError::bad_request("该模型已绑定此 Prompt") } else { AppError::internal("failed to save model prompt map") })?;
    Ok(Json(ApiResponse::new(json!({ "id": id }))))
}

pub async fn remove(
    user: CurrentUser,
    State(state): State<AiState>,
    Json(request): Json<DeleteRequest>,
) -> Result<Json<ApiResponse<bool>>, AppError> {
    require(&user, "ai:model:update")?;
    let result = sqlx::query("DELETE FROM ai.model_prompt_maps WHERE id=$1")
        .bind(request.id)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to delete model prompt map"))?;
    Ok(Json(ApiResponse::new(result.rows_affected() > 0)))
}

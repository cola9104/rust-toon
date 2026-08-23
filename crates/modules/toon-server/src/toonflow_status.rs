use axum::Json;
use rust_toon_framework_common::ApiResponse;
use serde_json::{Value, json};

/// Toonflow capability/status endpoint kept separate from the domain handlers.
pub async fn health() -> Json<ApiResponse<Value>> {
    Json(ApiResponse::new(json!({
        "module": "toonflow",
        "capabilities": [
            "project", "novel", "script", "assets", "storyboard",
            "production-flow", "vendor-config", "agent-deploy"
        ]
    })))
}

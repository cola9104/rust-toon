use axum::{Json, routing::get};
use chrono::{DateTime, Utc};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub service: String,
    pub status: &'static str,
    pub checked_at: DateTime<Utc>,
}

pub fn is_health_probe_path(path: &str) -> bool {
    matches!(path, "/health" | "/livez" | "/readyz")
}

pub fn health_route(service_name: &'static str) -> axum::Router {
    axum::Router::new().route(
        "/health",
        get(move || async move {
            Json(HealthResponse {
                service: service_name.to_string(),
                status: "ok",
                checked_at: Utc::now(),
            })
        }),
    )
}

#[cfg(test)]
mod tests {
    use super::is_health_probe_path;

    #[test]
    fn identifies_only_gateway_health_probe_paths() {
        assert!(is_health_probe_path("/health"));
        assert!(is_health_probe_path("/livez"));
        assert!(is_health_probe_path("/readyz"));
        assert!(!is_health_probe_path("/toonflow/health"));
        assert!(!is_health_probe_path("/readyz/extra"));
    }
}

#![recursion_limit = "256"]

use axum::{Json, Router, middleware::from_fn_with_state, routing::get};
use rust_toon_framework_common::{ApiResponse, ServiceConfig, health_route, init_tracing, serve};
use rust_toon_framework_database::{DatabaseConfig, connect, migrate};
use rust_toon_framework_redis::{RateLimitConfig, RateLimitState, RedisClient, RedisConfig};
use rust_toon_framework_security::{SecurityConfig, TokenService};
use rust_toon_framework_web::{AppError, WebConfig, apply_web_layers};
use serde::Serialize;
use tracing::warn;

mod audit;
mod openapi;
mod readiness;

const SERVICE_NAME: &str = "gateway";

#[derive(Debug, Serialize)]
struct GatewayIndex {
    service: &'static str,
    modules: [&'static str; 5],
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing(SERVICE_NAME);

    let database = connect(&DatabaseConfig::from_env()?).await?;
    migrate(&database).await?;
    rust_toon_toon_server::repair_interrupted_state(&database).await?;
    let redis_configured = std::env::var_os("REDIS_URL").is_some();
    let redis = connect_redis().await;
    let tokens = TokenService::new(SecurityConfig::from_env()?);
    let system_state = rust_toon_system_server::SystemState::with_cache(
        database.clone(),
        tokens.clone(),
        redis.clone(),
    );
    let infra_state = rust_toon_infra_server::InfraState::new(database.clone());
    let ai_state = rust_toon_ai_server::AiState::new(database.clone(), tokens.clone());
    let toon_state = rust_toon_toon_server::ToonState::new(database.clone(), tokens.clone());
    let recovered_cleanup = toon_state.recover_storage_cleanup_tasks().await?;
    tracing::info!(recovered_cleanup, "storage cleanup tasks recovered");
    let media_state = rust_toon_media_server::MediaState::new(database.clone(), tokens);
    system_state.bootstrap().await?;
    let recovered_images = toon_state.recover_interrupted_image_tasks().await?;
    if recovered_images > 0 {
        warn!(
            recovered_images,
            "marked image tasks interrupted by the previous process as failed"
        );
    }
    let database_auth = system_state.database_auth_state();

    let mut app = Router::new()
        .route("/", get(index))
        .route("/openapi.json", get(openapi::document))
        .merge(rust_toon_system_server::routes(system_state))
        .merge(rust_toon_infra_server::routes(infra_state))
        .merge(rust_toon_ai_server::routes(ai_state))
        .merge(rust_toon_toon_server::routes(toon_state))
        .merge(rust_toon_media_server::routes(media_state))
        .merge(readiness::routes(readiness::ReadinessState::new(
            database.clone(),
            redis.clone(),
            redis_configured,
        )))
        .merge(health_route(SERVICE_NAME))
        .fallback(not_found)
        .layer(from_fn_with_state(
            audit::AuditState::new(database),
            audit::record,
        ))
        .layer(from_fn_with_state(
            database_auth,
            rust_toon_system_server::authenticate_from_database,
        ));

    if let Some(redis) = redis {
        app = app.layer(from_fn_with_state(
            RateLimitState::new(redis, RateLimitConfig::from_env()),
            rust_toon_framework_redis::rate_limit,
        ));
    }

    let app = apply_web_layers(app, WebConfig::from_env());

    serve(ServiceConfig::from_env(SERVICE_NAME, 8080), app).await
}

async fn connect_redis() -> Option<RedisClient> {
    let config = RedisConfig::from_env()?;
    match RedisClient::connect(&config).await {
        Ok(client) => Some(client),
        Err(error) => {
            warn!(%error, "redis is configured but unavailable; cache and rate limit disabled");
            None
        }
    }
}

async fn not_found() -> AppError {
    AppError::not_found("route not found")
}

async fn index() -> Json<ApiResponse<GatewayIndex>> {
    Json(ApiResponse::new(GatewayIndex {
        service: SERVICE_NAME,
        modules: ["system", "infra", "ai", "toon", "media"],
    }))
}

use axum::{Router, body::Body, http::HeaderName};
use std::env;
use tower_http::{
    cors::{Any, CorsLayer},
    request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer},
    trace::TraceLayer,
};

const REQUEST_ID_HEADER: &str = "x-request-id";

#[derive(Debug, Clone, Default)]
pub struct WebConfig {
    /// Development-friendly default. Restrict this at the reverse proxy in production.
    pub permissive_cors: bool,
}

impl WebConfig {
    pub fn development() -> Self {
        Self {
            permissive_cors: true,
        }
    }

    pub fn from_env() -> Self {
        let permissive_cors = env::var("WEB_PERMISSIVE_CORS")
            .or_else(|_| env::var("CORS_PERMISSIVE"))
            .map(|value| matches!(value.as_str(), "1" | "true" | "TRUE" | "yes" | "YES"))
            .unwrap_or(false);

        Self { permissive_cors }
    }
}

pub fn apply_web_layers(router: Router, config: WebConfig) -> Router {
    let request_id_header = HeaderName::from_static(REQUEST_ID_HEADER);
    let router = router
        .layer(PropagateRequestIdLayer::new(request_id_header.clone()))
        .layer(SetRequestIdLayer::new(request_id_header, MakeRequestUuid))
        .layer(
            TraceLayer::new_for_http().make_span_with(|request: &axum::http::Request<Body>| {
                // Never include the query string here: Toonflow's compatible
                // WebSocket URL carries a JWT query parameter.
                let span = tracing::info_span!(
                    "http_request",
                    method = %request.method(),
                    path = %request.uri().path(),
                    trace_id = tracing::field::Empty,
                    "otel.kind" = "server",
                );
                rust_toon_framework_telemetry::set_parent_from_headers(&span, request.headers());
                span
            }),
        );

    if config.permissive_cors {
        router.layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
    } else {
        router
    }
}

#[cfg(test)]
mod tests {
    use axum::{Router, body::Body, http::Request, routing::get};
    use tower::ServiceExt;

    use super::{WebConfig, apply_web_layers};

    #[tokio::test]
    async fn adds_and_propagates_request_id() {
        let app = apply_web_layers(
            Router::new().route("/", get(|| async { "ok" })),
            WebConfig::default(),
        );

        let response = app
            .oneshot(Request::builder().uri("/").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert!(response.headers().contains_key("x-request-id"));
    }

    #[tokio::test]
    async fn preserves_client_request_id() {
        let app = apply_web_layers(
            Router::new().route("/", get(|| async { "ok" })),
            WebConfig::default(),
        );

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/")
                    .header("x-request-id", "client-id")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.headers()["x-request-id"], "client-id");
    }

    #[test]
    fn development_enables_permissive_cors() {
        assert!(WebConfig::development().permissive_cors);
    }
}

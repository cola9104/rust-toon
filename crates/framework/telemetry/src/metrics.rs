use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use axum::{
    Router,
    body::Body,
    extract::{MatchedPath, Request, State},
    http::{HeaderValue, Method, StatusCode, header::CONTENT_TYPE},
    middleware::Next,
    response::{IntoResponse, Response},
    routing::get,
};
use prometheus_client::{
    encoding::{EncodeLabelSet, text::encode},
    metrics::{
        counter::Counter,
        family::Family,
        gauge::Gauge,
        histogram::{Histogram, exponential_buckets},
    },
    registry::Registry,
};

const OPENMETRICS_CONTENT_TYPE: &str = "application/openmetrics-text; version=1.0.0; charset=utf-8";

#[derive(Clone)]
pub struct Metrics {
    inner: Arc<MetricsInner>,
}

struct MetricsInner {
    enabled: bool,
    service: String,
    registry: Registry,
    http_requests: Family<HttpLabels, Counter>,
    http_duration: Family<HttpLabels, Histogram>,
    http_inflight: Gauge,
    worker_jobs: Family<WorkerJobLabels, Counter>,
    worker_job_duration: Family<WorkerJobLabels, Histogram>,
    worker_inflight: Family<WorkerKindLabels, Gauge>,
    worker_dispatches: Family<WorkerJobLabels, Counter>,
    worker_lease_reaps: Family<OutcomeLabels, Counter>,
    worker_storage_cleanup: Family<OutcomeLabels, Counter>,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
struct HttpLabels {
    service: String,
    method: String,
    route: String,
    status: String,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
struct WorkerJobLabels {
    service: String,
    kind: String,
    outcome: String,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
struct WorkerKindLabels {
    service: String,
    kind: String,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
struct OutcomeLabels {
    service: String,
    outcome: String,
}

impl Metrics {
    pub fn new(service: impl Into<String>, enabled: bool) -> Self {
        let service = service.into();
        let http_requests = Family::<HttpLabels, Counter>::default();
        let http_duration = Family::<HttpLabels, Histogram>::new_with_constructor(|| {
            Histogram::new(exponential_buckets(0.005, 2.0, 16))
        });
        let http_inflight = Gauge::default();
        let worker_jobs = Family::<WorkerJobLabels, Counter>::default();
        let worker_job_duration =
            Family::<WorkerJobLabels, Histogram>::new_with_constructor(|| {
                Histogram::new(exponential_buckets(0.1, 2.0, 18))
            });
        let worker_inflight = Family::<WorkerKindLabels, Gauge>::default();
        let worker_dispatches = Family::<WorkerJobLabels, Counter>::default();
        let worker_lease_reaps = Family::<OutcomeLabels, Counter>::default();
        let worker_storage_cleanup = Family::<OutcomeLabels, Counter>::default();

        let mut registry = Registry::with_prefix("rust_toon");
        registry.register(
            "http_requests",
            "Total number of completed HTTP requests.",
            http_requests.clone(),
        );
        registry.register(
            "http_request_duration_seconds",
            "HTTP request duration in seconds.",
            http_duration.clone(),
        );
        registry.register(
            "http_requests_inflight",
            "Number of HTTP requests currently being served.",
            http_inflight.clone(),
        );
        registry.register(
            "worker_jobs",
            "Total number of durable worker job outcomes.",
            worker_jobs.clone(),
        );
        registry.register(
            "worker_job_duration_seconds",
            "Durable worker job execution duration in seconds.",
            worker_job_duration.clone(),
        );
        registry.register(
            "worker_jobs_inflight",
            "Number of durable worker jobs currently executing.",
            worker_inflight.clone(),
        );
        registry.register(
            "worker_dispatches",
            "Total number of durable outbox dispatch outcomes.",
            worker_dispatches.clone(),
        );
        registry.register(
            "worker_lease_reaps",
            "Total number of expired job leases reaped.",
            worker_lease_reaps.clone(),
        );
        registry.register(
            "worker_storage_cleanup",
            "Total number of object cleanup outcomes.",
            worker_storage_cleanup.clone(),
        );

        Self {
            inner: Arc::new(MetricsInner {
                enabled,
                service,
                registry,
                http_requests,
                http_duration,
                http_inflight,
                worker_jobs,
                worker_job_duration,
                worker_inflight,
                worker_dispatches,
                worker_lease_reaps,
                worker_storage_cleanup,
            }),
        }
    }

    pub fn enabled(&self) -> bool {
        self.inner.enabled
    }

    /// Returns a state-resolved `/metrics` router suitable for merging into a
    /// service router after authentication/audit layers have been applied.
    pub fn routes(&self) -> Router {
        Router::new()
            .route("/metrics", get(scrape))
            .with_state(self.clone())
    }

    pub fn encode(&self) -> Result<String, std::fmt::Error> {
        let mut body = String::new();
        encode(&mut body, &self.inner.registry)?;
        Ok(body)
    }

    pub fn worker_job_started(&self, kind: impl Into<String>) -> WorkerJobTimer {
        let kind = kind.into();
        if self.enabled() {
            self.inner
                .worker_inflight
                .get_or_create(&WorkerKindLabels {
                    service: self.inner.service.clone(),
                    kind: kind.clone(),
                })
                .inc();
        }
        WorkerJobTimer {
            metrics: self.clone(),
            kind,
            started: Instant::now(),
            finished: false,
        }
    }

    pub fn record_worker_dispatch(&self, kind: impl Into<String>, outcome: impl Into<String>) {
        if !self.enabled() {
            return;
        }
        self.inner
            .worker_dispatches
            .get_or_create(&WorkerJobLabels {
                service: self.inner.service.clone(),
                kind: kind.into(),
                outcome: outcome.into(),
            })
            .inc();
    }

    pub fn record_worker_lease_reaps(&self, retried: u64, failed: u64) {
        if !self.enabled() {
            return;
        }
        self.increment_outcomes(&self.inner.worker_lease_reaps, "retried", retried);
        self.increment_outcomes(&self.inner.worker_lease_reaps, "failed", failed);
    }

    pub fn record_worker_storage_cleanup(&self, completed: u64, deferred: u64, failed: u64) {
        if !self.enabled() {
            return;
        }
        self.increment_outcomes(&self.inner.worker_storage_cleanup, "completed", completed);
        self.increment_outcomes(&self.inner.worker_storage_cleanup, "deferred", deferred);
        self.increment_outcomes(&self.inner.worker_storage_cleanup, "failed", failed);
    }

    fn increment_outcomes(
        &self,
        family: &Family<OutcomeLabels, Counter>,
        outcome: &str,
        count: u64,
    ) {
        if count == 0 {
            return;
        }
        family
            .get_or_create(&OutcomeLabels {
                service: self.inner.service.clone(),
                outcome: outcome.to_string(),
            })
            .inc_by(count);
    }

    fn finish_worker_job(&self, kind: &str, outcome: &str, elapsed: Duration) {
        if !self.enabled() {
            return;
        }
        let labels = WorkerJobLabels {
            service: self.inner.service.clone(),
            kind: kind.to_string(),
            outcome: outcome.to_string(),
        };
        self.inner.worker_jobs.get_or_create(&labels).inc();
        self.inner
            .worker_job_duration
            .get_or_create(&labels)
            .observe(elapsed.as_secs_f64());
        self.inner
            .worker_inflight
            .get_or_create(&WorkerKindLabels {
                service: self.inner.service.clone(),
                kind: kind.to_string(),
            })
            .dec();
    }
}

pub struct WorkerJobTimer {
    metrics: Metrics,
    kind: String,
    started: Instant,
    finished: bool,
}

impl WorkerJobTimer {
    pub fn finish(mut self, outcome: &str) {
        self.metrics
            .finish_worker_job(&self.kind, outcome, self.started.elapsed());
        self.finished = true;
    }
}

impl Drop for WorkerJobTimer {
    fn drop(&mut self) {
        if !self.finished {
            self.metrics
                .finish_worker_job(&self.kind, "cancelled", self.started.elapsed());
        }
    }
}

struct HttpInflightGuard<'a>(&'a Gauge);

impl Drop for HttpInflightGuard<'_> {
    fn drop(&mut self) {
        self.0.dec();
    }
}

/// Axum middleware that records bounded-cardinality HTTP metrics. It uses the
/// matched route template, never the raw URI or query string.
pub async fn record_http_metrics(
    State(metrics): State<Metrics>,
    request: Request<Body>,
    next: Next,
) -> Response {
    if !metrics.enabled() {
        return next.run(request).await;
    }
    metrics.inner.http_inflight.inc();
    let _inflight = HttpInflightGuard(&metrics.inner.http_inflight);
    let started = Instant::now();
    let method = method_label(request.method()).to_string();
    let route = request
        .extensions()
        .get::<MatchedPath>()
        .map(MatchedPath::as_str)
        .unwrap_or("<unmatched>")
        .to_string();
    let response = next.run(request).await;
    let labels = HttpLabels {
        service: metrics.inner.service.clone(),
        method,
        route,
        status: response.status().as_u16().to_string(),
    };
    metrics.inner.http_requests.get_or_create(&labels).inc();
    metrics
        .inner
        .http_duration
        .get_or_create(&labels)
        .observe(started.elapsed().as_secs_f64());
    response
}

fn method_label(method: &Method) -> &'static str {
    match method.as_str() {
        "GET" => "GET",
        "POST" => "POST",
        "PUT" => "PUT",
        "PATCH" => "PATCH",
        "DELETE" => "DELETE",
        "HEAD" => "HEAD",
        "OPTIONS" => "OPTIONS",
        "CONNECT" => "CONNECT",
        "TRACE" => "TRACE",
        _ => "OTHER",
    }
}

async fn scrape(State(metrics): State<Metrics>) -> Response {
    if !metrics.enabled() {
        return StatusCode::NOT_FOUND.into_response();
    }
    match metrics.encode() {
        Ok(body) => {
            let mut response = body.into_response();
            response.headers_mut().insert(
                CONTENT_TYPE,
                HeaderValue::from_static(OPENMETRICS_CONTENT_TYPE),
            );
            response
        }
        Err(error) => {
            tracing::error!(%error, "failed to encode Prometheus metrics");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

#[cfg(test)]
mod tests {
    use axum::{
        Router,
        body::{Body, to_bytes},
        http::Request,
        middleware::from_fn_with_state,
        routing::get,
    };
    use tower::ServiceExt;

    use super::{Metrics, method_label, record_http_metrics};

    #[tokio::test]
    async fn http_metrics_use_route_templates_not_resource_ids() {
        let metrics = Metrics::new("test", true);
        let app = Router::new()
            .route("/items/{id}", get(|| async { "ok" }))
            .layer(from_fn_with_state(metrics.clone(), record_http_metrics));

        for id in ["private-a", "private-b"] {
            let response = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!("/items/{id}?token=secret"))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            assert!(response.status().is_success());
        }

        let output = metrics.encode().unwrap();
        assert!(output.contains("route=\"/items/{id}\""));
        assert!(output.contains("rust_toon_http_requests_total"));
        assert!(!output.contains("private-a"));
        assert!(!output.contains("token"));
    }

    #[tokio::test]
    async fn metrics_endpoint_emits_openmetrics_content_type() {
        let metrics = Metrics::new("test", true);
        let response = metrics
            .routes()
            .oneshot(
                Request::builder()
                    .uri("/metrics")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(response.status().is_success());
        assert!(
            response.headers()["content-type"]
                .to_str()
                .unwrap()
                .starts_with("application/openmetrics-text")
        );
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        assert!(String::from_utf8_lossy(&body).contains("# EOF"));
    }

    #[test]
    fn worker_timer_records_completion_and_drop_cancellation() {
        let metrics = Metrics::new("worker", true);
        metrics
            .worker_job_started("video.merge")
            .finish("completed");
        drop(metrics.worker_job_started("video.merge"));
        let output = metrics.encode().unwrap();
        assert!(output.contains("outcome=\"completed\""));
        assert!(output.contains("outcome=\"cancelled\""));
    }

    #[test]
    fn custom_http_methods_cannot_create_unbounded_labels() {
        let method = axum::http::Method::from_bytes(b"PRIVATE-resource-id").unwrap();
        assert_eq!(method_label(&method), "OTHER");
    }
}

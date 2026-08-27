//! Process-local observability primitives shared by the Gateway and workers.
//!
//! Prometheus metrics are exposed for pull-based collection without contacting
//! an external service. OTLP trace export is opt-in and is only constructed
//! when an explicit exporter endpoint is configured.

mod config;
mod metrics;

use std::collections::BTreeMap;

use axum::http::HeaderMap;
use opentelemetry::{
    global,
    propagation::{Extractor, Injector},
    trace::{TraceContextExt, TracerProvider as _},
};
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{Resource, propagation::TraceContextPropagator, trace::SdkTracerProvider};
pub use rust_toon_framework_common::init_tracing;
use tracing_opentelemetry::OpenTelemetrySpanExt;
use tracing_subscriber::{EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

pub use config::{LogFormat, TelemetryConfig};
pub use metrics::{Metrics, WorkerJobTimer, record_http_metrics};

struct HeaderExtractor<'a>(&'a HeaderMap);

pub type TraceContext = BTreeMap<String, String>;

struct TraceContextInjector<'a>(&'a mut TraceContext);

impl Injector for TraceContextInjector<'_> {
    fn set(&mut self, key: &str, value: String) {
        self.0.insert(key.to_string(), value);
    }
}

struct TraceContextExtractor<'a>(&'a TraceContext);

impl Extractor for TraceContextExtractor<'_> {
    fn get(&self, key: &str) -> Option<&str> {
        self.0.get(key).map(String::as_str)
    }

    fn keys(&self) -> Vec<&str> {
        self.0.keys().map(String::as_str).collect()
    }
}

impl Extractor for HeaderExtractor<'_> {
    fn get(&self, key: &str) -> Option<&str> {
        self.0.get(key).and_then(|value| value.to_str().ok())
    }

    fn keys(&self) -> Vec<&str> {
        self.0.keys().map(axum::http::HeaderName::as_str).collect()
    }
}

/// Applies a valid W3C `traceparent`/`tracestate` context to a tracing span.
/// Invalid or absent headers are intentionally ignored.
pub fn set_parent_from_headers(span: &tracing::Span, headers: &HeaderMap) {
    let parent =
        global::get_text_map_propagator(|propagator| propagator.extract(&HeaderExtractor(headers)));
    if parent.span().span_context().is_valid() {
        let _ = span.set_parent(parent);
    }
    record_span_trace_id(span);
}

/// Captures the current span as a portable W3C carrier suitable for JSON or
/// messaging headers. An empty map means there is no valid sampled context.
pub fn current_trace_context() -> TraceContext {
    let context = tracing::Span::current().context();
    let mut carrier = TraceContext::new();
    global::get_text_map_propagator(|propagator| {
        propagator.inject_context(&context, &mut TraceContextInjector(&mut carrier));
    });
    carrier
}

pub fn current_trace_id() -> Option<String> {
    let context = tracing::Span::current().context();
    let span = context.span();
    let span_context = span.span_context();
    span_context
        .is_valid()
        .then(|| span_context.trace_id().to_string())
}

pub fn set_parent_from_trace_context(span: &tracing::Span, carrier: &TraceContext) {
    let parent = global::get_text_map_propagator(|propagator| {
        propagator.extract(&TraceContextExtractor(carrier))
    });
    if parent.span().span_context().is_valid() {
        let _ = span.set_parent(parent);
    }
    record_span_trace_id(span);
}

fn record_span_trace_id(span: &tracing::Span) {
    let context = span.context();
    let otel_span = context.span();
    let span_context = otel_span.span_context();
    if span_context.is_valid() {
        let trace_id = span_context.trace_id().to_string();
        // `record` is a no-op for spans that do not declare this field. HTTP
        // and durable-job root spans declare it so JSON logs can link to Tempo.
        span.record("trace_id", trace_id.as_str());
    }
}

/// Keeps the optional batch trace provider alive and flushes it at shutdown.
pub struct Telemetry {
    metrics: Metrics,
    trace_provider: Option<SdkTracerProvider>,
}

impl Telemetry {
    pub fn metrics(&self) -> Metrics {
        self.metrics.clone()
    }

    pub fn otlp_enabled(&self) -> bool {
        self.trace_provider.is_some()
    }
}

impl Drop for Telemetry {
    fn drop(&mut self) {
        if let Some(provider) = self.trace_provider.take()
            && let Err(error) = provider.shutdown()
        {
            eprintln!("failed to flush OpenTelemetry traces: {error}");
        }
    }
}

/// Initializes compatible text/JSON logging, Prometheus metrics, and optional
/// OTLP tracing. No exporter is created unless an OTLP endpoint is explicit.
pub fn init_telemetry(service_name: &'static str) -> anyhow::Result<Telemetry> {
    init_telemetry_with_config(TelemetryConfig::from_env(service_name)?)
}

fn init_telemetry_with_config(config: TelemetryConfig) -> anyhow::Result<Telemetry> {
    global::set_text_map_propagator(TraceContextPropagator::new());
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let (trace_provider, tracer) = build_otlp_tracer(&config)?;
    let otel_layer = tracer.map(|tracer| tracing_opentelemetry::layer().with_tracer(tracer));

    match config.log_format {
        LogFormat::Text => tracing_subscriber::registry()
            .with(otel_layer)
            .with(filter)
            .with(
                tracing_subscriber::fmt::layer()
                    .with_target(false)
                    .with_thread_ids(true),
            )
            .try_init()?,
        LogFormat::Json => tracing_subscriber::registry()
            .with(otel_layer)
            .with(filter)
            .with(
                tracing_subscriber::fmt::layer()
                    .json()
                    .flatten_event(true)
                    .with_target(false)
                    .with_thread_ids(true),
            )
            .try_init()?,
    }

    let telemetry = Telemetry {
        metrics: Metrics::new(config.service_name.clone(), config.metrics_enabled),
        trace_provider,
    };
    tracing::info!(
        service = %config.service_name,
        log_format = %config.log_format,
        metrics_enabled = config.metrics_enabled,
        otlp_enabled = telemetry.otlp_enabled(),
        "telemetry initialized"
    );
    Ok(telemetry)
}

fn build_otlp_tracer(
    config: &TelemetryConfig,
) -> anyhow::Result<(
    Option<SdkTracerProvider>,
    Option<opentelemetry_sdk::trace::SdkTracer>,
)> {
    let Some(endpoint) = config.otlp_endpoint.as_deref() else {
        return Ok((None, None));
    };

    let exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .with_endpoint(endpoint)
        .with_timeout(config.otlp_timeout)
        .build()?;
    let provider = SdkTracerProvider::builder()
        .with_batch_exporter(exporter)
        .with_resource(
            Resource::builder()
                .with_service_name(config.service_name.clone())
                .build(),
        )
        .build();
    global::set_text_map_propagator(TraceContextPropagator::new());
    global::set_tracer_provider(provider.clone());
    let tracer = provider.tracer(config.service_name.clone());
    Ok((Some(provider), Some(tracer)))
}

#[cfg(test)]
mod tests {
    use axum::http::{HeaderMap, HeaderValue};
    use opentelemetry::{
        global,
        trace::{TraceContextExt, TracerProvider as _},
    };
    use opentelemetry_sdk::{propagation::TraceContextPropagator, trace::SdkTracerProvider};
    use tracing_opentelemetry::OpenTelemetrySpanExt;
    use tracing_subscriber::{layer::SubscriberExt, registry};

    use super::set_parent_from_headers;

    #[test]
    fn extracts_w3c_traceparent_as_the_http_span_parent() {
        global::set_text_map_propagator(TraceContextPropagator::new());
        let provider = SdkTracerProvider::builder().build();
        let tracer = provider.tracer("traceparent-test");
        let subscriber = registry().with(tracing_opentelemetry::layer().with_tracer(tracer));
        tracing::subscriber::with_default(subscriber, || {
            let mut headers = HeaderMap::new();
            headers.insert(
                "traceparent",
                HeaderValue::from_static("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"),
            );
            let span = tracing::info_span!("http_request");
            set_parent_from_headers(&span, &headers);
            assert_eq!(
                span.context().span().span_context().trace_id().to_string(),
                "4bf92f3577b34da6a3ce929d0e0e4736"
            );
        });
    }
}

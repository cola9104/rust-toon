//! Shared outbound HTTP resilience based on Tower.
//!
//! One client instance retains its bulkhead and circuit state across requests.
//! Retries are deliberately restricted to HTTP methods whose semantics are
//! idempotent; POST/PATCH calls are attempted exactly once.

use std::{
    error::Error,
    fmt,
    sync::{Arc, Mutex},
    time::Duration,
};

use reqwest::{Method, RequestBuilder, Response, StatusCode};
use tower::{Layer, ServiceExt, util::BoxCloneService};
use tower_resilience::{bulkhead::BulkheadLayer, circuitbreaker::CircuitBreakerLayer};

type BoxError = Box<dyn Error + Send + Sync>;

#[derive(Debug, Clone)]
pub struct ResilienceError {
    dependency: &'static str,
    message: String,
}

impl ResilienceError {
    pub fn dependency(&self) -> &'static str {
        self.dependency
    }
}

impl fmt::Display for ResilienceError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "{} request failed: {}",
            self.dependency, self.message
        )
    }
}

impl Error for ResilienceError {}

#[derive(Debug, Clone)]
pub struct HttpResilienceConfig {
    pub timeout: Duration,
    pub max_attempts: usize,
    pub initial_backoff: Duration,
    pub max_concurrent_calls: usize,
    pub max_wait: Duration,
}

impl Default for HttpResilienceConfig {
    fn default() -> Self {
        Self {
            timeout: Duration::from_secs(120),
            max_attempts: 3,
            initial_backoff: Duration::from_millis(250),
            max_concurrent_calls: 64,
            max_wait: Duration::from_secs(2),
        }
    }
}

#[derive(Clone)]
pub struct ResilientHttpClient {
    dependency: &'static str,
    service: Arc<Mutex<BoxCloneService<reqwest::Request, Response, BoxError>>>,
    config: HttpResilienceConfig,
}

impl ResilientHttpClient {
    pub fn new(
        dependency: &'static str,
        client: reqwest::Client,
        config: HttpResilienceConfig,
    ) -> Result<Self, ResilienceError> {
        let timeout = config.timeout;
        let base = tower::service_fn(move |request: reqwest::Request| {
            let client = client.clone();
            async move {
                tokio::time::timeout(timeout, client.execute(request))
                    .await
                    .map_err(|_| -> BoxError { "request deadline elapsed".into() })?
                    .map_err(|error| -> BoxError { Box::new(error) })
            }
        });
        let bulkhead = BulkheadLayer::builder()
            .max_concurrent_calls(config.max_concurrent_calls.max(1))
            .max_wait_duration(config.max_wait)
            .build()
            .map_err(|error| ResilienceError {
                dependency,
                message: format!("invalid bulkhead configuration: {error}"),
            })?;
        let breaker = CircuitBreakerLayer::builder()
            .name(dependency)
            .failure_rate_threshold(0.5)
            .sliding_window_size(20)
            .minimum_number_of_calls(10)
            .wait_duration_in_open(Duration::from_secs(30))
            .build()
            .map_err(|error| ResilienceError {
                dependency,
                message: format!("invalid circuit breaker configuration: {error}"),
            })?;
        let service = breaker
            .layer(bulkhead.layer(base))
            .map_err(|error| -> BoxError { Box::new(error) });
        Ok(Self {
            dependency,
            service: Arc::new(Mutex::new(BoxCloneService::new(service))),
            config,
        })
    }

    pub async fn execute(&self, builder: RequestBuilder) -> Result<Response, ResilienceError> {
        let mut request = builder.build().map_err(|error| ResilienceError {
            dependency: self.dependency,
            message: error.to_string(),
        })?;
        for (name, value) in rust_toon_framework_telemetry::current_trace_context() {
            if let (Ok(name), Ok(value)) = (
                reqwest::header::HeaderName::try_from(name),
                reqwest::header::HeaderValue::try_from(value),
            ) {
                request.headers_mut().insert(name, value);
            }
        }
        let replay = request.try_clone();
        let max_attempts = if is_idempotent(request.method()) && replay.is_some() {
            self.config.max_attempts.max(1)
        } else {
            1
        };
        let method = request.method().clone();
        let mut original = Some(request);
        let mut last_error = None;
        for attempt in 0..max_attempts {
            let current = if attempt == 0 {
                original.take().expect("first attempt owns request")
            } else {
                replay
                    .as_ref()
                    .and_then(reqwest::Request::try_clone)
                    .ok_or_else(|| ResilienceError {
                        dependency: self.dependency,
                        message: "request body cannot be replayed".to_string(),
                    })?
            };
            let service = self
                .service
                .lock()
                .map_err(|_| ResilienceError {
                    dependency: self.dependency,
                    message: "resilience service lock was poisoned".to_string(),
                })?
                .clone();
            match service.oneshot(current).await {
                Ok(response)
                    if retryable_status(response.status()) && attempt + 1 < max_attempts =>
                {
                    let delay = retry_after(&response).unwrap_or_else(|| self.backoff(attempt));
                    tracing::warn!(
                        dependency = self.dependency,
                        method = %method,
                        status = response.status().as_u16(),
                        attempt = attempt + 1,
                        max_attempts,
                        ?delay,
                        "idempotent outbound request will retry"
                    );
                    tokio::time::sleep(delay).await;
                }
                Ok(response) => return Ok(response),
                Err(error) if attempt + 1 < max_attempts => {
                    let delay = self.backoff(attempt);
                    tracing::warn!(
                        dependency = self.dependency,
                        method = %method,
                        attempt = attempt + 1,
                        max_attempts,
                        %error,
                        ?delay,
                        "idempotent outbound request will retry after transport failure"
                    );
                    last_error = Some(error.to_string());
                    tokio::time::sleep(delay).await;
                }
                Err(error) => {
                    return Err(ResilienceError {
                        dependency: self.dependency,
                        message: error.to_string(),
                    });
                }
            }
        }
        Err(ResilienceError {
            dependency: self.dependency,
            message: last_error.unwrap_or_else(|| "retry attempts exhausted".to_string()),
        })
    }

    fn backoff(&self, attempt: usize) -> Duration {
        self.config
            .initial_backoff
            .saturating_mul(2_u32.saturating_pow(u32::try_from(attempt).unwrap_or(8).min(8)))
            .min(Duration::from_secs(30))
    }
}

pub fn is_idempotent(method: &Method) -> bool {
    matches!(
        *method,
        Method::GET | Method::HEAD | Method::PUT | Method::DELETE | Method::OPTIONS | Method::TRACE
    )
}

/// Injects the current W3C carrier without applying retries or circuit logic.
/// This is for specially configured clients (for example DNS-pinned SSRF-safe
/// downloads) that cannot be replaced by the shared HTTP service.
pub fn inject_trace_context(mut builder: RequestBuilder) -> RequestBuilder {
    for (name, value) in rust_toon_framework_telemetry::current_trace_context() {
        builder = builder.header(name, value);
    }
    builder
}

fn retryable_status(status: StatusCode) -> bool {
    status.is_server_error() || matches!(status.as_u16(), 408 | 409 | 425 | 429)
}

fn retry_after(response: &Response) -> Option<Duration> {
    response
        .headers()
        .get("retry-after")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.parse::<u64>().ok())
        .map(|seconds| Duration::from_secs(seconds.min(30)))
}

#[cfg(test)]
mod tests {
    use reqwest::Method;

    use super::is_idempotent;

    #[test]
    fn retries_only_semantically_idempotent_methods() {
        assert!(is_idempotent(&Method::GET));
        assert!(is_idempotent(&Method::PUT));
        assert!(is_idempotent(&Method::DELETE));
        assert!(!is_idempotent(&Method::POST));
        assert!(!is_idempotent(&Method::PATCH));
    }
}

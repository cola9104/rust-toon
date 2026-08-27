use async_nats::{
    HeaderMap,
    header::NATS_MESSAGE_ID,
    jetstream::{
        self,
        consumer::{AckPolicy, PullConsumer, pull},
        stream::{Config as StreamConfig, DiscardPolicy, RetentionPolicy, StorageType},
    },
};
use serde::Serialize;
use std::{
    error::Error,
    path::PathBuf,
    sync::{Arc, Mutex},
    time::Duration,
};
use tower::{Layer, ServiceExt, util::BoxCloneService};
use tower_resilience::{bulkhead::BulkheadLayer, circuitbreaker::CircuitBreakerLayer};

use crate::{JobEnvelope, MqError, NatsConfig, Result, envelope::validate_subject_path};

/// Result returned after JetStream has persisted a published job reference.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublishReceipt {
    pub stream: String,
    pub sequence: u64,
    pub duplicate: bool,
}

/// Connected NATS and JetStream handles configured for durable job delivery.
#[derive(Clone)]
pub struct Broker {
    client: async_nats::Client,
    jetstream: jetstream::Context,
    config: NatsConfig,
    publish_service: Arc<Mutex<PublishService>>,
}

type BoxError = Box<dyn Error + Send + Sync>;
type PublishService = BoxCloneService<PublishRequest, PublishReceipt, BoxError>;

#[derive(Clone)]
struct PublishRequest {
    subject: String,
    headers: HeaderMap,
    payload: Vec<u8>,
}

impl Broker {
    /// Connect to NATS and declaratively create or update the WorkQueue stream.
    pub async fn connect(config: NatsConfig) -> Result<Self> {
        config.validate()?;

        let mut options = async_nats::ConnectOptions::new().name(&config.client_name);
        if let Some(path) = &config.credentials_file {
            options = options.credentials_file(path).await.map_err(|error| {
                MqError::Config(format!("failed to load NATS credentials file: {error}"))
            })?;
        }
        if config.tls_required {
            options = options.require_tls(true);
        }
        if let Some(path) = &config.tls_ca_file {
            options = options.add_root_certificates(PathBuf::from(path));
        }
        if let (Some(cert), Some(key)) = (&config.tls_client_cert_file, &config.tls_client_key_file)
        {
            options = options.add_client_certificate(PathBuf::from(cert), PathBuf::from(key));
        }
        let connect = options.connect(config.url.as_str());
        let client = tokio::time::timeout(config.connect_timeout, connect)
            .await
            .map_err(|_| MqError::Timeout("connect"))?
            .map_err(|error| MqError::Nats(error.to_string()))?;

        let mut jetstream = jetstream::new(client.clone());
        jetstream.set_timeout(config.request_timeout);
        let publish_service = build_publish_service(jetstream.clone(), config.request_timeout)?;
        let broker = Self {
            client,
            jetstream,
            config,
            publish_service: Arc::new(Mutex::new(publish_service)),
        };
        broker.ensure_work_queue_stream().await?;
        Ok(broker)
    }

    /// Ensure the server has the exact durable stream properties this client
    /// relies on. Incompatible immutable settings fail startup visibly.
    pub async fn ensure_work_queue_stream(&self) -> Result<()> {
        let expected = stream_config(&self.config);
        let stream = self
            .jetstream
            .get_or_create_stream(expected.clone())
            .await
            .map_err(|error| MqError::Nats(error.to_string()))?;
        validate_stream_config(&stream.cached_info().config, &expected)
    }

    /// Publish an envelope and wait for the JetStream persistence ack.
    ///
    /// `Nats-Msg-Id` is the outbox row's stable message UUID, so a publisher may
    /// safely retry when it loses the first publish acknowledgement.
    pub async fn publish<T>(&self, envelope: &JobEnvelope<T>) -> Result<PublishReceipt>
    where
        T: Serialize,
    {
        let payload = envelope.encode()?;
        let subject = self.subject_for(&envelope.kind)?;
        let headers = publish_headers(envelope);

        let service = self
            .publish_service
            .lock()
            .map_err(|_| MqError::Nats("publish resilience service lock was poisoned".into()))?
            .clone();
        service
            .oneshot(PublishRequest {
                subject,
                headers,
                payload,
            })
            .await
            .map_err(|error| MqError::Nats(error.to_string()))
    }

    /// Create or update a named durable pull consumer for one exact job kind.
    ///
    /// Multiple process replicas should use the same `durable_name` to form a
    /// queue of workers. Successful processing must explicitly acknowledge the
    /// message; long-running handlers should send progress acknowledgements.
    pub async fn durable_consumer(&self, durable_name: &str, kind: &str) -> Result<PullConsumer> {
        let stream = self
            .jetstream
            .get_stream(&self.config.stream_name)
            .await
            .map_err(|error| MqError::Nats(error.to_string()))?;
        stream
            .create_consumer(self.consumer_config(durable_name, kind)?)
            .await
            .map_err(|error| MqError::Nats(error.to_string()))
    }

    /// Perform a NATS PING/PONG round trip and verify the configured JetStream
    /// stream remains reachable.
    pub async fn readiness(&self) -> Result<()> {
        tokio::time::timeout(self.config.request_timeout, self.client.flush())
            .await
            .map_err(|_| MqError::Timeout("readiness ping"))?
            .map_err(|error| MqError::Nats(error.to_string()))?;
        tokio::time::timeout(
            self.config.request_timeout,
            self.jetstream.get_stream(&self.config.stream_name),
        )
        .await
        .map_err(|_| MqError::Timeout("JetStream readiness check"))?
        .map_err(|error| MqError::Nats(error.to_string()))?;
        Ok(())
    }

    pub fn subject_for(&self, kind: &str) -> Result<String> {
        subject_for_prefix(&self.config.subject_prefix, kind)
    }

    pub fn config(&self) -> &NatsConfig {
        &self.config
    }

    fn consumer_config(&self, durable_name: &str, kind: &str) -> Result<pull::Config> {
        consumer_config(&self.config, durable_name, kind)
    }
}

fn build_publish_service(
    jetstream: jetstream::Context,
    request_timeout: Duration,
) -> Result<PublishService> {
    let base = tower::service_fn(move |request: PublishRequest| {
        let jetstream = jetstream.clone();
        async move {
            let publish = jetstream.publish_with_headers(
                request.subject,
                request.headers,
                request.payload.into(),
            );
            let acknowledgement = tokio::time::timeout(request_timeout, publish)
                .await
                .map_err(|_| -> BoxError { Box::new(MqError::Timeout("publish")) })?
                .map_err(|error| -> BoxError { Box::new(MqError::Nats(error.to_string())) })?;
            let acknowledgement = tokio::time::timeout(request_timeout, acknowledgement)
                .await
                .map_err(|_| -> BoxError { Box::new(MqError::Timeout("publish acknowledgement")) })?
                .map_err(|error| -> BoxError { Box::new(MqError::Nats(error.to_string())) })?;
            Ok::<PublishReceipt, BoxError>(PublishReceipt {
                stream: acknowledgement.stream,
                sequence: acknowledgement.sequence,
                duplicate: acknowledgement.duplicate,
            })
        }
    });
    let bulkhead = BulkheadLayer::builder()
        .max_concurrent_calls(128)
        .max_wait_duration(Duration::from_secs(1))
        .build()
        .map_err(|error| MqError::Config(format!("invalid NATS bulkhead: {error}")))?;
    let breaker = CircuitBreakerLayer::builder()
        .name("nats-publish")
        .failure_rate_threshold(0.5)
        .sliding_window_size(20)
        .minimum_number_of_calls(10)
        .wait_duration_in_open(Duration::from_secs(15))
        .build()
        .map_err(|error| MqError::Config(format!("invalid NATS circuit breaker: {error}")))?;
    let service = breaker
        .layer(bulkhead.layer(base))
        .map_err(|error| -> BoxError { Box::new(error) });
    Ok(BoxCloneService::new(service))
}

fn publish_headers<T>(envelope: &JobEnvelope<T>) -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(NATS_MESSAGE_ID, envelope.deduplication_id());
    for key in ["traceparent", "tracestate"] {
        if let Some(value) = envelope.trace_context.get(key) {
            headers.insert(key, value.clone());
        }
    }
    headers
}

fn stream_config(config: &NatsConfig) -> StreamConfig {
    StreamConfig {
        name: config.stream_name.clone(),
        description: Some("Rust Toon durable background jobs".to_string()),
        subjects: vec![format!("{}.>", config.subject_prefix)],
        retention: RetentionPolicy::WorkQueue,
        storage: StorageType::File,
        discard: DiscardPolicy::New,
        max_age: config.stream_max_age,
        max_bytes: config.stream_max_bytes,
        num_replicas: config.stream_replicas,
        duplicate_window: config.duplicate_window,
        ..Default::default()
    }
}

fn validate_stream_config(actual: &StreamConfig, expected: &StreamConfig) -> Result<()> {
    let mut drift = Vec::new();
    if actual.retention != expected.retention {
        drift.push("retention");
    }
    if actual.storage != expected.storage {
        drift.push("storage");
    }
    if actual.discard != expected.discard {
        drift.push("discard");
    }
    if actual.subjects != expected.subjects {
        drift.push("subjects");
    }
    if actual.num_replicas != expected.num_replicas {
        drift.push("num_replicas");
    }
    if actual.max_age != expected.max_age {
        drift.push("max_age");
    }
    if actual.max_bytes != expected.max_bytes {
        drift.push("max_bytes");
    }
    if actual.duplicate_window != expected.duplicate_window {
        drift.push("duplicate_window");
    }
    if actual.no_ack != expected.no_ack {
        drift.push("no_ack");
    }
    if drift.is_empty() {
        Ok(())
    } else {
        Err(MqError::Protocol(format!(
            "JetStream stream {} configuration drift: {}; refusing to mutate a shared stream",
            expected.name,
            drift.join(", ")
        )))
    }
}

fn consumer_config(config: &NatsConfig, durable_name: &str, kind: &str) -> Result<pull::Config> {
    validate_durable_name(durable_name)?;
    Ok(pull::Config {
        durable_name: Some(durable_name.to_string()),
        name: Some(durable_name.to_string()),
        description: Some(format!("Rust Toon workers for {kind}")),
        filter_subject: subject_for_prefix(&config.subject_prefix, kind)?,
        ack_policy: AckPolicy::Explicit,
        ack_wait: config.consumer_ack_wait,
        max_deliver: config.consumer_max_deliver,
        max_ack_pending: config.consumer_max_ack_pending,
        ..Default::default()
    })
}

fn subject_for_prefix(prefix: &str, kind: &str) -> Result<String> {
    validate_subject_path("kind", kind)?;
    Ok(format!("{prefix}.{kind}"))
}

fn validate_durable_name(value: &str) -> Result<()> {
    if value.is_empty()
        || value.len() > 255
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
    {
        return Err(MqError::Protocol(
            "durable_name must be ASCII letters, digits, '_' or '-'".to_string(),
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    #[test]
    fn publish_uses_the_persisted_message_uuid_for_jetstream_deduplication() {
        let message_id = Uuid::parse_str("8db4fda4-72e6-4e0c-9b66-067b46c284a4").expect("UUID");
        let envelope =
            JobEnvelope::new(message_id, 41, 72, "video.merge", 0, "trace", ()).expect("envelope");

        let headers = publish_headers(&envelope);

        assert_eq!(
            headers
                .get(NATS_MESSAGE_ID)
                .expect("Nats-Msg-Id header")
                .as_str(),
            message_id.to_string()
        );
    }

    #[test]
    fn stream_is_a_file_backed_work_queue_that_refuses_overflow() {
        let config = stream_config(&NatsConfig::default());

        assert_eq!(config.retention, RetentionPolicy::WorkQueue);
        assert_eq!(config.storage, StorageType::File);
        assert_eq!(config.discard, DiscardPolicy::New);
        assert_eq!(config.subjects, vec!["rust_toon.jobs.>"]);
        assert_eq!(config.max_age, std::time::Duration::ZERO);
    }

    #[test]
    fn existing_stream_replica_drift_is_rejected_instead_of_downgraded() {
        let expected = stream_config(&NatsConfig::default());
        let mut actual = expected.clone();
        actual.num_replicas = 3;

        let error = validate_stream_config(&actual, &expected)
            .expect_err("a worker configured for one replica must not downgrade a shared stream");

        assert!(error.to_string().contains("num_replicas"));
        assert!(error.to_string().contains("refusing to mutate"));
    }

    #[test]
    fn consumer_requires_explicit_ack_and_an_exact_kind() {
        let config = consumer_config(&NatsConfig::default(), "video_workers", "video.merge")
            .expect("consumer config");

        assert_eq!(config.durable_name.as_deref(), Some("video_workers"));
        assert_eq!(config.ack_policy, AckPolicy::Explicit);
        assert_eq!(config.filter_subject, "rust_toon.jobs.video.merge");
        assert_eq!(config.ack_wait, std::time::Duration::from_secs(120));
    }

    #[test]
    fn subjects_and_durable_names_cannot_smuggle_wildcards() {
        assert!(subject_for_prefix("rust_toon.jobs", "video.>").is_err());
        assert!(consumer_config(&NatsConfig::default(), "video.*", "video.merge").is_err());
    }
}

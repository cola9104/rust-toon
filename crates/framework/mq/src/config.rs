use std::{env, str::FromStr, time::Duration};

use crate::{MqError, Result, envelope::validate_subject_path};

const DEFAULT_NATS_URL: &str = "nats://127.0.0.1:4222";
const DEFAULT_CLIENT_NAME: &str = "rust-toon";
const DEFAULT_STREAM_NAME: &str = "RUST_TOON_JOBS";
const DEFAULT_SUBJECT_PREFIX: &str = "rust_toon.jobs";

/// Runtime settings for the JetStream job transport.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NatsConfig {
    pub url: String,
    pub client_name: String,
    pub credentials_file: Option<String>,
    pub tls_required: bool,
    pub tls_ca_file: Option<String>,
    pub tls_client_cert_file: Option<String>,
    pub tls_client_key_file: Option<String>,
    pub stream_name: String,
    pub subject_prefix: String,
    pub connect_timeout: Duration,
    pub request_timeout: Duration,
    pub stream_max_age: Duration,
    pub stream_max_bytes: i64,
    pub stream_replicas: usize,
    pub duplicate_window: Duration,
    pub consumer_ack_wait: Duration,
    pub consumer_max_deliver: i64,
    pub consumer_max_ack_pending: i64,
}

impl Default for NatsConfig {
    fn default() -> Self {
        Self {
            url: DEFAULT_NATS_URL.to_string(),
            client_name: DEFAULT_CLIENT_NAME.to_string(),
            credentials_file: None,
            tls_required: false,
            tls_ca_file: None,
            tls_client_cert_file: None,
            tls_client_key_file: None,
            stream_name: DEFAULT_STREAM_NAME.to_string(),
            subject_prefix: DEFAULT_SUBJECT_PREFIX.to_string(),
            connect_timeout: Duration::from_secs(5),
            request_timeout: Duration::from_secs(3),
            // Zero means messages do not expire by age. With DiscardNew this
            // protects old, unacknowledged work when the stream is full.
            stream_max_age: Duration::ZERO,
            stream_max_bytes: 10 * 1024 * 1024 * 1024,
            stream_replicas: 1,
            duplicate_window: Duration::from_secs(24 * 60 * 60),
            consumer_ack_wait: Duration::from_secs(120),
            consumer_max_deliver: 20,
            consumer_max_ack_pending: 32,
        }
    }
}

impl NatsConfig {
    /// Load NATS settings from environment variables, applying safe local
    /// defaults for omitted values.
    pub fn from_env() -> Result<Self> {
        Self::from_source(|name| match env::var(name) {
            Ok(value) => Ok(Some(value)),
            Err(env::VarError::NotPresent) => Ok(None),
            Err(env::VarError::NotUnicode(_)) => {
                Err(MqError::Config(format!("{name} contains non-Unicode data")))
            }
        })
    }

    pub fn validate(&self) -> Result<()> {
        if self.url.trim().is_empty() {
            return Err(MqError::Config("NATS_URL must not be blank".to_string()));
        }
        if self.client_name.trim().is_empty() {
            return Err(MqError::Config(
                "NATS_CLIENT_NAME must not be blank".to_string(),
            ));
        }
        for (name, path) in [
            ("NATS_CREDENTIALS_FILE", self.credentials_file.as_deref()),
            ("NATS_TLS_CA_FILE", self.tls_ca_file.as_deref()),
            (
                "NATS_TLS_CLIENT_CERT_FILE",
                self.tls_client_cert_file.as_deref(),
            ),
            (
                "NATS_TLS_CLIENT_KEY_FILE",
                self.tls_client_key_file.as_deref(),
            ),
        ] {
            if path.is_some_and(|value| value.trim().is_empty()) {
                return Err(MqError::Config(format!("{name} must not be blank")));
            }
        }
        if self.tls_client_cert_file.is_some() != self.tls_client_key_file.is_some() {
            return Err(MqError::Config(
                "NATS_TLS_CLIENT_CERT_FILE and NATS_TLS_CLIENT_KEY_FILE must be set together"
                    .to_string(),
            ));
        }
        if !self.tls_required && (self.tls_ca_file.is_some() || self.tls_client_cert_file.is_some())
        {
            return Err(MqError::Config(
                "NATS_TLS_REQUIRED must be true when NATS TLS certificate files are configured"
                    .to_string(),
            ));
        }
        validate_stream_name(&self.stream_name)?;
        validate_subject_path("NATS_JOB_SUBJECT_PREFIX", &self.subject_prefix)
            .map_err(protocol_as_config)?;
        require_nonzero("NATS_CONNECT_TIMEOUT_MS", self.connect_timeout)?;
        require_nonzero("NATS_REQUEST_TIMEOUT_MS", self.request_timeout)?;
        if self.stream_max_bytes <= 0 {
            return Err(MqError::Config(
                "NATS_JOB_MAX_BYTES must be greater than zero".to_string(),
            ));
        }
        if !(1..=5).contains(&self.stream_replicas) {
            return Err(MqError::Config(
                "NATS_JOB_REPLICAS must be between 1 and 5".to_string(),
            ));
        }
        require_nonzero("NATS_JOB_DUPLICATE_WINDOW_SECONDS", self.duplicate_window)?;
        if !self.stream_max_age.is_zero() && self.duplicate_window > self.stream_max_age {
            return Err(MqError::Config(
                "NATS_JOB_DUPLICATE_WINDOW_SECONDS must not exceed NATS_JOB_MAX_AGE_SECONDS"
                    .to_string(),
            ));
        }
        require_nonzero("NATS_JOB_ACK_WAIT_SECONDS", self.consumer_ack_wait)?;
        if self.consumer_max_deliver <= 0 {
            return Err(MqError::Config(
                "NATS_JOB_MAX_DELIVER must be greater than zero".to_string(),
            ));
        }
        if self.consumer_max_ack_pending <= 0 {
            return Err(MqError::Config(
                "NATS_JOB_MAX_ACK_PENDING must be greater than zero".to_string(),
            ));
        }
        Ok(())
    }

    fn from_source<F>(mut source: F) -> Result<Self>
    where
        F: FnMut(&'static str) -> Result<Option<String>>,
    {
        let mut config = Self::default();

        assign_string(&mut config.url, source("NATS_URL")?);
        assign_string(&mut config.client_name, source("NATS_CLIENT_NAME")?);
        config.credentials_file = optional_nonblank(source("NATS_CREDENTIALS_FILE")?);
        assign_bool(
            &mut config.tls_required,
            "NATS_TLS_REQUIRED",
            source("NATS_TLS_REQUIRED")?,
        )?;
        config.tls_ca_file = optional_nonblank(source("NATS_TLS_CA_FILE")?);
        config.tls_client_cert_file = optional_nonblank(source("NATS_TLS_CLIENT_CERT_FILE")?);
        config.tls_client_key_file = optional_nonblank(source("NATS_TLS_CLIENT_KEY_FILE")?);
        assign_string(&mut config.stream_name, source("NATS_JOB_STREAM")?);
        assign_string(
            &mut config.subject_prefix,
            source("NATS_JOB_SUBJECT_PREFIX")?,
        );
        assign_millis(
            &mut config.connect_timeout,
            "NATS_CONNECT_TIMEOUT_MS",
            source("NATS_CONNECT_TIMEOUT_MS")?,
        )?;
        assign_millis(
            &mut config.request_timeout,
            "NATS_REQUEST_TIMEOUT_MS",
            source("NATS_REQUEST_TIMEOUT_MS")?,
        )?;
        assign_seconds(
            &mut config.stream_max_age,
            "NATS_JOB_MAX_AGE_SECONDS",
            source("NATS_JOB_MAX_AGE_SECONDS")?,
        )?;
        assign_number(
            &mut config.stream_max_bytes,
            "NATS_JOB_MAX_BYTES",
            source("NATS_JOB_MAX_BYTES")?,
        )?;
        assign_number(
            &mut config.stream_replicas,
            "NATS_JOB_REPLICAS",
            source("NATS_JOB_REPLICAS")?,
        )?;
        assign_seconds(
            &mut config.duplicate_window,
            "NATS_JOB_DUPLICATE_WINDOW_SECONDS",
            source("NATS_JOB_DUPLICATE_WINDOW_SECONDS")?,
        )?;
        assign_seconds(
            &mut config.consumer_ack_wait,
            "NATS_JOB_ACK_WAIT_SECONDS",
            source("NATS_JOB_ACK_WAIT_SECONDS")?,
        )?;
        assign_number(
            &mut config.consumer_max_deliver,
            "NATS_JOB_MAX_DELIVER",
            source("NATS_JOB_MAX_DELIVER")?,
        )?;
        assign_number(
            &mut config.consumer_max_ack_pending,
            "NATS_JOB_MAX_ACK_PENDING",
            source("NATS_JOB_MAX_ACK_PENDING")?,
        )?;

        config.validate()?;
        Ok(config)
    }
}

fn protocol_as_config(error: MqError) -> MqError {
    match error {
        MqError::Protocol(message) => MqError::Config(message),
        error => error,
    }
}

fn validate_stream_name(value: &str) -> Result<()> {
    if value.is_empty()
        || value.len() > 255
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
    {
        return Err(MqError::Config(
            "NATS_JOB_STREAM must be ASCII letters, digits, '_' or '-'".to_string(),
        ));
    }
    Ok(())
}

fn require_nonzero(name: &str, value: Duration) -> Result<()> {
    if value.is_zero() {
        return Err(MqError::Config(format!("{name} must be greater than zero")));
    }
    Ok(())
}

fn assign_string(target: &mut String, value: Option<String>) {
    if let Some(value) = value {
        *target = value;
    }
}

fn optional_nonblank(value: Option<String>) -> Option<String> {
    value.filter(|value| !value.trim().is_empty())
}

fn assign_bool(target: &mut bool, name: &'static str, value: Option<String>) -> Result<()> {
    if let Some(value) = value {
        *target = match value.to_ascii_lowercase().as_str() {
            "1" | "true" | "yes" => true,
            "0" | "false" | "no" => false,
            _ => return Err(MqError::Config(format!("{name} must be true or false"))),
        };
    }
    Ok(())
}

fn assign_millis(target: &mut Duration, name: &'static str, value: Option<String>) -> Result<()> {
    if let Some(value) = value {
        *target = Duration::from_millis(parse_number(name, &value)?);
    }
    Ok(())
}

fn assign_seconds(target: &mut Duration, name: &'static str, value: Option<String>) -> Result<()> {
    if let Some(value) = value {
        *target = Duration::from_secs(parse_number(name, &value)?);
    }
    Ok(())
}

fn assign_number<T>(target: &mut T, name: &'static str, value: Option<String>) -> Result<()>
where
    T: FromStr,
{
    if let Some(value) = value {
        *target = parse_number(name, &value)?;
    }
    Ok(())
}

fn parse_number<T>(name: &'static str, value: &str) -> Result<T>
where
    T: FromStr,
{
    value.parse().map_err(|_| {
        MqError::Config(format!(
            "{name} must be a valid {}",
            std::any::type_name::<T>()
        ))
    })
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::*;

    fn from_values(values: &[(&'static str, &'static str)]) -> Result<NatsConfig> {
        let values = values.iter().copied().collect::<HashMap<_, _>>();
        NatsConfig::from_source(|name| Ok(values.get(name).map(ToString::to_string)))
    }

    #[test]
    fn defaults_are_safe_for_a_single_node_and_do_not_expire_jobs() {
        let config = from_values(&[]).expect("default config");

        assert_eq!(config.url, DEFAULT_NATS_URL);
        assert_eq!(config.stream_replicas, 1);
        assert_eq!(config.stream_max_age, Duration::ZERO);
        assert_eq!(config.consumer_max_deliver, 20);
    }

    #[test]
    fn environment_values_override_defaults() {
        let config = from_values(&[
            ("NATS_URL", "nats://nats.internal:4222"),
            ("NATS_CLIENT_NAME", "video-worker-a"),
            ("NATS_CREDENTIALS_FILE", "/run/secrets/nats.creds"),
            ("NATS_TLS_REQUIRED", "true"),
            ("NATS_TLS_CA_FILE", "/etc/ssl/nats-ca.pem"),
            ("NATS_TLS_CLIENT_CERT_FILE", "/run/secrets/nats-client.pem"),
            ("NATS_TLS_CLIENT_KEY_FILE", "/run/secrets/nats-client.key"),
            ("NATS_JOB_STREAM", "PROD_JOBS"),
            ("NATS_JOB_SUBJECT_PREFIX", "prod.jobs"),
            ("NATS_CONNECT_TIMEOUT_MS", "2500"),
            ("NATS_JOB_MAX_AGE_SECONDS", "86400"),
            ("NATS_JOB_DUPLICATE_WINDOW_SECONDS", "3600"),
            ("NATS_JOB_REPLICAS", "3"),
            ("NATS_JOB_MAX_ACK_PENDING", "8"),
        ])
        .expect("overridden config");

        assert_eq!(config.connect_timeout, Duration::from_millis(2500));
        assert!(config.tls_required);
        assert_eq!(
            config.credentials_file.as_deref(),
            Some("/run/secrets/nats.creds")
        );
        assert_eq!(config.stream_max_age, Duration::from_secs(86400));
        assert_eq!(config.stream_replicas, 3);
        assert_eq!(config.consumer_max_ack_pending, 8);
    }

    #[test]
    fn invalid_replica_count_and_duration_are_rejected() {
        let replicas = from_values(&[("NATS_JOB_REPLICAS", "6")])
            .expect_err("JetStream supports at most five replicas");
        assert!(replicas.to_string().contains("between 1 and 5"));

        let timeout =
            from_values(&[("NATS_CONNECT_TIMEOUT_MS", "0")]).expect_err("zero timeout is unusable");
        assert!(timeout.to_string().contains("greater than zero"));
    }

    #[test]
    fn duplicate_window_cannot_outlive_messages() {
        let error = from_values(&[
            ("NATS_JOB_MAX_AGE_SECONDS", "60"),
            ("NATS_JOB_DUPLICATE_WINDOW_SECONDS", "61"),
        ])
        .expect_err("invalid window");

        assert!(error.to_string().contains("must not exceed"));
    }

    #[test]
    fn tls_client_identity_must_be_complete_and_explicitly_required() {
        let missing_key = from_values(&[
            ("NATS_TLS_REQUIRED", "true"),
            ("NATS_TLS_CLIENT_CERT_FILE", "/run/secrets/client.pem"),
        ])
        .expect_err("mTLS needs both certificate and key");
        assert!(missing_key.to_string().contains("must be set together"));

        let implicit_tls = from_values(&[("NATS_TLS_CA_FILE", "/etc/ssl/nats-ca.pem")])
            .expect_err("certificate configuration must not silently permit plaintext");
        assert!(implicit_tls.to_string().contains("NATS_TLS_REQUIRED"));

        let invalid_bool = from_values(&[("NATS_TLS_REQUIRED", "sometimes")])
            .expect_err("invalid booleans must be rejected");
        assert!(invalid_bool.to_string().contains("true or false"));
    }
}

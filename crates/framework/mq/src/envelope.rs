use serde::{Deserialize, Serialize, de::DeserializeOwned};
use uuid::Uuid;

use crate::{MqError, Result};

/// Current wire-format version for durable job messages.
pub const JOB_ENVELOPE_VERSION: u16 = 1;

/// A small, versioned reference to a durable job held in PostgreSQL.
///
/// `message_id` identifies the outbox message, `job_id` identifies the durable
/// job row, and `task_id` identifies the user-facing Toonflow task. The payload
/// should only contain immutable dispatch hints; mutable execution state
/// belongs in PostgreSQL.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct JobEnvelope<T = serde_json::Value> {
    pub schema_version: u16,
    pub message_id: Uuid,
    pub job_id: i64,
    pub task_id: i64,
    pub kind: String,
    pub attempt: u32,
    pub trace_id: String,
    pub payload: T,
}

impl<T> JobEnvelope<T> {
    pub fn new(
        message_id: Uuid,
        job_id: i64,
        task_id: i64,
        kind: impl Into<String>,
        attempt: u32,
        trace_id: impl Into<String>,
        payload: T,
    ) -> Result<Self> {
        let envelope = Self {
            schema_version: JOB_ENVELOPE_VERSION,
            message_id,
            job_id,
            task_id,
            kind: kind.into(),
            attempt,
            trace_id: trace_id.into(),
            payload,
        };
        envelope.validate()?;
        Ok(envelope)
    }

    /// Validate fields that are common to all payload types.
    pub fn validate(&self) -> Result<()> {
        if self.schema_version != JOB_ENVELOPE_VERSION {
            return Err(MqError::Protocol(format!(
                "unsupported schema_version {}; expected {}",
                self.schema_version, JOB_ENVELOPE_VERSION
            )));
        }
        if self.message_id.is_nil() {
            return Err(MqError::Protocol(
                "message_id must not be the nil UUID".to_string(),
            ));
        }
        if self.job_id <= 0 {
            return Err(MqError::Protocol("job_id must be positive".to_string()));
        }
        if self.task_id <= 0 {
            return Err(MqError::Protocol("task_id must be positive".to_string()));
        }
        validate_subject_path("kind", &self.kind)?;
        if self.trace_id.trim().is_empty() {
            return Err(MqError::Protocol("trace_id must not be blank".to_string()));
        }
        if self.trace_id.len() > 256 {
            return Err(MqError::Protocol(
                "trace_id must not exceed 256 bytes".to_string(),
            ));
        }
        Ok(())
    }

    /// Stable JetStream de-duplication key for one outbox message.
    ///
    /// The same database outbox row can be published repeatedly without
    /// creating duplicate stream entries.
    pub fn deduplication_id(&self) -> String {
        self.message_id.to_string()
    }
}

impl<T> JobEnvelope<T>
where
    T: Serialize,
{
    pub fn encode(&self) -> Result<Vec<u8>> {
        self.validate()?;
        Ok(serde_json::to_vec(self)?)
    }
}

impl<T> JobEnvelope<T>
where
    T: DeserializeOwned,
{
    pub fn decode(bytes: &[u8]) -> Result<Self> {
        let envelope: Self = serde_json::from_slice(bytes)?;
        envelope.validate()?;
        Ok(envelope)
    }
}

pub(crate) fn validate_subject_path(label: &str, value: &str) -> Result<()> {
    if value.is_empty() || value.len() > 255 {
        return Err(MqError::Protocol(format!(
            "{label} must contain between 1 and 255 bytes"
        )));
    }

    if value.split('.').any(|token| {
        token.is_empty()
            || !token
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
    }) {
        return Err(MqError::Protocol(format!(
            "{label} must be dot-separated ASCII letters, digits, '_' or '-'"
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use serde::{Deserialize, Serialize};

    use super::*;

    #[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
    struct Payload {
        source: String,
    }

    #[test]
    fn envelope_round_trips_with_a_stable_deduplication_id() {
        let envelope = JobEnvelope::new(
            Uuid::parse_str("8db4fda4-72e6-4e0c-9b66-067b46c284a4").expect("UUID"),
            41,
            72,
            "video.merge",
            2,
            "trace-abc",
            Payload {
                source: "project/72".to_string(),
            },
        )
        .expect("valid envelope");

        let bytes = envelope.encode().expect("encode envelope");
        let decoded = JobEnvelope::<Payload>::decode(&bytes).expect("decode envelope");

        assert_eq!(decoded, envelope);
        assert_eq!(decoded.schema_version, JOB_ENVELOPE_VERSION);
        assert_eq!(
            decoded.deduplication_id(),
            "8db4fda4-72e6-4e0c-9b66-067b46c284a4"
        );
    }

    #[test]
    fn envelope_rejects_unknown_versions_and_wildcard_kinds() {
        let mut envelope = JobEnvelope::new(Uuid::new_v4(), 1, 2, "video.merge", 0, "trace", ())
            .expect("valid envelope");
        envelope.schema_version = 99;
        assert!(matches!(envelope.validate(), Err(MqError::Protocol(_))));

        let error = JobEnvelope::new(Uuid::new_v4(), 1, 2, "video.*", 0, "trace", ())
            .expect_err("wildcards are not publishable job kinds");
        assert!(error.to_string().contains("dot-separated"));
    }

    #[test]
    fn decode_validates_the_wire_contract() {
        let bytes = br#"{
            "schema_version":1,
            "message_id":"8db4fda4-72e6-4e0c-9b66-067b46c284a4",
            "job_id":0,
            "task_id":2,
            "kind":"video.merge",
            "attempt":0,
            "trace_id":"trace",
            "payload":{}
        }"#;

        let error = JobEnvelope::<serde_json::Value>::decode(bytes)
            .expect_err("zero job id must not enter the worker");
        assert!(error.to_string().contains("job_id must be positive"));
    }
}

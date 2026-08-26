//! Durable job messaging primitives backed by NATS JetStream.
//!
//! PostgreSQL remains the source of truth for job state. This crate transports
//! versioned job references with at-least-once delivery semantics; consumers
//! must therefore make their terminal database transitions idempotent.

mod broker;
mod config;
mod envelope;
mod error;

pub use broker::{Broker, PublishReceipt};
pub use config::NatsConfig;
pub use envelope::{JOB_ENVELOPE_VERSION, JobEnvelope};
pub use error::{MqError, Result};

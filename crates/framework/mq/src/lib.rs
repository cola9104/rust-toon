//! Message queue framework extension point.
//!
//! This crate will own event naming, publisher/subscriber traits, retry
//! policies, and NATS/Kafka adapters.

use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct DomainEvent<T>
where
    T: Serialize,
{
    pub topic: String,
    pub payload: T,
}

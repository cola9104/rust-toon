use std::fmt;

/// Errors produced by the durable messaging layer.
#[derive(Debug)]
pub enum MqError {
    /// An environment or programmatic configuration value is invalid.
    Config(String),
    /// A job envelope or subject violates the protocol contract.
    Protocol(String),
    /// A payload could not be encoded or decoded as JSON.
    Serialization(serde_json::Error),
    /// NATS or JetStream rejected an operation.
    Nats(String),
    /// An operation exceeded its configured deadline.
    Timeout(&'static str),
}

impl fmt::Display for MqError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Config(message) => write!(formatter, "invalid NATS configuration: {message}"),
            Self::Protocol(message) => write!(formatter, "invalid job protocol value: {message}"),
            Self::Serialization(error) => write!(formatter, "job envelope JSON error: {error}"),
            Self::Nats(message) => write!(formatter, "NATS operation failed: {message}"),
            Self::Timeout(operation) => write!(formatter, "NATS {operation} timed out"),
        }
    }
}

impl std::error::Error for MqError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Serialization(error) => Some(error),
            _ => None,
        }
    }
}

impl From<serde_json::Error> for MqError {
    fn from(error: serde_json::Error) -> Self {
        Self::Serialization(error)
    }
}

pub type Result<T> = std::result::Result<T, MqError>;

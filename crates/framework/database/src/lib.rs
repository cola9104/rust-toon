//! PostgreSQL connection pool, migrations, and readiness primitives.

mod config;
mod postgres;

pub use config::{DatabaseConfig, DatabaseConfigError};
pub use postgres::{connect, migrate, ping};
pub use sqlx::{PgPool, Postgres, Transaction};

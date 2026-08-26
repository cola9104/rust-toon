use sqlx::{PgPool, postgres::PgPoolOptions};

use crate::DatabaseConfig;

// SQLx embeds the migration directory at compile time.
// 0001_initial.sql is the consolidated baseline. Add new migrations after it.
// The migration directory is embedded at compile time; keep this file tracked
// when adding migrations so the compile-time migrator is rebuilt (latest: 0002).
// Keep this file tied to the migration directory so newly added migrations are
// embedded when the gateway is rebuilt, and never edit a migration after it
// has been released.
// Recompile this crate whenever the migration catalog changes.
//
// Migrations are the sole source of truth for database schema and baseline data.
// sql/bootstrap/current.sql is a reference-only pg_dump snapshot kept for
// documentation and manual inspection — it is NOT loaded by the application.
static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("../../../sql/postgresql");

pub async fn connect(config: &DatabaseConfig) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .min_connections(config.min_connections)
        .max_connections(config.max_connections)
        .acquire_timeout(config.acquire_timeout)
        .connect(&config.url)
        .await
}

pub async fn migrate(pool: &PgPool) -> anyhow::Result<()> {
    initialize_empty_database(pool).await?;
    MIGRATOR.run(pool).await?;
    Ok(())
}

pub async fn ping(pool: &PgPool) -> Result<(), sqlx::Error> {
    sqlx::query("SELECT 1").execute(pool).await?;
    Ok(())
}

async fn initialize_empty_database(pool: &PgPool) -> anyhow::Result<()> {
    let has_migration_history: bool =
        sqlx::query_scalar("SELECT to_regclass('public._sqlx_migrations') IS NOT NULL")
            .fetch_one(pool)
            .await?;
    if has_migration_history {
        return Ok(());
    }

    let existing_application_tables: i64 = sqlx::query_scalar(
        "SELECT count(*)
         FROM pg_tables
         WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
           AND NOT (schemaname = 'public' AND tablename = 'spatial_ref_sys')",
    )
    .fetch_one(pool)
    .await?;
    anyhow::ensure!(
        existing_application_tables == 0,
        "database has application tables but no migration history; refusing to overwrite it"
    );

    tracing::info!("empty database detected; running all migrations from scratch");
    Ok(())
}

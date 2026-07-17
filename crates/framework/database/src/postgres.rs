use sqlx::{PgPool, postgres::PgPoolOptions};

use crate::DatabaseConfig;

// Yudao System, Infra compatibility, seed cleanup, performance, media, menu cleanup,
// Toonflow track ordering, and bigint video timestamps are embedded here.
// Recompile this crate whenever the embedded SQL migration catalog changes.
// SQLx embeds this directory at compile time; adding a migration must rebuild
// this module so local development and release binaries see the complete catalog (55 migrations).
static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("../../../sql/postgresql");
const CURRENT_DATABASE_BASELINE: &str = include_str!("../../../../sql/bootstrap/current.sql");

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

    tracing::info!("empty database detected; loading the current Rust Toon baseline");
    sqlx::raw_sql(CURRENT_DATABASE_BASELINE)
        .execute(pool)
        .await?;
    Ok(())
}

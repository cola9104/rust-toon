pub(crate) async fn load(pool: &sqlx::PgPool, key: &str, fallback: &str) -> String {
    sqlx::query_scalar::<_, String>(
        "SELECT data FROM toonflow.prompts WHERE source_key=$1 AND data<>'' ORDER BY id DESC LIMIT 1",
    )
    .bind(key)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten()
    .unwrap_or_else(|| fallback.to_string())
}

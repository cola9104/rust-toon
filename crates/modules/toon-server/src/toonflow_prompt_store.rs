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

pub(crate) async fn load_for_agent(
    pool: &sqlx::PgPool,
    agent_key: &str,
    fallback_key: &str,
    fallback: &str,
) -> String {
    let assigned: Option<String> = sqlx::query_scalar(
        "SELECT prompt_source_key FROM toonflow.agent_deployments
         WHERE key=$1 AND nullif(prompt_source_key,'') IS NOT NULL",
    )
    .bind(agent_key)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten();
    load(pool, assigned.as_deref().unwrap_or(fallback_key), fallback).await
}

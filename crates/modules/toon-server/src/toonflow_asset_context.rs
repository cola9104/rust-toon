use serde::Serialize;
use serde_json::{Value, json};
use sqlx::FromRow;

/// A production-facing asset record assembled from the canonical asset tables.
#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProductionAsset {
    id: i64,
    name: String,
    #[serde(rename = "type")]
    type_: String,
    description: String,
    prompt: String,
    image_id: Option<i64>,
    image_file_path: Option<String>,
    parent_asset_id: Option<i64>,
    source_project_id: i64,
    source_project_name: String,
}

/// Loads the live script text and its explicitly linked assets for production Agents and Flow UI.
///
/// Assets remain project-owned, while `script_assets` defines which reusable assets participate in
/// the current episode. Reading this projection on demand prevents the Agent workspace from keeping
/// a stale, manually copied asset list.
pub async fn load_script_context(
    pool: &sqlx::PgPool,
    project_id: i64,
    script_id: i64,
) -> Result<(String, Value), sqlx::Error> {
    let script = sqlx::query_scalar::<_, String>(
        "SELECT content FROM toonflow.scripts WHERE id=$1 AND project_id=$2",
    )
    .bind(script_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await?
    .unwrap_or_default();
    let assets = sqlx::query_as::<_, ProductionAsset>(
        r#"SELECT a.id, a.name, a.type AS type_, a.description, a.prompt,
                  a.image_id, i.file_path AS image_file_path, a.parent_asset_id,
                  a.project_id AS source_project_id, p.name AS source_project_name
           FROM toonflow.script_assets sa
           JOIN toonflow.assets a ON a.id=sa.asset_id
           JOIN toonflow.projects p ON p.id=a.project_id
           LEFT JOIN toonflow.images i ON i.id=a.image_id
           WHERE sa.script_id=$1
           ORDER BY a.parent_asset_id NULLS FIRST, a.type, a.name, a.id"#,
    )
    .bind(script_id)
    .fetch_all(pool)
    .await?;
    Ok((script, json!(assets)))
}

/// Returns usable image URLs for every asset explicitly associated with storyboards on a track.
pub async fn load_track_asset_references(
    pool: &sqlx::PgPool,
    project_id: i64,
    script_id: i64,
    track_id: i64,
) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar(
        r#"SELECT DISTINCT i.file_path
           FROM toonflow.storyboards s
           JOIN toonflow.assets_storyboards ast ON ast.storyboard_id=s.id
           JOIN toonflow.assets a ON a.id=ast.asset_id
           JOIN toonflow.images i ON i.id=a.image_id
           WHERE s.track_id=$1 AND s.project_id=$2 AND s.script_id=$3
             AND i.file_path IS NOT NULL AND i.file_path <> ''
           ORDER BY i.file_path"#,
    )
    .bind(track_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
}

/// Returns the current image URL of each asset associated with one storyboard.
pub async fn load_storyboard_asset_references(
    pool: &sqlx::PgPool,
    project_id: i64,
    script_id: i64,
    storyboard_id: i64,
) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar(
        r#"SELECT i.file_path
           FROM toonflow.assets_storyboards ast
           JOIN toonflow.storyboards s ON s.id=ast.storyboard_id
           JOIN toonflow.assets a ON a.id=ast.asset_id
           JOIN toonflow.images i ON i.id=a.image_id
           WHERE ast.storyboard_id=$1 AND s.project_id=$2 AND s.script_id=$3
             AND i.file_path IS NOT NULL AND i.file_path <> ''
           ORDER BY ast.sort_order, ast.asset_id"#,
    )
    .bind(storyboard_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
}

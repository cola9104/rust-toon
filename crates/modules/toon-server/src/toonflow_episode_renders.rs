use std::collections::HashMap;

use axum::{
    Json,
    extract::{Path, State},
};
use chrono::{DateTime, Utc};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::Serialize;
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::{
    ToonState,
    shared::{current_user_id, require},
    toonflow_agent_episode_scope::script_episode_number,
};

#[derive(Debug, FromRow)]
struct EpisodeRenderRow {
    id: i64,
    project_id: i64,
    script_id: i64,
    version: i32,
    object_path: String,
    file_path: String,
    cover_path: Option<String>,
    status: String,
    source_video_ids: Vec<i64>,
    metadata: Value,
    is_current: bool,
    created_by: Uuid,
    export_task_id: Option<i64>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeRender {
    pub id: i64,
    pub project_id: i64,
    pub script_id: i64,
    pub version: i32,
    pub url: String,
    pub object_path: String,
    pub file_path: String,
    pub poster_url: Option<String>,
    pub state: String,
    pub source_video_ids: Vec<i64>,
    pub metadata: Value,
    pub is_current: bool,
    pub created_by: String,
    pub export_task_id: Option<i64>,
    pub created_at: String,
    pub updated_at: String,
}

impl From<EpisodeRenderRow> for EpisodeRender {
    fn from(row: EpisodeRenderRow) -> Self {
        Self {
            id: row.id,
            project_id: row.project_id,
            script_id: row.script_id,
            version: row.version,
            url: row.file_path.clone(),
            object_path: row.object_path,
            file_path: row.file_path,
            poster_url: row.cover_path,
            state: row.status,
            source_video_ids: row.source_video_ids,
            metadata: row.metadata,
            is_current: row.is_current,
            created_by: row.created_by.to_string(),
            export_task_id: row.export_task_id,
            created_at: row.created_at.to_rfc3339(),
            updated_at: row.updated_at.to_rfc3339(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeArchive {
    pub script_id: i64,
    pub script_name: String,
    pub episode_no: Option<u32>,
    pub renders: Vec<EpisodeRender>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectVideoArchive {
    pub project_id: i64,
    pub episodes: Vec<EpisodeArchive>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeRenderList {
    pub project_id: i64,
    pub script_id: i64,
    pub renders: Vec<EpisodeRender>,
}

fn is_super_admin(user: &CurrentUser) -> bool {
    user.role_codes.iter().any(|role| role == "super_admin")
}

fn may_access_project(user: &CurrentUser, owner_id: Option<Uuid>, user_id: Uuid) -> bool {
    is_super_admin(user) || owner_id == Some(user_id)
}

pub(crate) async fn ensure_project_access(
    pool: &sqlx::PgPool,
    user: &CurrentUser,
    project_id: i64,
) -> Result<Uuid, AppError> {
    let user_id = current_user_id(user)?;
    let owner_id =
        sqlx::query_scalar::<_, Option<Uuid>>("SELECT user_id FROM toonflow.projects WHERE id=$1")
            .bind(project_id)
            .fetch_optional(pool)
            .await
            .map_err(|error| {
                tracing::error!(project_id, error = %error, "failed to authorize toonflow project");
                AppError::internal("failed to authorize project")
            })?
            .ok_or_else(|| AppError::not_found("project not found"))?;
    if !may_access_project(user, owner_id, user_id) {
        return Err(AppError::not_found("project not found"));
    }
    Ok(user_id)
}

pub(crate) async fn ensure_script_in_project(
    pool: &sqlx::PgPool,
    project_id: i64,
    script_id: i64,
) -> Result<(), AppError> {
    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM toonflow.scripts WHERE id=$1 AND project_id=$2)",
    )
    .bind(script_id)
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|error| {
        tracing::error!(project_id, script_id, error = %error, "failed to authorize toonflow script");
        AppError::internal("failed to authorize script")
    })?;
    if !exists {
        return Err(AppError::not_found("script not found"));
    }
    Ok(())
}

async fn render_rows_for_project(
    pool: &sqlx::PgPool,
    project_id: i64,
) -> Result<Vec<EpisodeRenderRow>, AppError> {
    sqlx::query_as::<_, EpisodeRenderRow>(
        "SELECT id,project_id,script_id,version,object_path,file_path,cover_path,status,
                source_video_ids,metadata,is_current,created_by,export_task_id,created_at,updated_at
         FROM toonflow.episode_renders
         WHERE project_id=$1 AND status='ready'
         ORDER BY script_id,version DESC,id DESC",
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|error| {
        tracing::error!(project_id, error = %error, "failed to list project episode renders");
        AppError::internal("failed to list episode renders")
    })
}

pub async fn project_video_archive(
    user: CurrentUser,
    State(state): State<ToonState>,
    Path(project_id): Path<i64>,
) -> Result<Json<ApiResponse<ProjectVideoArchive>>, AppError> {
    require(&user, "toon:project:read")?;
    ensure_project_access(&state.pool, &user, project_id).await?;

    let scripts: Vec<(i64, String)> = sqlx::query_as(
        "SELECT id,name FROM toonflow.scripts WHERE project_id=$1 ORDER BY create_time,id",
    )
    .bind(project_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|error| {
        tracing::error!(project_id, error = %error, "failed to list archive scripts");
        AppError::internal("failed to list archive scripts")
    })?;
    let mut renders_by_script: HashMap<i64, Vec<EpisodeRender>> = HashMap::new();
    for row in render_rows_for_project(&state.pool, project_id).await? {
        renders_by_script
            .entry(row.script_id)
            .or_default()
            .push(row.into());
    }
    let episodes = scripts
        .into_iter()
        .map(|(script_id, script_name)| EpisodeArchive {
            script_id,
            episode_no: script_episode_number(&script_name),
            script_name,
            renders: renders_by_script.remove(&script_id).unwrap_or_default(),
        })
        .collect();
    Ok(Json(ApiResponse::new(ProjectVideoArchive {
        project_id,
        episodes,
    })))
}

pub async fn list_episode_renders(
    user: CurrentUser,
    State(state): State<ToonState>,
    Path((project_id, script_id)): Path<(i64, i64)>,
) -> Result<Json<ApiResponse<EpisodeRenderList>>, AppError> {
    require(&user, "toon:episode:read")?;
    ensure_project_access(&state.pool, &user, project_id).await?;
    ensure_script_in_project(&state.pool, project_id, script_id).await?;

    let rows = sqlx::query_as::<_, EpisodeRenderRow>(
        "SELECT id,project_id,script_id,version,object_path,file_path,cover_path,status,
                source_video_ids,metadata,is_current,created_by,export_task_id,created_at,updated_at
         FROM toonflow.episode_renders
         WHERE project_id=$1 AND script_id=$2 AND status='ready'
         ORDER BY version DESC,id DESC",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|error| {
        tracing::error!(project_id, script_id, error = %error, "failed to list episode renders");
        AppError::internal("failed to list episode renders")
    })?;
    Ok(Json(ApiResponse::new(EpisodeRenderList {
        project_id,
        script_id,
        renders: rows.into_iter().map(Into::into).collect(),
    })))
}

pub async fn select_current_render(
    user: CurrentUser,
    State(state): State<ToonState>,
    Path(render_id): Path<i64>,
) -> Result<Json<ApiResponse<EpisodeRender>>, AppError> {
    require(&user, "toon:episode:update")?;
    let user_id = current_user_id(&user)?;
    let mut tx = state.pool.begin().await.map_err(|error| {
        tracing::error!(render_id, error = %error, "failed to begin current render transaction");
        AppError::internal("failed to select current render")
    })?;

    let target: Option<(i64, i64, String, Option<Uuid>)> = sqlx::query_as(
        "SELECT r.project_id,r.script_id,r.status,p.user_id
         FROM toonflow.episode_renders r
         JOIN toonflow.projects p ON p.id=r.project_id
         JOIN toonflow.scripts s ON s.id=r.script_id AND s.project_id=r.project_id
         WHERE r.id=$1
         FOR UPDATE OF s",
    )
    .bind(render_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|error| {
        tracing::error!(render_id, error = %error, "failed to lock current render target");
        AppError::internal("failed to select current render")
    })?;
    let (project_id, script_id, status, owner_id) =
        target.ok_or_else(|| AppError::not_found("episode render not found"))?;
    if !may_access_project(&user, owner_id, user_id) {
        return Err(AppError::not_found("episode render not found"));
    }
    if status != "ready" {
        return Err(AppError::bad_request(
            "only a ready episode render can be current",
        ));
    }

    sqlx::query(
        "UPDATE toonflow.episode_renders
         SET is_current=false,updated_at=now()
         WHERE project_id=$1 AND script_id=$2 AND is_current AND id<>$3",
    )
    .bind(project_id)
    .bind(script_id)
    .bind(render_id)
    .execute(&mut *tx)
    .await
    .map_err(|error| {
        tracing::error!(render_id, error = %error, "failed to clear previous current render");
        AppError::internal("failed to select current render")
    })?;
    let row = sqlx::query_as::<_, EpisodeRenderRow>(
        "UPDATE toonflow.episode_renders
         SET is_current=true,updated_at=now()
         WHERE id=$1 AND project_id=$2 AND script_id=$3 AND status='ready'
         RETURNING id,project_id,script_id,version,object_path,file_path,cover_path,status,
                   source_video_ids,metadata,is_current,created_by,export_task_id,created_at,updated_at",
    )
    .bind(render_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|error| {
        tracing::error!(render_id, error = %error, "failed to set current render");
        AppError::internal("failed to select current render")
    })?
    .ok_or_else(|| AppError::not_found("episode render not found"))?;
    tx.commit().await.map_err(|error| {
        tracing::error!(render_id, error = %error, "failed to commit current render transaction");
        AppError::internal("failed to select current render")
    })?;
    Ok(Json(ApiResponse::new(row.into())))
}

#[cfg(test)]
mod tests {
    use rust_toon_framework_security::{DataScope, PermissionSet};

    use super::*;

    fn user(id: &str, role_codes: &[&str]) -> CurrentUser {
        CurrentUser {
            user_id: id.to_string(),
            username: "render-test".into(),
            tenant_id: None,
            role_codes: role_codes.iter().map(|role| (*role).to_string()).collect(),
            permissions: PermissionSet::default(),
            data_scope: DataScope::SelfOnly,
        }
    }

    #[test]
    fn project_access_is_owner_scoped_with_super_admin_override() {
        let owner = Uuid::new_v4();
        let other = Uuid::new_v4();
        assert!(may_access_project(
            &user(&owner.to_string(), &[]),
            Some(owner),
            owner
        ));
        assert!(!may_access_project(
            &user(&other.to_string(), &[]),
            Some(owner),
            other
        ));
        assert!(may_access_project(
            &user(&other.to_string(), &["super_admin"]),
            Some(owner),
            other
        ));
        assert!(!may_access_project(
            &user(&owner.to_string(), &[]),
            None,
            owner
        ));
    }

    #[test]
    fn project_archive_contract_is_nested_under_data_episodes_in_camel_case() {
        let response = ApiResponse::new(ProjectVideoArchive {
            project_id: 42,
            episodes: vec![],
        });
        let value = serde_json::to_value(response).unwrap();
        assert_eq!(value["data"]["projectId"], 42);
        assert!(value["data"]["episodes"].is_array());
        assert!(value["data"].get("project_id").is_none());
    }
}

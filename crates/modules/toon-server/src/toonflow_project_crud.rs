use crate::{
    ToonState,
    shared::{affected, current_user_id, require},
    toonflow::{SaveProjectRequest, ToonflowProject},
    toonflow_project_helpers::{next_id, now_ms, validate_models, video_mode, video_ratio},
    toonflow_storage::{delete_asset_file, record_cleanup_failure},
};
use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde_json::{Value, json};

pub async fn list_projects(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<ToonflowProject>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, ToonflowProject>(
        r#"SELECT id, project_type, chat_model, image_model, image_quality, video_model, name, intro,
                  type as type_, art_style, director_manual, mode, video_ratio, create_time, update_time
           FROM toonflow.projects ORDER BY create_time DESC"#,
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list toonflow projects"))?;
    Ok(Json(ApiResponse::new(rows)))
}

pub async fn create_project(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SaveProjectRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:create")?;
    if request.name.trim().is_empty() {
        return Err(AppError::bad_request("project name is required"));
    }
    validate_models(
        &state.pool,
        request.chat_model,
        request.image_model,
        request.video_model,
    )
    .await?;
    let id = request.id.unwrap_or_else(|| next_id(0));
    let time = now_ms();
    sqlx::query("INSERT INTO toonflow.projects (id, project_type, chat_model, image_model, image_quality, video_model, name, intro, type, art_style, director_manual, mode, video_ratio, user_id, create_time, update_time) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$15)")
        .bind(id).bind(request.project_type).bind(request.chat_model).bind(request.image_model).bind(request.image_quality).bind(request.video_model).bind(request.name.trim()).bind(request.intro).bind(request.r#type).bind(request.art_style).bind(request.director_manual).bind(video_mode(&request.mode)).bind(video_ratio(&request.video_ratio)).bind(current_user_id(&user)?).bind(time)
        .execute(&state.pool).await.map_err(|_| AppError::internal("failed to create toonflow project"))?;
    Ok(Json(ApiResponse::with_message(
        json!({"id": id}),
        "新增项目成功",
    )))
}

pub async fn update_project(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SaveProjectRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    let id = request
        .id
        .ok_or_else(|| AppError::bad_request("project id is required"))?;
    validate_models(
        &state.pool,
        request.chat_model,
        request.image_model,
        request.video_model,
    )
    .await?;
    let result = sqlx::query("UPDATE toonflow.projects SET project_type=$2,chat_model=$3,image_model=$4,image_quality=$5,video_model=$6,name=$7,intro=$8,type=$9,art_style=$10,director_manual=$11,mode=$12,video_ratio=$13,update_time=$14 WHERE id=$1")
        .bind(id).bind(request.project_type).bind(request.chat_model).bind(request.image_model).bind(request.image_quality).bind(request.video_model).bind(request.name.trim()).bind(request.intro).bind(request.r#type).bind(request.art_style).bind(request.director_manual).bind(video_mode(&request.mode)).bind(video_ratio(&request.video_ratio)).bind(now_ms()).execute(&state.pool).await.map_err(|_| AppError::internal("failed to update toonflow project"))?;
    affected(result.rows_affected(), "project")?;
    Ok(Json(ApiResponse::with_message((), "编辑项目成功")))
}

pub async fn delete_project(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<crate::toonflow::IdRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:delete")?;
    let paths: Vec<Option<String>> = sqlx::query_scalar("SELECT file_path FROM toonflow.images WHERE assets_id IN (SELECT id FROM toonflow.assets WHERE project_id=$1) UNION ALL SELECT file_path FROM toonflow.storyboards WHERE project_id=$1 UNION ALL SELECT file_path FROM toonflow.videos WHERE project_id=$1 UNION ALL SELECT file_path FROM toonflow.episode_renders WHERE project_id=$1 UNION ALL SELECT cover_path FROM toonflow.episode_renders WHERE project_id=$1").bind(request.id).fetch_all(&state.pool).await.map_err(|_| AppError::internal("failed to collect project files"))?;
    let result = sqlx::query("DELETE FROM toonflow.projects WHERE id=$1")
        .bind(request.id)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to delete toonflow project"))?;
    affected(result.rows_affected(), "project")?;
    for path in paths.into_iter().flatten() {
        if let Err(error) = delete_asset_file(&path).await {
            record_cleanup_failure(&state.pool, &path, "project", Some(request.id), &error).await;
        }
    }
    Ok(Json(ApiResponse::with_message((), "删除项目成功")))
}

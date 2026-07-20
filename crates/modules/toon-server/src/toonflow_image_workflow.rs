use crate::{ToonState, ai_client, shared::require};
use axum::{Json, extract::State};
use base64::Engine;
use image::{DynamicImage, ImageFormat, RgbaImage, imageops};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::Deserialize;
use serde_json::{Value, json};

#[derive(Deserialize)]
pub struct FlowId {
    id: i64,
}
pub async fn get_flow(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<FlowId>,
) -> Result<Json<ApiResponse<Option<Value>>>, AppError> {
    require(&user, "toon:project:read")?;
    let row: Option<(i64, Value)> =
        sqlx::query_as("SELECT id,flow_data FROM toonflow.image_flows WHERE id=$1")
            .bind(req.id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get image flow"))?;
    Ok(Json(ApiResponse::new(row.map(|r| {
        let mut value = r.1;
        value["id"] = json!(r.0);
        value
    }))))
}
#[derive(Deserialize)]
pub struct SaveFlow {
    edges: Value,
    nodes: Value,
}
pub async fn save_flow(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<SaveFlow>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let id = chrono::Utc::now().timestamp_millis();
    sqlx::query("INSERT INTO toonflow.image_flows(id,flow_data)VALUES($1,$2)")
        .bind(id)
        .bind(json!({"edges":req.edges,"nodes":req.nodes}))
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to save image flow"))?;
    Ok(Json(ApiResponse::new(json!({"id":id}))))
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateFlow {
    flow_id: i64,
    edges: Value,
    nodes: Value,
}
pub async fn update_flow(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<UpdateFlow>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    sqlx::query("UPDATE toonflow.image_flows SET flow_data=$2 WHERE id=$1")
        .bind(req.flow_id)
        .bind(json!({"edges":req.edges,"nodes":req.nodes}))
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to update image flow"))?;
    Ok(Json(ApiResponse::new(())))
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FlowImage {
    model: String,
    references: Option<Vec<String>>,
    quality: String,
    ratio: String,
    prompt: String,
    project_id: i64,
}
pub async fn generate_flow_image(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<FlowImage>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let references = req.references.as_ref().map_or(0, Vec::len);
    let url = ai_client::image(
        &state.pool,
        &req.model,
        &format!(
            "{}\n画面比例：{}\n参考图数量：{references}",
            req.prompt, req.ratio
        ),
        &req.quality,
    )
    .await
    .map_err(AppError::bad_request)?;
    let now = chrono::Utc::now().timestamp_millis();
    let _=sqlx::query("INSERT INTO toonflow.tasks(id,project_id,task_class,related_objects,model,description,state,start_time)VALUES($1,$2,'工作流图片生成',$3,$4,'工作流图片生成','success',$1)").bind(now).bind(req.project_id).bind(json!({"prompt":req.prompt}).to_string()).bind(req.model).execute(&state.pool).await;
    Ok(Json(ApiResponse::new(json!({"url":url}))))
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectId {
    project_id: i64,
}
pub async fn default_model(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<ProjectId>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:read")?;
    let row: Option<(Option<i64>, String)> =
        sqlx::query_as("SELECT image_model,image_quality FROM toonflow.projects WHERE id=$1")
            .bind(req.project_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get image model"))?;
    Ok(Json(ApiResponse::new(
        row.map(|r| json!({"imageModel":r.0,"imageQuality":r.1}))
            .unwrap_or(Value::Null),
    )))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StoryboardGenerate {
    storyboard_ids: Vec<i64>,
    project_id: i64,
    script_id: i64,
    concurrent_count: Option<usize>,
    compulsory: Option<bool>,
}

pub async fn schedule_storyboard_generation(
    pool: &sqlx::PgPool,
    project_id: i64,
    script_id: i64,
    storyboard_ids: &[i64],
    concurrent_count: usize,
    compulsory: bool,
) -> Result<Vec<Value>, AppError> {
    if storyboard_ids.is_empty() {
        return Err(AppError::bad_request("storyboardIds不能为空"));
    }
    let rows=sqlx::query_as::<_,(i64,String,i32)>("SELECT id,prompt,should_generate_image FROM toonflow.storyboards WHERE project_id=$1 AND script_id=$2 AND id=ANY($3)").bind(project_id).bind(script_id).bind(storyboard_ids).fetch_all(pool).await.map_err(|_|AppError::internal("failed to get storyboards"))?;
    if rows.is_empty() {
        return Err(AppError::not_found("未查到分镜数据"));
    }
    let ids = rows
        .iter()
        .filter(|row| compulsory || row.2 != 0)
        .map(|row| row.0)
        .collect::<Vec<_>>();
    sqlx::query("UPDATE toonflow.storyboards SET state='生成中',reason=NULL WHERE id=ANY($1)")
        .bind(&ids)
        .execute(pool)
        .await
        .map_err(|_| AppError::internal("failed to start storyboards"))?;
    let response=rows.iter().map(|row|json!({"id":row.0,"prompt":row.1,"state":if ids.contains(&row.0){"生成中"}else{"未生成"},"shouldGenerateImage":row.2})).collect();
    let pool = pool.clone();
    tokio::spawn(async move {
        let setting: Option<(Option<i64>, String, String)> = sqlx::query_as(
            "SELECT image_model,image_quality,video_ratio FROM toonflow.projects WHERE id=$1",
        )
        .bind(project_id)
        .fetch_optional(&pool)
        .await
        .ok()
        .flatten();
        let Some((Some(model), quality, ratio)) = setting else {
            return;
        };
        let sem = std::sync::Arc::new(tokio::sync::Semaphore::new(concurrent_count.clamp(1, 10)));
        for (id, prompt, should) in rows {
            if !compulsory && should == 0 {
                continue;
            }
            let permit = sem.clone().acquire_owned().await;
            let pool = pool.clone();
            let model = model.to_string();
            let quality = quality.clone();
            let ratio = ratio.clone();
            tokio::spawn(async move {
                if permit.is_ok() {
                    let references =
                        crate::toonflow_asset_context::load_storyboard_asset_references(
                            &pool, project_id, script_id, id,
                        )
                        .await
                        .unwrap_or_default();
                    match ai_client::image_with_references(
                        &pool,
                        &model,
                        &format!("{prompt}\n画面比例：{ratio}"),
                        &quality,
                        references,
                    )
                    .await
                    {
                        Ok(url) => {
                            let _=sqlx::query("UPDATE toonflow.storyboards SET file_path=$2,state='已完成',reason=NULL WHERE id=$1").bind(id).bind(url).execute(&pool).await;
                        }
                        Err(reason) => {
                            let _=sqlx::query("UPDATE toonflow.storyboards SET state='生成失败',reason=$2 WHERE id=$1").bind(id).bind(reason).execute(&pool).await;
                        }
                    }
                }
            });
        }
    });
    Ok(response)
}

pub async fn generate_storyboards(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<StoryboardGenerate>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "toon:scene:update")?;
    let response = schedule_storyboard_generation(
        &state.pool,
        req.project_id,
        req.script_id,
        &req.storyboard_ids,
        req.concurrent_count.unwrap_or(5),
        req.compulsory.unwrap_or(false),
    )
    .await?;
    Ok(Json(ApiResponse::new(response)))
}

#[derive(Deserialize)]
pub struct Ids {
    ids: Vec<i64>,
}
pub async fn poll_storyboards(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<Ids>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "toon:scene:read")?;
    let rows=sqlx::query_as::<_,(i64,String,Option<String>,Option<String>,String)>("SELECT id,coalesce(state,''),reason,file_path,prompt FROM toonflow.storyboards WHERE id=ANY($1) AND state<>'生成中'").bind(req.ids).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to poll storyboards"))?;
    Ok(Json(ApiResponse::new(rows.into_iter().map(|r|json!({"id":r.0,"state":r.1,"reason":r.2,"filePath":r.3,"src":r.3,"prompt":r.4})).collect())))
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StoryboardUrl {
    id: i64,
    url: String,
    flow_id: i64,
}
pub async fn update_storyboard_url(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<StoryboardUrl>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:scene:update")?;
    sqlx::query("UPDATE toonflow.storyboards SET file_path=$2,flow_id=$3,state='已完成',should_generate_image=$4 WHERE id=$1").bind(req.id).bind(&req.url).bind(req.flow_id).bind(if req.url.is_empty(){0}else{1}).execute(&state.pool).await.map_err(|_|AppError::internal("failed to update storyboard image"))?;
    Ok(Json(ApiResponse::new(json!({"message":"更新分镜成功"}))))
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteStoryboards {
    ids: Vec<i64>,
    project_id: i64,
}
pub async fn delete_storyboards(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<DeleteStoryboards>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:scene:delete")?;
    if req.ids.is_empty() {
        return Err(AppError::bad_request("请先选择分镜"));
    }
    let mut tx = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin transaction"))?;
    sqlx::query("DELETE FROM toonflow.assets_storyboards WHERE storyboard_id=ANY($1)")
        .bind(&req.ids)
        .execute(&mut *tx)
        .await
        .map_err(|_| AppError::internal("failed to delete storyboard assets"))?;
    let result = sqlx::query("DELETE FROM toonflow.storyboards WHERE id=ANY($1) AND project_id=$2")
        .bind(req.ids)
        .bind(req.project_id)
        .execute(&mut *tx)
        .await
        .map_err(|_| AppError::internal("failed to delete storyboards"))?;
    if result.rows_affected() == 0 {
        return Err(AppError::not_found("当前选择分镜不存在"));
    }
    tx.commit()
        .await
        .map_err(|_| AppError::internal("failed to commit transaction"))?;
    Ok(Json(ApiResponse::new(json!({"message":"视频删除成功"}))))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PreviewRequest {
    #[serde(alias = "ids")]
    storyboard_ids: Vec<i64>,
}

async fn preview_png(pool: &sqlx::PgPool, ids: &[i64]) -> Result<Option<Vec<u8>>, AppError> {
    let rows = sqlx::query_as::<_, (i64, Option<String>)>(
        "SELECT id,file_path FROM toonflow.storyboards WHERE id=ANY($1)",
    )
    .bind(ids)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to get storyboard images"))?;
    let paths = rows
        .into_iter()
        .collect::<std::collections::HashMap<_, _>>();
    let mut images = Vec::new();
    let mut original_images = Vec::new();
    for id in ids {
        let Some(path) = paths.get(id).and_then(Clone::clone) else {
            continue;
        };
        let bytes = if let Some(encoded) = path.split_once(";base64,").map(|v| v.1) {
            base64::engine::general_purpose::STANDARD
                .decode(encoded)
                .map_err(|_| AppError::bad_request("invalid image data"))?
        } else {
            reqwest::get(path)
                .await
                .map_err(|_| AppError::bad_request("failed to fetch storyboard image"))?
                .bytes()
                .await
                .map_err(|_| AppError::bad_request("failed to read storyboard image"))?
                .to_vec()
        };
        if looks_like_image(&bytes) {
            original_images.push(bytes.clone());
        }
        if let Ok(image) = image::load_from_memory(&bytes) {
            images.push(image);
        }
    }
    if images.is_empty() {
        if ids.len() == 1 {
            return Ok(original_images.into_iter().next());
        }
        return Ok(None);
    }
    let thumb = 256u32;
    let cols = images.len().min(5) as u32;
    let row_count = images.len().div_ceil(cols as usize) as u32;
    let mut canvas = RgbaImage::from_pixel(
        cols * thumb,
        row_count * thumb,
        image::Rgba([255, 255, 255, 255]),
    );
    for (index, image) in images.into_iter().enumerate() {
        let resized = image.resize(thumb, thumb, imageops::FilterType::Lanczos3);
        let x = index as u32 % cols * thumb + (thumb - resized.width()) / 2;
        let y = index as u32 / cols * thumb + (thumb - resized.height()) / 2;
        imageops::overlay(&mut canvas, &resized, x.into(), y.into());
    }
    let mut cursor = std::io::Cursor::new(Vec::new());
    DynamicImage::ImageRgba8(canvas)
        .write_to(&mut cursor, ImageFormat::Png)
        .map_err(|_| AppError::internal("failed to encode preview"))?;
    Ok(Some(cursor.into_inner()))
}

fn looks_like_image(bytes: &[u8]) -> bool {
    bytes.starts_with(b"\x89PNG\r\n\x1a\n")
        || bytes.starts_with(b"\xff\xd8\xff")
        || bytes.starts_with(b"GIF87a")
        || bytes.starts_with(b"GIF89a")
        || bytes.starts_with(b"RIFF") && bytes.get(8..12) == Some(b"WEBP")
}

pub async fn preview_storyboards(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<PreviewRequest>,
) -> Result<Json<ApiResponse<Option<String>>>, AppError> {
    require(&user, "toon:scene:read")?;
    let png = preview_png(&state.pool, &req.storyboard_ids).await?;
    Ok(Json(ApiResponse::new(png.map(|data| {
        format!(
            "data:image/png;base64,{}",
            base64::engine::general_purpose::STANDARD.encode(data)
        )
    }))))
}

pub async fn download_storyboards(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<PreviewRequest>,
) -> Result<axum::response::Response, AppError> {
    require(&user, "toon:scene:read")?;
    let png = preview_png(&state.pool, &req.storyboard_ids)
        .await?
        .ok_or_else(|| AppError::not_found("没有可下载的分镜图片"))?;
    axum::response::Response::builder()
        .header("content-type", "image/png")
        .header(
            "content-disposition",
            "attachment; filename=storyboard-preview.png",
        )
        .body(axum::body::Body::from(png))
        .map_err(|_| AppError::internal("failed to build download"))
}

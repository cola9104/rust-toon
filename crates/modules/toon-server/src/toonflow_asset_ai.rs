use crate::{ToonState, ai_client, shared::require};
use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::Deserialize;
use serde_json::{Value, json};

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PolishItem {
    assets_id: i64,
    #[serde(rename = "type")]
    type_: String,
    name: String,
    describe: String,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PolishRequest {
    assets_id: i64,
    project_id: i64,
    #[serde(rename = "type")]
    type_: String,
    name: String,
    describe: String,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BatchRequest {
    items: Vec<PolishItem>,
    project_id: i64,
    concurrent_count: Option<usize>,
    other_text_prompt: String,
}
fn manual_key(kind: &str, derivative: bool) -> Option<(&'static str, &'static str)> {
    match kind {
        "role" => Some((
            "角色",
            if derivative {
                "art_character_derivative"
            } else {
                "art_character"
            },
        )),
        "scene" => Some((
            "场景",
            if derivative {
                "art_scene_derivative"
            } else {
                "art_scene"
            },
        )),
        "tool" => Some((
            "道具",
            if derivative {
                "art_prop_derivative"
            } else {
                "art_prop"
            },
        )),
        _ => None,
    }
}

async fn run(
    pool: &sqlx::PgPool,
    project_id: i64,
    item: PolishItem,
    extra: &str,
) -> Result<String, String> {
    sqlx::query(
        "UPDATE toonflow.assets SET prompt_state='生成中',prompt_error_reason=NULL WHERE id=$1",
    )
    .bind(item.assets_id)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;
    let context:Option<(String,Option<i64>)>=sqlx::query_as("SELECT p.art_style,a.parent_asset_id FROM toonflow.assets a JOIN toonflow.projects p ON p.id=a.project_id WHERE a.id=$1 AND a.project_id=$2").bind(item.assets_id).bind(project_id).fetch_optional(pool).await.map_err(|e|e.to_string())?;
    let (manual_path, parent) = context.ok_or_else(|| "资产不存在".to_string())?;
    let (label, key) =
        manual_key(&item.type_, parent.is_some()).ok_or_else(|| "不支持的类型".to_string())?;
    let data: Option<(Value,)> = sqlx::query_as(
        "SELECT data FROM toonflow.creative_manuals WHERE kind='visual' AND path=$1",
    )
    .bind(manual_path)
    .fetch_optional(pool)
    .await
    .map_err(|e| e.to_string())?;
    let system = data
        .and_then(|r| {
            r.0.as_array().and_then(|items| {
                items
                    .iter()
                    .find(|v| v.get("value").and_then(Value::as_str) == Some(key))
                    .and_then(|v| v.get("data"))
                    .and_then(Value::as_str)
                    .map(str::to_string)
            })
        })
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "视觉手册未定义".to_string())?;
    let prompt = ai_client::text(
        pool,
        "universalAi",
        &format!("{system}\n{extra}"),
        &format!(
            "{label}名称：{}\n{label}描述：{}\n只输出可直接用于图片生成的提示词。",
            item.name, item.describe
        ),
    )
    .await?;
    sqlx::query("UPDATE toonflow.assets SET prompt=$2,prompt_state='已完成',prompt_error_reason=NULL WHERE id=$1").bind(item.assets_id).bind(&prompt).execute(pool).await.map_err(|e|e.to_string())?;
    Ok(prompt)
}
async fn mark_failed(pool: &sqlx::PgPool, id: i64, reason: &str) {
    let _ = sqlx::query(
        "UPDATE toonflow.assets SET prompt_state='失败',prompt_error_reason=$2 WHERE id=$1",
    )
    .bind(id)
    .bind(reason)
    .execute(pool)
    .await;
}
pub async fn polish(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<PolishRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let item = PolishItem {
        assets_id: req.assets_id,
        type_: req.type_,
        name: req.name,
        describe: req.describe,
    };
    match run(&state.pool, req.project_id, item.clone(), "").await {
        Ok(prompt) => Ok(Json(ApiResponse::new(
            json!({"prompt":prompt,"assetsId":item.assets_id}),
        ))),
        Err(reason) => {
            mark_failed(&state.pool, item.assets_id, &reason).await;
            Err(AppError::bad_request(reason))
        }
    }
}
pub async fn batch_polish(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<BatchRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let total = req.items.len();
    let pool = state.pool.clone();
    tokio::spawn(async move {
        let sem = std::sync::Arc::new(tokio::sync::Semaphore::new(
            req.concurrent_count.unwrap_or(1).clamp(1, 20),
        ));
        let mut jobs = Vec::new();
        for item in req.items {
            let pool = pool.clone();
            let extra = req.other_text_prompt.clone();
            let permit = sem.clone().acquire_owned().await;
            let project_id = req.project_id;
            jobs.push(tokio::spawn(async move {
                if permit.is_ok() {
                    if let Err(reason) = run(&pool, project_id, item.clone(), &extra).await {
                        mark_failed(&pool, item.assets_id, &reason).await;
                    }
                }
            }));
        }
        for job in jobs {
            let _ = job.await;
        }
    });
    Ok(Json(ApiResponse::new(json!({"total":total}))))
}
#[derive(Deserialize)]
pub struct Ids {
    ids: Vec<i64>,
}
pub async fn poll_prompts(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<Ids>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows=sqlx::query_as::<_,(i64,String,String,Option<String>)>("SELECT id,prompt,coalesce(prompt_state,''),prompt_error_reason FROM toonflow.assets WHERE id=ANY($1) AND coalesce(prompt_state,'')<>'生成中'").bind(req.ids).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to poll asset prompts"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter()
            .map(|r| json!({"id":r.0,"prompt":r.1,"promptState":r.2,"promptErrorReason":r.3}))
            .collect(),
    )))
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ImageItem {
    pub(crate) id: i64,
    #[serde(rename = "type")]
    pub(crate) type_: String,
    pub(crate) name: String,
    pub(crate) prompt: String,
    pub(crate) base64: Option<String>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GenerateImageRequest {
    project_id: i64,
    model: String,
    resolution: String,
    id: i64,
    #[serde(rename = "type")]
    type_: String,
    name: String,
    prompt: String,
    base64: Option<String>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BatchImageRequest {
    project_id: i64,
    model: String,
    resolution: String,
    concurrent_count: Option<usize>,
    items: Vec<ImageItem>,
}
async fn new_image(
    pool: &sqlx::PgPool,
    item: &ImageItem,
    model: &str,
    resolution: &str,
    offset: i64,
) -> Result<i64, AppError> {
    let id = chrono::Utc::now().timestamp_millis() + offset;
    sqlx::query("INSERT INTO toonflow.images(id,type,assets_id,model,resolution,state) VALUES($1,$2,$3,$4,$5,'生成中')").bind(id).bind(&item.type_).bind(item.id).bind(model).bind(resolution).execute(pool).await.map_err(|_|AppError::internal("failed to create image"))?;
    Ok(id)
}
async fn make_image(
    pool: &sqlx::PgPool,
    project_id: i64,
    model: &str,
    resolution: &str,
    item: ImageItem,
    image_id: i64,
) -> Result<String, String> {
    let style: Option<(String,)> =
        sqlx::query_as("SELECT art_style FROM toonflow.projects WHERE id=$1")
            .bind(project_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| e.to_string())?;
    let style = style.ok_or_else(|| "项目为空".to_string())?.0;
    let prompt = format!(
        "画风：{style}\n类型：{}\n名称：{}\n{}{}",
        item.type_,
        item.name,
        item.prompt,
        if item.base64.is_some() {
            "\n保持参考图主体特征一致。"
        } else {
            ""
        }
    );
    match ai_client::image(pool, model, &prompt, resolution).await {
        Ok(path) => {
            let updated = sqlx::query("UPDATE toonflow.images SET file_path=$2,state='已完成' WHERE id=$1 AND state='生成中'")
                .bind(image_id)
                .bind(&path)
                .execute(pool)
                .await
                .map_err(|e| e.to_string())?;
            if updated.rows_affected() == 0 {
                return Err("生成任务已取消".into());
            }
            sqlx::query("UPDATE toonflow.assets SET image_id=$2 WHERE id=$1")
                .bind(item.id)
                .bind(image_id)
                .execute(pool)
                .await
                .map_err(|e| e.to_string())?;
            Ok(path)
        }
        Err(reason) => {
            let _ = sqlx::query(
                "UPDATE toonflow.images SET state='生成失败',error_reason=$2 WHERE id=$1",
            )
            .bind(image_id)
            .bind(&reason)
            .execute(pool)
            .await;
            Err(reason)
        }
    }
}

pub(crate) async fn schedule_asset_generation(
    pool: &sqlx::PgPool,
    project_id: i64,
    asset_ids: &[i64],
    concurrent_count: usize,
) -> Result<Vec<Value>, AppError> {
    if asset_ids.is_empty() {
        return Err(AppError::bad_request("ids不能为空"));
    }
    let setting: Option<(Option<i64>, String)> =
        sqlx::query_as("SELECT image_model,image_quality FROM toonflow.projects WHERE id=$1")
            .bind(project_id)
            .fetch_optional(pool)
            .await
            .map_err(|_| AppError::internal("failed to load project image model"))?;
    let (model, resolution) = setting.ok_or_else(|| AppError::not_found("project not found"))?;
    let model = model
        .ok_or_else(|| AppError::bad_request("请先配置项目图片模型"))?
        .to_string();
    let rows: Vec<(i64, String, String, String)> = sqlx::query_as(
        "SELECT id,type,name,prompt FROM toonflow.assets WHERE project_id=$1 AND id=ANY($2)",
    )
    .bind(project_id)
    .bind(asset_ids)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to load assets"))?;
    let mut queue = Vec::new();
    for (offset, (id, type_, name, prompt)) in rows.into_iter().enumerate() {
        let item = ImageItem {
            id,
            type_,
            name,
            prompt,
            base64: None,
        };
        let image_id = new_image(pool, &item, &model, &resolution, offset as i64).await?;
        queue.push((image_id, item));
    }
    let response = queue
        .iter()
        .map(|(image_id, item)| json!({"id":item.id,"imageId":image_id,"state":"生成中"}))
        .collect::<Vec<_>>();
    let pool = pool.clone();
    tokio::spawn(async move {
        let sem = std::sync::Arc::new(tokio::sync::Semaphore::new(concurrent_count.clamp(1, 10)));
        for (image_id, item) in queue {
            let permit = sem.clone().acquire_owned().await;
            let pool = pool.clone();
            let model = model.clone();
            let resolution = resolution.clone();
            tokio::spawn(async move {
                if permit.is_ok() {
                    let _ =
                        make_image(&pool, project_id, &model, &resolution, item, image_id).await;
                }
            });
        }
    });
    Ok(response)
}
pub async fn generate_image(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<GenerateImageRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let item = ImageItem {
        id: req.id,
        type_: req.type_,
        name: req.name,
        prompt: req.prompt,
        base64: req.base64,
    };
    let image_id = new_image(&state.pool, &item, &req.model, &req.resolution, 0).await?;
    match make_image(
        &state.pool,
        req.project_id,
        &req.model,
        &req.resolution,
        item.clone(),
        image_id,
    )
    .await
    {
        Ok(path) => Ok(Json(ApiResponse::new(
            json!({"path":path,"assetsId":item.id}),
        ))),
        Err(reason) => Err(AppError::bad_request(reason)),
    }
}
pub async fn batch_generate_images(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<BatchImageRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let total = req.items.len();
    let mut queue = Vec::new();
    for (index, item) in req.items.into_iter().enumerate() {
        queue.push((
            new_image(
                &state.pool,
                &item,
                &req.model,
                &req.resolution,
                index as i64,
            )
            .await?,
            item,
        ));
    }
    let pool = state.pool.clone();
    tokio::spawn(async move {
        let sem = std::sync::Arc::new(tokio::sync::Semaphore::new(
            req.concurrent_count.unwrap_or(1).clamp(1, 10),
        ));
        for (image_id, item) in queue {
            let permit = sem.clone().acquire_owned().await;
            let pool = pool.clone();
            let model = req.model.clone();
            let resolution = req.resolution.clone();
            tokio::spawn(async move {
                if permit.is_ok() {
                    let _ = make_image(&pool, req.project_id, &model, &resolution, item, image_id)
                        .await;
                }
            });
        }
    });
    Ok(Json(ApiResponse::new(json!({"total":total}))))
}
pub async fn poll_images(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<Ids>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows=sqlx::query_as::<_,(i64,String,Option<String>,Option<String>,i64)>("SELECT a.id,i.state,i.file_path,i.error_reason,i.id FROM toonflow.assets a JOIN LATERAL (SELECT id,state,file_path,error_reason FROM toonflow.images WHERE assets_id=a.id ORDER BY id DESC LIMIT 1) i ON true WHERE a.id=ANY($1)").bind(req.ids).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to poll images"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter()
            .map(|r| json!({"id":r.0,"state":r.1,"filePath":r.2,"errorReason":r.3,"imageId":r.4}))
            .collect(),
    )))
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetImageRequest {
    assets_id: i64,
}
pub async fn get_images(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<AssetImageRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:read")?;
    let asset: Option<(i64, Option<i64>)> =
        sqlx::query_as("SELECT id,image_id FROM toonflow.assets WHERE id=$1")
            .bind(req.assets_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get asset"))?;
    let asset = asset.ok_or_else(|| AppError::not_found("asset not found"))?;
    let rows=sqlx::query_as::<_,(i64,Option<String>,String)>("SELECT id,file_path,coalesce(state,'') FROM toonflow.images WHERE assets_id=$1 ORDER BY id DESC").bind(req.assets_id).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to get images"))?;
    Ok(Json(ApiResponse::new(
        json!({"id":asset.0,"imageId":asset.1,"tempAssets":rows.into_iter().map(|r|json!({"id":r.0,"filePath":r.1,"state":r.2,"selected":asset.1==Some(r.0)})).collect::<Vec<_>>()}),
    )))
}
#[derive(Deserialize)]
pub struct ImageId {
    id: i64,
}
pub async fn cancel_image(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<ImageId>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let result = sqlx::query("UPDATE toonflow.images SET state='生成失败',error_reason='用户取消生成' WHERE id=$1 AND state='生成中'")
        .bind(req.id)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to cancel image generation"))?;
    Ok(Json(ApiResponse::new(
        json!({"message":"取消成功","canceled":result.rows_affected()>0}),
    )))
}
pub async fn delete_image(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<ImageId>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let mut tx = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin transaction"))?;
    sqlx::query("UPDATE toonflow.assets SET image_id=NULL WHERE image_id=$1")
        .bind(req.id)
        .execute(&mut *tx)
        .await
        .map_err(|_| AppError::internal("failed to unbind image"))?;
    sqlx::query("DELETE FROM toonflow.images WHERE id=$1")
        .bind(req.id)
        .execute(&mut *tx)
        .await
        .map_err(|_| AppError::internal("failed to delete image"))?;
    tx.commit()
        .await
        .map_err(|_| AppError::internal("failed to commit transaction"))?;
    Ok(Json(ApiResponse::new(
        json!({"message":"资产图片删除成功"}),
    )))
}

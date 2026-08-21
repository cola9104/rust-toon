use axum::{
    Json,
    extract::{Path, State},
};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::FromRow;

#[derive(Deserialize)]
pub struct ModelListRequest {
    #[serde(rename = "type")]
    kind: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelDetailRequest {
    model_id: String,
}

pub async fn model_list(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ModelListRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:read")?;
    let kind = if request.kind == "text" {
        "chat"
    } else {
        request.kind.as_str()
    };
    let rows: Vec<(i64, String, String, String, String)> = sqlx::query_as(
        "SELECT id,name,model,type,platform FROM ai.model_configs WHERE status=0 AND ($1='all' OR type=$1) AND ($1<>'all' OR type<>'video') ORDER BY name,id",
    )
    .bind(kind)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list models"))?;
    let data = rows
        .into_iter()
        .map(|(id, label, model, kind, platform)| {
            let public_kind = if kind == "chat" { "text" } else { &kind };
            json!({"id":platform,"label":label,"value":model,"type":public_kind,"name":platform,"modelConfigId":id})
        })
        .collect::<Vec<_>>();
    Ok(Json(ApiResponse::new(json!(data))))
}

pub async fn model_detail(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ModelDetailRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:read")?;
    let numeric_id = request.model_id.parse::<i64>().ok();
    let (platform, model) = request
        .model_id
        .split_once(':')
        .map(|(platform, model)| (Some(platform), model))
        .unwrap_or((None, request.model_id.as_str()));
    let row: Option<(i64, String, String, String, String, Value)> = sqlx::query_as(
        "SELECT id,name,model,type,platform,config FROM ai.model_configs WHERE status=0 AND (($1::bigint IS NOT NULL AND id=$1) OR ($1 IS NULL AND model=$2 AND ($3::text IS NULL OR platform=$3))) ORDER BY id LIMIT 1",
    ).bind(numeric_id).bind(model).bind(platform).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to load model"))?;
    let data = row
        .map(|(id, name, model, kind, platform, config)| {
            let public_kind = if kind == "chat" { "text" } else { &kind };
            json!({"id":id,"name":name,"modelName":model,"type":public_kind,"vendorId":platform,"config":config})
        })
        .unwrap_or(Value::Null);
    Ok(Json(ApiResponse::new(data)))
}

pub async fn version() -> Json<ApiResponse<&'static str>> {
    Json(ApiResponse::new(env!("CARGO_PKG_VERSION")))
}

#[derive(Deserialize)]
pub struct ExtractStyleRequest {
    images: Vec<String>,
}

pub async fn extract_style_prompt(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ExtractStyleRequest>,
) -> Result<Json<ApiResponse<String>>, AppError> {
    require(&user, "toon:project:update")?;
    if request.images.is_empty() {
        return Err(AppError::bad_request("请至少提供一张图片"));
    }
    let content = request
        .images
        .into_iter()
        .map(|image| json!({"type":"image_url","image_url":{"url":image}}))
        .collect::<Vec<_>>();
    let raw = crate::ai_client::text_tools(
        &state.pool,
        "universalAi",
        vec![
            json!({"role":"system","content":"综合分析图片共同画风，只输出一个括号包裹的中英文画风提示词，格式：(画风：中文描述, idiomatic English style prompt)。无法识别时输出无法描述。"}),
            json!({"role":"user","content":content}),
        ],
        Vec::new(),
    )
    .await
    .map_err(AppError::bad_request)?;
    let result = raw
        .pointer("/choices/0/message/content")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .trim()
        .to_string();
    if result.is_empty() {
        return Err(AppError::bad_request("模型未返回画风提示词"));
    }
    Ok(Json(ApiResponse::new(result)))
}

use crate::{
    ToonState,
    shared::{affected, require},
};

fn next_id() -> i64 {
    chrono::Utc::now().timestamp_millis()
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct ArtStyle {
    id: i64,
    name: String,
    file_url: String,
    label: String,
    prompt: String,
    create_time: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveArtStyle {
    id: Option<i64>,
    name: String,
    #[serde(default)]
    file_url: String,
    #[serde(default)]
    label: String,
    #[serde(default)]
    prompt: String,
}

pub async fn list_art_styles(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<ArtStyle>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, ArtStyle>("SELECT id, name, file_url, label, prompt, create_time FROM toonflow.art_styles ORDER BY create_time DESC")
        .fetch_all(&state.pool).await.map_err(|_| AppError::internal("failed to list art styles"))?;
    Ok(Json(ApiResponse::new(rows)))
}

pub async fn save_art_style(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SaveArtStyle>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    sqlx::query("INSERT INTO toonflow.art_styles (id,name,file_url,label,prompt) VALUES ($1,$2,$3,$4,$5) ON CONFLICT (id) DO UPDATE SET name=excluded.name,file_url=excluded.file_url,label=excluded.label,prompt=excluded.prompt")
        .bind(request.id.unwrap_or_else(next_id)).bind(request.name).bind(request.file_url).bind(request.label).bind(request.prompt)
        .execute(&state.pool).await.map_err(|_| AppError::internal("failed to save art style"))?;
    Ok(Json(ApiResponse::new(())))
}

pub async fn delete_art_style(
    user: CurrentUser,
    State(state): State<ToonState>,
    Path(id): Path<i64>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    let result = sqlx::query("DELETE FROM toonflow.art_styles WHERE id=$1")
        .bind(id)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to delete art style"))?;
    affected(result.rows_affected(), "art style")?;
    Ok(Json(ApiResponse::new(())))
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct Task {
    id: i64,
    project_id: Option<i64>,
    project_name: Option<String>,
    task_class: String,
    related_objects: String,
    model: String,
    description: String,
    state: String,
    start_time: Option<i64>,
    reason: Option<String>,
    input: serde_json::Value,
    retry_of_id: Option<i64>,
    progress_current: Option<i32>,
    progress_total: Option<i32>,
}

pub async fn list_tasks(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<Task>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, Task>("SELECT t.id,t.project_id,p.name project_name,t.task_class,coalesce(n.chapter,t.related_objects) related_objects,coalesce(mc.name,t.model) model,t.description,t.state,t.start_time,t.reason,t.input,t.retry_of_id,t.progress_current,t.progress_total FROM toonflow.tasks t LEFT JOIN toonflow.projects p ON p.id=t.project_id LEFT JOIN toonflow.agent_deployments d ON d.key=t.model LEFT JOIN ai.model_configs mc ON mc.id=coalesce(d.model_config_id,CASE WHEN t.model ~ '^[0-9]+$' THEN t.model::bigint END) LEFT JOIN toonflow.novels n ON t.task_class='novelEvent' AND n.id::text=t.related_objects ORDER BY t.start_time DESC NULLS LAST,t.id DESC")
        .fetch_all(&state.pool).await.map_err(|_| AppError::internal("failed to list tasks"))?;
    Ok(Json(ApiResponse::new(rows)))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskQuery {
    #[serde(default = "default_page")]
    page: i64,
    #[serde(default = "default_limit")]
    limit: i64,
    task_class: Option<String>,
    state: Option<String>,
    project_id: Option<i64>,
}

fn default_page() -> i64 {
    1
}
fn default_limit() -> i64 {
    10
}

#[derive(Debug, Serialize)]
pub struct TaskPage {
    data: Vec<Task>,
    total: i64,
}

pub async fn query_tasks(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<TaskQuery>,
) -> Result<Json<ApiResponse<TaskPage>>, AppError> {
    require(&user, "toon:project:read")?;
    let page = request.page.max(1);
    let limit = request.limit.clamp(1, 100);
    let task_class = request.task_class.filter(|value| !value.is_empty());
    let task_state = request.state.filter(|value| !value.is_empty());
    let rows = sqlx::query_as::<_, Task>(
        r#"SELECT t.id,t.project_id,p.name project_name,t.task_class,
                  coalesce(n.chapter,t.related_objects) related_objects,
                  coalesce(mc.name,t.model) model,t.description,t.state,t.start_time,t.reason,t.input,t.retry_of_id,t.progress_current,t.progress_total
           FROM toonflow.tasks t
           LEFT JOIN toonflow.projects p ON p.id=t.project_id
           LEFT JOIN toonflow.agent_deployments d ON d.key=t.model
           LEFT JOIN ai.model_configs mc ON mc.id=coalesce(d.model_config_id,CASE WHEN t.model ~ '^[0-9]+$' THEN t.model::bigint END)
           LEFT JOIN toonflow.novels n ON t.task_class='novelEvent' AND n.id::text=t.related_objects
           WHERE ($1::text IS NULL OR t.task_class=$1)
             AND ($2::text IS NULL OR t.state=$2)
             AND ($3::bigint IS NULL OR t.project_id=$3)
           ORDER BY t.id DESC OFFSET $4 LIMIT $5"#,
    )
    .bind(&task_class)
    .bind(&task_state)
    .bind(request.project_id)
    .bind((page - 1) * limit)
    .bind(limit)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to query tasks"))?;
    let total: (i64,) = sqlx::query_as(
        "SELECT count(*) FROM toonflow.tasks WHERE ($1::text IS NULL OR task_class=$1) AND ($2::text IS NULL OR state=$2) AND ($3::bigint IS NULL OR project_id=$3)",
    ).bind(task_class).bind(task_state).bind(request.project_id)
     .fetch_one(&state.pool).await.map_err(|_| AppError::internal("failed to count tasks"))?;
    Ok(Json(ApiResponse::new(TaskPage {
        data: rows,
        total: total.0,
    })))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskId {
    task_id: i64,
}

pub async fn task_details(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<TaskId>,
) -> Result<Json<ApiResponse<Option<Task>>>, AppError> {
    require(&user, "toon:project:read")?;
    let row = sqlx::query_as::<_, Task>("SELECT t.id,t.project_id,p.name project_name,t.task_class,coalesce(n.chapter,t.related_objects) related_objects,coalesce(mc.name,t.model) model,t.description,t.state,t.start_time,t.reason,t.input,t.retry_of_id,t.progress_current,t.progress_total FROM toonflow.tasks t LEFT JOIN toonflow.projects p ON p.id=t.project_id LEFT JOIN toonflow.agent_deployments d ON d.key=t.model LEFT JOIN ai.model_configs mc ON mc.id=coalesce(d.model_config_id,CASE WHEN t.model ~ '^[0-9]+$' THEN t.model::bigint END) LEFT JOIN toonflow.novels n ON t.task_class='novelEvent' AND n.id::text=t.related_objects WHERE t.id=$1")
        .bind(request.task_id).fetch_optional(&state.pool).await.map_err(|_| AppError::internal("failed to get task"))?;
    Ok(Json(ApiResponse::new(row)))
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct TaskCategory {
    task_class: String,
}

pub async fn task_categories(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<TaskCategory>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, TaskCategory>(
        "SELECT DISTINCT task_class FROM toonflow.tasks WHERE task_class<>'' ORDER BY task_class",
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list task categories"))?;
    Ok(Json(ApiResponse::new(rows)))
}

#[derive(Debug, Serialize, FromRow)]
pub struct TaskProject {
    id: i64,
    name: String,
}

pub async fn task_projects(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<TaskProject>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, TaskProject>(
        "SELECT id,name FROM toonflow.projects WHERE name<>'' ORDER BY name",
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list task projects"))?;
    Ok(Json(ApiResponse::new(rows)))
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct Prompt {
    id: i64,
    name: String,
    #[serde(rename = "type")]
    type_: String,
    data: String,
    use_data: Option<String>,
    source_key: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SavePrompt {
    id: Option<i64>,
    name: String,
    #[serde(rename = "type")]
    type_: String,
    #[serde(default)]
    data: String,
    #[serde(rename = "useData")]
    use_data: Option<String>,
    #[serde(rename = "sourceKey")]
    source_key: Option<String>,
}

pub async fn list_prompts(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<Prompt>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, Prompt>(
        "SELECT id,name,type as type_,data,use_data,source_key
         FROM toonflow.prompts
         ORDER BY CASE source_key
           WHEN 'eventExtraction' THEN 0
           WHEN 'scriptAssetExtraction' THEN 1
           WHEN 'videoPromptGeneration' THEN 2
           WHEN 'audioBindPrompt' THEN 3
           ELSE 10
         END, id DESC",
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list prompts"))?;
    Ok(Json(ApiResponse::new(rows)))
}

pub async fn save_prompt(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SavePrompt>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    let source_key = request.source_key.filter(|value| !value.trim().is_empty());
    sqlx::query("INSERT INTO toonflow.prompts (id,name,type,data,use_data,source_key) VALUES (coalesce($1,nextval('toonflow.prompts_id_seq')),$2,$3,$4,$5,$6) ON CONFLICT (id) DO UPDATE SET name=excluded.name,type=excluded.type,data=excluded.data,use_data=excluded.use_data,source_key=excluded.source_key")
        .bind(request.id).bind(request.name).bind(request.type_).bind(request.data).bind(request.use_data).bind(source_key).execute(&state.pool).await.map_err(|_| AppError::internal("failed to save prompt"))?;
    Ok(Json(ApiResponse::new(())))
}

pub async fn delete_prompt(
    user: CurrentUser,
    State(state): State<ToonState>,
    Path(id): Path<i64>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    let result = sqlx::query("DELETE FROM toonflow.prompts WHERE id=$1")
        .bind(id)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to delete prompt"))?;
    affected(result.rows_affected(), "prompt")?;
    Ok(Json(ApiResponse::new(())))
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct Skill {
    id: String,
    name: String,
    description: String,
    #[serde(rename = "type")]
    type_: String,
    path: String,
    state: i32,
    create_time: i64,
    update_time: i64,
}

pub async fn list_skills(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<Skill>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, Skill>("SELECT id,name,description,type as type_,path,state,create_time,update_time FROM toonflow.skill_list ORDER BY update_time DESC").fetch_all(&state.pool).await.map_err(|_| AppError::internal("failed to list skills"))?;
    Ok(Json(ApiResponse::new(rows)))
}

pub async fn skill_paths(
    user: CurrentUser,
    State(state): State<ToonState>,
) -> Result<Json<ApiResponse<Vec<String>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows: Vec<(String,)> = sqlx::query_as("SELECT path FROM toonflow.skill_list ORDER BY path")
        .fetch_all(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to list skill paths"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter().map(|row| row.0).collect(),
    )))
}

#[derive(Debug, Deserialize)]
pub struct SkillPathRequest {
    path: String,
}
pub async fn skill_content(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SkillPathRequest>,
) -> Result<Json<ApiResponse<String>>, AppError> {
    require(&user, "toon:project:read")?;
    let content: Option<(String,)> =
        sqlx::query_as("SELECT content FROM toonflow.skill_list WHERE path=$1")
            .bind(request.path)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get skill content"))?;
    Ok(Json(ApiResponse::new(
        content.map(|row| row.0).unwrap_or_default(),
    )))
}

#[derive(Debug, Deserialize)]
pub struct SaveSkillContentRequest {
    path: String,
    content: String,
}
pub async fn save_skill_content(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SaveSkillContentRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:project:update")?;
    if request.path.contains("..")
        || request.path.starts_with('/')
        || request.path.starts_with('\\')
    {
        return Err(AppError::bad_request("无效的路径"));
    }
    let result =
        sqlx::query("UPDATE toonflow.skill_list SET content=$2,update_time=$3 WHERE path=$1")
            .bind(request.path)
            .bind(request.content)
            .bind(chrono::Utc::now().timestamp_millis())
            .execute(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to save skill content"))?;
    affected(result.rows_affected(), "skill")?;
    Ok(Json(ApiResponse::new(())))
}

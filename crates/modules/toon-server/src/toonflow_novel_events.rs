use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::{FromRow, PgPool};

use crate::{ToonState, ai_client, shared::require};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GenerateRequest {
    project_id: i64,
    novel_ids: Vec<i64>,
    concurrent_count: Option<usize>,
}
pub async fn generate(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<GenerateRequest>,
) -> Result<Json<ApiResponse<&'static str>>, AppError> {
    require(&user, "toon:episode:update")?;
    if req.novel_ids.is_empty() {
        return Err(AppError::bad_request("没有对应章节"));
    }
    sqlx::query("UPDATE toonflow.novels SET event_state=0,event=NULL,error_reason=NULL WHERE project_id=$1 AND id=ANY($2)").bind(req.project_id).bind(&req.novel_ids).execute(&state.pool).await.map_err(|_|AppError::internal("failed to reset novel event state"))?;
    let pool = state.pool.clone();
    let project_id = req.project_id;
    let ids = req.novel_ids;
    let concurrency = req.concurrent_count.unwrap_or(5).clamp(1, 20);
    tokio::spawn(async move {
        let semaphore = std::sync::Arc::new(tokio::sync::Semaphore::new(concurrency));
        let mut jobs = Vec::new();
        for id in ids {
            let pool = pool.clone();
            let permit = semaphore.clone().acquire_owned().await;
            jobs.push(tokio::spawn(async move {
                if permit.is_ok() {
                    process_chapter(&pool, project_id, id).await;
                }
            }));
        }
        for job in jobs {
            let _ = job.await;
        }
    });
    Ok(Json(ApiResponse::new("生成事件成功")))
}

async fn process_chapter(pool: &PgPool, project_id: i64, id: i64) {
    let chapter: Option<(String, String)> = sqlx::query_as(
        "SELECT chapter,chapter_data FROM toonflow.novels WHERE id=$1 AND project_id=$2",
    )
    .bind(id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten();
    let Some((title, content)) = chapter else {
        return;
    };
    let task_id = chrono::Utc::now().timestamp_millis() + id % 1000;
    let _=sqlx::query("INSERT INTO toonflow.tasks(id,project_id,task_class,related_objects,model,description,state,start_time) VALUES($1,$2,'novelEvent',$3,'universalAi',$4,'running',$5) ON CONFLICT(id) DO NOTHING").bind(task_id).bind(project_id).bind(id.to_string()).bind(format!("提取事件：{title}")).bind(chrono::Utc::now().timestamp_millis()).execute(pool).await;
    let system = "你是小说事件分析器。将章节拆成关键事件，只输出 JSON 数组，每项格式为 {\"name\":\"事件名称\",\"detail\":\"事件详情\"}，禁止输出 Markdown。";
    match ai_client::text(
        pool,
        "universalAi",
        system,
        &format!("章节：{title}\n\n{content}"),
    )
    .await
    {
        Ok(raw) => {
            if let Err(reason) = save_events(pool, id, &raw).await {
                fail(pool, id, task_id, &reason).await
            } else {
                let _ = sqlx::query("UPDATE toonflow.tasks SET state='success' WHERE id=$1")
                    .bind(task_id)
                    .execute(pool)
                    .await;
            }
        }
        Err(reason) => fail(pool, id, task_id, &reason).await,
    }
}
async fn save_events(pool: &PgPool, novel_id: i64, raw: &str) -> Result<(), String> {
    let cleaned = raw
        .trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim();
    let events: Vec<Value> =
        serde_json::from_str(cleaned).map_err(|e| format!("事件 JSON 解析失败: {e}"))?;
    let mut tx = pool.begin().await.map_err(|e| e.to_string())?;
    sqlx::query("DELETE FROM toonflow.event_chapters WHERE novel_id=$1")
        .bind(novel_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| e.to_string())?;
    for (index, event) in events.iter().enumerate() {
        let name = event
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or("未命名事件");
        let detail = event.get("detail").and_then(Value::as_str).unwrap_or("");
        let event_id = chrono::Utc::now().timestamp_millis() + index as i64;
        sqlx::query("INSERT INTO toonflow.events(id,name,detail,create_time) VALUES($1,$2,$3,$4)")
            .bind(event_id)
            .bind(name)
            .bind(detail)
            .bind(chrono::Utc::now().timestamp_millis())
            .execute(&mut *tx)
            .await
            .map_err(|e| e.to_string())?;
        sqlx::query("INSERT INTO toonflow.event_chapters(event_id,novel_id) VALUES($1,$2)")
            .bind(event_id)
            .bind(novel_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| e.to_string())?;
    }
    sqlx::query("UPDATE toonflow.novels SET event=$2,event_state=1,error_reason=NULL WHERE id=$1")
        .bind(novel_id)
        .bind(raw)
        .execute(&mut *tx)
        .await
        .map_err(|e| e.to_string())?;
    tx.commit().await.map_err(|e| e.to_string())?;
    Ok(())
}
async fn fail(pool: &PgPool, id: i64, task_id: i64, reason: &str) {
    let _ = sqlx::query("UPDATE toonflow.novels SET event_state=-1,error_reason=$2 WHERE id=$1")
        .bind(id)
        .bind(reason)
        .execute(pool)
        .await;
    let _ = sqlx::query("UPDATE toonflow.tasks SET state='failed',reason=$2 WHERE id=$1")
        .bind(task_id)
        .bind(reason)
        .execute(pool)
        .await;
}

#[derive(Deserialize)]
pub struct StatesRequest {
    ids: Vec<i64>,
}
pub async fn states(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<StatesRequest>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "toon:episode:read")?;
    let rows=sqlx::query_as::<_,(i64,Option<String>,i32,Option<String>)>("SELECT id,event,event_state,error_reason FROM toonflow.novels WHERE id=ANY($1) AND event_state<>0").bind(req.ids).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to list event states"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter()
            .map(|r| json!({"id":r.0,"event":r.1,"eventState":r.2,"errorReason":r.3}))
            .collect(),
    )))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListRequest {
    project_id: i64,
    page: i64,
    limit: i64,
    search: Option<String>,
}
#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct EventRow {
    id: i64,
    event_name: String,
    detail: String,
    create_time: i64,
    chapters: Vec<i32>,
}
pub async fn list(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<ListRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:episode:read")?;
    let search = req.search.filter(|s| !s.is_empty());
    let total:(i64,)=sqlx::query_as("SELECT count(DISTINCT e.id) FROM toonflow.events e JOIN toonflow.event_chapters ec ON ec.event_id=e.id JOIN toonflow.novels n ON n.id=ec.novel_id WHERE n.project_id=$1 AND ($2::text IS NULL OR e.name ILIKE '%'||$2||'%')").bind(req.project_id).bind(&search).fetch_one(&state.pool).await.map_err(|_|AppError::internal("failed to count events"))?;
    let rows=sqlx::query_as::<_,EventRow>("SELECT e.id,e.name event_name,e.detail,e.create_time,array_agg(n.chapter_index ORDER BY n.chapter_index)::int4[] chapters FROM toonflow.events e JOIN toonflow.event_chapters ec ON ec.event_id=e.id JOIN toonflow.novels n ON n.id=ec.novel_id WHERE n.project_id=$1 AND ($2::text IS NULL OR e.name ILIKE '%'||$2||'%') GROUP BY e.id ORDER BY e.id DESC OFFSET $3 LIMIT $4").bind(req.project_id).bind(search).bind((req.page.max(1)-1)*req.limit.clamp(1,100)).bind(req.limit.clamp(1,100)).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to list events"))?;
    Ok(Json(ApiResponse::new(json!({"list":rows,"total":total.0}))))
}

#[derive(Deserialize)]
pub struct DeleteRequest {
    id: i64,
}
#[derive(Deserialize)]
pub struct BatchDeleteRequest {
    ids: Vec<i64>,
}
pub async fn delete(
    user: CurrentUser,
    state: State<ToonState>,
    Json(req): Json<DeleteRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    batch_delete(user, state, Json(BatchDeleteRequest { ids: vec![req.id] })).await
}
pub async fn batch_delete(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(req): Json<BatchDeleteRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    require(&user, "toon:episode:delete")?;
    sqlx::query("DELETE FROM toonflow.events WHERE id=ANY($1)")
        .bind(req.ids)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to delete events"))?;
    Ok(Json(ApiResponse::new(())))
}

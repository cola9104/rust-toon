use crate::{ToonState, ai_client, shared::require, toonflow_agent_tools};
use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::FromRow;
use std::{
    collections::HashMap,
    sync::{LazyLock, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};

static ACTIVE_RUNS: LazyLock<Mutex<HashMap<i64, tokio::task::AbortHandle>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
fn next_id(offset: i64) -> i64 {
    now_ms() * 1000 + offset
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatRequest {
    agent_type: String,
    isolation_key: String,
    project_id: i64,
    script_id: Option<i64>,
    content: String,
    #[serde(default)]
    think: bool,
    #[serde(default)]
    think_level: i32,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionRequest {
    agent_type: String,
    isolation_key: String,
}
#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct MemoryRow {
    id: i64,
    role: String,
    content: String,
    memory_type: String,
    create_time: i64,
}
#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct RunRow {
    id: i64,
    agent_type: String,
    isolation_key: String,
    project_id: i64,
    script_id: Option<i64>,
    input: String,
    output: Option<String>,
    state: String,
    error_reason: Option<String>,
    think: bool,
    think_level: i32,
    start_time: i64,
    finish_time: Option<i64>,
}

#[derive(Deserialize)]
pub struct RunIdRequest {
    id: i64,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EventRequest {
    run_id: i64,
    #[serde(default)]
    after_id: i64,
}
#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct RunEvent {
    id: i64,
    run_id: i64,
    event_type: String,
    data: Value,
    create_time: i64,
}

fn validate_agent(value: &str) -> Result<&'static str, AppError> {
    match value {
        "scriptAgent" => Ok("scriptAgent:decisionAgent"),
        "productionAgent" => Ok("productionAgent:decisionAgent"),
        _ => Err(AppError::bad_request(
            "agentType 仅支持 scriptAgent 或 productionAgent",
        )),
    }
}

async fn project_context(state: &ToonState, request: &ChatRequest) -> Result<String, AppError> {
    let project: Option<(String,String,String,String,String,Option<i64>,Option<i64>)> = sqlx::query_as("SELECT name,type,intro,art_style,video_ratio,image_model,video_model FROM toonflow.projects WHERE id=$1")
        .bind(request.project_id).fetch_optional(&state.pool).await.map_err(|_| AppError::internal("failed to load agent project"))?;
    let (name, kind, intro, style, ratio, image_model, video_model) =
        project.ok_or_else(|| AppError::not_found("project not found"))?;
    if request.agent_type == "scriptAgent" {
        let chapters: i64 =
            sqlx::query_scalar("SELECT count(*) FROM toonflow.novels WHERE project_id=$1")
                .bind(request.project_id)
                .fetch_one(&state.pool)
                .await
                .unwrap_or(0);
        Ok(format!(
            "## 项目信息\n小说名称：{name}\n小说类型：{kind}\n小说简介：{intro}\n视觉风格：{style}\n视频画幅：{ratio}\n章节数量：{chapters}章"
        ))
    } else {
        let script = if let Some(id) = request.script_id {
            sqlx::query_as::<_, (String, String)>(
                "SELECT name,content FROM toonflow.scripts WHERE id=$1 AND project_id=$2",
            )
            .bind(id)
            .bind(request.project_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to load agent script"))?
        } else {
            None
        };
        let script_context = script
            .map(|(n, c)| format!("\n当前剧本：{n}\n剧本内容：{c}"))
            .unwrap_or_default();
        Ok(format!(
            "## 生产上下文\n项目：{name}\n图像模型 ID：{}\n视频模型 ID：{}\n视频画幅：{ratio}{script_context}",
            image_model
                .map(|x| x.to_string())
                .unwrap_or_else(|| "未配置".into()),
            video_model
                .map(|x| x.to_string())
                .unwrap_or_else(|| "未配置".into())
        ))
    }
}

async fn memory_context(state: &ToonState, request: &ChatRequest) -> Result<String, AppError> {
    let summaries:Vec<String>=sqlx::query_scalar("SELECT content FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='summary' ORDER BY create_time DESC LIMIT 5").bind(&request.agent_type).bind(&request.isolation_key).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to load agent memory"))?;
    let messages:Vec<(String,String)>=sqlx::query_as("SELECT role,content FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='message' ORDER BY create_time DESC LIMIT 8").bind(&request.agent_type).bind(&request.isolation_key).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to load agent memory"))?;
    let recent = messages
        .into_iter()
        .rev()
        .map(|(r, c)| format!("{r}: {c}"))
        .collect::<Vec<_>>()
        .join("\n");
    Ok(format!(
        "## Memory\n以下是内部记忆，不要主动说明记忆机制。\n历史摘要：\n{}\n近期对话：\n{recent}",
        summaries.into_iter().rev().collect::<Vec<_>>().join("\n")
    ))
}

async fn add_memory(
    state: &ToonState,
    agent: &str,
    isolation: &str,
    role: &str,
    content: &str,
) -> Result<i64, AppError> {
    let id = next_id(if role == "user" { 1 } else { 2 });
    sqlx::query("INSERT INTO toonflow.agent_memories(id,agent_type,isolation_key,role,content,create_time) VALUES($1,$2,$3,$4,$5,$6)").bind(id).bind(agent).bind(isolation).bind(role).bind(content).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to save agent memory"))?;
    Ok(id)
}

async fn summarize_if_needed(state: &ToonState, request: &ChatRequest, agent_key: &str) {
    let rows:Vec<(i64,String,String)>=sqlx::query_as("SELECT id,role,content FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='message' AND summarized=false ORDER BY create_time LIMIT 6").bind(&request.agent_type).bind(&request.isolation_key).fetch_all(&state.pool).await.unwrap_or_default();
    if rows.len() < 6 {
        return;
    }
    let source = rows
        .iter()
        .map(|(_, r, c)| format!("{r}: {c}"))
        .collect::<Vec<_>>()
        .join("\n");
    let Ok(summary) = ai_client::text(
        &state.pool,
        agent_key,
        "将对话压缩为500字以内的事实摘要，只输出摘要。",
        &source,
    )
    .await
    else {
        return;
    };
    let ids = rows.iter().map(|(id, _, _)| *id).collect::<Vec<_>>();
    let Ok(mut tx) = state.pool.begin().await else {
        return;
    };
    if sqlx::query("INSERT INTO toonflow.agent_memories(id,agent_type,isolation_key,role,content,memory_type,related_message_ids,create_time) VALUES($1,$2,$3,'system',$4,'summary',$5,$6)").bind(next_id(3)).bind(&request.agent_type).bind(&request.isolation_key).bind(summary).bind(json!(ids)).bind(now_ms()).execute(&mut *tx).await.is_err(){return}
    let _ = sqlx::query("UPDATE toonflow.agent_memories SET summarized=true WHERE id=ANY($1)")
        .bind(&ids)
        .execute(&mut *tx)
        .await;
    let _ = tx.commit().await;
}

fn tool_guide(agent_type: &str) -> &'static str {
    if agent_type == "scriptAgent" {
        r#"可用工具：get_novel_events({chapterIndexs}), get_novel_text({chapterIndex}), get_script_content({ids}), run_sub_agent_storySkeleton({prompt}), run_sub_agent_adaptationStrategy({prompt}), run_sub_agent_script({prompt}), run_supervision_agent({prompt})。
需要调用工具时，仅输出一个或多个如下标签，不要编造结果：
<tool_call>{"name":"工具名","arguments":{}}</tool_call>"#
    } else {
        r#"可用工具：get_flowData({key}), set_flowData({key,value}), add_deriveAsset({assetsId,id,name,desc}), del_deriveAsset({id}), generate_deriveAsset({ids,concurrentCount}), add_flowData_storyboard({videoDesc,prompt,track,duration,associateAssetsIds,shouldGenerateImage}), update_storyboard({id,...}), generate_storyboard({ids,concurrentCount}), delete_storyboard({ids}), run_sub_agent_derive_assets({prompt}), run_sub_agent_generate_assets({prompt}), run_sub_agent_director_plan({prompt}), run_sub_agent_storyboard_gen({prompt}), run_sub_agent_storyboard_panel({prompt}), run_sub_agent_storyboard_table({prompt}), run_sub_agent_supervision({prompt})。
需要调用工具时，仅输出一个或多个如下标签，不要编造结果：
<tool_call>{"name":"工具名","arguments":{}}</tool_call>"#
    }
}

fn parse_tool_calls(text: &str) -> Vec<(String, Value)> {
    let mut calls = Vec::new();
    let mut rest = text;
    while let Some(start) = rest.find("<tool_call>") {
        let content = &rest[start + 11..];
        let Some(end) = content.find("</tool_call>") else {
            break;
        };
        if let Ok(value) = serde_json::from_str::<Value>(&content[..end]) {
            if let Some(name) = value.get("name").and_then(Value::as_str) {
                calls.push((
                    name.to_string(),
                    value.get("arguments").cloned().unwrap_or_else(|| json!({})),
                ));
            }
        }
        rest = &content[end + 12..];
    }
    calls
}

async fn run_with_tools(
    state: &ToonState,
    request: &ChatRequest,
    agent_key: &str,
    system: &str,
    run_id: i64,
) -> Result<String, String> {
    let mut prompt = request.content.clone();
    for _ in 0..4 {
        let event_pool = state.pool.clone();
        let output = ai_client::text_stream(
            &state.pool,
            agent_key,
            &format!("{system}\n\n{}", tool_guide(&request.agent_type)),
            &prompt,
            move |delta| { let pool=event_pool.clone(); async move { sqlx::query("INSERT INTO toonflow.agent_run_events(run_id,event_type,data,create_time)VALUES($1,'delta',$2,$3)").bind(run_id).bind(json!({"text":delta})).bind(now_ms()).execute(&pool).await.map_err(|error|error.to_string())?;Ok(()) } },
        )
        .await?;
        let calls = parse_tool_calls(&output);
        if calls.is_empty() {
            return Ok(output);
        }
        let mut results = Vec::new();
        for (name, arguments) in calls {
            let tool_request = toonflow_agent_tools::ToolRequest {
                agent_type: request.agent_type.clone(),
                project_id: request.project_id,
                script_id: request.script_id,
                tool_name: name.clone(),
                arguments,
            };
            match toonflow_agent_tools::execute_recorded(state, &tool_request).await {
                Ok((call_id, value)) => results
                    .push(json!({"callId":call_id,"tool":name,"success":true,"result":value})),
                Err(error) => {
                    results.push(json!({"tool":name,"success":false,"error":format!("{error:?}")}))
                }
            }
        }
        prompt = format!(
            "用户任务：{}\n工具执行结果：{}\n请根据结果继续；如无需其他工具，直接给出最终答复。",
            request.content,
            serde_json::to_string_pretty(&results).unwrap_or_default()
        );
    }
    Err("Agent 工具调用超过最大轮数".to_string())
}

async fn create_run(state: &ToonState, request: &ChatRequest) -> Result<i64, AppError> {
    validate_agent(&request.agent_type)?;
    if request.isolation_key.trim().is_empty() || request.content.trim().is_empty() {
        return Err(AppError::bad_request("isolationKey 和 content 不能为空"));
    }
    let run_id = next_id(0);
    sqlx::query("INSERT INTO toonflow.agent_runs(id,agent_type,isolation_key,project_id,script_id,input,state,think,think_level,start_time) VALUES($1,$2,$3,$4,$5,$6,'running',$7,$8,$9)").bind(run_id).bind(&request.agent_type).bind(&request.isolation_key).bind(request.project_id).bind(request.script_id).bind(&request.content).bind(request.think).bind(request.think_level.clamp(0,3)).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to start agent run"))?;
    Ok(run_id)
}

async fn perform_run(
    state: &ToonState,
    request: &ChatRequest,
    run_id: i64,
) -> Result<String, String> {
    let agent_key = validate_agent(&request.agent_type).map_err(|error| format!("{error:?}"))?;
    add_memory(
        state,
        &request.agent_type,
        &request.isolation_key,
        "user",
        &request.content,
    )
    .await
    .map_err(|error| format!("{error:?}"))?;
    let context = project_context(state, request)
        .await
        .map_err(|error| format!("{error:?}"))?;
    let memory = memory_context(state, request)
        .await
        .map_err(|error| format!("{error:?}"))?;
    let system = format!(
        "你是 Toonflow 的{}。根据上下文统筹任务，给出明确、可执行的结果。\n{context}\n{memory}",
        if request.agent_type == "scriptAgent" {
            "剧本 Agent"
        } else {
            "生产 Agent"
        }
    );
    match run_with_tools(state, request, agent_key, &system, run_id).await {
        Ok(output) => {
            add_memory(
                state,
                &request.agent_type,
                &request.isolation_key,
                "assistant",
                &output,
            )
            .await
            .map_err(|error| format!("{error:?}"))?;
            sqlx::query("UPDATE toonflow.agent_runs SET output=$2,state='success',finish_time=$3 WHERE id=$1 AND state='running'").bind(run_id).bind(&output).bind(now_ms()).execute(&state.pool).await.map_err(|error|error.to_string())?;
            summarize_if_needed(state, request, agent_key).await;
            Ok(output)
        }
        Err(error) => {
            sqlx::query("UPDATE toonflow.agent_runs SET state='failed',error_reason=$2,finish_time=$3 WHERE id=$1 AND state='running'").bind(run_id).bind(&error).bind(now_ms()).execute(&state.pool).await.ok();
            Err(error)
        }
    }
}

pub async fn chat(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ChatRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    recover_stale(&state).await;
    let run_id = create_run(&state, &request).await?;
    let output = perform_run(&state, &request, run_id)
        .await
        .map_err(AppError::bad_request)?;
    Ok(Json(ApiResponse::new(
        json!({"id":run_id,"state":"success","content":output}),
    )))
}

pub async fn start(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ChatRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    recover_stale(&state).await;
    let run_id = create_run(&state, &request).await?;
    let task_state = state.clone();
    let handle = tokio::spawn(async move {
        let _ = perform_run(&task_state, &request, run_id).await;
        ACTIVE_RUNS
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&run_id);
    });
    ACTIVE_RUNS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .insert(run_id, handle.abort_handle());
    Ok(Json(ApiResponse::new(
        json!({"id":run_id,"state":"running"}),
    )))
}

pub async fn run_state(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<RunIdRequest>,
) -> Result<Json<ApiResponse<RunRow>>, AppError> {
    require(&user, "toon:project:read")?;
    let row=sqlx::query_as("SELECT id,agent_type,isolation_key,project_id,script_id,input,output,state,error_reason,think,think_level,start_time,finish_time FROM toonflow.agent_runs WHERE id=$1").bind(request.id).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to get agent run"))?.ok_or_else(||AppError::not_found("agent run not found"))?;
    Ok(Json(ApiResponse::new(row)))
}

pub async fn stop(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<RunIdRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    if let Some(handle) = ACTIVE_RUNS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .remove(&request.id)
    {
        handle.abort();
    }
    let result=sqlx::query("UPDATE toonflow.agent_runs SET state='canceled',error_reason='用户已中止',finish_time=$2 WHERE id=$1 AND state='running'").bind(request.id).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to stop agent run"))?;
    if result.rows_affected() == 0 {
        return Err(AppError::bad_request("运行已结束或不存在"));
    }
    Ok(Json(ApiResponse::new(
        json!({"id":request.id,"state":"canceled"}),
    )))
}

pub async fn events(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<EventRequest>,
) -> Result<Json<ApiResponse<Vec<RunEvent>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows=sqlx::query_as("SELECT id,run_id,event_type,data,create_time FROM toonflow.agent_run_events WHERE run_id=$1 AND id>$2 ORDER BY id LIMIT 500").bind(request.run_id).bind(request.after_id).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to get agent events"))?;
    Ok(Json(ApiResponse::new(rows)))
}

async fn recover_stale(state: &ToonState) {
    let active = ACTIVE_RUNS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .keys()
        .copied()
        .collect::<Vec<_>>();
    let _=sqlx::query("UPDATE toonflow.agent_runs SET state='interrupted',error_reason='服务重启导致任务中断',finish_time=$1 WHERE state='running' AND NOT(id=ANY($2))").bind(now_ms()).bind(active).execute(&state.pool).await;
}

pub async fn retry(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(source): Json<RunIdRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    recover_stale(&state).await;
    let row:Option<(String,String,i64,Option<i64>,String,bool,i32)>=sqlx::query_as("SELECT agent_type,isolation_key,project_id,script_id,input,think,think_level FROM toonflow.agent_runs WHERE id=$1 AND state IN('failed','canceled','interrupted')").bind(source.id).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to load retry run"))?;
    let (agent_type, isolation_key, project_id, script_id, content, think, think_level) =
        row.ok_or_else(|| AppError::bad_request("仅失败、中止或中断的运行可重试"))?;
    let request = ChatRequest {
        agent_type,
        isolation_key,
        project_id,
        script_id,
        content,
        think,
        think_level,
    };
    let run_id = create_run(&state, &request).await?;
    let task_state = state.clone();
    let handle = tokio::spawn(async move {
        let _ = perform_run(&task_state, &request, run_id).await;
        ACTIVE_RUNS
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&run_id);
    });
    ACTIVE_RUNS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .insert(run_id, handle.abort_handle());
    Ok(Json(ApiResponse::new(
        json!({"id":run_id,"state":"running","retryOf":source.id}),
    )))
}

pub async fn memories(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SessionRequest>,
) -> Result<Json<ApiResponse<Vec<MemoryRow>>>, AppError> {
    require(&user, "toon:project:read")?;
    validate_agent(&request.agent_type)?;
    let rows=sqlx::query_as("SELECT id,role,content,memory_type,create_time FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 ORDER BY create_time").bind(request.agent_type).bind(request.isolation_key).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to list memories"))?;
    Ok(Json(ApiResponse::new(rows)))
}
pub async fn runs(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SessionRequest>,
) -> Result<Json<ApiResponse<Vec<RunRow>>>, AppError> {
    require(&user, "toon:project:read")?;
    validate_agent(&request.agent_type)?;
    let rows=sqlx::query_as("SELECT id,agent_type,isolation_key,project_id,script_id,input,output,state,error_reason,think,think_level,start_time,finish_time FROM toonflow.agent_runs WHERE agent_type=$1 AND isolation_key=$2 ORDER BY start_time DESC LIMIT 50").bind(request.agent_type).bind(request.isolation_key).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to list agent runs"))?;
    Ok(Json(ApiResponse::new(rows)))
}
pub async fn clear(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SessionRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    validate_agent(&request.agent_type)?;
    sqlx::query("DELETE FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2")
        .bind(request.agent_type)
        .bind(request.isolation_key)
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to clear memories"))?;
    Ok(Json(ApiResponse::new(json!(true))))
}

#[cfg(test)]
mod tests {
    use super::parse_tool_calls;

    #[test]
    fn parses_multiple_tool_calls() {
        let calls = parse_tool_calls(
            r#"<tool_call>{"name":"get_flowData","arguments":{"key":"scriptPlan"}}</tool_call><tool_call>{"name":"generate_storyboard","arguments":{"ids":[1,2]}}</tool_call>"#,
        );
        assert_eq!(calls.len(), 2);
        assert_eq!(calls[0].0, "get_flowData");
        assert_eq!(calls[1].1["ids"], serde_json::json!([1, 2]));
    }

    #[test]
    fn ignores_invalid_tool_payload() {
        assert!(parse_tool_calls("<tool_call>not-json</tool_call>").is_empty());
    }
}

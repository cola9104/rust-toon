use crate::{ToonState, ai_client, shared::require, toonflow_asset_ai, toonflow_image_workflow};
use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::Deserialize;
use serde_json::{Value, json};
use std::time::{SystemTime, UNIX_EPOCH};

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

fn tagged(text: &str, tag: &str) -> Option<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let start = text.find(&open)? + open.len();
    let end = text[start..].find(&close)? + start;
    Some(text[start..end].trim().to_string())
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectAgentRequest {
    project_id: i64,
    agent_type: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SavePlanRequest {
    project_id: i64,
    agent_type: String,
    data: Value,
}

#[derive(Deserialize)]
pub struct UpdatePlanRequest {
    id: i64,
    data: Value,
}

fn validate_script_agent(agent: &str) -> Result<(), AppError> {
    if agent == "scriptAgent" {
        Ok(())
    } else {
        Err(AppError::bad_request("agentType 必须是 scriptAgent"))
    }
}

async fn scripts(pool: &sqlx::PgPool, project_id: i64) -> Result<Value, AppError> {
    let rows: Vec<(i64, String, String)> = sqlx::query_as(
        "SELECT id,name,content FROM toonflow.scripts WHERE project_id=$1 ORDER BY create_time,id",
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to load scripts"))?;
    Ok(json!(
        rows.into_iter()
            .map(|(id, name, content)| json!({"id":id,"name":name,"content":content}))
            .collect::<Vec<_>>()
    ))
}

pub async fn get_plan(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ProjectAgentRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:read")?;
    validate_script_agent(&request.agent_type)?;
    let row:Option<(i64,Value)>=sqlx::query_as("SELECT id,data FROM toonflow.agent_work_data WHERE project_id=$1 AND episodes_id IS NULL AND key=$2").bind(request.project_id).bind(&request.agent_type).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to load plan data"))?;
    let (id, mut data) = if let Some(row) = row {
        row
    } else {
        let id: i64=sqlx::query_scalar("INSERT INTO toonflow.agent_work_data(project_id,episodes_id,key,data,create_time,update_time)VALUES($1,NULL,$2,$3,$4,$4) RETURNING id").bind(request.project_id).bind(&request.agent_type).bind(json!({"storySkeleton":"","adaptationStrategy":""})).bind(now_ms()).fetch_one(&state.pool).await.map_err(|_|AppError::internal("failed to create plan data"))?;
        (id, json!({"storySkeleton":"","adaptationStrategy":""}))
    };
    data["script"] = scripts(&state.pool, request.project_id).await?;
    Ok(Json(ApiResponse::new(json!({"id":id,"data":data}))))
}

pub async fn set_plan(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<SavePlanRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    validate_script_agent(&request.agent_type)?;
    let skeleton = request
        .data
        .get("storySkeleton")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let strategy = request
        .data
        .get("adaptationStrategy")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let id:i64=sqlx::query_scalar("INSERT INTO toonflow.agent_work_data(project_id,episodes_id,key,data,create_time,update_time)VALUES($1,NULL,$2,$3,$4,$4) ON CONFLICT(project_id,key) WHERE episodes_id IS NULL DO UPDATE SET data=excluded.data,update_time=excluded.update_time RETURNING id").bind(request.project_id).bind(&request.agent_type).bind(json!({"storySkeleton":skeleton,"adaptationStrategy":strategy})).bind(now_ms()).fetch_one(&state.pool).await.map_err(|_|AppError::internal("failed to save plan data"))?;
    if let Some(items) = request.data.get("script").and_then(Value::as_array) {
        for (index, item) in items.iter().enumerate() {
            let name = item
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("未命名剧本");
            let content = item
                .get("content")
                .and_then(Value::as_str)
                .unwrap_or_default();
            let script_id = now_ms() * 1000 + index as i64;
            sqlx::query("INSERT INTO toonflow.scripts(id,name,content,project_id,create_time)VALUES($1,$2,$3,$4,$5) ON CONFLICT(id) DO UPDATE SET name=excluded.name,content=excluded.content").bind(item.get("id").and_then(Value::as_i64).unwrap_or(script_id)).bind(name).bind(content).bind(request.project_id).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to save agent script"))?;
        }
    }
    Ok(Json(ApiResponse::new(json!({"id":id}))))
}

pub async fn update_plan(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<UpdatePlanRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let row: Option<(i64, String)> =
        sqlx::query_as("SELECT project_id,key FROM toonflow.agent_work_data WHERE id=$1")
            .bind(request.id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to load plan data"))?;
    let (project_id, key) = row.ok_or_else(|| AppError::not_found("plan data not found"))?;
    validate_script_agent(&key)?;
    sqlx::query("UPDATE toonflow.agent_work_data SET data=$2,update_time=$3 WHERE id=$1")
        .bind(request.id)
        .bind(&request.data)
        .bind(now_ms())
        .execute(&state.pool)
        .await
        .map_err(|_| AppError::internal("failed to update plan data"))?;
    if let Some(items) = request.data.get("script").and_then(Value::as_array) {
        for item in items {
            if let (Some(id), Some(content)) = (
                item.get("id").and_then(Value::as_i64),
                item.get("content").and_then(Value::as_str),
            ) {
                sqlx::query("UPDATE toonflow.scripts SET content=$3 WHERE id=$1 AND project_id=$2")
                    .bind(id)
                    .bind(project_id)
                    .bind(content)
                    .execute(&state.pool)
                    .await
                    .map_err(|_| AppError::internal("failed to update script"))?;
            }
        }
    }
    Ok(Json(ApiResponse::new(json!(true))))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ToolRequest {
    pub(crate) agent_type: String,
    pub(crate) project_id: i64,
    pub(crate) script_id: Option<i64>,
    pub(crate) tool_name: String,
    #[serde(default)]
    pub(crate) arguments: Value,
}

pub async fn execute(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ToolRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    let (call_id, value) = execute_recorded(&state, &request).await?;
    Ok(Json(ApiResponse::new(
        json!({"callId":call_id,"result":value}),
    )))
}

pub(crate) async fn execute_recorded(
    state: &ToonState,
    request: &ToolRequest,
) -> Result<(i64, Value), AppError> {
    let call_id = now_ms() * 1000;
    sqlx::query("INSERT INTO toonflow.agent_tool_calls(id,agent_type,tool_name,arguments,state,create_time)VALUES($1,$2,$3,$4,'running',$5)").bind(call_id).bind(&request.agent_type).bind(&request.tool_name).bind(&request.arguments).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to start tool call"))?;
    match execute_inner(state, request).await {
        Ok(value) => {
            sqlx::query("UPDATE toonflow.agent_tool_calls SET result=$2,state='success',finish_time=$3 WHERE id=$1").bind(call_id).bind(&value).bind(now_ms()).execute(&state.pool).await.ok();
            Ok((call_id, value))
        }
        Err(error) => {
            sqlx::query("UPDATE toonflow.agent_tool_calls SET state='failed',error_reason=$2,finish_time=$3 WHERE id=$1").bind(call_id).bind(format!("{error:?}")).bind(now_ms()).execute(&state.pool).await.ok();
            Err(error)
        }
    }
}

pub(crate) async fn execute_inner(
    state: &ToonState,
    request: &ToolRequest,
) -> Result<Value, AppError> {
    match (request.agent_type.as_str(), request.tool_name.as_str()) {
        ("scriptAgent", "get_novel_events") => {
            let indexes = request
                .arguments
                .get("chapterIndexs")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|v| v.as_i64())
                .collect::<Vec<_>>();
            let rows:Vec<(i32,String,Option<String>)>=sqlx::query_as("SELECT chapter_index,chapter,event FROM toonflow.novels WHERE project_id=$1 AND chapter_index=ANY($2) ORDER BY chapter_index").bind(request.project_id).bind(indexes.iter().map(|v|*v as i32).collect::<Vec<_>>()).fetch_all(&state.pool).await.map_err(|_|AppError::internal("failed to get novel events"))?;
            Ok(json!(
                rows.into_iter()
                    .map(|(i, c, e)| format!("第{i}章，标题:{c}，事件:{}", e.unwrap_or_default()))
                    .collect::<Vec<_>>()
                    .join("\n")
            ))
        }
        ("scriptAgent", "get_novel_text") => {
            let index = request
                .arguments
                .get("chapterIndex")
                .and_then(|v| v.as_i64().or_else(|| v.as_str()?.parse().ok()))
                .ok_or_else(|| AppError::bad_request("缺少 chapterIndex"))?;
            let text: Option<String> = sqlx::query_scalar(
                "SELECT chapter_data FROM toonflow.novels WHERE project_id=$1 AND chapter_index=$2",
            )
            .bind(request.project_id)
            .bind(index as i32)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get novel text"))?;
            Ok(json!(text.unwrap_or_default()))
        }
        ("scriptAgent", "get_script_content") => {
            let ids = request
                .arguments
                .get("ids")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|v| v.as_i64().or_else(|| v.as_str()?.parse().ok()))
                .collect::<Vec<_>>();
            let rows: Vec<(String, String)> = sqlx::query_as(
                "SELECT name,content FROM toonflow.scripts WHERE project_id=$1 AND id=ANY($2)",
            )
            .bind(request.project_id)
            .bind(ids)
            .fetch_all(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get scripts"))?;
            Ok(json!(
                rows.into_iter()
                    .map(|(n, c)| format!("<scriptItem name=\"{n}\">{c}</scriptItem>"))
                    .collect::<Vec<_>>()
                    .join("\n")
            ))
        }
        ("scriptAgent", name)
            if name.starts_with("run_sub_agent_") || name == "run_supervision_agent" =>
        {
            let (agent_key, label, tag) = match name {
                "run_sub_agent_storySkeleton" => (
                    "scriptAgent:storySkeletonAgent",
                    "故事骨架",
                    Some("storySkeleton"),
                ),
                "run_sub_agent_adaptationStrategy" => (
                    "scriptAgent:adaptationStrategyAgent",
                    "改编策略",
                    Some("adaptationStrategy"),
                ),
                "run_sub_agent_script" => ("scriptAgent:scriptAgent", "剧本", None),
                "run_supervision_agent" => ("scriptAgent:supervisionAgent", "监督", None),
                _ => return Err(AppError::bad_request("不支持的剧本子 Agent")),
            };
            let prompt = request
                .arguments
                .get("prompt")
                .and_then(Value::as_str)
                .ok_or_else(|| AppError::bad_request("缺少 prompt"))?;
            let output = ai_client::text(
                &state.pool,
                agent_key,
                &format!(
                    "你是 Toonflow 的{label}子 Agent。严格完成委派任务并返回可写入工作区的内容。"
                ),
                prompt,
            )
            .await
            .map_err(AppError::bad_request)?;
            if let Some(tag) = tag {
                if let Some(content) = tagged(&output, tag) {
                    let mut data:Value=sqlx::query_scalar("SELECT data FROM toonflow.agent_work_data WHERE project_id=$1 AND episodes_id IS NULL AND key='scriptAgent'").bind(request.project_id).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to load script workspace"))?.unwrap_or_else(||json!({"storySkeleton":"","adaptationStrategy":""}));
                    data[tag] = json!(content);
                    sqlx::query("INSERT INTO toonflow.agent_work_data(project_id,episodes_id,key,data,create_time,update_time)VALUES($1,NULL,'scriptAgent',$2,$3,$3) ON CONFLICT(project_id,key) WHERE episodes_id IS NULL DO UPDATE SET data=excluded.data,update_time=excluded.update_time").bind(request.project_id).bind(data).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to save sub agent result"))?;
                }
            }
            Ok(json!({"agent":agent_key,"content":output}))
        }
        ("productionAgent", "get_flowData") => {
            let script_id = request
                .script_id
                .ok_or_else(|| AppError::bad_request("生产工具缺少 scriptId"))?;
            let data:Option<Value>=sqlx::query_scalar("SELECT data FROM toonflow.agent_work_data WHERE project_id=$1 AND episodes_id=$2 AND key='productionAgent'").bind(request.project_id).bind(script_id).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to get flow data"))?;
            let data = data.unwrap_or_else(|| json!({}));
            let key = request
                .arguments
                .get("key")
                .and_then(Value::as_str)
                .unwrap_or_default();
            Ok(if key.is_empty() {
                data
            } else {
                data.get(key).cloned().unwrap_or(Value::Null)
            })
        }
        ("productionAgent", "add_deriveAsset") => {
            let parent = request
                .arguments
                .get("assetsId")
                .and_then(Value::as_i64)
                .ok_or_else(|| AppError::bad_request("缺少 assetsId"))?;
            let parent_type: Option<String> = sqlx::query_scalar(
                "SELECT type FROM toonflow.assets WHERE id=$1 AND project_id=$2",
            )
            .bind(parent)
            .bind(request.project_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to get parent asset"))?;
            let id = request
                .arguments
                .get("id")
                .and_then(Value::as_i64)
                .unwrap_or(now_ms() * 1000);
            sqlx::query("INSERT INTO toonflow.assets(id,name,prompt,type,description,parent_asset_id,project_id,start_time)VALUES($1,$2,'',$3,$4,$5,$6,$7) ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description").bind(id).bind(request.arguments.get("name").and_then(Value::as_str).unwrap_or("衍生资产")).bind(parent_type.ok_or_else(||AppError::not_found("parent asset not found"))?).bind(request.arguments.get("desc").and_then(Value::as_str).unwrap_or_default()).bind(parent).bind(request.project_id).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to save derived asset"))?;
            if let Some(script_id) = request.script_id {
                sqlx::query("INSERT INTO toonflow.script_assets(script_id,asset_id)VALUES($1,$2) ON CONFLICT DO NOTHING").bind(script_id).bind(id).execute(&state.pool).await.ok();
            }
            Ok(json!({"id":id}))
        }
        ("productionAgent", "del_deriveAsset") => {
            let id = request
                .arguments
                .get("id")
                .and_then(Value::as_i64)
                .ok_or_else(|| AppError::bad_request("缺少 id"))?;
            sqlx::query("DELETE FROM toonflow.assets WHERE id=$1 AND project_id=$2 AND parent_asset_id IS NOT NULL").bind(id).bind(request.project_id).execute(&state.pool).await.map_err(|_|AppError::internal("failed to delete derived asset"))?;
            Ok(json!(true))
        }
        ("productionAgent", "generate_deriveAsset") => {
            let ids = request
                .arguments
                .get("ids")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|value| value.as_i64())
                .collect::<Vec<_>>();
            let rows = toonflow_asset_ai::schedule_asset_generation(
                &state.pool,
                request.project_id,
                &ids,
                request
                    .arguments
                    .get("concurrentCount")
                    .and_then(Value::as_u64)
                    .unwrap_or(3) as usize,
            )
            .await?;
            Ok(json!(rows))
        }
        ("productionAgent", name) if name.starts_with("run_sub_agent_") => {
            let (agent_key, label, flow_tag) = match name {
                "run_sub_agent_derive_assets" => {
                    ("productionAgent:deriveAssetsAgent", "衍生资产", None)
                }
                "run_sub_agent_generate_assets" => {
                    ("productionAgent:generateAssetsAgent", "资产生成", None)
                }
                "run_sub_agent_director_plan" => (
                    "productionAgent:directorPlanAgent",
                    "导演规划",
                    Some(("scriptPlan", "scriptPlan")),
                ),
                "run_sub_agent_storyboard_gen" => {
                    ("productionAgent:storyboardGenAgent", "分镜图生成", None)
                }
                "run_sub_agent_storyboard_panel" => {
                    ("productionAgent:storyboardPanelAgent", "分镜面板", None)
                }
                "run_sub_agent_storyboard_table" => (
                    "productionAgent:storyboardTableAgent",
                    "分镜表",
                    Some(("storyboardTable", "storyboardTable")),
                ),
                "run_sub_agent_supervision" => ("productionAgent:supervisionAgent", "监制", None),
                _ => return Err(AppError::bad_request("不支持的生产子 Agent")),
            };
            let prompt = request
                .arguments
                .get("prompt")
                .and_then(Value::as_str)
                .ok_or_else(|| AppError::bad_request("缺少 prompt"))?;
            let output=ai_client::text(&state.pool,agent_key,&format!("你是 Toonflow 的{label}子 Agent。严格完成委派任务，使用要求的工作区 XML 格式输出。"),prompt).await.map_err(AppError::bad_request)?;
            if let (Some((tag, key)), Some(script_id)) = (flow_tag, request.script_id) {
                if let Some(content) = tagged(&output, tag) {
                    let mut data:Value=sqlx::query_scalar("SELECT data FROM toonflow.agent_work_data WHERE project_id=$1 AND episodes_id=$2 AND key='productionAgent'").bind(request.project_id).bind(script_id).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to load production workspace"))?.unwrap_or_else(||json!({}));
                    data[key] = json!(content);
                    sqlx::query("INSERT INTO toonflow.agent_work_data(project_id,episodes_id,key,data,create_time,update_time)VALUES($1,$2,'productionAgent',$3,$4,$4) ON CONFLICT(project_id,episodes_id,key) DO UPDATE SET data=excluded.data,update_time=excluded.update_time").bind(request.project_id).bind(script_id).bind(data).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to save production sub agent result"))?;
                }
            }
            Ok(json!({"agent":agent_key,"content":output}))
        }
        ("productionAgent", "set_flowData") => {
            let script_id = request
                .script_id
                .ok_or_else(|| AppError::bad_request("生产工具缺少 scriptId"))?;
            let key = request
                .arguments
                .get("key")
                .and_then(Value::as_str)
                .ok_or_else(|| AppError::bad_request("缺少 key"))?;
            if !matches!(
                key,
                "scriptPlan" | "storyboardTable" | "script" | "assets" | "storyboard"
            ) {
                return Err(AppError::bad_request("不支持的 Flow key"));
            }
            let value = request
                .arguments
                .get("value")
                .cloned()
                .unwrap_or(Value::Null);
            let mut data:Value=sqlx::query_scalar("SELECT data FROM toonflow.agent_work_data WHERE project_id=$1 AND episodes_id=$2 AND key='productionAgent'").bind(request.project_id).bind(script_id).fetch_optional(&state.pool).await.map_err(|_|AppError::internal("failed to load flow data"))?.unwrap_or_else(||json!({}));
            data[key] = value;
            sqlx::query("INSERT INTO toonflow.agent_work_data(project_id,episodes_id,key,data,create_time,update_time)VALUES($1,$2,'productionAgent',$3,$4,$4) ON CONFLICT(project_id,episodes_id,key) DO UPDATE SET data=excluded.data,update_time=excluded.update_time").bind(request.project_id).bind(script_id).bind(&data).bind(now_ms()).execute(&state.pool).await.map_err(|_|AppError::internal("failed to save flow data"))?;
            Ok(json!({"key":key,"data":data[key]}))
        }
        ("productionAgent", "add_flowData_storyboard") => {
            let script_id = request
                .script_id
                .ok_or_else(|| AppError::bad_request("生产工具缺少 scriptId"))?;
            let id = now_ms() * 1000;
            let duration = request
                .arguments
                .get("duration")
                .and_then(Value::as_i64)
                .unwrap_or(4)
                .clamp(1, 60);
            let should = request
                .arguments
                .get("shouldGenerateImage")
                .map(|value| {
                    value
                        .as_bool()
                        .unwrap_or_else(|| value.as_str() != Some("false"))
                })
                .unwrap_or(true);
            let index:i32=sqlx::query_scalar("SELECT coalesce(max(index),-1)+1 FROM toonflow.storyboards WHERE project_id=$1 AND script_id=$2").bind(request.project_id).bind(script_id).fetch_one(&state.pool).await.unwrap_or(0);
            let track_id = id + 1;
            let mut tx = state
                .pool
                .begin()
                .await
                .map_err(|_| AppError::internal("failed to add storyboard"))?;
            sqlx::query("INSERT INTO toonflow.video_tracks(id,project_id,script_id,state,duration)VALUES($1,$2,$3,'未生成',$4)").bind(track_id).bind(request.project_id).bind(script_id).bind(duration as i32).execute(&mut *tx).await.map_err(|_|AppError::internal("failed to add storyboard track"))?;
            sqlx::query("INSERT INTO toonflow.storyboards(id,script_id,prompt,duration,state,track_id,track,video_desc,should_generate_image,project_id,index,create_time)VALUES($1,$2,$3,$4,'未生成',$5,$6,$7,$8,$9,$10,$11)").bind(id).bind(script_id).bind(request.arguments.get("prompt").and_then(Value::as_str).unwrap_or_default()).bind(duration.to_string()).bind(track_id).bind(request.arguments.get("track").and_then(Value::as_str).unwrap_or("main")).bind(request.arguments.get("videoDesc").and_then(Value::as_str).unwrap_or_default()).bind(if should{1}else{0}).bind(request.project_id).bind(index).bind(now_ms()).execute(&mut *tx).await.map_err(|_|AppError::internal("failed to add storyboard"))?;
            if let Some(ids) = request
                .arguments
                .get("associateAssetsIds")
                .and_then(Value::as_array)
            {
                for asset_id in ids.iter().filter_map(Value::as_i64) {
                    sqlx::query("INSERT INTO toonflow.assets_storyboards(storyboard_id,asset_id)VALUES($1,$2) ON CONFLICT DO NOTHING").bind(id).bind(asset_id).execute(&mut *tx).await.map_err(|_|AppError::internal("failed to bind storyboard asset"))?;
                }
            }
            tx.commit()
                .await
                .map_err(|_| AppError::internal("failed to add storyboard"))?;
            Ok(json!({"id":id,"index":index}))
        }
        ("productionAgent", "update_storyboard") => {
            let id = request
                .arguments
                .get("id")
                .and_then(Value::as_i64)
                .ok_or_else(|| AppError::bad_request("缺少 id"))?;
            let result=sqlx::query("UPDATE toonflow.storyboards SET prompt=coalesce($3,prompt),video_desc=coalesce($4,video_desc),duration=coalesce($5,duration),track=coalesce($6,track),should_generate_image=coalesce($7,should_generate_image) WHERE id=$1 AND project_id=$2").bind(id).bind(request.project_id).bind(request.arguments.get("prompt").and_then(Value::as_str)).bind(request.arguments.get("videoDesc").and_then(Value::as_str)).bind(request.arguments.get("duration").and_then(Value::as_i64).map(|v|v.to_string())).bind(request.arguments.get("track").and_then(Value::as_str)).bind(request.arguments.get("shouldGenerateImage").and_then(Value::as_bool).map(|v|if v{1}else{0})).execute(&state.pool).await.map_err(|_|AppError::internal("failed to update storyboard"))?;
            if result.rows_affected() == 0 {
                return Err(AppError::not_found("storyboard not found"));
            }
            Ok(json!(true))
        }
        ("productionAgent", "generate_storyboard") => {
            let script_id = request
                .script_id
                .ok_or_else(|| AppError::bad_request("生产工具缺少 scriptId"))?;
            let ids = request
                .arguments
                .get("ids")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|value| value.as_i64())
                .collect::<Vec<_>>();
            let rows = toonflow_image_workflow::schedule_storyboard_generation(
                &state.pool,
                request.project_id,
                script_id,
                &ids,
                request
                    .arguments
                    .get("concurrentCount")
                    .and_then(Value::as_u64)
                    .unwrap_or(5) as usize,
                false,
            )
            .await?;
            Ok(json!(rows))
        }
        ("productionAgent", "delete_storyboard") => {
            let ids = request
                .arguments
                .get("ids")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|value| value.as_i64())
                .collect::<Vec<_>>();
            sqlx::query("DELETE FROM toonflow.storyboards WHERE id=ANY($1) AND project_id=$2")
                .bind(&ids)
                .bind(request.project_id)
                .execute(&state.pool)
                .await
                .map_err(|_| AppError::internal("failed to delete storyboards"))?;
            Ok(json!({"ids":ids}))
        }
        _ => Err(AppError::bad_request("不支持的 Agent 工具")),
    }
}

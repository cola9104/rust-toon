use std::{
    collections::{HashMap, HashSet},
    sync::{Mutex, OnceLock},
};

use axum::{
    Json,
    extract::{Query, State},
};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_database::PgPool;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::FromRow;
use tokio::task::AbortHandle;

pub use crate::toonflow_workflow_control::{cancel_node, cancel_run, latest_node_run, retry_node};
pub use crate::toonflow_workflow_definition::{
    WorkflowDefinition, WorkflowNode, default_production_workflow, validate_workflow,
    workflow_from_data,
};
use crate::toonflow_workflow_utils::{
    default_concurrency, empty_object, manual_trigger, merge_node_settings,
};
use crate::{
    ToonState, shared::require, toonflow_agent_tools, toonflow_image_workflow, toonflow_video,
};

static ACTIVE_NODE_RUNS: OnceLock<Mutex<HashMap<i64, AbortHandle>>> = OnceLock::new();
static ACTIVE_WORKFLOW_RUNS: OnceLock<Mutex<HashMap<i64, AbortHandle>>> = OnceLock::new();

pub(crate) fn active_node_runs() -> &'static Mutex<HashMap<i64, AbortHandle>> {
    ACTIVE_NODE_RUNS.get_or_init(|| Mutex::new(HashMap::new()))
}

pub(crate) fn active_workflow_runs() -> &'static Mutex<HashMap<i64, AbortHandle>> {
    ACTIVE_WORKFLOW_RUNS.get_or_init(|| Mutex::new(HashMap::new()))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ValidateWorkflowRequest {
    pub workflow: WorkflowDefinition,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ValidateWorkflowResponse {
    pub valid: bool,
    pub execution_order: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateWorkflowRunRequest {
    pub project_id: i64,
    pub script_id: i64,
    #[serde(default = "manual_trigger")]
    pub trigger_type: String,
    #[serde(default = "empty_object")]
    pub input: Value,
    #[serde(default)]
    pub auto_start: bool,
}

#[derive(Debug, Deserialize)]
pub struct WorkflowRunIdRequest {
    pub id: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListWorkflowRunsQuery {
    pub project_id: i64,
    pub script_id: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LatestNodeRunQuery {
    pub project_id: i64,
    pub script_id: i64,
    pub node_id: String,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowRunSummary {
    pub id: i64,
    pub definition_version: i32,
    pub state: String,
    pub trigger_type: String,
    pub error_reason: Option<String>,
    pub start_time: Option<i64>,
    pub finish_time: Option<i64>,
    pub create_time: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateWorkflowRunResponse {
    pub id: i64,
    pub definition_version: i32,
    pub state: &'static str,
    pub node_count: usize,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowRunDetail {
    pub id: i64,
    pub definition_version: i32,
    pub state: String,
    pub trigger_type: String,
    pub input: Value,
    pub output: Option<Value>,
    pub error_reason: Option<String>,
    pub start_time: Option<i64>,
    pub finish_time: Option<i64>,
    pub create_time: i64,
    pub nodes: Vec<WorkflowNodeRunResponse>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StoryboardImageNodeInput {
    pub storyboard_ids: Vec<i64>,
    #[serde(default = "default_concurrency")]
    pub concurrent_count: usize,
    #[serde(default)]
    pub compulsory: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartWorkflowNodeRequest {
    pub workflow_run_id: i64,
    pub node_id: String,
    #[serde(default = "empty_object")]
    pub input: Value,
    pub agent_run_id: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct NodeRunIdRequest {
    pub id: i64,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowNodeRunResponse {
    pub id: i64,
    pub workflow_run_id: i64,
    pub agent_run_id: Option<i64>,
    pub node_id: String,
    pub node_type: String,
    pub attempt: i32,
    pub state: String,
    pub input: Value,
    pub output: Option<Value>,
    pub error_reason: Option<String>,
    pub progress_current: i32,
    pub progress_total: i32,
    pub retry_of_id: Option<i64>,
    pub start_time: Option<i64>,
    pub finish_time: Option<i64>,
    pub create_time: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartWorkflowNodeResponse {
    pub id: i64,
    pub workflow_run_id: i64,
    pub node_id: String,
    pub state: &'static str,
    pub progress_current: i32,
    pub progress_total: i32,
}

pub async fn persist_definition(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
    workflow: &WorkflowDefinition,
    time: i64,
) -> Result<(), AppError> {
    validate_workflow(workflow)?;
    let definition = serde_json::to_value(workflow)
        .map_err(|_| AppError::internal("failed to serialize workflow definition"))?;
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin workflow transaction"))?;
    let current = sqlx::query_as::<_, (i64, i32, Value)>(
        "SELECT id,version,definition FROM toonflow.workflow_definitions
         WHERE project_id=$1 AND script_id=$2 AND active=true
         FOR UPDATE",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to load workflow definition"))?;
    if current
        .as_ref()
        .is_some_and(|(_, _, value)| value == &definition)
    {
        transaction
            .commit()
            .await
            .map_err(|_| AppError::internal("failed to commit workflow transaction"))?;
        return Ok(());
    }
    let next_version = current.as_ref().map_or(1, |(_, version, _)| version + 1);
    sqlx::query(
        "UPDATE toonflow.workflow_definitions SET active=false,update_time=$3
         WHERE project_id=$1 AND script_id=$2 AND active=true",
    )
    .bind(project_id)
    .bind(script_id)
    .bind(time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to retire workflow definition"))?;
    sqlx::query(
        "INSERT INTO toonflow.workflow_definitions
         (project_id,script_id,version,schema_version,definition,active,create_time,update_time)
         VALUES($1,$2,$3,$4,$5,true,$6,$6)",
    )
    .bind(project_id)
    .bind(script_id)
    .bind(next_version)
    .bind(workflow.schema_version)
    .bind(definition)
    .bind(time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to save workflow definition"))?;
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal("failed to commit workflow transaction"))?;
    Ok(())
}

pub async fn validate(
    user: CurrentUser,
    State(_state): State<ToonState>,
    Json(request): Json<ValidateWorkflowRequest>,
) -> Result<Json<ApiResponse<ValidateWorkflowResponse>>, AppError> {
    require(&user, "toon:scene:update")?;
    let execution_order = validate_workflow(&request.workflow)?;
    Ok(Json(ApiResponse::new(ValidateWorkflowResponse {
        valid: true,
        execution_order,
    })))
}

pub async fn create_run(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<CreateWorkflowRunRequest>,
) -> Result<Json<ApiResponse<CreateWorkflowRunResponse>>, AppError> {
    require(&user, "toon:scene:update")?;
    if !request.input.is_object() {
        return Err(AppError::bad_request(
            "workflow run input must be an object",
        ));
    }
    let trigger_type = request.trigger_type.trim();
    if trigger_type.is_empty() || trigger_type.len() > 32 {
        return Err(AppError::bad_request("workflow trigger type is invalid"));
    }
    let definition = sqlx::query_as::<_, (i64, i32, Value)>(
        "SELECT id,version,definition FROM toonflow.workflow_definitions
         WHERE project_id=$1 AND script_id=$2 AND active=true",
    )
    .bind(request.project_id)
    .bind(request.script_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to load active workflow definition"))?
    .ok_or_else(|| AppError::bad_request("save the production workflow before running it"))?;
    let workflow: WorkflowDefinition = serde_json::from_value(definition.2)
        .map_err(|_| AppError::internal("stored workflow definition is invalid"))?;
    validate_workflow(&workflow)?;
    let requested = request
        .input
        .get("requestedNodeIds")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect::<HashSet<_>>()
        })
        .or_else(|| {
            request
                .input
                .get("requestedNodeId")
                .and_then(Value::as_str)
                .map(|id| HashSet::from([id.to_string()]))
        });
    if requested.as_ref().is_some_and(|nodes| {
        nodes.is_empty()
            || nodes
                .iter()
                .any(|id| !workflow.nodes.iter().any(|node| &node.id == id))
    }) {
        return Err(AppError::bad_request(
            "requested workflow nodes are empty or invalid",
        ));
    }
    let targets = workflow
        .edges
        .iter()
        .filter(|edge| {
            requested
                .as_ref()
                .is_none_or(|nodes| nodes.contains(&edge.source) && nodes.contains(&edge.target))
        })
        .map(|edge| edge.target.as_str())
        .collect::<HashSet<_>>();
    let time = chrono::Utc::now().timestamp_millis();
    let mut transaction = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin workflow run"))?;
    if request.auto_start {
        let lock_key = format!(
            "toonflow-workflow:{}:{}",
            request.project_id, request.script_id
        );
        sqlx::query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))")
            .bind(lock_key)
            .execute(&mut *transaction)
            .await
            .map_err(|_| AppError::internal("failed to lock workflow execution"))?;
        let active_run_exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(
               SELECT 1 FROM toonflow.workflow_runs
               WHERE project_id=$1 AND script_id=$2 AND state IN('pending','running')
             )",
        )
        .bind(request.project_id)
        .bind(request.script_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(|_| AppError::internal("failed to check active workflow execution"))?;
        if active_run_exists {
            return Err(AppError::bad_request(
                "当前剧本已有工作流正在运行，请等待完成或先取消",
            ));
        }
    }
    let run_id: i64 = sqlx::query_scalar(
        "INSERT INTO toonflow.workflow_runs
         (workflow_definition_id,project_id,script_id,definition_version,state,trigger_type,input,create_time)
         VALUES($1,$2,$3,$4,'pending',$5,$6,$7) RETURNING id",
    )
    .bind(definition.0)
    .bind(request.project_id)
    .bind(request.script_id)
    .bind(definition.1)
    .bind(trigger_type)
    .bind(&request.input)
    .bind(time)
    .fetch_one(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to create workflow run"))?;
    for node in &workflow.nodes {
        let node_state = if requested
            .as_ref()
            .is_some_and(|nodes| !nodes.contains(&node.id))
        {
            "skipped"
        } else if targets.contains(node.id.as_str()) {
            "blocked"
        } else {
            "pending"
        };
        sqlx::query(
            "INSERT INTO toonflow.workflow_node_runs
             (workflow_run_id,node_id,node_type,state,input,create_time)
             VALUES($1,$2,$3,$4,'{}',$5)",
        )
        .bind(run_id)
        .bind(&node.id)
        .bind(&node.node_type)
        .bind(node_state)
        .bind(time)
        .execute(&mut *transaction)
        .await
        .map_err(|_| AppError::internal("failed to create workflow node run"))?;
    }
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal("failed to commit workflow run"))?;
    if request.auto_start {
        schedule_workflow_run(state.clone(), run_id);
    }
    Ok(Json(ApiResponse::new(CreateWorkflowRunResponse {
        id: run_id,
        definition_version: definition.1,
        state: "pending",
        node_count: workflow.nodes.len(),
    })))
}

pub(crate) async fn recover_stale_node_runs(state: &ToonState) {
    let active = active_node_runs()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .keys()
        .copied()
        .collect::<Vec<_>>();
    let stale = sqlx::query_as::<_, (i64, i64, String, Value, i64, i64)>(
        "SELECT nr.id,nr.workflow_run_id,nr.node_type,nr.input,r.project_id,r.script_id
         FROM toonflow.workflow_node_runs nr
         JOIN toonflow.workflow_runs r ON r.id=nr.workflow_run_id
         WHERE nr.state='running' AND NOT(nr.id=ANY($1))",
    )
    .bind(&active)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();
    if stale.is_empty() {
        return;
    }
    let node_ids = stale.iter().map(|row| row.0).collect::<Vec<_>>();
    let run_ids = stale.iter().map(|row| row.1).collect::<Vec<_>>();
    for (_, _, node_type, input, project_id, script_id) in &stale {
        if node_type == "storyboard.image" {
            if let Ok(input) = serde_json::from_value::<StoryboardImageNodeInput>(input.clone()) {
                let _ = sqlx::query(
                    "UPDATE toonflow.storyboards SET state='生成失败',reason='服务重启导致任务中断' WHERE id=ANY($1) AND state='生成中'",
                )
                .bind(input.storyboard_ids)
                .execute(&state.pool)
                .await;
            }
        } else if node_type == "video.generate" {
            if let Ok(input) =
                serde_json::from_value::<toonflow_video::WorkflowVideoInput>(input.clone())
            {
                let _ = sqlx::query(
                    "UPDATE toonflow.videos SET state='生成失败',error_reason='服务重启导致任务中断' WHERE id=ANY($1) AND state='生成中'",
                )
                .bind(input.video_ids)
                .execute(&state.pool)
                .await;
            }
        } else if node_type == "storyboard.plan" {
            let _ = rollback_partial_storyboard_panel(&state.pool, *project_id, *script_id, input)
                .await;
        }
    }
    let time = chrono::Utc::now().timestamp_millis();
    let _ = sqlx::query(
        "UPDATE toonflow.workflow_node_runs
         SET state='failed',error_reason='服务重启导致任务中断',finish_time=$2
         WHERE id=ANY($1) AND state='running'",
    )
    .bind(&node_ids)
    .bind(time)
    .execute(&state.pool)
    .await;
    let _ = sqlx::query(
        "UPDATE toonflow.workflow_runs
         SET state='failed',error_reason='服务重启导致任务中断',finish_time=$2
         WHERE id=ANY($1) AND state='running'",
    )
    .bind(&run_ids)
    .bind(time)
    .execute(&state.pool)
    .await;
}

async fn finish_node_run(
    pool: &PgPool,
    node_run_id: i64,
    workflow_run_id: i64,
    node_state: &str,
    output: Value,
    error_reason: Option<String>,
) {
    let time = chrono::Utc::now().timestamp_millis();
    let updated = sqlx::query(
        "UPDATE toonflow.workflow_node_runs
         SET state=$2,output=$3,error_reason=$4,progress_current=progress_total,finish_time=$5
         WHERE id=$1 AND state='running'",
    )
    .bind(node_run_id)
    .bind(node_state)
    .bind(&output)
    .bind(&error_reason)
    .bind(time)
    .execute(pool)
    .await
    .map(|result| result.rows_affected())
    .unwrap_or(0);
    if updated == 0 {
        return;
    }
    if node_state == "failed" {
        let _ = sqlx::query(
            "UPDATE toonflow.workflow_runs SET state='failed',output=$2,error_reason=$3,finish_time=$4 WHERE id=$1",
        )
        .bind(workflow_run_id)
        .bind(output)
        .bind(error_reason)
        .bind(time)
        .execute(pool)
        .await;
        return;
    }
    let remaining: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM toonflow.workflow_node_runs WHERE workflow_run_id=$1 AND state IN('pending','blocked','running')",
    )
    .bind(workflow_run_id)
    .fetch_one(pool)
    .await
    .unwrap_or(0);
    if remaining == 0 {
        let _ = sqlx::query(
            "UPDATE toonflow.workflow_runs SET state='success',output=$2,error_reason=NULL,finish_time=$3 WHERE id=$1",
        )
        .bind(workflow_run_id)
        .bind(output)
        .bind(time)
        .execute(pool)
        .await;
    }
}

async fn launch_storyboard_node(
    state: &ToonState,
    node_run_id: i64,
    input_value: Value,
) -> Result<StartWorkflowNodeResponse, AppError> {
    let row = sqlx::query_as::<_, (i64, String, String, i64, i64, String)>(
        "SELECT nr.workflow_run_id,nr.node_id,nr.node_type,r.project_id,r.script_id,nr.state
         FROM toonflow.workflow_node_runs nr
         JOIN toonflow.workflow_runs r ON r.id=nr.workflow_run_id
         WHERE nr.id=$1",
    )
    .bind(node_run_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to load workflow node run"))?
    .ok_or_else(|| AppError::not_found("workflow node run not found"))?;
    let input: StoryboardImageNodeInput = serde_json::from_value(input_value)
        .map_err(|_| AppError::bad_request("storyboard.image node input is invalid"))?;
    if !matches!(row.5.as_str(), "pending" | "blocked") {
        return Err(AppError::bad_request(
            "workflow node run has already started",
        ));
    }
    let (_storyboards, jobs) = toonflow_image_workflow::prepare_storyboard_generation(
        &state.pool,
        row.3,
        row.4,
        &input.storyboard_ids,
        input.compulsory,
    )
    .await?;
    let input_json = serde_json::to_value(&input)
        .map_err(|_| AppError::internal("failed to serialize workflow node input"))?;
    let time = chrono::Utc::now().timestamp_millis();
    let mut transaction = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin workflow node run"))?;
    sqlx::query(
        "UPDATE toonflow.workflow_node_runs
         SET state='running',input=$2,output=NULL,error_reason=NULL,
             progress_current=0,progress_total=$3,start_time=$4,finish_time=NULL
         WHERE id=$1",
    )
    .bind(node_run_id)
    .bind(input_json)
    .bind(jobs.len() as i32)
    .bind(time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to start workflow node run"))?;
    sqlx::query(
        "UPDATE toonflow.workflow_runs
         SET state='running',input=$2,output=NULL,error_reason=NULL,start_time=$3,finish_time=NULL
         WHERE id=$1",
    )
    .bind(row.0)
    .bind(json!({"nodeId": row.1, "nodeRunId": node_run_id, "input": input}))
    .bind(time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to start workflow run"))?;
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal("failed to commit workflow node run"))?;

    let total = jobs.len();
    let generated_storyboard_ids = jobs.iter().map(|job| job.id).collect::<Vec<_>>();
    let task_state = state.clone();
    let workflow_run_id = row.0;
    let concurrency = input.concurrent_count;
    let (start_tx, start_rx) = tokio::sync::oneshot::channel();
    let handle = tokio::spawn(async move {
        let _ = start_rx.await;
        let summary = toonflow_image_workflow::run_storyboard_generation(
            task_state.pool.clone(),
            row.3,
            row.4,
            jobs,
            concurrency,
            Some(node_run_id),
        )
        .await;
        let (node_state, error_reason) = if summary.failed == 0 {
            ("success", None)
        } else {
            (
                "failed",
                Some(format!("{} 个分镜图片生成失败", summary.failed)),
            )
        };
        let storyboards = toonflow_image_workflow::load_storyboard_generation_results(
            &task_state.pool,
            &generated_storyboard_ids,
        )
        .await;
        let output = json!({
            "total": summary.total,
            "succeeded": summary.succeeded,
            "failed": summary.failed,
            "storyboards": storyboards,
        });
        finish_node_run(
            &task_state.pool,
            node_run_id,
            workflow_run_id,
            node_state,
            output,
            error_reason,
        )
        .await;
        active_node_runs()
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&node_run_id);
    });
    active_node_runs()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .insert(node_run_id, handle.abort_handle());
    let _ = start_tx.send(());

    Ok(StartWorkflowNodeResponse {
        id: node_run_id,
        workflow_run_id: row.0,
        node_id: row.1,
        state: "running",
        progress_current: 0,
        progress_total: total as i32,
    })
}

enum PreparedNodeExecution {
    ScriptSource,
    Agent {
        tool_name: String,
        prompt: String,
        materialize_storyboard_panel: bool,
    },
    Video {
        jobs: Vec<toonflow_video::WorkflowVideoJob>,
        concurrency: usize,
        video_ids: Vec<i64>,
    },
}

async fn storyboard_ids(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
) -> Result<Vec<i64>, String> {
    sqlx::query_scalar(
        "SELECT id FROM toonflow.storyboards WHERE project_id=$1 AND script_id=$2 ORDER BY index,id",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())
}

async fn remove_storyboard_rows(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
    storyboard_ids: &[i64],
) -> Result<(), String> {
    if storyboard_ids.is_empty() {
        return Ok(());
    }
    let mut transaction = pool.begin().await.map_err(|error| error.to_string())?;
    let track_ids: Vec<i64> = sqlx::query_scalar(
        "SELECT DISTINCT track_id FROM toonflow.storyboards WHERE id=ANY($1) AND track_id IS NOT NULL",
    )
    .bind(storyboard_ids)
    .fetch_all(&mut *transaction)
    .await
    .map_err(|error| error.to_string())?;
    sqlx::query("DELETE FROM toonflow.storyboards WHERE id=ANY($1)")
        .bind(storyboard_ids)
        .execute(&mut *transaction)
        .await
        .map_err(|error| error.to_string())?;
    sqlx::query(
        "DELETE FROM toonflow.video_tracks vt WHERE id=ANY($1) AND NOT EXISTS (SELECT 1 FROM toonflow.storyboards s WHERE s.track_id=vt.id)",
    )
    .bind(&track_ids)
    .execute(&mut *transaction)
    .await
    .map_err(|error| error.to_string())?;
    sqlx::query(
        "WITH ordered AS (
           SELECT id,(row_number() OVER (ORDER BY index,id)-1)::integer AS new_index
           FROM toonflow.storyboards WHERE project_id=$1 AND script_id=$2
         )
         UPDATE toonflow.storyboards s SET index=o.new_index FROM ordered o WHERE s.id=o.id",
    )
    .bind(project_id)
    .bind(script_id)
    .execute(&mut *transaction)
    .await
    .map_err(|error| error.to_string())?;
    transaction
        .commit()
        .await
        .map_err(|error| error.to_string())
}

pub(crate) async fn rollback_partial_storyboard_panel(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
    input: &Value,
) -> Result<(), String> {
    let Some(previous_ids) = input
        .get("panelPreviousStoryboardIds")
        .and_then(Value::as_array)
        .map(|ids| ids.iter().filter_map(Value::as_i64).collect::<Vec<_>>())
    else {
        return Ok(());
    };
    let current_ids = storyboard_ids(pool, project_id, script_id).await?;
    let partial_ids = current_ids
        .into_iter()
        .filter(|id| !previous_ids.contains(id))
        .collect::<Vec<_>>();
    remove_storyboard_rows(pool, project_id, script_id, &partial_ids).await
}

async fn launch_standard_node(
    state: &ToonState,
    node_run_id: i64,
    mut input: Value,
) -> Result<StartWorkflowNodeResponse, AppError> {
    let row = sqlx::query_as::<_, (i64, String, String, i64, i64, String)>(
        "SELECT nr.workflow_run_id,nr.node_id,nr.node_type,r.project_id,r.script_id,nr.state
         FROM toonflow.workflow_node_runs nr
         JOIN toonflow.workflow_runs r ON r.id=nr.workflow_run_id
         WHERE nr.id=$1",
    )
    .bind(node_run_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to load workflow node run"))?
    .ok_or_else(|| AppError::not_found("workflow node run not found"))?;
    if !matches!(row.5.as_str(), "pending" | "blocked") {
        return Err(AppError::bad_request(
            "workflow node run has already started",
        ));
    }
    if !input.is_object() {
        return Err(AppError::bad_request(
            "workflow node input must be an object",
        ));
    }
    let (execution, progress_total) = match row.2.as_str() {
        "script.source" => (PreparedNodeExecution::ScriptSource, 1),
        "director.plan" | "storyboard.plan" => {
            let prompt = input
                .get("prompt")
                .and_then(Value::as_str)
                .filter(|prompt| !prompt.trim().is_empty())
                .map(str::to_string)
                .unwrap_or_else(|| {
                    if row.2 == "director.plan" {
                        "读取当前剧本与资产，生成完整导演规划并写入工作区。".into()
                    } else {
                        "读取剧本、资产和导演规划，生成完整分镜表并写入工作区。".into()
                    }
                });
            let tool_name = if row.2 == "director.plan" {
                "run_sub_agent_director_plan"
            } else {
                "run_sub_agent_storyboard_table"
            };
            (
                PreparedNodeExecution::Agent {
                    tool_name: tool_name.into(),
                    prompt,
                    materialize_storyboard_panel: row.2 == "storyboard.plan",
                },
                if row.2 == "storyboard.plan" { 2 } else { 1 },
            )
        }
        "video.generate" => {
            let mut video_input: toonflow_video::WorkflowVideoInput =
                serde_json::from_value(input.clone())
                    .map_err(|_| AppError::bad_request("video.generate node input is invalid"))?;
            let jobs = toonflow_video::prepare_workflow_video_generation(
                &state.pool,
                row.3,
                row.4,
                &mut video_input,
            )
            .await?;
            let total = jobs.len() as i32;
            input = serde_json::to_value(&video_input)
                .map_err(|_| AppError::internal("failed to serialize video node input"))?;
            (
                PreparedNodeExecution::Video {
                    jobs,
                    concurrency: video_input.concurrent_count,
                    video_ids: video_input.video_ids,
                },
                total,
            )
        }
        _ => return Err(AppError::bad_request("unsupported workflow node type")),
    };
    let time = chrono::Utc::now().timestamp_millis();
    let mut transaction = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin workflow node run"))?;
    sqlx::query(
        "UPDATE toonflow.workflow_node_runs
         SET state='running',input=$2,output=NULL,error_reason=NULL,
             progress_current=0,progress_total=$3,start_time=$4,finish_time=NULL
         WHERE id=$1",
    )
    .bind(node_run_id)
    .bind(&input)
    .bind(progress_total)
    .bind(time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to start workflow node run"))?;
    sqlx::query(
        "UPDATE toonflow.workflow_runs
         SET state='running',error_reason=NULL,start_time=coalesce(start_time,$2),finish_time=NULL
         WHERE id=$1",
    )
    .bind(row.0)
    .bind(time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to start workflow run"))?;
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal("failed to commit workflow node run"))?;

    let task_state = state.clone();
    let workflow_run_id = row.0;
    let node_id = row.1.clone();
    let project_id = row.3;
    let script_id = row.4;
    let (start_tx, start_rx) = tokio::sync::oneshot::channel();
    let handle = tokio::spawn(async move {
        let _ = start_rx.await;
        let result: Result<Value, String> = match execution {
            PreparedNodeExecution::ScriptSource => async {
                let script: Option<(String, String)> = sqlx::query_as(
                    "SELECT name,content FROM toonflow.scripts WHERE id=$1 AND project_id=$2",
                )
                .bind(script_id)
                .bind(project_id)
                .fetch_optional(&task_state.pool)
                .await
                .map_err(|error| error.to_string())?;
                let (name, content) = script.ok_or_else(|| "当前剧本不存在".to_string())?;
                let asset_count: i64 = sqlx::query_scalar(
                    "SELECT count(*) FROM toonflow.script_assets sa JOIN toonflow.assets a ON a.id=sa.asset_id WHERE sa.script_id=$1 AND a.project_id=$2",
                )
                .bind(script_id)
                .bind(project_id)
                .fetch_one(&task_state.pool)
                .await
                .map_err(|error| error.to_string())?;
                Ok(json!({"scriptId":script_id,"name":name,"contentLength":content.chars().count(),"assetCount":asset_count}))
            }
            .await,
            PreparedNodeExecution::Agent {
                tool_name,
                prompt,
                materialize_storyboard_panel,
            } => async {
                let request = toonflow_agent_tools::ToolRequest {
                    emitter: None,
                    agent_type: "productionAgent".into(),
                    isolation_key: format!("productionAgent:{project_id}:{script_id}"),
                    project_id,
                    script_id: Some(script_id),
                    tool_name,
                    arguments: json!({"prompt":prompt}),
                };
                let (plan_run_id, plan_output) = toonflow_agent_tools::execute_recorded(&task_state, &request)
                    .await
                    .map_err(|error| format!("{error:?}"))?;
                sqlx::query("UPDATE toonflow.workflow_node_runs SET agent_run_id=$2 WHERE id=$1")
                    .bind(node_run_id)
                    .bind(plan_run_id)
                    .execute(&task_state.pool)
                    .await
                    .map_err(|error| error.to_string())?;
                if !materialize_storyboard_panel {
                    Ok(plan_output)
                } else {
                    let previous_ids =
                        storyboard_ids(&task_state.pool, project_id, script_id).await?;
                    sqlx::query(
                        "UPDATE toonflow.workflow_node_runs
                         SET progress_current=1,
                             input=jsonb_set(input,'{panelPreviousStoryboardIds}',$2::jsonb,true)
                         WHERE id=$1 AND state='running'",
                    )
                    .bind(node_run_id)
                    .bind(json!(&previous_ids))
                    .execute(&task_state.pool)
                    .await
                    .map_err(|error| error.to_string())?;
                    let panel_request = toonflow_agent_tools::ToolRequest {
                        emitter: None,
                        agent_type: "productionAgent".into(),
                        isolation_key: format!("productionAgent:{project_id}:{script_id}"),
                        project_id,
                        script_id: Some(script_id),
                        tool_name: "run_sub_agent_storyboard_panel".into(),
                        arguments: json!({"prompt":"读取刚生成的最新分镜表，按项目当前模式完整写入分镜面板。必须逐项调用写入工具，不得只返回文字说明。"}),
                    };
                    let (panel_run_id, panel_output) = match toonflow_agent_tools::execute_recorded(
                        &task_state,
                        &panel_request,
                    )
                    .await
                    {
                        Ok((run_id, output)) => (run_id, output),
                        Err(error) => {
                            rollback_partial_storyboard_panel(
                                &task_state.pool,
                                project_id,
                                script_id,
                                &json!({"panelPreviousStoryboardIds":&previous_ids}),
                            )
                            .await?;
                            return Err(format!("分镜表已生成，但自动写入面板失败：{error:?}"));
                        }
                    };
                    sqlx::query("UPDATE toonflow.workflow_node_runs SET agent_run_id=$2 WHERE id=$1")
                        .bind(node_run_id)
                        .bind(panel_run_id)
                        .execute(&task_state.pool)
                        .await
                        .map_err(|error| error.to_string())?;
                    let current_ids = storyboard_ids(&task_state.pool, project_id, script_id).await?;
                    let new_ids = current_ids
                        .into_iter()
                        .filter(|id| !previous_ids.contains(id))
                        .collect::<Vec<_>>();
                    if new_ids.is_empty() {
                        return Err("分镜表已生成，但面板 Agent 未写入任何分镜".into());
                    }
                    remove_storyboard_rows(
                        &task_state.pool,
                        project_id,
                        script_id,
                        &previous_ids,
                    )
                    .await?;
                    let track_ids: Vec<i64> = sqlx::query_scalar(
                        "SELECT DISTINCT track_id FROM toonflow.storyboards WHERE id=ANY($1) AND track_id IS NOT NULL ORDER BY track_id",
                    )
                    .bind(&new_ids)
                    .fetch_all(&task_state.pool)
                    .await
                    .map_err(|error| error.to_string())?;
                    Ok(json!({
                        "plan": plan_output,
                        "panel": panel_output,
                        "storyboardCount": new_ids.len(),
                        "storyboardIds": new_ids,
                        "trackIds": track_ids,
                    }))
                }
            }
            .await,
            PreparedNodeExecution::Video {
                jobs,
                concurrency,
                video_ids,
            } => {
                let summary = toonflow_video::run_workflow_video_generation(
                    task_state.pool.clone(),
                    project_id,
                    jobs,
                    concurrency,
                    node_run_id,
                )
                .await;
                if summary.failed == 0 {
                    Ok(json!({"total":summary.total,"succeeded":summary.succeeded,"failed":summary.failed,"videoIds":summary.video_ids}))
                } else {
                    Err(format!("{} 个视频生成失败（任务：{:?}）", summary.failed, video_ids))
                }
            }
        };
        let (node_state, output, error_reason) = match result {
            Ok(output) => ("success", output, None),
            Err(reason) => ("failed", json!({}), Some(reason)),
        };
        finish_node_run(
            &task_state.pool,
            node_run_id,
            workflow_run_id,
            node_state,
            output,
            error_reason,
        )
        .await;
        active_node_runs()
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&node_run_id);
    });
    active_node_runs()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .insert(node_run_id, handle.abort_handle());
    let _ = start_tx.send(());
    Ok(StartWorkflowNodeResponse {
        id: node_run_id,
        workflow_run_id: row.0,
        node_id,
        state: "running",
        progress_current: 0,
        progress_total,
    })
}

pub(crate) async fn launch_node(
    state: &ToonState,
    node_run_id: i64,
    input: Value,
) -> Result<StartWorkflowNodeResponse, AppError> {
    let node_type: String =
        sqlx::query_scalar("SELECT node_type FROM toonflow.workflow_node_runs WHERE id=$1")
            .bind(node_run_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to load workflow node type"))?
            .ok_or_else(|| AppError::not_found("workflow node run not found"))?;
    if node_type == "storyboard.image" {
        launch_storyboard_node(state, node_run_id, input).await
    } else {
        launch_standard_node(state, node_run_id, input).await
    }
}

async fn orchestrated_node_input(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
    node: &WorkflowNode,
    run_input: &Value,
    upstream_outputs: Value,
) -> Result<Value, String> {
    let overrides = run_input
        .get("nodeInputs")
        .and_then(|value| value.get(&node.id));
    let settings = merge_node_settings(&node.config, overrides);
    let mut input = match node.node_type.as_str() {
        "script.source" => json!({}),
        "director.plan" | "storyboard.plan" => {
            json!({"prompt":settings.get("prompt").and_then(Value::as_str).unwrap_or_default()})
        }
        "storyboard.image" => {
            let storyboard_ids: Vec<i64> = if let Some(ids) =
                settings.get("storyboardIds").and_then(Value::as_array)
            {
                ids.iter().filter_map(Value::as_i64).collect()
            } else {
                sqlx::query_scalar(
                    "SELECT id FROM toonflow.storyboards WHERE project_id=$1 AND script_id=$2 ORDER BY index,id",
                )
                .bind(project_id)
                .bind(script_id)
                .fetch_all(pool)
                .await
                .map_err(|error| error.to_string())?
            };
            if storyboard_ids.is_empty() {
                return Err("当前没有可以生成的分镜，分镜规划节点必须先成功写入面板".into());
            }
            json!({
                "storyboardIds":storyboard_ids,
                "concurrentCount":settings.get("concurrentCount").and_then(Value::as_u64).unwrap_or(5),
                "compulsory":settings.get("compulsory").and_then(Value::as_bool).unwrap_or(false),
            })
        }
        "video.generate" => {
            let track_ids: Vec<i64> = if let Some(ids) =
                settings.get("trackIds").and_then(Value::as_array)
            {
                ids.iter().filter_map(Value::as_i64).collect()
            } else {
                sqlx::query_scalar(
                    "SELECT id FROM toonflow.video_tracks WHERE project_id=$1 AND script_id=$2 ORDER BY sort_order,id",
                )
                .bind(project_id)
                .bind(script_id)
                .fetch_all(pool)
                .await
                .map_err(|error| error.to_string())?
            };
            json!({
                "trackIds":track_ids,
                "concurrentCount":settings.get("concurrentCount").and_then(Value::as_u64).unwrap_or(2),
                "resolution":settings.get("resolution").and_then(Value::as_str).unwrap_or("1080p"),
                "audio":settings.get("audio").and_then(Value::as_bool).unwrap_or(false),
            })
        }
        _ => {
            return Err(format!(
                "unsupported workflow node type: {}",
                node.node_type
            ));
        }
    };
    if let Some(object) = input.as_object_mut() {
        object.insert("upstreamOutputs".into(), upstream_outputs);
    }
    Ok(input)
}

async fn fail_orchestrated_node(
    pool: &PgPool,
    workflow_run_id: i64,
    node_run_id: i64,
    reason: &str,
) {
    let time = chrono::Utc::now().timestamp_millis();
    let _ = sqlx::query(
        "UPDATE toonflow.workflow_node_runs
         SET state='failed',error_reason=$2,finish_time=$3
         WHERE id=$1 AND state IN('pending','blocked')",
    )
    .bind(node_run_id)
    .bind(reason)
    .bind(time)
    .execute(pool)
    .await;
    let _ = sqlx::query(
        "UPDATE toonflow.workflow_runs
         SET state='failed',error_reason=$2,finish_time=$3 WHERE id=$1 AND state<>'cancelled'",
    )
    .bind(workflow_run_id)
    .bind(reason)
    .bind(time)
    .execute(pool)
    .await;
}

async fn orchestrate_workflow_run(state: ToonState, workflow_run_id: i64) {
    let loaded = sqlx::query_as::<_, (i64, i64, Value, Value)>(
        "SELECT r.project_id,r.script_id,r.input,d.definition
         FROM toonflow.workflow_runs r
         JOIN toonflow.workflow_definitions d ON d.id=r.workflow_definition_id
         WHERE r.id=$1",
    )
    .bind(workflow_run_id)
    .fetch_optional(&state.pool)
    .await;
    let Ok(Some((project_id, script_id, run_input, definition))) = loaded else {
        active_workflow_runs()
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&workflow_run_id);
        return;
    };
    let Ok(workflow) = serde_json::from_value::<WorkflowDefinition>(definition) else {
        fail_orchestrated_node(&state.pool, workflow_run_id, 0, "工作流定义无效").await;
        active_workflow_runs()
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&workflow_run_id);
        return;
    };
    let Ok(execution_order) = validate_workflow(&workflow) else {
        fail_orchestrated_node(&state.pool, workflow_run_id, 0, "工作流定义校验失败").await;
        active_workflow_runs()
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .remove(&workflow_run_id);
        return;
    };
    let mut outputs = HashMap::<String, Value>::new();
    for node_id in execution_order {
        let run_state: Option<String> =
            sqlx::query_scalar("SELECT state FROM toonflow.workflow_runs WHERE id=$1")
                .bind(workflow_run_id)
                .fetch_optional(&state.pool)
                .await
                .unwrap_or(None);
        if run_state
            .as_deref()
            .is_some_and(|value| matches!(value, "cancelled" | "failed" | "success"))
        {
            break;
        }
        let Some(node) = workflow.nodes.iter().find(|node| node.id == node_id) else {
            continue;
        };
        let node_run = sqlx::query_as::<_, (i64, String)>(
            "SELECT id,state FROM toonflow.workflow_node_runs
             WHERE workflow_run_id=$1 AND node_id=$2 ORDER BY attempt DESC LIMIT 1",
        )
        .bind(workflow_run_id)
        .bind(&node.id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);
        let Some((node_run_id, node_state)) = node_run else {
            continue;
        };
        if node_state == "skipped" {
            continue;
        }
        let upstream_outputs = workflow
            .edges
            .iter()
            .filter(|edge| edge.target == node.id)
            .filter_map(|edge| {
                outputs
                    .get(&edge.source)
                    .cloned()
                    .map(|output| (edge.source.clone(), output))
            })
            .collect::<serde_json::Map<_, _>>();
        let input = match orchestrated_node_input(
            &state.pool,
            project_id,
            script_id,
            node,
            &run_input,
            Value::Object(upstream_outputs),
        )
        .await
        {
            Ok(input) => input,
            Err(reason) => {
                fail_orchestrated_node(&state.pool, workflow_run_id, node_run_id, &reason).await;
                break;
            }
        };
        if let Err(error) = launch_node(&state, node_run_id, input).await {
            let reason = format!("{error:?}");
            fail_orchestrated_node(&state.pool, workflow_run_id, node_run_id, &reason).await;
            break;
        }
        loop {
            let state_output = sqlx::query_as::<_, (String, Option<Value>, Option<String>)>(
                "SELECT state,output,error_reason FROM toonflow.workflow_node_runs WHERE id=$1",
            )
            .bind(node_run_id)
            .fetch_optional(&state.pool)
            .await;
            match state_output {
                Ok(Some((node_state, output, _))) if node_state == "success" => {
                    outputs.insert(node.id.clone(), output.unwrap_or(Value::Null));
                    break;
                }
                Ok(Some((node_state, _, _)))
                    if matches!(node_state.as_str(), "failed" | "cancelled") =>
                {
                    break;
                }
                Ok(None) | Err(_) => break,
                _ => tokio::time::sleep(std::time::Duration::from_millis(500)).await,
            }
        }
        let terminal_state: Option<String> =
            sqlx::query_scalar("SELECT state FROM toonflow.workflow_node_runs WHERE id=$1")
                .bind(node_run_id)
                .fetch_optional(&state.pool)
                .await
                .unwrap_or(None);
        if terminal_state.as_deref() != Some("success") {
            break;
        }
    }
    active_workflow_runs()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .remove(&workflow_run_id);
}

fn schedule_workflow_run(state: ToonState, workflow_run_id: i64) {
    let (start_tx, start_rx) = tokio::sync::oneshot::channel();
    let handle = tokio::spawn(async move {
        let _ = start_rx.await;
        orchestrate_workflow_run(state, workflow_run_id).await;
    });
    active_workflow_runs()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .insert(workflow_run_id, handle.abort_handle());
    let _ = start_tx.send(());
}

pub async fn start_node(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<StartWorkflowNodeRequest>,
) -> Result<Json<ApiResponse<StartWorkflowNodeResponse>>, AppError> {
    require(&user, "toon:scene:update")?;
    recover_stale_node_runs(&state).await;
    let node_run_id: i64 = sqlx::query_scalar(
        "SELECT id FROM toonflow.workflow_node_runs
         WHERE workflow_run_id=$1 AND node_id=$2
         ORDER BY attempt DESC LIMIT 1",
    )
    .bind(request.workflow_run_id)
    .bind(&request.node_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to find workflow node run"))?
    .ok_or_else(|| AppError::not_found("workflow node run not found"))?;
    if let Some(agent_run_id) = request.agent_run_id {
        sqlx::query("UPDATE toonflow.workflow_node_runs SET agent_run_id=$2 WHERE id=$1")
            .bind(node_run_id)
            .bind(agent_run_id)
            .execute(&state.pool)
            .await
            .map_err(|_| AppError::internal("failed to link agent run"))?;
    }
    let response = launch_node(&state, node_run_id, request.input).await?;
    Ok(Json(ApiResponse::new(response)))
}

pub async fn node_state(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<NodeRunIdRequest>,
) -> Result<Json<ApiResponse<WorkflowNodeRunResponse>>, AppError> {
    require(&user, "toon:scene:read")?;
    recover_stale_node_runs(&state).await;
    let row = sqlx::query_as::<_, WorkflowNodeRunResponse>(
        "SELECT id,workflow_run_id,agent_run_id,node_id,node_type,attempt,state,input,output,error_reason,
                progress_current,progress_total,retry_of_id,start_time,finish_time,create_time
         FROM toonflow.workflow_node_runs WHERE id=$1",
    )
    .bind(request.id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to load workflow node run"))?
    .ok_or_else(|| AppError::not_found("workflow node run not found"))?;
    Ok(Json(ApiResponse::new(row)))
}

pub async fn run_state(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<WorkflowRunIdRequest>,
) -> Result<Json<ApiResponse<WorkflowRunDetail>>, AppError> {
    require(&user, "toon:scene:read")?;
    recover_stale_node_runs(&state).await;
    let run = sqlx::query_as::<
        _,
        (
            i64,
            i32,
            String,
            String,
            Value,
            Option<Value>,
            Option<String>,
            Option<i64>,
            Option<i64>,
            i64,
        ),
    >(
        "SELECT id,definition_version,state,trigger_type,input,output,error_reason,
                start_time,finish_time,create_time
         FROM toonflow.workflow_runs WHERE id=$1",
    )
    .bind(request.id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to load workflow run"))?
    .ok_or_else(|| AppError::not_found("workflow run not found"))?;
    let nodes = sqlx::query_as::<_, WorkflowNodeRunResponse>(
        "SELECT DISTINCT ON(node_id)
                id,workflow_run_id,agent_run_id,node_id,node_type,attempt,state,input,output,error_reason,
                progress_current,progress_total,retry_of_id,start_time,finish_time,create_time
         FROM toonflow.workflow_node_runs WHERE workflow_run_id=$1
         ORDER BY node_id,attempt DESC",
    )
    .bind(request.id)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to load workflow run nodes"))?;
    Ok(Json(ApiResponse::new(WorkflowRunDetail {
        id: run.0,
        definition_version: run.1,
        state: run.2,
        trigger_type: run.3,
        input: run.4,
        output: run.5,
        error_reason: run.6,
        start_time: run.7,
        finish_time: run.8,
        create_time: run.9,
        nodes,
    })))
}

pub async fn list_runs(
    user: CurrentUser,
    State(state): State<ToonState>,
    Query(query): Query<ListWorkflowRunsQuery>,
) -> Result<Json<ApiResponse<Vec<WorkflowRunSummary>>>, AppError> {
    require(&user, "toon:scene:read")?;
    let rows = sqlx::query_as::<_, WorkflowRunSummary>(
        "SELECT id,definition_version,state,trigger_type,error_reason,start_time,finish_time,create_time
         FROM toonflow.workflow_runs WHERE project_id=$1 AND script_id=$2
         ORDER BY create_time DESC,id DESC LIMIT 100",
    )
    .bind(query.project_id)
    .bind(query.script_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to list workflow runs"))?;
    Ok(Json(ApiResponse::new(rows)))
}

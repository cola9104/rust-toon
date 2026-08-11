use rust_toon_framework_web::AppError;
use serde_json::Value;
use sqlx::PgPool;

use crate::toonflow_agent_runtime;

pub(crate) fn memory_isolation_key(
    agent_type: &str,
    project_id: i64,
    script_id: Option<i64>,
) -> String {
    if agent_type == "productionAgent" {
        format!(
            "productionAgent:{project_id}:{}",
            script_id
                .map(|id| id.to_string())
                .unwrap_or_else(|| "none".into())
        )
    } else {
        format!("scriptAgent:{project_id}:project")
    }
}

pub(crate) async fn start(
    pool: &PgPool,
    call_id: i64,
    agent_type: &str,
    tool_name: &str,
    arguments: &Value,
    time: i64,
) -> Result<(), AppError> {
    sqlx::query("INSERT INTO toonflow.agent_tool_calls(id,agent_type,tool_name,arguments,state,create_time)VALUES($1,$2,$3,$4,'running',$5)")
        .bind(call_id).bind(agent_type).bind(tool_name).bind(arguments).bind(time)
        .execute(pool).await.map_err(|_| AppError::internal("failed to start tool call"))?;
    Ok(())
}

pub(crate) async fn succeed(pool: &PgPool, call_id: i64, value: &Value, time: i64) {
    sqlx::query(
        "UPDATE toonflow.agent_tool_calls SET result=$2,state='success',finish_time=$3 WHERE id=$1",
    )
    .bind(call_id)
    .bind(value)
    .bind(time)
    .execute(pool)
    .await
    .ok();
}

pub(crate) async fn fail(pool: &PgPool, call_id: i64, error: &AppError, time: i64) {
    sqlx::query("UPDATE toonflow.agent_tool_calls SET state='failed',error_reason=$2,finish_time=$3 WHERE id=$1")
        .bind(call_id).bind(format!("{error:?}")).bind(time).execute(pool).await.ok();
}

pub(crate) async fn remember_ui_execution(
    pool: &PgPool,
    call_id: i64,
    project_id: i64,
    script_id: i64,
    tool_name: &str,
    arguments: &Value,
    result: &Value,
    time: i64,
) {
    let memory_id = call_id + 1;
    let isolation_key = memory_isolation_key("productionAgent", project_id, Some(script_id));
    let content = format!("工具 {tool_name} 已执行。参数：{arguments}。结果：{result}");
    if sqlx::query("INSERT INTO toonflow.agent_memories(id,agent_type,isolation_key,role,content,create_time)VALUES($1,'productionAgent',$2,'assistant:execution',$3,$4)")
        .bind(memory_id).bind(isolation_key).bind(&content).bind(time).execute(pool).await.is_ok()
    {
        toonflow_agent_runtime::store_memory_embedding(pool, memory_id, &content).await;
    }
}

#[cfg(test)]
mod tests {
    use super::memory_isolation_key;

    #[test]
    fn isolates_project_and_production_memories_consistently() {
        assert_eq!(
            memory_isolation_key("scriptAgent", 101, None),
            "scriptAgent:101:project"
        );
        assert_eq!(
            memory_isolation_key("productionAgent", 101, Some(202)),
            "productionAgent:101:202"
        );
        assert_eq!(
            memory_isolation_key("productionAgent", 101, None),
            "productionAgent:101:none"
        );
    }
}

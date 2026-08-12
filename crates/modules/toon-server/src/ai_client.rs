use serde_json::Value;
use sqlx::PgPool;
use std::sync::atomic::{AtomicI64, Ordering};

static TASK_SEQUENCE: AtomicI64 = AtomicI64::new(0);

fn normalized_app_error(error: rust_toon_framework_web::AppError) -> String {
    if let Some(data) = error.data()
        && data.get("code").is_some()
        && data.get("category").is_some()
    {
        return data.to_string();
    }
    serde_json::json!({
        "code": format!("AI_REQUEST_{}", error.code()),
        "category": if error.status().is_server_error() { "internal" } else { "request" },
        "message": error.message(),
        "status": error.status().as_u16(),
        "retryable": error.status().is_server_error(),
    })
    .to_string()
}

fn task_id() -> i64 {
    chrono::Utc::now().timestamp_millis() * 1000
        + TASK_SEQUENCE.fetch_add(1, Ordering::Relaxed) % 1000
}

async fn recorded<T, F>(
    pool: &PgPool,
    task_class: &str,
    model: &str,
    description: &str,
    future: F,
) -> Result<T, String>
where
    F: std::future::Future<Output = Result<T, String>>,
{
    let id = task_id();
    sqlx::query("INSERT INTO toonflow.tasks(id,task_class,model,description,state,start_time) VALUES($1,$2,$3,$4,'running',$5)")
        .bind(id).bind(task_class).bind(model).bind(description).bind(chrono::Utc::now().timestamp_millis())
        .execute(pool).await.map_err(|error| format!("创建 AI 任务记录失败：{error}"))?;
    match future.await {
        Ok(value) => {
            sqlx::query("UPDATE toonflow.tasks SET state='success',reason=NULL WHERE id=$1")
                .bind(id)
                .execute(pool)
                .await
                .map_err(|error| format!("更新 AI 任务记录失败：{error}"))?;
            Ok(value)
        }
        Err(error) => {
            let _ = sqlx::query("UPDATE toonflow.tasks SET state='failed',reason=$2 WHERE id=$1")
                .bind(id)
                .bind(&error)
                .execute(pool)
                .await;
            Err(error)
        }
    }
}

async fn project_agent_model(
    pool: &PgPool,
    key: &str,
    project_id: i64,
) -> Result<(i64, i32, i32), String> {
    let row: Option<(Option<i64>, i32, i32, bool)> = sqlx::query_as(
        "SELECT coalesce(p.chat_model,d.model_config_id),d.temperature,d.max_output_tokens,d.disabled
         FROM toonflow.agent_deployments d
         LEFT JOIN toonflow.projects p ON p.id=$2
         WHERE d.key=$1",
    )
    .bind(key)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|error| error.to_string())?;
    let (model, temperature, tokens, disabled) =
        row.ok_or_else(|| format!("Agent {key} 未配置"))?;
    if disabled {
        return Err(format!("Agent {key} 已停用"));
    }
    Ok((
        model.ok_or_else(|| format!("Agent {key} 尚未绑定对话模型"))?,
        temperature,
        tokens,
    ))
}

async fn agent_model(pool: &PgPool, key: &str) -> Result<(i64, i32, i32), String> {
    let row: Option<(Option<i64>, i32, i32, bool)> = sqlx::query_as(
        "SELECT model_config_id,temperature,max_output_tokens,disabled FROM toonflow.agent_deployments WHERE key=$1",
    )
    .bind(key)
    .fetch_optional(pool)
    .await
    .map_err(|error| error.to_string())?;
    let (model, temperature, tokens, disabled) =
        row.ok_or_else(|| format!("Agent {key} 未配置"))?;
    if disabled {
        return Err(format!("Agent {key} 已停用"));
    }
    Ok((
        model.ok_or_else(|| format!("Agent {key} 尚未绑定统一 AI 模型"))?,
        temperature,
        tokens,
    ))
}

pub async fn text_tools(
    pool: &PgPool,
    key: &str,
    messages: Vec<Value>,
    tools: Vec<Value>,
) -> Result<Value, String> {
    let (model, temperature, tokens) = agent_model(pool, key).await?;
    recorded(pool, "text", &model.to_string(), key, async move {
        rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .chat_tools(
                model,
                messages,
                tools,
                Some(temperature as f64),
                (tokens > 0).then_some(tokens as u32),
            )
            .await
            .map_err(normalized_app_error)
    })
    .await
}

pub async fn project_text_tools(
    pool: &PgPool,
    key: &str,
    project_id: i64,
    messages: Vec<Value>,
    tools: Vec<Value>,
) -> Result<Value, String> {
    let (model, temperature, tokens) = project_agent_model(pool, key, project_id).await?;
    recorded(pool, "text", &model.to_string(), key, async move {
        rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .chat_tools(
                model,
                messages,
                tools,
                Some(temperature as f64),
                (tokens > 0).then_some(tokens as u32),
            )
            .await
            .map_err(normalized_app_error)
    })
    .await
}
fn chat_request(
    system: &str,
    user: &str,
    temperature: i32,
    tokens: i32,
) -> rust_toon_ai_api::ChatRequest {
    rust_toon_ai_api::ChatRequest {
        model: String::new(),
        messages: vec![
            rust_toon_ai_api::ChatMessage {
                role: "system".into(),
                content: system.into(),
            },
            rust_toon_ai_api::ChatMessage {
                role: "user".into(),
                content: user.into(),
            },
        ],
        temperature: Some(temperature as f64),
        max_tokens: (tokens > 0).then_some(tokens as u32),
    }
}
pub async fn project_text(
    pool: &PgPool,
    key: &str,
    project_id: i64,
    system: &str,
    user: &str,
) -> Result<String, String> {
    let (model, temperature, tokens) = project_agent_model(pool, key, project_id).await?;
    recorded(pool, "text", &model.to_string(), key, async move {
        rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .chat(model, chat_request(system, user, temperature, tokens))
            .await
            .map(|response| response.content)
            .map_err(normalized_app_error)
    })
    .await
}

pub async fn text(pool: &PgPool, key: &str, system: &str, user: &str) -> Result<String, String> {
    let (model, temperature, tokens) = agent_model(pool, key).await?;
    recorded(pool, "text", &model.to_string(), key, async move {
        rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .chat(model, chat_request(system, user, temperature, tokens))
            .await
            .map(|x| x.content)
            .map_err(normalized_app_error)
    })
    .await
}
pub async fn project_text_stream<F, Fut>(
    pool: &PgPool,
    key: &str,
    project_id: i64,
    system: &str,
    user: &str,
    on_delta: F,
) -> Result<String, String>
where
    F: FnMut(String) -> Fut,
    Fut: std::future::Future<Output = Result<(), String>>,
{
    let (model, temperature, tokens) = project_agent_model(pool, key, project_id).await?;
    recorded(pool, "text", &model.to_string(), key, async move {
        rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .chat_stream(
                model,
                chat_request(system, user, temperature, tokens),
                on_delta,
            )
            .await
            .map(|x| x.content)
            .map_err(normalized_app_error)
    })
    .await
}
fn model_id(value: &str, kind: &str) -> Result<i64, String> {
    value
        .parse()
        .map_err(|_| format!("{kind}模型必须是统一 AI 模型 ID"))
}
/// Generates an image with ordered visual references when the configured provider supports edits.
pub async fn image_with_references(
    pool: &PgPool,
    configured: &str,
    prompt: &str,
    size: &str,
    references: Vec<String>,
) -> Result<String, String> {
    let model = model_id(configured, "图片")?;
    recorded(pool, "image", &model.to_string(), "图片生成", async move {
        let mut last_error = String::new();
        for attempt in 1..=3 {
            match rust_toon_ai_server::AiModelFactory::new(pool.clone())
                .image(
                    model,
                    rust_toon_ai_api::ImageRequest {
                        prompt: prompt.into(),
                        size: size.into(),
                        references: references.clone(),
                    },
                )
                .await
            {
                Ok(response) => return Ok(response.url),
                Err(error) => {
                    last_error = normalized_app_error(error);
                    if attempt == 3 || !is_transient_model_error(&last_error) {
                        break;
                    }
                    tokio::time::sleep(std::time::Duration::from_secs(attempt as u64 * 2)).await;
                }
            }
        }
        Err(last_error)
    })
    .await
}

fn is_transient_model_error(error: &str) -> bool {
    let error = error.to_ascii_lowercase();
    [
        "rate limit",
        "429",
        "too many requests",
        "timeout",
        "timed out",
        "connection",
        "temporarily unavailable",
        "502",
        "503",
        "504",
    ]
    .iter()
    .any(|marker| error.contains(marker))
}
pub async fn video(pool: &PgPool, configured: &str, payload: Value) -> Result<String, String> {
    let model_id = model_id(configured, "视频")?;
    let config = rust_toon_ai_server::AiModelFactory::new(pool.clone())
        .config(model_id)
        .await
        .map_err(normalized_app_error)?;
    let capabilities = config.capabilities();
    let mode = payload
        .get("mode")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if !capabilities.video_modes.is_empty()
        && !mode.is_empty()
        && !capabilities.video_modes.iter().any(|value| value == mode)
    {
        return Err(format!("模型 {} 不支持视频模式 {mode}", config.name));
    }
    let duration = payload.get("duration").and_then(Value::as_i64);
    let resolution = payload.get("resolution").and_then(Value::as_str);
    if let (Some(duration), Some(resolution), Some(allowed)) = (
        duration,
        resolution,
        duration.and_then(|value| capabilities.duration_resolution_map.get(&value.to_string())),
    ) && !allowed.is_empty()
        && !allowed.iter().any(|value| value == resolution)
    {
        return Err(format!(
            "模型 {} 在 {duration} 秒时不支持分辨率 {resolution}",
            config.name
        ));
    }
    recorded(
        pool,
        "video",
        &model_id.to_string(),
        "视频生成",
        video_unrecorded(pool, model_id, payload),
    )
    .await
}

async fn video_unrecorded(pool: &PgPool, model_id: i64, payload: Value) -> Result<String, String> {
    let factory = rust_toon_ai_server::AiModelFactory::new(pool.clone());
    let response = factory
        .video(model_id, payload)
        .await
        .map_err(normalized_app_error)?;
    if !response.url.is_empty() {
        return Ok(response.url);
    }
    let task_id = response
        .task_id
        .ok_or_else(|| "视频响应缺少 URL 或任务 ID".to_string())?;
    let interval = std::env::var("AI_VIDEO_POLL_INTERVAL_SECONDS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(5)
        .max(1);
    let timeout = std::env::var("AI_VIDEO_POLL_TIMEOUT_SECONDS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(600)
        .max(interval);
    for _ in 0..timeout.div_ceil(interval) {
        tokio::time::sleep(std::time::Duration::from_secs(interval)).await;
        let result = factory
            .poll_video(model_id, &task_id)
            .await
            .map_err(normalized_app_error)?;
        if !result.url.is_empty() {
            return Ok(result.url);
        }
        let state = result
            .raw
            .pointer("/status")
            .or_else(|| result.raw.pointer("/state"))
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_ascii_lowercase();
        if matches!(
            state.as_str(),
            "failed" | "error" | "cancelled" | "canceled"
        ) {
            let reason = [
                "/error/message",
                "/error",
                "/message",
                "/failReason",
                "/data/error",
            ]
            .iter()
            .find_map(|path| result.raw.pointer(path).and_then(Value::as_str))
            .unwrap_or("上游视频任务失败");
            return Err(format!("视频任务 {task_id} 失败：{reason}"));
        }
    }
    Err(format!("视频任务 {task_id} 等待超时"))
}
pub async fn speech(
    pool: &PgPool,
    configured: &str,
    input: &str,
    voice: &str,
) -> Result<String, String> {
    let model = model_id(configured, "TTS")?;
    recorded(pool, "speech", &model.to_string(), "语音生成", async move {
        rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .speech(
                model,
                rust_toon_ai_api::SpeechRequest {
                    input: input.into(),
                    voice: voice.into(),
                    format: "mp3".into(),
                },
            )
            .await
            .map(|x| x.url)
            .map_err(normalized_app_error)
    })
    .await
}

#[cfg(test)]
mod tests {
    use super::is_transient_model_error;

    #[test]
    fn retries_rate_limits_and_network_failures() {
        assert!(is_transient_model_error("rate limit exceeded"));
        assert!(is_transient_model_error("HTTP 429 Too Many Requests"));
        assert!(is_transient_model_error("connection timed out"));
        assert!(is_transient_model_error("upstream returned 503"));
    }

    #[test]
    fn does_not_retry_prompt_rejections() {
        assert!(!is_transient_model_error(
            "input text may contain sensitive information"
        ));
    }
}

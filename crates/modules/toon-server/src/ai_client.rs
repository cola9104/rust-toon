use serde_json::Value;
use sqlx::PgPool;

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
pub async fn project_text_tools(
    pool: &PgPool,
    key: &str,
    project_id: i64,
    messages: Vec<Value>,
    tools: Vec<Value>,
) -> Result<Value, String> {
    let (model, temperature, tokens) = project_agent_model(pool, key, project_id).await?;
    rust_toon_ai_server::AiModelFactory::new(pool.clone())
        .chat_tools(
            model,
            messages,
            tools,
            Some(temperature as f64),
            (tokens > 0).then_some(tokens as u32),
        )
        .await
        .map_err(|error| error.to_string())
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
    rust_toon_ai_server::AiModelFactory::new(pool.clone())
        .chat(model, chat_request(system, user, temperature, tokens))
        .await
        .map(|response| response.content)
        .map_err(|error| error.to_string())
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
    rust_toon_ai_server::AiModelFactory::new(pool.clone())
        .chat_stream(
            model,
            chat_request(system, user, temperature, tokens),
            on_delta,
        )
        .await
        .map(|response| response.content)
        .map_err(|error| error.to_string())
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
    let model_id = model_id(configured, "图片")?;
    let mut last_error = String::new();
    for attempt in 1..=3 {
        match rust_toon_ai_server::AiModelFactory::new(pool.clone())
            .image(
                model_id,
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
                last_error = format!("{error:?}");
                if attempt == 3 || !is_transient_model_error(&last_error) {
                    break;
                }
                tokio::time::sleep(std::time::Duration::from_secs(attempt as u64 * 2)).await;
            }
        }
    }
    Err(last_error)
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
    let factory = rust_toon_ai_server::AiModelFactory::new(pool.clone());
    let response = factory
        .video(model_id, payload)
        .await
        .map_err(|e| format!("{e:?}"))?;
    if !response.url.is_empty() {
        return Ok(response.url);
    }
    let task_id = response
        .task_id
        .ok_or_else(|| "视频响应缺少 URL 或任务 ID".to_string())?;
    for _ in 0..120 {
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        let result = factory
            .poll_video(model_id, &task_id)
            .await
            .map_err(|e| format!("{e:?}"))?;
        if !result.url.is_empty() {
            return Ok(result.url);
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
    rust_toon_ai_server::AiModelFactory::new(pool.clone())
        .speech(
            model_id(configured, "TTS")?,
            rust_toon_ai_api::SpeechRequest {
                input: input.into(),
                voice: voice.into(),
                format: "mp3".into(),
            },
        )
        .await
        .map(|x| x.url)
        .map_err(|e| format!("{e:?}"))
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

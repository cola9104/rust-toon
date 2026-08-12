use async_trait::async_trait;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use futures_util::StreamExt;
use rust_toon_ai_api::{
    ChatRequest, ChatResponse, EmbeddingRequest, EmbeddingResponse, ImageRequest, MediaResponse,
    ModelConfig, SpeechRequest,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ProviderError {
    pub code: String,
    pub category: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub response_data: Option<Value>,
    pub retryable: bool,
}

impl ProviderError {
    fn encoded(self) -> String {
        serde_json::to_string(&self).unwrap_or(self.message)
    }
}

pub(crate) fn provider_app_error(error: String) -> rust_toon_framework_web::AppError {
    if let Ok(details) = serde_json::from_str::<ProviderError>(&error) {
        let message = details.message.clone();
        return rust_toon_framework_web::AppError::new(
            axum::http::StatusCode::BAD_GATEWAY,
            502,
            message,
        )
        .with_data(serde_json::to_value(details).unwrap_or(Value::Null));
    }
    rust_toon_framework_web::AppError::bad_request(error)
}

fn truncate(value: &str, limit: usize) -> String {
    value.chars().take(limit).collect()
}

fn transport_error(error: &reqwest::Error) -> String {
    let (code, message, retryable) = if error.is_timeout() {
        ("AI_UPSTREAM_TIMEOUT", "AI 服务响应超时", true)
    } else if error.is_connect() {
        ("AI_UPSTREAM_UNAVAILABLE", "无法连接 AI 服务", true)
    } else {
        ("AI_UPSTREAM_TRANSPORT", "AI 服务网络请求失败", false)
    };
    ProviderError {
        code: code.into(),
        category: "transport".into(),
        message: message.into(),
        status: error.status().map(|status| status.as_u16()),
        response_data: Some(json!({"summary": truncate(&error.to_string(), 1000)})),
        retryable,
    }
    .encoded()
}

async fn response_json(
    response: reqwest::Response,
    fallback: &str,
) -> Result<(reqwest::StatusCode, Value), String> {
    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|error| transport_error(&error))?;
    match serde_json::from_str(&body) {
        Ok(value) => Ok((status, value)),
        Err(_) if status.is_success() => Err(ProviderError {
            code: "AI_INVALID_RESPONSE".into(),
            category: "response".into(),
            message: format!("{fallback}：上游返回了无法解析的响应"),
            status: Some(status.as_u16()),
            response_data: Some(json!({"summary": truncate(&body, 1000)})),
            retryable: false,
        }
        .encoded()),
        Err(_) => Err(upstream_error(
            status,
            &Value::String(truncate(&body, 1000)),
            fallback,
        )),
    }
}

fn request_timeout() -> std::time::Duration {
    std::time::Duration::from_secs(
        std::env::var("AI_REQUEST_TIMEOUT_SECONDS")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(120),
    )
}

pub(crate) fn http_client() -> reqwest::Client {
    reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(15))
        .timeout(request_timeout())
        .build()
        .unwrap_or_else(|_| reqwest::Client::new())
}

pub(crate) async fn send_with_retry(
    request: reqwest::RequestBuilder,
) -> Result<reqwest::Response, String> {
    let template = request
        .try_clone()
        .ok_or_else(|| "AI 请求无法安全重试".to_string())?;
    for attempt in 0..3 {
        let current = if attempt == 0 {
            request
                .try_clone()
                .unwrap_or_else(|| template.try_clone().unwrap())
        } else {
            template.try_clone().unwrap()
        };
        match current.send().await {
            Ok(response) if response.status().is_server_error() && attempt < 2 => {}
            Ok(response) => return Ok(response),
            Err(error) if (error.is_connect() || error.is_timeout()) && attempt < 2 => {}
            Err(error) => return Err(transport_error(&error)),
        }
        tokio::time::sleep(std::time::Duration::from_millis(250 * (1 << attempt))).await;
    }
    Err(ProviderError {
        code: "AI_UPSTREAM_RETRY_EXHAUSTED".into(),
        category: "transport".into(),
        message: "AI 服务暂时不可用，请稍后重试".into(),
        status: None,
        response_data: None,
        retryable: true,
    }
    .encoded())
}

mod anthropic;
mod azure;
mod doubao;
mod gemini;
pub use anthropic::AnthropicProvider;
pub use azure::AzureOpenAiProvider;
pub use doubao::DouBaoMediaProvider;
pub use gemini::GeminiProvider;

fn value_as_id(value: &Value) -> Option<String> {
    value
        .as_str()
        .map(str::to_string)
        .or_else(|| value.as_i64().map(|v| v.to_string()))
}
fn task_id_from(value: &Value) -> Option<String> {
    [
        "/result",
        "/id",
        "/taskId",
        "/task_id",
        "/data/id",
        "/data/taskId",
    ]
    .iter()
    .find_map(|path| value.pointer(path).and_then(value_as_id))
}
fn media_url_from(value: &Value) -> Option<String> {
    [
        "/imageUrl",
        "/image_url",
        "/url",
        "/data/imageUrl",
        "/data/image_url",
        "/data/url",
    ]
    .iter()
    .find_map(|path| {
        value
            .pointer(path)
            .and_then(Value::as_str)
            .map(str::to_string)
    })
}

#[async_trait]
pub trait ChatProvider: Send + Sync {
    async fn chat(
        &self,
        config: &ModelConfig,
        request: &ChatRequest,
    ) -> Result<ChatResponse, String>;
}

pub struct OpenAiCompatibleProvider;

impl OpenAiCompatibleProvider {
    pub async fn raw_chat_with_header(
        &self,
        config: &ModelConfig,
        body: Value,
        auth_header: &str,
    ) -> Result<Value, String> {
        let path = config
            .config
            .get("textPath")
            .and_then(Value::as_str)
            .unwrap_or("/chat/completions");
        let mut builder = http_client()
            .post(format!("{}{}", config.url.trim_end_matches('/'), path))
            .json(&body);
        if !config.api_key.is_empty() {
            builder = if auth_header.eq_ignore_ascii_case("authorization") {
                builder.bearer_auth(config.api_key.trim_start_matches("Bearer "))
            } else {
                builder.header(auth_header, &config.api_key)
            }
        }
        let response = send_with_retry(builder).await?;
        let (status, value) = response_json(response, "模型工具请求失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "模型工具请求失败"));
        }
        Ok(value)
    }
    pub async fn chat_with_header(
        &self,
        config: &ModelConfig,
        request: &ChatRequest,
        auth_header: &str,
    ) -> Result<ChatResponse, String> {
        let path = config
            .config
            .get("textPath")
            .and_then(Value::as_str)
            .unwrap_or("/chat/completions");
        let mut body = json!({"model":request.model,"messages":request.messages,"temperature":request.temperature.unwrap_or(0.7)});
        if let Some(limit) = request.max_tokens {
            body["max_tokens"] = json!(limit);
        }
        let mut builder = http_client()
            .post(format!("{}{}", config.url.trim_end_matches('/'), path))
            .json(&body);
        if !config.api_key.is_empty() {
            builder = if auth_header.eq_ignore_ascii_case("authorization") {
                builder.bearer_auth(config.api_key.trim_start_matches("Bearer "))
            } else {
                builder.header(auth_header, &config.api_key)
            };
        }
        let response = send_with_retry(builder).await?;
        let (status, value) = response_json(response, "模型请求失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "模型请求失败"));
        }
        let content = value
            .pointer("/choices/0/message/content")
            .and_then(Value::as_str)
            .ok_or_else(|| "模型未返回文本".to_string())?
            .to_string();
        Ok(ChatResponse {
            content,
            reasoning: value
                .pointer("/choices/0/message/reasoning_content")
                .and_then(Value::as_str)
                .map(str::to_string),
            usage: value.get("usage").cloned().unwrap_or_else(|| json!({})),
        })
    }
    pub async fn chat_stream_with_header<F, Fut>(
        &self,
        config: &ModelConfig,
        request: &ChatRequest,
        mut on_delta: F,
        auth_header: &str,
    ) -> Result<ChatResponse, String>
    where
        F: FnMut(String) -> Fut,
        Fut: std::future::Future<Output = Result<(), String>>,
    {
        let path = config
            .config
            .get("textPath")
            .and_then(Value::as_str)
            .unwrap_or("/chat/completions");
        let mut body = json!({"model":request.model,"messages":request.messages,"temperature":request.temperature.unwrap_or(0.7),"stream":true});
        if let Some(limit) = request.max_tokens {
            body["max_tokens"] = json!(limit)
        }
        let mut builder = http_client()
            .post(format!("{}{}", config.url.trim_end_matches('/'), path))
            .json(&body);
        if !config.api_key.is_empty() {
            builder = if auth_header.eq_ignore_ascii_case("authorization") {
                builder.bearer_auth(config.api_key.trim_start_matches("Bearer "))
            } else {
                builder.header(auth_header, &config.api_key)
            }
        }
        let response = send_with_retry(builder).await?;
        let status = response.status();
        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            let value = serde_json::from_str(&body).unwrap_or(Value::String(body));
            return Err(upstream_error(status, &value, "模型请求失败"));
        }
        let mut stream = response.bytes_stream();
        let mut buffer = String::new();
        let mut content = String::new();
        while let Some(chunk) = stream.next().await {
            buffer.push_str(&String::from_utf8_lossy(
                &chunk.map_err(|error| transport_error(&error))?,
            ));
            while let Some(pos) = buffer.find('\n') {
                let line = buffer[..pos].trim().to_string();
                buffer.drain(..=pos);
                let Some(data) = line.strip_prefix("data:").map(str::trim) else {
                    continue;
                };
                if data == "[DONE]" {
                    continue;
                }
                let value: Value = serde_json::from_str(data).map_err(|e| e.to_string())?;
                if let Some(delta) = value
                    .pointer("/choices/0/delta/content")
                    .and_then(Value::as_str)
                {
                    content.push_str(delta);
                    on_delta(delta.into()).await?
                }
            }
        }
        if content.is_empty() {
            return Err("模型未返回流式文本".into());
        }
        Ok(ChatResponse {
            content,
            reasoning: None,
            usage: json!({}),
        })
    }
    fn request(&self, config: &ModelConfig, path: &str) -> reqwest::RequestBuilder {
        let mut request =
            http_client().post(format!("{}{}", config.url.trim_end_matches('/'), path));
        if !config.api_key.is_empty() {
            request = request.bearer_auth(config.api_key.trim_start_matches("Bearer "));
        }
        request
    }
    pub async fn image(
        &self,
        config: &ModelConfig,
        request: &ImageRequest,
    ) -> Result<MediaResponse, String> {
        let path = config
            .config
            .get("imageGeneratePath")
            .and_then(Value::as_str)
            .unwrap_or("/images/generations");
        let size = doubao::normalize_seedream_size(&config.model, &request.size);
        let mut body = json!({"model":config.model,"prompt":request.prompt,"size":size,"n":1});
        let path = if request.references.is_empty() {
            path
        } else if config.platform == rust_toon_ai_api::AiPlatform::DouBao.code() {
            body["image"] = json!(request.references);
            path
        } else {
            body["images"] = json!(
                request
                    .references
                    .iter()
                    .map(|url| json!({"image_url":url}))
                    .collect::<Vec<_>>()
            );
            config
                .config
                .get("imageEditPath")
                .and_then(Value::as_str)
                .unwrap_or("/images/edits")
        };
        // Ark occasionally resets negotiated HTTP/2 POST streams while the same endpoint remains
        // reachable over HTTP/1.1. Image jobs are long-lived and benefit from the conservative
        // transport; chat and video clients keep their existing negotiation behavior.
        let image_client = reqwest::Client::builder()
            .http1_only()
            .connect_timeout(std::time::Duration::from_secs(15))
            .timeout(request_timeout())
            .build()
            .map_err(|error| format!("创建图片 HTTP 客户端失败: {error:?}"))?;
        let mut image_request =
            image_client.post(format!("{}{}", config.url.trim_end_matches('/'), path));
        if !config.api_key.is_empty() {
            image_request = image_request.bearer_auth(config.api_key.trim_start_matches("Bearer "));
        }
        let response = send_with_retry(image_request.json(&body)).await?;
        let (status, value) = response_json(response, "图片生成失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "图片生成失败"));
        }
        let url = value
            .pointer("/data/0/url")
            .and_then(Value::as_str)
            .map(str::to_string)
            .or_else(|| {
                value
                    .pointer("/data/0/b64_json")
                    .and_then(Value::as_str)
                    .map(|data| format!("data:image/png;base64,{data}"))
            })
            .ok_or_else(|| "图片响应缺少 URL 或 Base64".to_string())?;
        Ok(MediaResponse {
            url,
            task_id: value.get("id").and_then(Value::as_str).map(str::to_string),
            raw: value,
        })
    }
    async fn midjourney_submit(
        &self,
        config: &ModelConfig,
        config_key: &str,
        default_path: &str,
        payload: Value,
        operation: &str,
    ) -> Result<MediaResponse, String> {
        let path = config
            .config
            .get(config_key)
            .and_then(Value::as_str)
            .unwrap_or(default_path);
        let value = self
            .raw_media_request(
                config,
                reqwest::Method::POST,
                path,
                Some(payload),
                operation,
            )
            .await?;
        let task_id = task_id_from(&value);
        let url = media_url_from(&value).unwrap_or_default();
        if task_id.is_none() && url.is_empty() {
            return Err(format!("{operation}响应缺少任务 ID 或图片 URL"));
        }
        Ok(MediaResponse {
            url,
            task_id,
            raw: value,
        })
    }
    pub async fn midjourney_imagine(
        &self,
        config: &ModelConfig,
        mut payload: Value,
    ) -> Result<MediaResponse, String> {
        payload["model"] = json!(config.model);
        self.midjourney_submit(
            config,
            "midjourneyImaginePath",
            "/mj/submit/imagine",
            payload,
            "Midjourney Imagine",
        )
        .await
    }
    pub async fn midjourney_action(
        &self,
        config: &ModelConfig,
        payload: Value,
    ) -> Result<MediaResponse, String> {
        self.midjourney_submit(
            config,
            "midjourneyActionPath",
            "/mj/submit/action",
            payload,
            "Midjourney Action",
        )
        .await
    }
    pub async fn poll_midjourney(
        &self,
        config: &ModelConfig,
        task_id: &str,
    ) -> Result<MediaResponse, String> {
        let template = config
            .config
            .get("midjourneyTaskPath")
            .and_then(Value::as_str)
            .unwrap_or("/mj/task/{taskId}/fetch");
        let path = template.replace("{taskId}", task_id);
        let value = self
            .raw_media_request(
                config,
                reqwest::Method::GET,
                &path,
                None,
                "Midjourney 任务查询",
            )
            .await?;
        Ok(MediaResponse {
            url: media_url_from(&value).unwrap_or_default(),
            task_id: Some(task_id.into()),
            raw: value,
        })
    }
    async fn raw_media_request(
        &self,
        config: &ModelConfig,
        method: reqwest::Method,
        path: &str,
        payload: Option<Value>,
        operation: &str,
    ) -> Result<Value, String> {
        let mut request = http_client().request(
            method,
            format!("{}{}", config.url.trim_end_matches('/'), path),
        );
        if !config.api_key.is_empty() {
            let header = config
                .config
                .get("authHeader")
                .and_then(Value::as_str)
                .unwrap_or("Authorization");
            request = if header.eq_ignore_ascii_case("authorization") {
                request.bearer_auth(config.api_key.trim_start_matches("Bearer "))
            } else {
                request.header(header, &config.api_key)
            };
        }
        if let Some(body) = payload {
            request = request.json(&body);
        }
        let response = send_with_retry(request).await?;
        let (status, value) = response_json(response, operation).await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, operation));
        }
        Ok(value)
    }
    pub async fn video(
        &self,
        config: &ModelConfig,
        mut payload: Value,
    ) -> Result<MediaResponse, String> {
        let path = config
            .config
            .get("videoGeneratePath")
            .and_then(Value::as_str)
            .unwrap_or("/videos/generations");
        payload["model"] = json!(config.model);
        let response = send_with_retry(self.request(config, path).json(&payload)).await?;
        let (status, value) = response_json(response, "视频生成失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "视频生成失败"));
        }
        let url = value
            .get("url")
            .or_else(|| value.pointer("/data/0/url"))
            .or_else(|| value.get("filePath"))
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        let task_id = value
            .get("id")
            .or_else(|| value.get("task_id"))
            .and_then(Value::as_str)
            .map(str::to_string);
        if url.is_empty() && task_id.is_none() {
            return Err("视频响应缺少 URL 或任务 ID".into());
        }
        Ok(MediaResponse {
            url,
            task_id,
            raw: value,
        })
    }
    pub async fn music(
        &self,
        config: &ModelConfig,
        mut payload: Value,
    ) -> Result<MediaResponse, String> {
        let path = config
            .config
            .get("musicGeneratePath")
            .and_then(Value::as_str)
            .unwrap_or("/music/generations");
        payload["model"] = json!(config.model);
        let response = send_with_retry(self.request(config, path).json(&payload)).await?;
        let (status, value) = response_json(response, "音乐生成失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "音乐生成失败"));
        }
        let url = value
            .get("audio_url")
            .or_else(|| value.get("audioUrl"))
            .or_else(|| value.pointer("/data/0/audio_url"))
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        let task_id = value
            .get("id")
            .or_else(|| value.get("task_id"))
            .and_then(Value::as_str)
            .map(str::to_string);
        if url.is_empty() && task_id.is_none() {
            return Err("音乐响应缺少音频 URL 或任务 ID".into());
        }
        Ok(MediaResponse {
            url,
            task_id,
            raw: value,
        })
    }
    pub async fn poll_music(
        &self,
        config: &ModelConfig,
        task_id: &str,
    ) -> Result<MediaResponse, String> {
        let template = config
            .config
            .get("musicTaskPath")
            .and_then(Value::as_str)
            .unwrap_or("/music/tasks/{taskId}");
        let path = template.replace("{taskId}", task_id);
        let mut request =
            http_client().get(format!("{}{}", config.url.trim_end_matches('/'), path));
        if !config.api_key.is_empty() {
            let header = config
                .config
                .get("authHeader")
                .and_then(Value::as_str)
                .unwrap_or("Authorization");
            request = if header.eq_ignore_ascii_case("authorization") {
                request.bearer_auth(config.api_key.trim_start_matches("Bearer "))
            } else {
                request.header(header, &config.api_key)
            }
        }
        let response = send_with_retry(request).await?;
        let (status, value) = response_json(response, "音乐任务查询失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "音乐任务查询失败"));
        }
        let url = value
            .get("audio_url")
            .or_else(|| value.get("audioUrl"))
            .or_else(|| value.pointer("/data/audio_url"))
            .or_else(|| value.pointer("/data/audioUrl"))
            .or_else(|| value.pointer("/data/0/audio_url"))
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        Ok(MediaResponse {
            url,
            task_id: Some(task_id.into()),
            raw: value,
        })
    }
    pub async fn speech(
        &self,
        config: &ModelConfig,
        request: &SpeechRequest,
    ) -> Result<MediaResponse, String> {
        let path = config
            .config
            .get("speechPath")
            .and_then(Value::as_str)
            .unwrap_or("/audio/speech");
        let response = send_with_retry(self.request(config,path).json(&json!({"model":config.model,"input":request.input,"voice":request.voice,"response_format":request.format}))).await?;
        let status = response.status();
        let content_type = response
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|value| value.to_str().ok())
            .unwrap_or("audio/mpeg")
            .to_string();
        let bytes = response
            .bytes()
            .await
            .map_err(|error| transport_error(&error))?;
        if !status.is_success() {
            let body = String::from_utf8_lossy(&bytes).into_owned();
            let value = serde_json::from_str(&body).unwrap_or(Value::String(body));
            return Err(upstream_error(status, &value, "语音生成失败"));
        }
        Ok(MediaResponse {
            url: format!("data:{content_type};base64,{}", STANDARD.encode(bytes)),
            task_id: None,
            raw: json!({}),
        })
    }
    pub async fn embedding(
        &self,
        config: &ModelConfig,
        request: &EmbeddingRequest,
    ) -> Result<EmbeddingResponse, String> {
        let path = config
            .config
            .get("embeddingPath")
            .and_then(Value::as_str)
            .unwrap_or("/embeddings");
        let response = send_with_retry(
            self.request(config, path)
                .json(&json!({"model":config.model,"input":request.inputs})),
        )
        .await?;
        let (status, value) = response_json(response, "Embedding 请求失败").await?;
        if !status.is_success() {
            return Err(upstream_error(status, &value, "Embedding 请求失败"));
        }
        let embeddings = value
            .get("data")
            .and_then(Value::as_array)
            .ok_or_else(|| "Embedding 响应缺少 data".to_string())?
            .iter()
            .map(|item| {
                item.get("embedding")
                    .and_then(Value::as_array)
                    .ok_or_else(|| "Embedding 数据无效".to_string())?
                    .iter()
                    .map(|number| {
                        number
                            .as_f64()
                            .map(|value| value as f32)
                            .ok_or_else(|| "Embedding 数值无效".to_string())
                    })
                    .collect()
            })
            .collect::<Result<Vec<Vec<f32>>, String>>()?;
        Ok(EmbeddingResponse {
            embeddings,
            usage: value.get("usage").cloned().unwrap_or_else(|| json!({})),
        })
    }
    pub async fn chat_stream<F, Fut>(
        &self,
        config: &ModelConfig,
        request: &ChatRequest,
        on_delta: F,
    ) -> Result<ChatResponse, String>
    where
        F: FnMut(String) -> Fut,
        Fut: std::future::Future<Output = Result<(), String>>,
    {
        self.chat_stream_with_header(config, request, on_delta, "authorization")
            .await
    }
}
pub(super) fn upstream_error(status: reqwest::StatusCode, value: &Value, fallback: &str) -> String {
    let upstream_message = value
        .pointer("/error/message")
        .and_then(Value::as_str)
        .or_else(|| value.get("message").and_then(Value::as_str))
        .unwrap_or(fallback)
        .to_string();
    let message = match status.as_u16() {
        401 | 403 => "AI 服务认证失败，请检查模型密钥与权限".to_string(),
        408 | 504 => "AI 服务响应超时，请稍后重试".to_string(),
        429 => "AI 服务请求过于频繁，请稍后重试".to_string(),
        500..=599 => "AI 服务暂时不可用，请稍后重试".to_string(),
        _ => upstream_message.clone(),
    };
    ProviderError {
        code: format!("AI_UPSTREAM_HTTP_{}", status.as_u16()),
        category: "upstream".into(),
        message,
        status: Some(status.as_u16()),
        response_data: Some(json!({
            "message": upstream_message,
            "summary": truncate(&value.to_string(), 1000)
        })),
        retryable: status.is_server_error() || status.as_u16() == 429,
    }
    .encoded()
}

#[async_trait]
impl ChatProvider for OpenAiCompatibleProvider {
    async fn chat(
        &self,
        config: &ModelConfig,
        request: &ChatRequest,
    ) -> Result<ChatResponse, String> {
        self.chat_with_header(config, request, "authorization")
            .await
    }
}

#[cfg(test)]
mod structured_error_tests {
    use super::{ProviderError, provider_app_error, upstream_error};
    use reqwest::StatusCode;
    use serde_json::json;

    #[test]
    fn preserves_upstream_status_and_response_summary() {
        let encoded = upstream_error(
            StatusCode::TOO_MANY_REQUESTS,
            &json!({"error":{"message":"quota exceeded"}}),
            "模型请求失败",
        );
        let error: ProviderError = serde_json::from_str(&encoded).unwrap();
        assert_eq!(error.code, "AI_UPSTREAM_HTTP_429");
        assert_eq!(error.status, Some(429));
        assert!(error.retryable);
        assert_eq!(error.message, "AI 服务请求过于频繁，请稍后重试");
        assert_eq!(
            error.response_data.unwrap()["message"],
            json!("quota exceeded")
        );
    }

    #[test]
    fn maps_provider_details_into_http_error_data() {
        let encoded = upstream_error(
            StatusCode::UNAUTHORIZED,
            &json!({"message":"invalid token"}),
            "模型请求失败",
        );
        let error = provider_app_error(encoded);
        assert_eq!(error.status(), StatusCode::BAD_GATEWAY);
        assert_eq!(error.data().unwrap()["status"], json!(401));
    }
}

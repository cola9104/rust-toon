use crate::{ToonState, toonflow_agents};
use axum::{
    extract::{
        Path, Query, State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    response::IntoResponse,
};
use futures_util::{SinkExt, StreamExt};
use rust_toon_framework_web::AppError;
use serde::Deserialize;
use serde_json::{Value, json};
use tokio::sync::watch;
use tracing::warn;

// ---------------------------------------------------------------------------
// Connection auth params (query string)
// ---------------------------------------------------------------------------
#[derive(Deserialize)]
pub(crate) struct WsParams {
    token: String,
    #[serde(rename = "isolationKey")]
    isolation_key: String,
    #[serde(rename = "projectId")]
    project_id: i64,
    #[serde(rename = "scriptId")]
    script_id: Option<i64>,
}

// ---------------------------------------------------------------------------
// Incoming client messages
// ---------------------------------------------------------------------------
#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
enum ClientMessage {
    #[serde(rename = "chat")]
    Chat { content: String },
    #[serde(rename = "stop")]
    Stop,
    #[serde(rename = "updateThinkConfig")]
    ThinkConfig {
        think: bool,
        #[serde(rename = "thinkLevel")]
        think_level: i32,
    },
    #[serde(rename = "updateContext")]
    UpdateContext {
        #[serde(rename = "isolationKey")]
        isolation_key: String,
        #[serde(rename = "projectId")]
        project_id: i64,
        #[serde(rename = "scriptId")]
        script_id: Option<i64>,
    },
}

// ---------------------------------------------------------------------------
// Outgoing event builders (mirrors Toonflow-app socket protocol)
// ---------------------------------------------------------------------------

fn uuid() -> String {
    uuid::Uuid::new_v4().to_string()
}

fn normalized_error(error: &str) -> Value {
    let Ok(mut details) = serde_json::from_str::<Value>(error) else {
        return json!({
            "error": error,
            "errorCode": "AGENT_EXECUTION_FAILED",
            "errorCategory": "agent"
        });
    };
    let message = details
        .get("message")
        .and_then(Value::as_str)
        .unwrap_or("AI 服务请求失败")
        .to_string();
    let code = details
        .get("code")
        .cloned()
        .unwrap_or_else(|| json!("AI_REQUEST_FAILED"));
    let category = details
        .get("category")
        .cloned()
        .unwrap_or_else(|| json!("unknown"));
    let Some(object) = details.as_object_mut() else {
        return json!({ "error": message, "errorCode": code, "errorCategory": category });
    };
    object.insert("error".into(), json!(message));
    object.insert("errorCode".into(), code);
    object.insert("errorCategory".into(), category);
    details
}

fn friendly_error(error: &str) -> String {
    normalized_error(error)
        .get("error")
        .and_then(Value::as_str)
        .unwrap_or(error)
        .to_string()
}

#[cfg(test)]
mod error_tests {
    use super::{friendly_error, normalized_error};
    use serde_json::json;

    #[test]
    fn maps_structured_ai_errors_without_breaking_legacy_error_field() {
        let source = json!({
            "code":"AI_UPSTREAM_HTTP_429",
            "category":"upstream",
            "message":"AI 服务请求过于频繁，请稍后重试",
            "status":429,
            "responseData":{"summary":"quota exceeded"},
            "retryable":true
        })
        .to_string();
        let result = normalized_error(&source);
        assert_eq!(result["error"], json!("AI 服务请求过于频繁，请稍后重试"));
        assert_eq!(result["errorCode"], json!("AI_UPSTREAM_HTTP_429"));
        assert_eq!(result["status"], json!(429));
        assert_eq!(friendly_error(&source), "AI 服务请求过于频繁，请稍后重试");
    }

    #[test]
    fn keeps_plain_agent_errors_compatible() {
        let result = normalized_error("工具执行失败");
        assert_eq!(result["error"], json!("工具执行失败"));
        assert_eq!(result["errorCategory"], json!("agent"));
    }
}

/// Shared sender that agent execution uses to push events to the WebSocket.
#[derive(Clone)]
pub struct WsEmitter {
    tx: tokio::sync::mpsc::UnboundedSender<Message>,
}

impl WsEmitter {
    fn send_json(&self, value: &Value) {
        let _ = self.tx.send(Message::Text(value.to_string().into()));
    }

    /// Create a new message bubble. Returns (message_id, datetime).
    pub fn new_message(&self, name: &str, role: &str) -> (String, String) {
        let id = uuid();
        let datetime = chrono::Utc::now().to_rfc3339();
        self.send_json(&json!({
            "event": "message",
            "data": {
                "id": id,
                "role": role,
                "name": name,
                "status": "pending",
                "datetime": datetime,
                "content": []
            }
        }));
        (id, datetime)
    }

    /// Update a message's status.
    pub fn update_message(&self, id: &str, status: &str, error: Option<&str>) {
        let mut payload = json!({
            "event": "message:update",
            "data": { "id": id, "status": status }
        });
        if let Some(err) = error {
            payload["data"]["ext"] = normalized_error(err);
        }
        self.send_json(&payload);
    }

    /// Add a content block to a message. Returns content_id.
    pub fn add_content(&self, message_id: &str, content_type: &str, data: &Value) -> String {
        let content_id = uuid();
        let status = match content_type {
            "thinking" | "toolcall" => "pending",
            _ => "pending",
        };
        self.send_json(&json!({
            "event": "content:add",
            "data": {
                "messageId": message_id,
                "content": {
                    "type": content_type,
                    "id": content_id,
                    "data": data,
                    "status": status
                }
            }
        }));
        content_id
    }

    /// Stream-update a content block (append or merge).
    pub fn update_content(
        &self,
        message_id: &str,
        content_id: &str,
        content_type: &str,
        data: &Value,
        strategy: &str,
        status: &str,
    ) {
        self.send_json(&json!({
            "event": "content:update",
            "data": {
                "messageId": message_id,
                "contentId": content_id,
                "type": content_type,
                "data": data,
                "strategy": strategy,
                "status": status
            }
        }));
    }

    /// Convenience: append text delta to a text content block.
    pub fn text_delta(&self, message_id: &str, content_id: &str, text: &str) {
        self.update_content(
            message_id,
            content_id,
            "text",
            &json!(text),
            "append",
            "streaming",
        );
    }

    /// Convenience: complete a text content block.
    pub fn text_complete(&self, message_id: &str, content_id: &str) {
        self.update_content(
            message_id,
            content_id,
            "text",
            &json!(null),
            "append",
            "complete",
        );
    }

    /// Convenience: add and stream a toolcall content block. Returns content_id.
    pub fn tool_call_start(&self, message_id: &str, tool_call_id: &str, tool_name: &str) -> String {
        self.add_content(
            message_id,
            "toolcall",
            &json!({
                "toolCallId": tool_call_id,
                "toolCallName": tool_name,
                "parentMessageId": message_id
            }),
        )
    }

    /// Convenience: append tool call args chunk.
    pub fn tool_call_args(
        &self,
        message_id: &str,
        content_id: &str,
        tool_call_id: &str,
        chunk: &str,
    ) {
        self.update_content(
            message_id,
            content_id,
            "toolcall",
            &json!({ "toolCallId": tool_call_id, "args": chunk }),
            "append",
            "streaming",
        );
    }

    /// Convenience: finalize a tool call with success.
    pub fn tool_call_success(
        &self,
        message_id: &str,
        content_id: &str,
        tool_call_id: &str,
        result: &str,
    ) {
        self.update_content(
            message_id,
            content_id,
            "toolcall",
            &json!({ "toolCallId": tool_call_id, "result": result }),
            "merge",
            "complete",
        );
    }

    /// Convenience: finalize a tool call with error.
    pub fn tool_call_error(
        &self,
        message_id: &str,
        content_id: &str,
        tool_call_id: &str,
        error: &str,
    ) {
        self.update_content(
            message_id,
            content_id,
            "toolcall",
            &json!({ "toolCallId": tool_call_id, "result": error }),
            "merge",
            "error",
        );
    }

    /// Convenience: thinking block start. Returns content_id.
    pub fn thinking_start(&self, message_id: &str, title: &str) -> String {
        self.add_content(
            message_id,
            "thinking",
            &json!({ "title": title, "text": "" }),
        )
    }

    /// Convenience: append thinking text.
    pub fn thinking_append(&self, message_id: &str, content_id: &str, text: &str) {
        self.update_content(
            message_id,
            content_id,
            "thinking",
            &json!({ "text": text }),
            "append",
            "streaming",
        );
    }

    /// Convenience: complete thinking block.
    pub fn thinking_complete(&self, message_id: &str, content_id: &str, title: &str, text: &str) {
        self.update_content(
            message_id,
            content_id,
            "thinking",
            &json!({ "title": title, "text": text }),
            "merge",
            "complete",
        );
    }
}

// ---------------------------------------------------------------------------
// WebSocket upgrade handler
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
pub(crate) struct AgentPath {
    agent: String,
}

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<ToonState>,
    Path(path): Path<AgentPath>,
    Query(params): Query<WsParams>,
) -> Result<impl IntoResponse, AppError> {
    // Verify JWT token
    let claims = state
        .tokens
        .verify_access_token(&params.token)
        .map_err(|_| AppError::unauthorized("invalid token"))?;

    let agent_type = match path.agent.as_str() {
        "productionAgent" => "productionAgent",
        _ => "scriptAgent",
    };

    // Validate agent type
    let _ = toonflow_agents::agent_key_for(agent_type).map_err(|e| AppError::bad_request(&e))?;

    let user_id = claims.user.user_id;

    Ok(ws.on_upgrade(move |socket| {
        handle_socket(socket, state, params, agent_type.to_string(), user_id)
    }))
}

async fn handle_socket(
    socket: WebSocket,
    state: ToonState,
    mut params: WsParams,
    agent_type: String,
    _user_id: String,
) {
    let (mut ws_tx, mut ws_rx) = socket.split();

    // Create a channel for the emitter
    let (emitter_tx, mut emitter_rx) = tokio::sync::mpsc::unbounded_channel::<Message>();

    // Spawn a task to forward emitter messages to the WebSocket
    let forward_handle = tokio::spawn(async move {
        while let Some(msg) = emitter_rx.recv().await {
            if ws_tx.send(msg).await.is_err() {
                break;
            }
        }
    });

    let emitter = WsEmitter { tx: emitter_tx };
    let heartbeat_tx = emitter.tx.clone();
    let heartbeat_handle = tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
        interval.tick().await;
        loop {
            interval.tick().await;
            if heartbeat_tx.send(Message::Ping(Vec::new().into())).is_err() {
                break;
            }
        }
    });

    // Resolve agent key
    let agent_key = match toonflow_agents::agent_key_for(&agent_type) {
        Ok(k) => k.to_string(),
        Err(_) => return,
    };

    // Think config defaults
    let mut think = false;
    let mut think_level: i32 = 0;

    // Abort controller
    let (mut abort_tx, _abort_rx) = watch::channel(false);

    // Restore historical messages as chat bubbles
    let memories: Vec<toonflow_agents::MemoryRow> = sqlx::query_as(
        "SELECT id,role,content,memory_type,create_time FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='message' ORDER BY create_time",
    )
    .bind(&agent_type)
    .bind(&params.isolation_key)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    for mem in &memories {
        let role = if mem.role.starts_with("user") {
            "user"
        } else {
            "assistant"
        };
        let name = if role == "user" {
            "你"
        } else {
            if mem.role.contains("execution:storySkeleton")
                || mem.role.contains("execution:adaptationStrategy")
                || mem.role.contains("execution:script")
            {
                "编剧"
            } else if mem.role.contains("supervision") {
                "编辑"
            } else {
                "统筹"
            }
        };
        let (mid, _dt) = emitter.new_message(name, role);
        let cid = emitter.add_content(&mid, "text", &json!(""));
        emitter.text_delta(&mid, &cid, &mem.content);
        emitter.text_complete(&mid, &cid);
        emitter.update_message(&mid, "complete", None);
    }

    // If no history, send proactive greeting
    let has_user_msg = memories.iter().any(|m| m.role.starts_with("user"));
    if !has_user_msg {
        let (greeting_id, _dt) = emitter.new_message("统筹", "assistant");
        let greeting_cid = emitter.add_content(&greeting_id, "text", &json!(""));
        let greeting = if agent_type == "scriptAgent" {
            "你好！我是剧本创作 Agent，我已读取当前项目的类型、画风等配置。\n\n需要我为你生成剧本吗？"
        } else {
            "你好！我是生产制作 Agent。我可以帮你进行分镜设计、视频生成等制片工作。\n\n请选择剧本后告诉我你的需求。"
        };
        emitter.text_delta(&greeting_id, &greeting_cid, greeting);
        emitter.text_complete(&greeting_id, &greeting_cid);
        emitter.update_message(&greeting_id, "complete", None);
    }

    // Main message loop
    loop {
        let msg_result =
            match tokio::time::timeout(std::time::Duration::from_secs(90), ws_rx.next()).await {
                Ok(Some(result)) => result,
                Ok(None) | Err(_) => break,
            };
        let msg = match msg_result {
            Ok(m) => m,
            Err(_) => break,
        };

        let text = match msg {
            Message::Text(t) => t,
            Message::Close(_) => break,
            _ => continue,
        };

        // Parse client message
        let client_msg: ClientMessage = match serde_json::from_str(&text) {
            Ok(m) => m,
            Err(_) => {
                warn!("invalid client ws message: {text}");
                continue;
            }
        };

        match client_msg {
            ClientMessage::Chat { content } => {
                if content.trim().is_empty() {
                    continue;
                }

                // Create user message bubble
                let (user_mid, _dt) = emitter.new_message("你", "user");
                let user_cid = emitter.add_content(&user_mid, "text", &json!(""));
                emitter.text_delta(&user_mid, &user_cid, &content);
                emitter.text_complete(&user_mid, &user_cid);
                emitter.update_message(&user_mid, "complete", None);

                // Create assistant message bubble
                let agent_name = "统筹";
                let (msg_id, _msg_dt) = emitter.new_message(agent_name, "assistant");
                let text_cid = emitter.add_content(&msg_id, "text", &json!(""));

                // Build the agent request
                let request = toonflow_agents::ChatRequest {
                    agent_type: agent_type.clone(),
                    isolation_key: params.isolation_key.clone(),
                    project_id: params.project_id,
                    script_id: params.script_id,
                    content: content.clone(),
                    think,
                    think_level,
                };

                // Create fresh abort channel for this run
                // Cancel the previous run, but keep this WebSocket session
                // alive so the user can immediately submit another message.
                let _ = abort_tx.send(true);
                let (new_abort_tx, new_abort_rx) = watch::channel(false);
                abort_tx = new_abort_tx;

                // Spawn agent execution
                let exec_emitter = emitter.clone();
                let exec_state = state.clone();
                let exec_agent_key = agent_key.clone();
                let exec_msg_id = msg_id.clone();
                let exec_text_cid = text_cid.clone();
                let exec_abort_rx = new_abort_rx;

                tokio::spawn(async move {
                    let result = toonflow_agents::run_with_emitter(
                        &exec_state,
                        &request,
                        &exec_agent_key,
                        &exec_emitter,
                        &exec_msg_id,
                        &exec_text_cid,
                        exec_abort_rx,
                    )
                    .await;

                    match result {
                        Ok(_) => {
                            exec_emitter.text_complete(&exec_msg_id, &exec_text_cid);
                            exec_emitter.update_message(&exec_msg_id, "complete", None);
                        }
                        Err(error) => {
                            let friendly = friendly_error(&error);
                            exec_emitter.text_delta(
                                &exec_msg_id,
                                &exec_text_cid,
                                &format!("\n\n错误：{friendly}"),
                            );
                            exec_emitter.update_message(&exec_msg_id, "error", Some(&error));
                        }
                    }
                });
            }

            ClientMessage::Stop => {
                let _ = abort_tx.send(true);
            }

            ClientMessage::ThinkConfig {
                think: t,
                think_level: tl,
            } => {
                think = t;
                think_level = tl.clamp(0, 3);
            }
            ClientMessage::UpdateContext {
                isolation_key,
                project_id,
                script_id,
            } => {
                params.isolation_key = isolation_key;
                params.project_id = project_id;
                params.script_id = script_id;
                emitter.send_json(&json!({"event":"updateContext:ack","data":{"success":true}}));
            }
        }
    }

    // Cleanup
    forward_handle.abort();
    heartbeat_handle.abort();
}

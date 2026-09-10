use std::{net::SocketAddr, time::Instant};

use axum::{
    body::{Body, to_bytes},
    extract::{ConnectInfo, Request, State},
    http::{HeaderMap, Uri},
    middleware::Next,
    response::Response,
};
use rust_toon_framework_common::is_health_probe_path;
use rust_toon_framework_database::PgPool;
use rust_toon_framework_security::CurrentUser;

const MAX_AUDIT_BODY_BYTES: usize = 512 * 1024;

#[derive(Clone)]
pub struct AuditState {
    pool: PgPool,
}

impl AuditState {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

pub async fn record(
    State(state): State<AuditState>,
    request: Request<Body>,
    next: Next,
) -> Response {
    if is_health_probe_path(request.uri().path()) {
        return next.run(request).await;
    }
    let started_at = chrono::Utc::now().naive_utc();
    let timer = Instant::now();
    let method = request.method().to_string();
    let uri = request.uri().clone();
    let path = audit_path(&uri);
    let authenticated_id = request.extensions().get::<CurrentUser>()
        .map(|user| user.user_id.clone());
    let peer_ip = request.extensions().get::<ConnectInfo<SocketAddr>>()
        .map(|peer| peer.0.ip());
    let request_headers = request.headers().clone();
    let user_agent = request_headers
        .get("user-agent")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default()
        .chars()
        .take(500)
        .collect::<String>();
    let request_trace_id = request_headers
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map(str::to_string);
    let user_ip = peer_ip.map(|ip| ip.to_string());
    let (request, request_body) = capture_request(request, &request_headers, &uri).await;
    let request_params = request_preview(&method, &uri, &request_headers, &request_body);
    let response = next.run(request).await;
    let status = response.status().as_u16() as i32;
    let trace_id = request_trace_id
        .or_else(|| {
            response
                .headers()
                .get("x-request-id")
                .and_then(|value| value.to_str().ok())
                .map(str::to_string)
        })
        .unwrap_or_default();
    let (response, response_body) = capture_response(response, status).await;
    let duration = timer.elapsed().as_millis().min(i32::MAX as u128) as i32;
    let ended_at = chrono::Utc::now().naive_utc();
    let module = uri
        .path()
        .trim_start_matches('/')
        .split('/')
        .next()
        .unwrap_or("gateway")
        .to_string();
    let (operate_name, operate_type) = operation_metadata(&method, uri.path());
    let pool = state.pool.clone();
    tokio::spawn(async move {
        // CurrentUser uses the stable UUID identity; logs use system_users.id.
        let user_id: Option<i64> = match authenticated_id {
            Some(id) => sqlx::query_scalar(
                "SELECT id FROM system_users WHERE md5('yudao-user:' || id::text)::uuid::text=$1",
            ).bind(id).fetch_optional(&pool).await.unwrap_or(None),
            None => None,
        };
        let user_type: Option<i16> = user_id.map(|_| 2);
        let _ = sqlx::query(
            "INSERT INTO infra_api_access_log(
                trace_id, application_name, request_method, request_url, request_params,
                response_body, user_ip, user_agent, operate_module, operate_name, operate_type,
                begin_time, end_time, duration, result_code, result_msg, user_id, user_type
             ) VALUES($1,'rust-toon-gateway',$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)",
        )
        .bind(trace_id)
        .bind(method)
        .bind(path)
        .bind(request_params)
        .bind(response_body)
        .bind(user_ip)
        .bind(user_agent)
        .bind(module)
        .bind(operate_name)
        .bind(operate_type)
        .bind(started_at)
        .bind(ended_at)
        .bind(duration)
        .bind(status)
        .bind(if status >= 400 { "failed" } else { "ok" })
        .bind(user_id)
        .bind(user_type)
        .execute(&pool)
        .await;
    });
    response
}

fn audit_path(uri: &Uri) -> String {
    uri.path_and_query()
        .map(|value| value.as_str())
        .unwrap_or_else(|| uri.path())
        .chars()
        .take(1024)
        .collect()
}

async fn capture_request(
    request: Request<Body>,
    headers: &HeaderMap,
    uri: &Uri,
) -> (Request<Body>, String) {
    let (parts, body) = request.into_parts();
    if !can_capture_body(headers) {
        return (Request::from_parts(parts, body), String::new());
    }
    match to_bytes(body, usize::MAX).await {
        Ok(bytes) => (
            Request::from_parts(parts, Body::from(bytes.clone())),
            bytes_preview(&bytes),
        ),
        Err(_) => (
            Request::from_parts(parts, Body::empty()),
            format!("[request body could not be read: {uri}]"),
        ),
    }
}

fn request_preview(method: &str, uri: &Uri, headers: &HeaderMap, body: &str) -> String {
    let mut output = format!("{method} {}\n{}", uri, headers_preview(headers));
    if !body.is_empty() {
        output.push_str("\n");
        output.push_str(body);
    }
    output
}

async fn capture_response(response: Response, status: i32) -> (Response, String) {
    let (parts, body) = response.into_parts();
    let headers = parts.headers.clone();
    let status_line = format!("HTTP/1.1 {status}\n{}", headers_preview(&headers));
    if !can_capture_body(&headers) {
        return (
            Response::from_parts(parts, body),
            format!("{status_line}\n[streaming or binary body not captured]"),
        );
    }
    match to_bytes(body, usize::MAX).await {
        Ok(bytes) => {
            let text = bytes_preview(&bytes);
            let preview = if text.is_empty() {
                status_line
            } else {
                format!("{status_line}\n{text}")
            };
            (Response::from_parts(parts, Body::from(bytes)), preview)
        }
        Err(_) => (
            Response::from_parts(parts, Body::empty()),
            format!("{status_line}\n[response body exceeded {MAX_AUDIT_BODY_BYTES} bytes]"),
        ),
    }
}

fn can_capture_body(headers: &HeaderMap) -> bool {
    let length = headers
        .get("content-length")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.parse::<usize>().ok());
    if length.is_some_and(|value| value > MAX_AUDIT_BODY_BYTES) {
        return false;
    }
    let content_type = headers
        .get("content-type")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default()
        .to_ascii_lowercase();
    !content_type.contains("text/event-stream")
        && !content_type.contains("application/octet-stream")
        && !content_type.starts_with("image/")
        && !content_type.starts_with("audio/")
        && !content_type.starts_with("video/")
}

fn bytes_preview(bytes: &[u8]) -> String {
    let truncated = bytes.len() > MAX_AUDIT_BODY_BYTES;
    let preview = String::from_utf8_lossy(&bytes[..bytes.len().min(MAX_AUDIT_BODY_BYTES)]);
    if truncated {
        format!("{preview}\n[body truncated at {MAX_AUDIT_BODY_BYTES} bytes]")
    } else {
        preview.into_owned()
    }
}

fn headers_preview(headers: &HeaderMap) -> String {
    headers
        .iter()
        .filter_map(|(name, value)| value.to_str().ok().map(|value| format!("{name}: {value}")))
        .collect::<Vec<_>>()
        .join("\n")
}

fn operation_metadata(method: &str, path: &str) -> (String, i16) {
    let segments = path
        .trim_matches('/')
        .split('/')
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    let action = segments.last().copied().unwrap_or("request");
    let resource = if action.parse::<i64>().is_ok()
        || matches!(
        action,
        "page" | "list" | "get" | "create" | "update" | "delete" | "export-excel"
            | "import" | "login" | "logout" | "trigger" | "retry"
    ) {
        segments.iter().rev().nth(1).copied().unwrap_or("gateway")
    } else {
        action
    };
    let (label, operate_type) = match action {
        "page" => ("分页查询", 1),
        "list" => ("列表查询", 1),
        "get" => ("查询详情", 1),
        "create" => ("新增", 2),
        "update" => ("修改", 3),
        "delete" => ("删除", 4),
        "export-excel" => ("导出", 5),
        "import" => ("导入", 6),
        "login" => ("登录", 0),
        "logout" => ("退出登录", 0),
        "trigger" => ("触发", 3),
        "retry" => ("重试", 3),
        _ => match method {
            "POST" => ("提交", 2),
            "PUT" | "PATCH" => ("修改", 3),
            "DELETE" => ("删除", 4),
            _ => ("查询", 1),
        },
    };
    (format!("{resource} · {label}"), operate_type)
}

#[cfg(test)]
mod tests {
    use super::{audit_path, operation_metadata};
    use axum::http::Uri;

    #[test]
    fn audit_path_keeps_the_complete_request_target() {
        let uri: Uri = "/toonflow/ws?token=super-secret-jwt&projectId=42"
            .parse()
            .expect("valid URI");

        let path = audit_path(&uri);

        assert_eq!(path, "/toonflow/ws?token=super-secret-jwt&projectId=42");
    }

    #[test]
    fn operation_metadata_uses_resource_and_action_semantics() {
        assert_eq!(
            operation_metadata("GET", "/infra/api-access-log/page"),
            ("api-access-log · 分页查询".to_string(), 1)
        );
        assert_eq!(
            operation_metadata("POST", "/system/auth/login"),
            ("auth · 登录".to_string(), 0)
        );
        assert_eq!(
            operation_metadata("DELETE", "/toonflow/projects/42"),
            ("projects · 删除".to_string(), 4)
        );
    }
}

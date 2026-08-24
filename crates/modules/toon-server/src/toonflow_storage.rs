use base64::Engine;
use chrono::Utc;
use hmac::{Hmac, Mac};
use reqwest::{Method, Url, header};
use rust_toon_framework_web::AppError;
use sha2::{Digest, Sha256};

use axum::{
    body::Body,
    extract::Path,
    http::{HeaderMap, HeaderValue, Response, StatusCode, header as http_header},
};

type HmacSha256 = Hmac<Sha256>;

struct MinioConfig {
    endpoint: String,
    access_key: String,
    secret_key: String,
    bucket: String,
    region: String,
}

fn config() -> MinioConfig {
    MinioConfig {
        endpoint: std::env::var("MINIO_ENDPOINT")
            .unwrap_or_else(|_| "http://127.0.0.1:9000".to_string())
            .trim_end_matches('/')
            .to_string(),
        access_key: std::env::var("MINIO_ACCESS_KEY").unwrap_or_else(|_| "rust_toon".to_string()),
        secret_key: std::env::var("MINIO_SECRET_KEY")
            .unwrap_or_else(|_| "rust_toon_password".to_string()),
        bucket: std::env::var("MINIO_BUCKET").unwrap_or_else(|_| "rust-toon".to_string()),
        region: std::env::var("MINIO_REGION").unwrap_or_else(|_| "us-east-1".to_string()),
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}

fn hmac(key: &[u8], data: &str) -> Result<Vec<u8>, String> {
    let mut mac = HmacSha256::new_from_slice(key).map_err(|error| error.to_string())?;
    mac.update(data.as_bytes());
    Ok(mac.finalize().into_bytes().to_vec())
}

async fn signed_request(
    method: Method,
    object_key: Option<&str>,
    body: Vec<u8>,
) -> Result<reqwest::Response, String> {
    signed_request_with_range(method, object_key, body, None).await
}

async fn signed_request_with_range(
    method: Method,
    object_key: Option<&str>,
    body: Vec<u8>,
    range: Option<&str>,
) -> Result<reqwest::Response, String> {
    let config = config();
    let canonical_uri = match object_key {
        Some(key) => format!("/{}/{}", config.bucket, key.trim_start_matches('/')),
        None => format!("/{}", config.bucket),
    };
    let url = Url::parse(&format!("{}{}", config.endpoint, canonical_uri))
        .map_err(|error| error.to_string())?;
    let host = match url.port() {
        Some(port) => format!("{}:{port}", url.host_str().unwrap_or_default()),
        None => url.host_str().unwrap_or_default().to_string(),
    };
    let now = Utc::now();
    let amz_date = now.format("%Y%m%dT%H%M%SZ").to_string();
    let date = now.format("%Y%m%d").to_string();
    let payload_hash = sha256_hex(&body);
    let canonical_headers =
        format!("host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n");
    let signed_headers = "host;x-amz-content-sha256;x-amz-date";
    let canonical_request = format!(
        "{}\n{canonical_uri}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}",
        method.as_str(),
    );
    let scope = format!("{date}/{}/s3/aws4_request", config.region);
    let string_to_sign = format!(
        "AWS4-HMAC-SHA256\n{amz_date}\n{scope}\n{}",
        sha256_hex(canonical_request.as_bytes()),
    );
    let date_key = hmac(format!("AWS4{}", config.secret_key).as_bytes(), &date)?;
    let region_key = hmac(&date_key, &config.region)?;
    let service_key = hmac(&region_key, "s3")?;
    let signing_key = hmac(&service_key, "aws4_request")?;
    let signature = hex::encode(hmac(&signing_key, &string_to_sign)?);
    let authorization = format!(
        "AWS4-HMAC-SHA256 Credential={}/{scope}, SignedHeaders={signed_headers}, Signature={signature}",
        config.access_key,
    );
    let mut request = reqwest::Client::new()
        .request(method, url)
        .header(header::HOST, host)
        .header("x-amz-content-sha256", payload_hash)
        .header("x-amz-date", amz_date)
        .header(header::AUTHORIZATION, authorization)
        .body(body);
    if let Some(range) = range {
        request = request.header(header::RANGE, range);
    }
    request.send().await.map_err(|error| error.to_string())
}

async fn ensure_bucket() -> Result<(), String> {
    let response = signed_request(Method::PUT, None, Vec::new()).await?;
    if response.status().is_success() || response.status().as_u16() == 409 {
        return Ok(());
    }
    Err(format!(
        "创建 MinIO bucket 失败：HTTP {}",
        response.status()
    ))
}

pub async fn persist_remote_image(url: &str, asset_id: i64) -> Result<String, String> {
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Ok(url.to_string());
    }
    let response = reqwest::Client::new()
        .get(url)
        .send()
        .await
        .map_err(|error| format!("下载生成图片失败：{error}"))?;
    if !response.status().is_success() {
        return Err(format!("下载生成图片失败：HTTP {}", response.status()));
    }
    let content_type = response
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("image/jpeg")
        .to_string();
    let bytes = response.bytes().await.map_err(|error| error.to_string())?;
    ensure_bucket().await?;
    let extension = if content_type.contains("png") {
        "png"
    } else if content_type.contains("webp") {
        "webp"
    } else {
        "jpg"
    };
    let key = format!(
        "toonflow/assets/{asset_id}/{}.{}",
        uuid::Uuid::new_v4(),
        extension
    );
    let upload = signed_request(Method::PUT, Some(&key), bytes.to_vec()).await?;
    if !upload.status().is_success() {
        return Err(format!(
            "上传生成图片到 MinIO 失败：HTTP {}",
            upload.status()
        ));
    }
    Ok(format!("/toonflow/assets/files/{key}"))
}

pub async fn persist_remote_video(url: &str, project_id: i64) -> Result<String, String> {
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Ok(url.to_string());
    }
    let response = reqwest::Client::new()
        .get(url)
        .send()
        .await
        .map_err(|error| format!("下载生成视频失败：{error}"))?;
    if !response.status().is_success() {
        return Err(format!("下载生成视频失败：HTTP {}", response.status()));
    }
    let bytes = response
        .bytes()
        .await
        .map_err(|error| format!("读取生成视频失败：{error}"))?;
    persist_asset_bytes(project_id, "videos", "mp4", bytes.to_vec()).await
}

pub async fn persist_asset_bytes(
    project_id: i64,
    category: &str,
    extension: &str,
    bytes: Vec<u8>,
) -> Result<String, String> {
    ensure_bucket().await?;
    let safe_extension = extension
        .chars()
        .filter(|character| character.is_ascii_alphanumeric())
        .collect::<String>();
    let key = format!(
        "toonflow/{project_id}/assets/{category}/{}.{}",
        uuid::Uuid::new_v4(),
        if safe_extension.is_empty() {
            "bin"
        } else {
            &safe_extension
        }
    );
    let upload = signed_request(Method::PUT, Some(&key), bytes).await?;
    if !upload.status().is_success() {
        return Err(format!("上传资产到 MinIO 失败：HTTP {}", upload.status()));
    }
    Ok(format!("/toonflow/assets/files/{key}"))
}

async fn read_image(key: &str) -> Result<(String, Vec<u8>), String> {
    let response = signed_request(Method::GET, Some(key), Vec::new()).await?;
    if !response.status().is_success() {
        return Err(format!("读取 MinIO 图片失败：HTTP {}", response.status()));
    }
    let mut content_type = response
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("application/octet-stream")
        .to_string();
    if content_type.split(';').next().is_some_and(|value| {
        value
            .trim()
            .eq_ignore_ascii_case("application/octet-stream")
    }) {
        content_type = stored_content_type_for_key(key).to_string();
    }
    let bytes = response.bytes().await.map_err(|error| error.to_string())?;
    Ok((content_type, bytes.to_vec()))
}

fn stored_content_type_for_key(key: &str) -> &'static str {
    match key
        .rsplit('.')
        .next()
        .unwrap_or_default()
        .to_ascii_lowercase()
        .as_str()
    {
        "jpg" | "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "mp3" | "mpeg" => "audio/mpeg",
        "wav" => "audio/wav",
        "m4a" => "audio/mp4",
        "flac" => "audio/flac",
        "aiff" => "audio/aiff",
        "mp4" | "m4v" => "video/mp4",
        "mov" => "video/quicktime",
        "webm" => "video/webm",
        "ogv" => "video/ogg",
        _ => "application/octet-stream",
    }
}

pub async fn image_data_url(file_path: &str) -> Result<String, String> {
    let key = asset_image_key(file_path).ok_or_else(|| "不支持的资产图片路径".to_string())?;
    let (stored_content_type, bytes) = read_image(key).await?;
    let content_type = image_content_type(&bytes).ok_or_else(|| {
        format!(
            "资产参考图不是有效的 PNG、JPEG、GIF 或 WebP 图片（存储类型：{stored_content_type}）"
        )
    })?;
    Ok(format!(
        "data:{content_type};base64,{}",
        base64::engine::general_purpose::STANDARD.encode(bytes)
    ))
}

pub(crate) async fn normalize_image_reference(reference: &str) -> Result<String, String> {
    let reference = reference.trim();
    if reference.is_empty() {
        return Err("参考图地址不能为空".to_string());
    }
    if reference.starts_with("data:")
        || reference.starts_with("http://")
        || reference.starts_with("https://")
    {
        return Ok(reference.to_string());
    }
    if is_asset_image_path(reference) {
        return image_data_url(reference).await;
    }
    Err(format!("不支持的参考图地址：{reference}"))
}

pub(crate) fn is_asset_image_path(file_path: &str) -> bool {
    asset_image_key(file_path).is_some()
}

pub(crate) async fn delete_asset_file(file_path: &str) -> Result<(), String> {
    let Some(key) = asset_image_key(file_path) else {
        return Ok(());
    };
    let response = signed_request(Method::DELETE, Some(key), Vec::new()).await?;
    if response.status().is_success() || response.status().as_u16() == 404 {
        Ok(())
    } else {
        Err(format!(
            "删除 MinIO 资产文件失败：HTTP {}",
            response.status()
        ))
    }
}

pub(crate) async fn record_cleanup_failure(
    pool: &sqlx::PgPool,
    object_path: &str,
    resource_type: &str,
    resource_id: Option<i64>,
    error: &str,
) {
    let id = chrono::Utc::now().timestamp_millis();
    let _ = sqlx::query(
        "INSERT INTO toonflow.storage_cleanup_tasks(id,object_path,resource_type,resource_id,error_reason,attempts,state,create_time,update_time)
         VALUES($1,$2,$3,$4,$5,1,'pending',$6,$6)
         ON CONFLICT(id) DO NOTHING",
    )
    .bind(id)
    .bind(object_path)
    .bind(resource_type)
    .bind(resource_id)
    .bind(error)
    .bind(id)
    .execute(pool)
    .await;
}

fn asset_image_key(file_path: &str) -> Option<&str> {
    file_path
        .strip_prefix("/toonflow/assets/files/")
        .or_else(|| file_path.strip_prefix("/api/toonflow/assets/files/"))
        .filter(|key| !key.is_empty())
}

/// Check that a persisted Toonflow asset is readable from the configured object store.
///
/// This is intentionally shared with the production pipeline verification so tests validate
/// the same MinIO-backed storage path used in production instead of assuming local `/upload`
/// files.
#[cfg(test)]
pub(crate) async fn asset_exists(file_path: &str) -> Result<bool, String> {
    let Some(key) = asset_image_key(file_path) else {
        return Ok(false);
    };
    let response = signed_request(Method::GET, Some(key), Vec::new()).await?;
    Ok(response.status().is_success())
}

pub(crate) async fn read_asset_bytes(file_path: &str) -> Result<Vec<u8>, String> {
    let Some(key) = asset_image_key(file_path) else {
        return Err("不支持的 MinIO 资产路径".into());
    };
    let response = signed_request(Method::GET, Some(key), Vec::new()).await?;
    if !response.status().is_success() {
        return Err(format!("读取 MinIO 资产失败：HTTP {}", response.status()));
    }
    response
        .bytes()
        .await
        .map(|bytes| bytes.to_vec())
        .map_err(|error| error.to_string())
}

fn image_content_type(bytes: &[u8]) -> Option<&'static str> {
    if bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
        Some("image/png")
    } else if bytes.starts_with(b"\xff\xd8\xff") {
        Some("image/jpeg")
    } else if bytes.starts_with(b"GIF87a") || bytes.starts_with(b"GIF89a") {
        Some("image/gif")
    } else if bytes.starts_with(b"RIFF") && bytes.get(8..12) == Some(b"WEBP") {
        Some("image/webp")
    } else {
        None
    }
}

pub async fn serve_image(
    Path(key): Path<String>,
    request_headers: HeaderMap,
) -> Result<Response<Body>, AppError> {
    let range = request_headers
        .get(http_header::RANGE)
        .and_then(|value| value.to_str().ok());
    let upstream = signed_request_with_range(Method::GET, Some(&key), Vec::new(), range)
        .await
        .map_err(|_| AppError::not_found("asset file not found"))?;
    if !upstream.status().is_success() {
        return Err(AppError::not_found("asset file not found"));
    }
    let status = if upstream.status() == reqwest::StatusCode::PARTIAL_CONTENT {
        StatusCode::PARTIAL_CONTENT
    } else {
        StatusCode::OK
    };
    let upstream_headers = upstream.headers().clone();
    let bytes = upstream
        .bytes()
        .await
        .map_err(|_| AppError::not_found("asset file not found"))?;
    let content_type = upstream_headers
        .get(http_header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .filter(|value| {
            !value
                .split(';')
                .next()
                .is_some_and(|part| part.trim().eq_ignore_ascii_case("application/octet-stream"))
        })
        .map(str::to_string)
        .unwrap_or_else(|| stored_content_type_for_key(&key).to_string());
    let mut response = Response::builder()
        .status(status)
        .body(Body::from(bytes.clone()))
        .map_err(|_| AppError::internal("failed to build asset response"))?;
    response.headers_mut().insert(
        http_header::CONTENT_TYPE,
        HeaderValue::from_str(&content_type)
            .map_err(|_| AppError::internal("invalid asset content type"))?,
    );
    response.headers_mut().insert(
        http_header::ACCEPT_RANGES,
        HeaderValue::from_static("bytes"),
    );
    response.headers_mut().insert(
        http_header::CONTENT_LENGTH,
        HeaderValue::from_str(&bytes.len().to_string())
            .map_err(|_| AppError::internal("invalid asset content length"))?,
    );
    response.headers_mut().insert(
        http_header::CACHE_CONTROL,
        HeaderValue::from_static("public, max-age=31536000, immutable"),
    );
    if let Some(content_range) = upstream_headers.get(http_header::CONTENT_RANGE) {
        response
            .headers_mut()
            .insert(http_header::CONTENT_RANGE, content_range.clone());
    }
    Ok(response)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_reference_image_content_type_from_file_signature() {
        assert_eq!(
            image_content_type(b"\x89PNG\r\n\x1a\nrest"),
            Some("image/png")
        );
        assert_eq!(image_content_type(b"\xff\xd8\xffrest"), Some("image/jpeg"));
        assert_eq!(image_content_type(b"GIF89arest"), Some("image/gif"));
        assert_eq!(image_content_type(b"RIFF1234WEBPrest"), Some("image/webp"));
        assert_eq!(image_content_type(b"not-an-image"), None);
    }

    #[test]
    fn accepts_asset_paths_with_or_without_api_gateway_prefix() {
        let key = "toonflow/assets/1/reference.jpg";
        assert_eq!(
            asset_image_key(&format!("/toonflow/assets/files/{key}")),
            Some(key)
        );
        assert_eq!(
            asset_image_key(&format!("/api/toonflow/assets/files/{key}")),
            Some(key)
        );
        assert!(is_asset_image_path(&format!(
            "/api/toonflow/assets/files/{key}"
        )));
        assert_eq!(asset_image_key("/api/toonflow/assets/files/"), None);
    }

    #[test]
    fn detects_video_content_type_from_object_key() {
        assert_eq!(
            stored_content_type_for_key("toonflow/assets/1/video.mp4"),
            "video/mp4"
        );
        assert_eq!(
            stored_content_type_for_key("toonflow/assets/1/video.webm"),
            "video/webm"
        );
    }

    #[tokio::test]
    #[ignore = "requires the local MinIO service"]
    async fn minio_round_trip() {
        ensure_bucket().await.expect("create test bucket");
        let key = format!("toonflow/tests/{}.txt", uuid::Uuid::new_v4());
        let uploaded = signed_request(Method::PUT, Some(&key), b"rust-toon".to_vec())
            .await
            .expect("upload object");
        assert!(uploaded.status().is_success());
        let (_, bytes) = read_image(&key).await.expect("read object");
        assert_eq!(bytes, b"rust-toon");
    }
}

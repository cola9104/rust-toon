use std::time::Duration;

use rust_toon_framework_database::{DatabaseConfig, connect};
use serde_json::Value;

use crate::ai_client;

#[tokio::test]
#[ignore = "paid provider smoke test; run with script/test-real-ai-providers.sh"]
async fn configured_image_and_video_providers_return_media_urls() {
    assert_eq!(std::env::var("RUN_PAID_AI_E2E").as_deref(), Ok("1"));
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL is required");
    let image_model =
        std::env::var("REAL_IMAGE_MODEL_ID").expect("REAL_IMAGE_MODEL_ID is required");
    let video_model =
        std::env::var("REAL_VIDEO_MODEL_ID").expect("REAL_VIDEO_MODEL_ID is required");
    let video_payload: Value = serde_json::from_str(
        &std::env::var("REAL_VIDEO_PAYLOAD_JSON").expect("REAL_VIDEO_PAYLOAD_JSON is required"),
    )
    .expect("REAL_VIDEO_PAYLOAD_JSON must be valid JSON");
    let pool = connect(
        &DatabaseConfig::new(database_url, 1, 3, Duration::from_secs(20))
            .expect("database configuration"),
    )
    .await
    .expect("database connection");

    let image_url = ai_client::image_with_references(
        &pool,
        &image_model,
        &std::env::var("REAL_IMAGE_PROMPT").unwrap_or_else(|_| {
            "A single red paper boat on a neutral gray studio background".into()
        }),
        &std::env::var("REAL_IMAGE_SIZE").unwrap_or_else(|_| "1024x1024".into()),
        vec![],
    )
    .await
    .expect("real image provider request");
    assert!(image_url.starts_with("http://") || image_url.starts_with("https://"));

    let submission = ai_client::video_submit(&pool, &video_model, video_payload)
        .await
        .expect("real video provider request");
    let video_url = match submission {
        ai_client::VideoSubmission { url: Some(url), .. } => url,
        ai_client::VideoSubmission {
            task_id: Some(task_id),
            ..
        } => ai_client::video_poll_task(&pool, &video_model, &task_id)
            .await
            .expect("real video provider polling"),
        _ => panic!("video response carried neither URL nor task ID"),
    };
    assert!(video_url.starts_with("http://") || video_url.starts_with("https://"));
}

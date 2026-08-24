use std::{process::Command, time::Duration};

use axum::{Json, extract::State};
use rust_toon_framework_database::{DatabaseConfig, connect, migrate};
use rust_toon_framework_security::{
    CurrentUser, DataScope, PermissionSet, SecurityConfig, TokenService,
};

use crate::{ToonState, toonflow, toonflow_project_crud, toonflow_storage, toonflow_video_export};

fn user() -> CurrentUser {
    CurrentUser {
        user_id: "00000000-0000-0000-0000-000000000001".into(),
        username: "production-e2e".into(),
        tenant_id: None,
        role_codes: vec!["super_admin".into()],
        permissions: PermissionSet::default(),
        data_scope: DataScope::All,
    }
}

#[tokio::test]
#[ignore = "run with script/test-production-e2e.sh"]
async fn project_content_storyboard_and_video_export_form_a_complete_pipeline() {
    let url = std::env::var("TEST_DATABASE_URL").expect("TEST_DATABASE_URL is required");
    let upload_dir = std::env::var("TEST_UPLOAD_DIR").expect("TEST_UPLOAD_DIR is required");
    // This ignored test runs in its own process through test-production-e2e.sh.

    let pool =
        connect(&DatabaseConfig::new(url, 1, 5, Duration::from_secs(10)).expect("database config"))
            .await
            .expect("database connection");
    migrate(&pool).await.expect("database migrations");
    let tokens = TokenService::new(
        SecurityConfig::new(
            "production-e2e-secret-at-least-32-bytes",
            "test",
            "test",
            Duration::from_secs(60),
        )
        .expect("security config"),
    );
    let state = ToonState::new(pool.clone(), tokens);

    let project = toonflow_project_crud::create_project(
        user(),
        State(state.clone()),
        Json(toonflow::SaveProjectRequest {
            id: None,
            project_type: "shortDrama".into(),
            chat_model: None,
            image_model: None,
            image_quality: "2K".into(),
            video_model: None,
            name: "Production E2E".into(),
            intro: "automated production pipeline".into(),
            r#type: "anime".into(),
            art_style: "2D".into(),
            director_manual: String::new(),
            mode: "firstLastFrame".into(),
            video_ratio: "16:9".into(),
        }),
    )
    .await
    .expect("create project");
    let project_id = project.0.data["id"].as_i64().expect("project id");

    let _ = toonflow::add_novel(
        user(),
        State(state.clone()),
        Json(toonflow::AddNovelRequest {
            project_id,
            data: vec![toonflow::NovelItemRequest {
                index: 1,
                reel: "第一卷".into(),
                chapter: "第一章".into(),
                chapter_data: "主角在雨夜车站相遇。".into(),
            }],
        }),
    )
    .await
    .expect("add novel");

    let script = toonflow::add_script(
        user(),
        State(state.clone()),
        Json(toonflow::SaveScriptRequest {
            id: None,
            name: "第1集".into(),
            content: "雨夜车站，主角回头。".into(),
            project_id: Some(project_id),
            assets: Some(vec![]),
        }),
    )
    .await
    .expect("add script");
    let script_id = script.0.data["id"].as_i64().expect("script id");

    let asset = toonflow::save_asset(
        user(),
        State(state.clone()),
        Json(toonflow::SaveAssetRequest {
            id: None,
            project_id,
            name: "雨夜车站".into(),
            prompt: Some("wet railway platform at night".into()),
            remark: None,
            r#type: Some("scene".into()),
            description: Some("雨水反射站台灯光".into()),
            script_id: Some(script_id),
            parent_asset_id: None,
            image_id: None,
            base64: None,
        }),
    )
    .await
    .expect("save asset");
    let asset_id = asset.0.data["id"].as_i64().expect("asset id");

    let _ = toonflow::batch_add_storyboards(
        user(),
        State(state.clone()),
        Json(toonflow::BatchStoryboardRequest {
            project_id,
            script_id,
            data: vec![toonflow::SaveStoryboardRequest {
                id: None,
                prompt: "主角站在雨夜站台中景".into(),
                duration: Some(1),
                state: "未生成".into(),
                video_desc: Some("镜头缓慢推进".into()),
                should_generate_image: 1,
                file_path: None,
                script_id: Some(script_id),
                project_id: Some(project_id),
                track: Some("main".into()),
                associate_assets_ids: vec![asset_id],
            }],
        }),
    )
    .await
    .expect("add storyboard");

    let track_id: i64 = sqlx::query_scalar(
        "SELECT id FROM toonflow.video_tracks WHERE project_id=$1 AND script_id=$2",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_one(&pool)
    .await
    .expect("storyboard track");

    let source_dir = std::path::Path::new(&upload_dir).join("e2e");
    std::fs::create_dir_all(&source_dir).expect("create upload directory");
    let source_path = source_dir.join("source.mp4");
    let output = Command::new("ffmpeg")
        .args([
            "-y",
            "-f",
            "lavfi",
            "-i",
            "color=c=black:s=320x180:d=1",
            "-pix_fmt",
            "yuv420p",
        ])
        .arg(&source_path)
        .output()
        .expect("run ffmpeg fixture generation");
    assert!(output.status.success(), "ffmpeg fixture generation failed");
    let source_bytes = tokio::fs::read(&source_path)
        .await
        .expect("read source video");
    let source_url = toonflow_storage::persist_asset_bytes(project_id, "e2e", "mp4", source_bytes)
        .await
        .expect("persist source video");

    let video_id = project_id + 90_000;
    sqlx::query("INSERT INTO toonflow.videos(id,file_path,state,script_id,project_id,video_track_id) VALUES($1,$2,'生成成功',$3,$4,$5)")
        .bind(video_id)
        .bind(&source_url)
        .bind(script_id)
        .bind(project_id)
        .bind(track_id)
        .execute(&pool)
        .await
        .expect("insert selected video");
    sqlx::query("UPDATE toonflow.video_tracks SET video_id=$2,select_video_id=$2,state='生成成功' WHERE id=$1")
        .bind(track_id)
        .bind(video_id)
        .execute(&pool)
        .await
        .expect("select generated video");

    let export = toonflow_video_export::export(
        user(),
        State(state),
        Json(toonflow_video_export::ExportRequest {
            project_id,
            script_id,
            video_ids: vec![],
        }),
    )
    .await
    .expect("submit export");
    let task_id = export.0.data["taskId"].as_i64().expect("export task id");

    let mut exported_url = None;
    for _ in 0..100 {
        let task: Option<(String, String)> =
            sqlx::query_as("SELECT state,related_objects FROM toonflow.tasks WHERE id=$1")
                .bind(task_id)
                .fetch_optional(&pool)
                .await
                .expect("poll export task");
        if let Some((task_state, related_objects)) = task {
            if task_state == "failed" {
                panic!("video export failed: {related_objects}");
            }
            if task_state == "success" {
                exported_url = serde_json::from_str::<serde_json::Value>(&related_objects)
                    .ok()
                    .and_then(|value| value["url"].as_str().map(str::to_owned));
                break;
            }
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
    let exported_url = exported_url.expect("export task did not complete");
    assert!(exported_url.ends_with(".mp4"));
    assert!(
        toonflow_storage::asset_exists(&exported_url)
            .await
            .expect("check exported asset")
    );
    toonflow_storage::delete_asset_file(&exported_url)
        .await
        .expect("cleanup exported asset");
    toonflow_storage::delete_asset_file(&source_url)
        .await
        .expect("cleanup source asset");

    sqlx::query("DELETE FROM toonflow.projects WHERE id=$1")
        .bind(project_id)
        .execute(&pool)
        .await
        .expect("clean project");
}

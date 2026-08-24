use crate::{ToonState, shared::require};
use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::Deserialize;
use serde_json::{Value, json};
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportRequest {
    pub project_id: i64,
    pub script_id: i64,
    #[serde(default)]
    pub video_ids: Vec<i64>,
}

async fn ffmpeg_available() -> bool {
    tokio::task::spawn_blocking(|| {
        let ffmpeg = std::process::Command::new("ffmpeg")
            .arg("-version")
            .output()
            .is_ok_and(|output| output.status.success());
        let ffprobe = std::process::Command::new("ffprobe")
            .arg("-version")
            .output()
            .is_ok_and(|output| output.status.success());
        ffmpeg && ffprobe
    })
    .await
    .unwrap_or(false)
}

async fn probe_dimensions(path: &Path) -> Result<(u32, u32), String> {
    let path = path.to_owned();
    tokio::task::spawn_blocking(move || {
        let output = std::process::Command::new("ffprobe")
            .args([
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=width,height",
                "-of",
                "csv=p=0:s=x",
            ])
            .arg(path)
            .output()
            .map_err(|error| format!("探测视频尺寸失败：{error}"))?;
        if !output.status.success() {
            return Err(format!(
                "探测视频尺寸失败：{}",
                String::from_utf8_lossy(&output.stderr).trim()
            ));
        }
        let value = String::from_utf8_lossy(&output.stdout);
        let (width, height) = value
            .trim()
            .split_once('x')
            .ok_or_else(|| "无法识别视频尺寸".to_string())?;
        Ok((
            width.parse().map_err(|_| "无法识别视频宽度".to_string())?,
            height.parse().map_err(|_| "无法识别视频高度".to_string())?,
        ))
    })
    .await
    .map_err(|error| format!("探测视频尺寸任务异常：{error}"))?
}

async fn probe_has_audio(path: &Path) -> Result<bool, String> {
    let path = path.to_owned();
    tokio::task::spawn_blocking(move || {
        let output = std::process::Command::new("ffprobe")
            .args([
                "-v",
                "error",
                "-select_streams",
                "a:0",
                "-show_entries",
                "stream=index",
                "-of",
                "csv=p=0",
            ])
            .arg(path)
            .output()
            .map_err(|error| format!("探测视频音频失败：{error}"))?;
        if !output.status.success() {
            return Err(format!(
                "探测视频音频失败：{}",
                String::from_utf8_lossy(&output.stderr).trim()
            ));
        }
        Ok(!output.stdout.is_empty())
    })
    .await
    .map_err(|error| format!("探测视频音频任务异常：{error}"))?
}

async fn normalize_video(
    source: &Path,
    destination: &Path,
    width: u32,
    height: u32,
) -> Result<(), String> {
    let source = source.to_owned();
    let destination = destination.to_owned();
    let has_audio = probe_has_audio(&source).await?;
    tokio::task::spawn_blocking(move || {
        let scale = format!(
            "scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=black,fps=30,format=yuv420p,setsar=1,setpts=PTS-STARTPTS"
        );
        let mut command = std::process::Command::new("ffmpeg");
        command.args(["-y", "-fflags", "+genpts", "-i"]);
        command.arg(&source);
        if has_audio {
            command.args([
                "-map",
                "0:v:0",
                "-map",
                "0:a:0",
                "-vf",
                &scale,
                "-af",
                "aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,asetpts=N/SR/TB",
            ]);
        } else {
            command.args([
                "-f",
                "lavfi",
                "-i",
                "anullsrc=channel_layout=stereo:sample_rate=48000",
                "-map",
                "0:v:0",
                "-map",
                "1:a:0",
                "-vf",
                &scale,
                "-shortest",
            ]);
        }
        command
            .args([
                "-r",
                "30",
                "-c:v",
                "libx264",
                "-preset",
                "medium",
                "-crf",
                "23",
                "-c:a",
                "aac",
                "-ar",
                "48000",
                "-ac",
                "2",
                "-b:a",
                "192k",
                "-movflags",
                "+faststart",
            ])
            .arg(&destination);
        let output = command
            .output()
            .map_err(|error| format!("启动视频标准化失败：{error}"))?;
        if output.status.success() {
            Ok(())
        } else {
            Err(format!(
                "视频标准化失败：{}",
                String::from_utf8_lossy(&output.stderr)
                    .lines()
                    .last()
                    .unwrap_or("FFmpeg 执行失败")
            ))
        }
    })
    .await
    .map_err(|error| format!("视频标准化任务异常：{error}"))?
}

async fn materialize_video(
    source: &str,
    directory: &Path,
    index: usize,
) -> Result<PathBuf, String> {
    let destination = directory.join(format!("{index:04}.mp4"));
    if source.starts_with("/toonflow/assets/files/")
        || source.starts_with("/api/toonflow/assets/files/")
    {
        let bytes = crate::toonflow_storage::read_asset_bytes(source).await?;
        tokio::fs::write(&destination, bytes)
            .await
            .map_err(|error| format!("无法读取 MinIO 视频：{error}"))?;
    } else if source.starts_with("http://") || source.starts_with("https://") {
        let bytes = reqwest::get(source)
            .await
            .map_err(|error| format!("下载视频失败：{error}"))?
            .error_for_status()
            .map_err(|error| format!("下载视频失败：{error}"))?
            .bytes()
            .await
            .map_err(|error| format!("读取视频失败：{error}"))?;
        tokio::fs::write(&destination, bytes)
            .await
            .map_err(|error| format!("保存视频失败：{error}"))?;
    } else {
        return Err(format!("不支持的视频地址：{source}"));
    }
    tokio::fs::canonicalize(destination)
        .await
        .map_err(|error| format!("解析视频路径失败：{error}"))
}

async fn run_export(
    pool: sqlx::PgPool,
    project_id: i64,
    script_id: i64,
    task_id: i64,
    video_ids: Vec<i64>,
) -> Result<String, String> {
    let sources: Vec<String> = if video_ids.is_empty() {
        sqlx::query_scalar("SELECT v.file_path FROM toonflow.video_tracks t JOIN toonflow.videos v ON v.id=COALESCE((SELECT selected.id FROM toonflow.videos selected WHERE selected.id=t.video_id AND selected.state='生成成功' AND coalesce(selected.file_path,'')<>''),(SELECT latest.id FROM toonflow.videos latest WHERE latest.video_track_id=t.id AND latest.state='生成成功' AND coalesce(latest.file_path,'')<>'' ORDER BY latest.time DESC,latest.id DESC LIMIT 1)) WHERE t.project_id=$1 AND t.script_id=$2 ORDER BY coalesce((SELECT min(coalesce(s.index,2147483647)) FROM toonflow.storyboards s WHERE s.track_id=t.id),2147483647),t.sort_order,t.id")
            .bind(project_id)
            .bind(script_id)
            .fetch_all(&pool)
            .await
            .map_err(|error| error.to_string())?
    } else {
        sqlx::query_scalar("SELECT v.file_path FROM toonflow.videos v JOIN toonflow.video_tracks t ON t.id=v.video_track_id WHERE v.id=ANY($3) AND v.project_id=$1 AND v.script_id=$2 AND v.state='生成成功' AND coalesce(v.file_path,'')<>'' ORDER BY coalesce((SELECT min(coalesce(s.index,2147483647)) FROM toonflow.storyboards s WHERE s.track_id=t.id),2147483647),t.sort_order,t.id")
            .bind(project_id)
            .bind(script_id)
            .bind(&video_ids)
            .fetch_all(&pool)
            .await
            .map_err(|error| error.to_string())?
    };
    if sources.is_empty() {
        return Err("请先为每条轨道选择已生成的视频".into());
    }
    let _ =
        sqlx::query("UPDATE toonflow.tasks SET progress_current=0,progress_total=$2 WHERE id=$1")
            .bind(task_id)
            .bind(sources.len() as i32)
            .execute(&pool)
            .await;
    let work_dir = std::env::temp_dir().join(format!(
        "rust-toon/toonflow/{project_id}/exports/work-{task_id}"
    ));
    tokio::fs::create_dir_all(&work_dir)
        .await
        .map_err(|error| error.to_string())?;
    let mut files = Vec::new();
    for (index, source) in sources.iter().enumerate() {
        let file = materialize_video(source, &work_dir, index).await?;
        files.push(file);
        let _ = sqlx::query("UPDATE toonflow.tasks SET progress_current=$2 WHERE id=$1")
            .bind(task_id)
            .bind((index + 1) as i32)
            .execute(&pool)
            .await;
    }
    let (first_width, first_height) = probe_dimensions(&files[0]).await?;
    let (target_width, target_height) = if first_width >= first_height {
        (1920, 1080)
    } else {
        (1080, 1920)
    };
    let normalized_dir = work_dir.join("normalized");
    tokio::fs::create_dir_all(&normalized_dir)
        .await
        .map_err(|error| error.to_string())?;
    let mut normalized_files = Vec::with_capacity(files.len());
    for (index, file) in files.iter().enumerate() {
        let normalized = normalized_dir.join(format!("{index:04}.mp4"));
        normalize_video(file, &normalized, target_width, target_height).await?;
        normalized_files.push(normalized);
    }

    let list_path = work_dir.join("concat.txt");
    let list = normalized_files
        .iter()
        .map(|path| format!("file '{}'", path.to_string_lossy().replace('\'', "'\\''")))
        .collect::<Vec<_>>()
        .join("\n");
    tokio::fs::write(&list_path, list)
        .await
        .map_err(|error| error.to_string())?;
    let output_path = work_dir.join(format!("{script_id}_{task_id}.mp4"));
    let ffmpeg_output_path = output_path.clone();
    if let Some(parent) = output_path.parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .map_err(|error| error.to_string())?;
    }
    let output = tokio::task::spawn_blocking(move || {
        std::process::Command::new("ffmpeg")
            .args(["-y", "-f", "concat", "-safe", "0", "-i"])
            .arg(&list_path)
            .args([
                "-fflags",
                "+genpts",
                "-c:v",
                "libx264",
                "-c:a",
                "aac",
                "-ar",
                "48000",
                "-ac",
                "2",
                "-movflags",
                "+faststart",
            ])
            .arg(&ffmpeg_output_path)
            .output()
    })
    .await
    .map_err(|error| format!("FFmpeg 任务异常：{error}"))?
    .map_err(|error| format!("启动 FFmpeg 失败：{error}"))?;
    if !output.status.success() {
        let _ = tokio::fs::remove_dir_all(&work_dir).await;
        return Err(format!(
            "成片导出失败：{}",
            String::from_utf8_lossy(&output.stderr)
                .lines()
                .last()
                .unwrap_or("FFmpeg 执行失败")
        ));
    }
    let bytes = tokio::fs::read(&output_path)
        .await
        .map_err(|error| format!("读取导出文件失败：{error}"))?;
    let stored =
        crate::toonflow_storage::persist_asset_bytes(project_id, "exports", "mp4", bytes).await?;
    let _ = tokio::fs::remove_dir_all(&work_dir).await;
    Ok(stored)
}

pub async fn export(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ExportRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:scene:update")?;
    if !ffmpeg_available().await {
        return Err(AppError::bad_request(
            "服务器未安装可用的 FFmpeg/FFprobe，安装后即可使用成片导出",
        ));
    }
    let task_id = chrono::Utc::now().timestamp_millis();
    let video_ids = request.video_ids;
    let task_video_ids = video_ids.clone();
    let related_objects = json!({
        "scriptId": request.script_id,
        "videoIds": &task_video_ids,
    })
    .to_string();
    let input = json!({
        "projectId": request.project_id,
        "scriptId": request.script_id,
        "videoIds": &video_ids,
    });
    sqlx::query("INSERT INTO toonflow.tasks(id,project_id,task_class,related_objects,model,description,state,start_time,input,progress_current,progress_total) VALUES($1,$2,'videoExport',$3,'ffmpeg','合并选中视频为最终成片','running',$1,$4,0,NULL)")
        .bind(task_id)
        .bind(request.project_id)
        .bind(related_objects)
        .bind(input)
        .execute(&state.pool)
        .await
        .map_err(|error| {
            tracing::error!(task_id, error = %error, "failed to create video export task");
            AppError::internal("failed to create export task")
        })?;
    let pool = state.pool.clone();
    tokio::spawn(async move {
        match run_export(
            pool.clone(),
            request.project_id,
            request.script_id,
            task_id,
            video_ids,
        )
        .await
        {
            Ok(url) => {
                let _=sqlx::query("UPDATE toonflow.tasks SET state='success',related_objects=$2,reason=NULL WHERE id=$1").bind(task_id).bind(json!({"scriptId":request.script_id,"videoIds":task_video_ids,"url":url}).to_string()).execute(&pool).await;
            }
            Err(reason) => {
                let _ =
                    sqlx::query("UPDATE toonflow.tasks SET state='failed',reason=$2 WHERE id=$1")
                        .bind(task_id)
                        .bind(reason)
                        .execute(&pool)
                        .await;
            }
        }
    });
    Ok(Json(ApiResponse::new(
        json!({"taskId":task_id,"state":"running"}),
    )))
}

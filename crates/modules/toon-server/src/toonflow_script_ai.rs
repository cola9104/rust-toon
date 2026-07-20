use crate::{ToonState, ai_client, shared::require};
use axum::{Json, extract::State};
use rust_toon_framework_common::ApiResponse;
use rust_toon_framework_security::CurrentUser;
use rust_toon_framework_web::AppError;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExtractRequest {
    script_ids: Vec<i64>,
    project_id: i64,
    group_size: Option<usize>,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct ExtractedAsset {
    name: String,
    #[serde(default, alias = "description")]
    desc: String,
    #[serde(rename = "type")]
    #[serde(default)]
    type_: String,
    #[serde(default)]
    script_ids: Vec<i64>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExtractedResult {
    #[serde(default)]
    new_assets: Vec<ExtractedAsset>,
    #[serde(default)]
    existing_asset_refs: Vec<ExtractedAsset>,
}

fn parse_result(output: &str) -> Result<ExtractedResult, String> {
    let trimmed = output
        .trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim();
    serde_json::from_str(trimmed).or_else(|_| {
        let start = trimmed.find('{').ok_or("AI 未返回 JSON 对象")?;
        let end = trimmed.rfind('}').ok_or("AI 未返回完整 JSON 对象")?;
        serde_json::from_str(&trimmed[start..=end]).map_err(|error| error.to_string())
    })
}

async fn extract_group(
    pool: &sqlx::PgPool,
    project_id: i64,
    script_ids: &[i64],
) -> Result<(), String> {
    let scripts = sqlx::query_as::<_, (i64, String, String)>(
        "SELECT id,name,content FROM toonflow.scripts WHERE project_id=$1 AND id=ANY($2)",
    )
    .bind(project_id)
    .bind(script_ids)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())?;
    if scripts.len() != script_ids.len() {
        return Err("部分剧本不存在".into());
    }
    sqlx::query("UPDATE toonflow.scripts SET extract_state=0,error_reason=NULL WHERE project_id=$1 AND id=ANY($2)")
        .bind(project_id)
        .bind(script_ids)
        .execute(pool)
        .await
        .map_err(|error| error.to_string())?;
    let existing = sqlx::query_as::<_, (String, String)>(
        r#"SELECT a.name,a.type FROM toonflow.assets a
           WHERE a.project_id=$1 OR EXISTS(
             SELECT 1 FROM toonflow.project_assets pa
             WHERE pa.project_id=$1 AND pa.asset_id=a.id
           )"#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())?
    .into_iter()
    .map(|row| format!("{}({})", row.0, row.1))
    .collect::<Vec<_>>()
    .join("、");
    let content = scripts
        .iter()
        .map(|row| format!("===== 剧本ID:{} {} =====\n{}", row.0, row.1, row.2))
        .collect::<Vec<_>>()
        .join("\n\n");
    let output = ai_client::text(
        pool,
        "universalAi",
        r#"从剧本中提取后续分镜和视频生成需要保持视觉一致的基础资产。只返回一个 JSON 对象：
{"newAssets":[{"name":"","desc":"","type":"role","scriptIds":[1]}],"existingAssetRefs":[{"name":"","type":"role","scriptIds":[1]}]}
分类只能是：role=有名且需保持外观一致的角色；scene=反复出现或叙事关键场所；tool=被角色使用、推动剧情或需特写的关键道具；costume=需跨镜头保持一致的独立服装方案。
不提取群演、一次性背景物、普通家具、无剧情作用的日常物品；角色当前穿着只写入角色 desc，只有可复用或需单独生成的服装才列 costume。
同一实体跨多个剧本使用统一名称；已有资产必须放 existingAssetRefs，禁止换名重建；新资产放 newAssets。desc 要写可视化的稳定外观特征，不写动作和剧情。scriptIds 必须来自输入。不要输出 Markdown。"#,
        &format!("已有资产：{existing}\n\n{content}"),
    )
    .await?;
    let result = parse_result(&output)?;
    let allowed = ["role", "scene", "tool", "costume"];
    let mut tx = pool.begin().await.map_err(|error| error.to_string())?;
    sqlx::query("DELETE FROM toonflow.script_assets WHERE script_id=ANY($1)")
        .bind(script_ids)
        .execute(&mut *tx)
        .await
        .map_err(|error| error.to_string())?;
    for asset in result.new_assets {
        if asset.name.trim().is_empty() || !allowed.contains(&asset.type_.as_str()) {
            continue;
        }
        let existing_id: Option<i64> = sqlx::query_scalar(
            "SELECT id FROM toonflow.assets WHERE project_id=$1 AND name=$2 AND type=$3 LIMIT 1",
        )
        .bind(project_id)
        .bind(asset.name.trim())
        .bind(&asset.type_)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|error| error.to_string())?;
        let asset_id = if let Some(id) = existing_id {
            id
        } else {
            let id = chrono::Utc::now().timestamp_micros();
            sqlx::query("INSERT INTO toonflow.assets(id,name,type,description,project_id,start_time) VALUES($1,$2,$3,$4,$5,$6)")
                .bind(id).bind(asset.name.trim()).bind(&asset.type_).bind(&asset.desc).bind(project_id).bind(chrono::Utc::now().timestamp_millis())
                .execute(&mut *tx).await.map_err(|error|error.to_string())?;
            id
        };
        sqlx::query("INSERT INTO toonflow.project_assets(project_id,asset_id,linked_at) VALUES($1,$2,$3) ON CONFLICT DO NOTHING")
            .bind(project_id).bind(asset_id).bind(chrono::Utc::now().timestamp_millis())
            .execute(&mut *tx).await.map_err(|error|error.to_string())?;
        for script_id in asset
            .script_ids
            .into_iter()
            .filter(|id| script_ids.contains(id))
        {
            sqlx::query("INSERT INTO toonflow.script_assets(script_id,asset_id) VALUES($1,$2) ON CONFLICT DO NOTHING")
                .bind(script_id).bind(asset_id).execute(&mut *tx).await.map_err(|error|error.to_string())?;
        }
    }
    for reference in result.existing_asset_refs {
        let asset_id: Option<i64> = sqlx::query_scalar(
            r#"SELECT a.id FROM toonflow.assets a
               WHERE a.name=$2 AND a.type=$3 AND (
                 a.project_id=$1 OR EXISTS(
                   SELECT 1 FROM toonflow.project_assets pa
                   WHERE pa.project_id=$1 AND pa.asset_id=a.id
                 )
               ) ORDER BY CASE WHEN a.project_id=$1 THEN 0 ELSE 1 END LIMIT 1"#,
        )
        .bind(project_id)
        .bind(reference.name.trim())
        .bind(&reference.type_)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|error| error.to_string())?;
        if let Some(asset_id) = asset_id {
            for script_id in reference
                .script_ids
                .into_iter()
                .filter(|id| script_ids.contains(id))
            {
                sqlx::query("INSERT INTO toonflow.script_assets(script_id,asset_id) VALUES($1,$2) ON CONFLICT DO NOTHING")
                    .bind(script_id).bind(asset_id).execute(&mut *tx).await.map_err(|error|error.to_string())?;
            }
        }
    }
    sqlx::query("UPDATE toonflow.scripts SET extract_state=1,error_reason=NULL WHERE project_id=$1 AND id=ANY($2)")
        .bind(project_id).bind(script_ids).execute(&mut *tx).await.map_err(|error|error.to_string())?;
    tx.commit().await.map_err(|error| error.to_string())
}

pub async fn extract_assets(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<ExtractRequest>,
) -> Result<Json<ApiResponse<Value>>, AppError> {
    require(&user, "toon:project:update")?;
    if request.script_ids.is_empty() {
        return Err(AppError::bad_request("请先选择剧本"));
    }
    sqlx::query("UPDATE toonflow.scripts SET extract_state=2,error_reason=NULL WHERE project_id=$1 AND id=ANY($2)")
        .bind(request.project_id).bind(&request.script_ids).execute(&state.pool).await.map_err(|_|AppError::internal("failed to queue asset extraction"))?;
    let pool = state.pool.clone();
    let project_id = request.project_id;
    let ids = request.script_ids;
    let group_size = request.group_size.unwrap_or(5).clamp(1, 20);
    tokio::spawn(async move {
        for group in ids.chunks(group_size) {
            if let Err(reason) = extract_group(&pool, project_id, group).await {
                let _=sqlx::query("UPDATE toonflow.scripts SET extract_state=-1,error_reason=$3 WHERE project_id=$1 AND id=ANY($2)").bind(project_id).bind(group).bind(&reason).execute(&pool).await;
            }
        }
    });
    Ok(Json(ApiResponse::new(json!({"message":"开始提取资产"}))))
}

#[derive(Deserialize)]
pub struct Ids {
    ids: Vec<i64>,
}

pub async fn poll(
    user: CurrentUser,
    State(state): State<ToonState>,
    Json(request): Json<Ids>,
) -> Result<Json<ApiResponse<Vec<Value>>>, AppError> {
    require(&user, "toon:project:read")?;
    let rows = sqlx::query_as::<_, (i64, Option<i32>, Option<String>)>(
        "SELECT id,extract_state,error_reason FROM toonflow.scripts WHERE id=ANY($1) AND coalesce(extract_state,2)<>0",
    )
    .bind(request.ids)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to poll script assets"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter()
            .map(|row| json!({"id":row.0,"extractState":row.1,"errorReason":row.2}))
            .collect(),
    )))
}

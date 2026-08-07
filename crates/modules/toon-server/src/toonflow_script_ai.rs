use crate::{
    ToonState, ai_client,
    shared::require,
    toonflow_asset_description,
    toonflow_character_identity::{normalize_age_stage, normalize_role_name},
    toonflow_prompt_store,
};
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
struct ExtractedAppearance {
    role_name: String,
    name: String,
    #[serde(default)]
    scenes: Vec<String>,
    costume_prompt: String,
    #[serde(default)]
    description: String,
    script_id: i64,
    #[serde(default)]
    age_stage: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExtractedResult {
    #[serde(default)]
    new_assets: Vec<ExtractedAsset>,
    #[serde(default)]
    existing_asset_refs: Vec<ExtractedAsset>,
    #[serde(default)]
    appearances: Vec<ExtractedAppearance>,
}

fn normalized_asset_type(name: &str, description: &str, extracted_type: &str) -> String {
    const WEARABLE_MARKERS: &[&str] = &[
        "帽", "服", "衣", "裤", "裙", "鞋", "靴", "眼镜", "口罩", "手套", "围巾", "领带", "耳环",
        "耳饰", "项链", "手链", "腕表", "护甲", "披风",
    ];
    if extracted_type == "tool"
        && WEARABLE_MARKERS
            .iter()
            .any(|marker| name.contains(marker) || description.contains(marker))
    {
        "costume".to_string()
    } else {
        extracted_type.to_string()
    }
}

#[cfg(test)]
mod classification_tests {
    use super::normalized_asset_type;

    #[test]
    fn wearable_items_are_costumes_not_tools() {
        assert_eq!(
            normalized_asset_type("黑色鸭舌帽", "棉质", "tool"),
            "costume"
        );
        assert_eq!(
            normalized_asset_type("深紫技师服", "服务制服", "tool"),
            "costume"
        );
        assert_eq!(normalized_asset_type("水果刀", "削苹果", "tool"), "tool");
    }
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

async fn reconnect_legacy_derivatives(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    project_id: i64,
    script_ids: &[i64],
) -> Result<(), String> {
    sqlx::query(
        r#"WITH unmatched_appearances AS (
               SELECT ca.id AS appearance_id, ca.script_id, ca.role_asset_id,
                      row_number() OVER (
                          PARTITION BY ca.script_id, ca.role_asset_id ORDER BY ca.id
                      ) AS position,
                      count(*) OVER (
                          PARTITION BY ca.script_id, ca.role_asset_id
                      ) AS item_count
               FROM toonflow.character_appearances ca
               WHERE ca.project_id=$1 AND ca.script_id=ANY($2)
                 AND NOT EXISTS (
                     SELECT 1 FROM toonflow.assets current_asset
                     WHERE current_asset.appearance_id=ca.id
                       AND current_asset.parent_asset_id=ca.role_asset_id
                 )
           ), legacy_derivatives AS (
               SELECT d.id AS derived_id, sa.script_id, d.parent_asset_id AS role_asset_id,
                      row_number() OVER (
                          PARTITION BY sa.script_id, d.parent_asset_id ORDER BY d.id
                      ) AS position,
                      count(*) OVER (
                          PARTITION BY sa.script_id, d.parent_asset_id
                      ) AS item_count
               FROM toonflow.assets d
               JOIN toonflow.script_assets sa ON sa.asset_id=d.id
               WHERE d.project_id=$1 AND sa.script_id=ANY($2)
                 AND d.parent_asset_id IS NOT NULL AND d.appearance_id IS NULL
           ), pairs AS (
               SELECT legacy.derived_id, appearance.appearance_id
               FROM legacy_derivatives legacy
               JOIN unmatched_appearances appearance
                 ON appearance.script_id=legacy.script_id
                AND appearance.role_asset_id=legacy.role_asset_id
                AND appearance.position=legacy.position
                AND appearance.item_count=legacy.item_count
           )
           UPDATE toonflow.assets derived
           SET appearance_id=pairs.appearance_id
           FROM pairs
           WHERE derived.id=pairs.derived_id AND derived.appearance_id IS NULL"#,
    )
    .bind(project_id)
    .bind(script_ids)
    .execute(&mut **tx)
    .await
    .map_err(|error| error.to_string())?;
    Ok(())
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
    let existing = sqlx::query_as::<_, (String, String, String)>(
        "SELECT a.name,a.type,a.description FROM toonflow.assets a WHERE a.project_id=$1",
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())?
    .into_iter()
    .map(|row| format!("{}({})：{}", row.0, row.1, row.2))
    .collect::<Vec<_>>()
    .join("、");
    let content = scripts
        .iter()
        .map(|row| format!("===== 剧本ID:{} {} =====\n{}", row.0, row.1, row.2))
        .collect::<Vec<_>>()
        .join("\n\n");
    let system_prompt = toonflow_prompt_store::load(
        pool,
        "script_asset_extraction",
        "提取 role/scene/tool 基础资产，并逐场输出每个有名角色的 appearances。基础角色名必须使用统一身份名：童年王闲、少年王闲、成年王闲都必须写为 roleName=王闲，不得创建多个基础角色；role 描述只写不随年龄变化的身份特征，不得写年龄、身高、童年或成年外貌。年龄差异写入 appearance.ageStage，仅允许 child、teen、young_adult、adult、middle_aged、senior，剧本未明确年龄阶段时留空。role 不得包含服装，appearance 必须包含 roleName、name、ageStage、scenes、costumePrompt、description、scriptId。只输出约定 JSON。",
    )
    .await;
    let output = ai_client::project_text(
        pool,
        "universalAi",
        project_id,
        &system_prompt,
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
        let asset_type = normalized_asset_type(&asset.name, &asset.desc, &asset.type_);
        if asset.name.trim().is_empty() || !allowed.contains(&asset_type.as_str()) {
            continue;
        }
        let asset_name = if asset_type == "role" {
            normalize_role_name(asset.name.trim()).0
        } else {
            asset.name.trim().to_string()
        };
        if asset_type == "role" {
            toonflow_asset_description::validate_role_description(&asset.desc)?;
        }
        let existing_id: Option<i64> = sqlx::query_scalar(
            "SELECT id FROM toonflow.assets WHERE project_id=$1 AND name=$2 AND type=$3 LIMIT 1",
        )
        .bind(project_id)
        .bind(&asset_name)
        .bind(&asset_type)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|error| error.to_string())?;
        let asset_id = if let Some(id) = existing_id {
            id
        } else {
            let id = chrono::Utc::now().timestamp_micros();
            sqlx::query("INSERT INTO toonflow.assets(id,name,type,description,project_id,start_time) VALUES($1,$2,$3,$4,$5,$6)")
                .bind(id).bind(&asset_name).bind(&asset_type).bind(asset.desc.trim()).bind(project_id).bind(chrono::Utc::now().timestamp_millis())
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
        let reference_type =
            normalized_asset_type(&reference.name, &reference.desc, &reference.type_);
        let reference_name = if reference_type == "role" {
            normalize_role_name(reference.name.trim()).0
        } else {
            reference.name.trim().to_string()
        };
        let asset_id: Option<i64> = sqlx::query_scalar(
            "SELECT a.id FROM toonflow.assets a WHERE a.project_id=$1 AND a.name=$2 AND a.type=$3 LIMIT 1",
        )
        .bind(project_id)
        .bind(&reference_name)
        .bind(&reference_type)
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
    let mut retained_appearance_ids = Vec::new();
    for (offset, appearance) in result.appearances.into_iter().enumerate() {
        if !script_ids.contains(&appearance.script_id)
            || appearance.role_name.trim().is_empty()
            || appearance.name.trim().is_empty()
            || appearance.costume_prompt.trim().is_empty()
        {
            continue;
        }
        let (role_name, inferred_from_role) = normalize_role_name(appearance.role_name.trim());
        let inferred_from_appearance = normalize_role_name(appearance.name.trim()).1;
        let age_stage = normalize_age_stage(&appearance.age_stage)
            .or(inferred_from_role)
            .or(inferred_from_appearance)
            .unwrap_or("");
        let role_asset_id: Option<i64> = sqlx::query_scalar(
            "SELECT id FROM toonflow.assets WHERE project_id=$1 AND type='role' AND name=$2 AND parent_asset_id IS NULL LIMIT 1",
        )
        .bind(project_id)
        .bind(&role_name)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|error| error.to_string())?;
        let Some(role_asset_id) = role_asset_id else {
            continue;
        };
        let id = chrono::Utc::now().timestamp_micros() + offset as i64;
        let retained_id: i64 = sqlx::query_scalar("INSERT INTO toonflow.character_appearances(id,project_id,script_id,role_asset_id,name,age_stage,scenes,costume_prompt,description,create_time,update_time) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10) ON CONFLICT(script_id,role_asset_id,age_stage,name) DO UPDATE SET scenes=excluded.scenes,costume_prompt=excluded.costume_prompt,description=excluded.description,update_time=excluded.update_time RETURNING id")
            .bind(id)
            .bind(project_id)
            .bind(appearance.script_id)
            .bind(role_asset_id)
            .bind(appearance.name.trim())
            .bind(age_stage)
            .bind(json!(appearance.scenes))
            .bind(appearance.costume_prompt.trim())
            .bind(appearance.description.trim())
            .bind(chrono::Utc::now().timestamp_millis())
            .fetch_one(&mut *tx)
            .await
            .map_err(|error| error.to_string())?;
        retained_appearance_ids.push(retained_id);
    }
    sqlx::query(
        "DELETE FROM toonflow.character_appearances WHERE script_id=ANY($1) AND NOT(id=ANY($2))",
    )
    .bind(script_ids)
    .bind(&retained_appearance_ids)
    .execute(&mut *tx)
    .await
    .map_err(|error| error.to_string())?;
    reconnect_legacy_derivatives(&mut tx, project_id, script_ids).await?;
    sqlx::query("UPDATE toonflow.scripts SET extract_state=1,error_reason=NULL WHERE project_id=$1 AND id=ANY($2)")
        .bind(project_id).bind(script_ids).execute(&mut *tx).await.map_err(|error|error.to_string())?;
    tx.commit().await.map_err(|error| error.to_string())?;
    Ok(())
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
    let task_id = chrono::Utc::now().timestamp_micros();
    let mut tx = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to queue asset extraction"))?;
    let queued = sqlx::query("UPDATE toonflow.scripts SET extract_state=2,error_reason=NULL WHERE project_id=$1 AND id=ANY($2)")
        .bind(request.project_id).bind(&request.script_ids).execute(&mut *tx).await.map_err(|_|AppError::internal("failed to queue asset extraction"))?;
    if queued.rows_affected() != request.script_ids.len() as u64 {
        return Err(AppError::not_found("部分剧本不存在，请刷新后重试"));
    }
    let related_objects = json!({"scriptIds":request.script_ids}).to_string();
    sqlx::query("INSERT INTO toonflow.tasks(id,project_id,task_class,related_objects,model,description,state,start_time) SELECT $1,$2,'scriptAssetExtraction',$3,coalesce(chat_model::text,'universalAi'),'剧本资产提取','running',$4 FROM toonflow.projects WHERE id=$2")
        .bind(task_id).bind(request.project_id).bind(related_objects).bind(chrono::Utc::now().timestamp_millis()).execute(&mut *tx).await.map_err(|_|AppError::internal("failed to create asset extraction task"))?;
    tx.commit()
        .await
        .map_err(|_| AppError::internal("failed to queue asset extraction"))?;
    let pool = state.pool.clone();
    let project_id = request.project_id;
    let ids = request.script_ids;
    let group_size = request.group_size.unwrap_or(5).clamp(1, 20);
    tokio::spawn(async move {
        let mut failure = None;
        for group in ids.chunks(group_size) {
            if let Err(reason) = extract_group(&pool, project_id, group).await {
                let _=sqlx::query("UPDATE toonflow.scripts SET extract_state=-1,error_reason=$3 WHERE project_id=$1 AND id=ANY($2)").bind(project_id).bind(group).bind(&reason).execute(&pool).await;
                if failure.is_none() {
                    failure = Some(reason);
                }
            }
        }
        if let Some(reason) = failure {
            let _ = sqlx::query("UPDATE toonflow.tasks SET state='failed',reason=$2 WHERE id=$1")
                .bind(task_id)
                .bind(reason)
                .execute(&pool)
                .await;
        } else {
            let counts = sqlx::query_as::<_, (i64, i64)>(
                "SELECT count(DISTINCT sa.asset_id),count(DISTINCT ca.id) FROM unnest($1::bigint[]) AS scripts(script_id) LEFT JOIN toonflow.script_assets sa ON sa.script_id=scripts.script_id LEFT JOIN toonflow.character_appearances ca ON ca.script_id=scripts.script_id",
            )
            .bind(&ids)
            .fetch_one(&pool)
            .await
            .unwrap_or((0, 0));
            let description = format!(
                "剧本资产提取完成：{} 个基础资产，{} 套人物服装/形态",
                counts.0, counts.1
            );
            let related_objects =
                json!({"scriptIds":ids,"assetCount":counts.0,"appearanceCount":counts.1})
                    .to_string();
            let _ = sqlx::query("UPDATE toonflow.tasks SET state='success',description=$2,related_objects=$3,reason=NULL WHERE id=$1")
                .bind(task_id).bind(description).bind(related_objects).execute(&pool).await;
        }
    });
    Ok(Json(ApiResponse::new(
        json!({"message":"开始提取资产","taskId":task_id}),
    )))
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
    let rows = sqlx::query_as::<_, (i64, Option<i32>, Option<String>, i64)>(
        "SELECT s.id,s.extract_state,s.error_reason,(SELECT count(*) FROM toonflow.character_appearances ca WHERE ca.script_id=s.id) FROM toonflow.scripts s WHERE s.id=ANY($1) AND coalesce(s.extract_state,2)<>0",
    )
    .bind(request.ids)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| AppError::internal("failed to poll script assets"))?;
    Ok(Json(ApiResponse::new(
        rows.into_iter()
            .map(|row| json!({"id":row.0,"extractState":row.1,"errorReason":row.2,"appearanceCount":row.3}))
            .collect(),
    )))
}

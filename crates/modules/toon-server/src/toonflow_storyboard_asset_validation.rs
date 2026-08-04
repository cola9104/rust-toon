use rust_toon_framework_web::AppError;

pub async fn validate_storyboard_asset_ids(
    pool: &sqlx::PgPool,
    project_id: i64,
    asset_ids: &[i64],
) -> Result<(), AppError> {
    if asset_ids.is_empty() {
        return Ok(());
    }
    let contains_foreign_or_missing: bool = sqlx::query_scalar(
        r#"SELECT EXISTS(
             SELECT 1 FROM unnest($2::bigint[]) requested(id)
             WHERE NOT EXISTS(
               SELECT 1 FROM toonflow.assets a
               WHERE a.id=requested.id AND a.project_id=$1
             )
           )"#,
    )
    .bind(project_id)
    .bind(asset_ids)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal("failed to validate storyboard assets"))?;
    if contains_foreign_or_missing {
        return Err(AppError::bad_request(
            "分镜只能关联当前项目中的资产，请重新读取当前项目资产列表",
        ));
    }
    let names: Vec<String> = sqlx::query_scalar(
        "SELECT name FROM toonflow.assets WHERE project_id=$1 AND id=ANY($2) AND type='role' AND parent_asset_id IS NULL ORDER BY name",
    )
    .bind(project_id)
    .bind(asset_ids)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to validate storyboard role assets"))?;
    reject_names(names)
}

pub async fn reject_base_roles_for_storyboards(
    pool: &sqlx::PgPool,
    storyboard_ids: &[i64],
) -> Result<(), AppError> {
    let names: Vec<String> = sqlx::query_scalar(
        "SELECT DISTINCT a.name FROM toonflow.assets a JOIN toonflow.assets_storyboards ast ON ast.asset_id=a.id WHERE ast.storyboard_id=ANY($1) AND a.type='role' AND a.parent_asset_id IS NULL ORDER BY a.name",
    )
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal("failed to validate storyboard role assets"))?;
    reject_names(names)
}

fn reject_names(names: Vec<String>) -> Result<(), AppError> {
    if names.is_empty() {
        Ok(())
    } else {
        Err(AppError::bad_request(format!(
            "分镜禁止直接引用基础人物：{}。请改用对应场次的衍生人物形象后再生成。",
            names.join("、")
        )))
    }
}

use anyhow::{Context, bail};

use crate::SystemState;

pub async fn initialize(state: &SystemState) -> anyhow::Result<()> {
    let administrators = sqlx::query_scalar::<_, i64>(
        "SELECT count(*)
         FROM system_users u
         JOIN system_user_role ur ON ur.user_id = u.id AND ur.deleted = 0
         JOIN system_role r ON r.id = ur.role_id AND r.deleted = 0
         WHERE u.deleted = 0 AND u.status = 0 AND r.status = 0
           AND r.code = 'super_admin'",
    )
    .fetch_one(&state.pool)
    .await
    .context("failed to verify Yudao administrator")?;
    if administrators == 0 {
        bail!("Yudao system_users has no enabled super administrator");
    }
    tracing::info!(administrators, "Yudao administrators are ready");
    Ok(())
}

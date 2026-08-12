use rust_toon_framework_database::{DatabaseConfig, connect, migrate};
use sqlx::Row;

#[tokio::test]
#[ignore = "run with script/test-database-migrations.sh"]
async fn applies_all_migrations_to_empty_postgres() {
    let url = std::env::var("TEST_DATABASE_URL").expect("TEST_DATABASE_URL is required");
    let config = DatabaseConfig::new(url, 1, 5, std::time::Duration::from_secs(10))
        .expect("valid test database config");
    let pool = connect(&config).await.expect("connect test database");
    migrate(&pool).await.expect("apply complete migration set");

    let applied: i64 = sqlx::query_scalar("SELECT count(*) FROM _sqlx_migrations WHERE success")
        .fetch_one(&pool)
        .await
        .expect("read migration history");
    assert_eq!(applied, 18);

    let script_name_is_unique: bool = sqlx::query_scalar(
        "SELECT EXISTS(
           SELECT 1 FROM pg_indexes
           WHERE schemaname='toonflow'
             AND tablename='scripts'
             AND indexname='uq_toonflow_scripts_project_name'
         )",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect project script name uniqueness");
    assert!(script_name_is_unique);

    let appearance_age_stage_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='toonflow' AND table_name='character_appearances' AND column_name='age_stage')",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect character appearance age stage column");
    assert!(appearance_age_stage_exists);

    let project_chat_model_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(
           SELECT 1 FROM information_schema.columns
           WHERE table_schema='toonflow'
             AND table_name='projects'
             AND column_name='chat_model'
         )",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect project chat model column");
    assert!(project_chat_model_exists);

    let storyboard_asset_order_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(
           SELECT 1 FROM information_schema.columns
           WHERE table_schema='toonflow'
             AND table_name='assets_storyboards'
             AND column_name='sort_order'
         )",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect storyboard asset ordering column");
    assert!(storyboard_asset_order_exists);

    for column in ["progress_current", "progress_total", "retry_of_id"] {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(
               SELECT 1 FROM information_schema.columns
               WHERE table_schema='toonflow'
                 AND table_name='workflow_node_runs'
                 AND column_name=$1
             )",
        )
        .bind(column)
        .fetch_one(&pool)
        .await
        .expect("inspect workflow node run column");
        assert!(exists, "expected workflow node run column {column}");
    }

    let project_defaults: (Option<String>, Option<String>) = sqlx::query_as(
        "SELECT
           (SELECT column_default FROM information_schema.columns
            WHERE table_schema='toonflow' AND table_name='projects' AND column_name='video_ratio'),
           (SELECT column_default FROM information_schema.columns
            WHERE table_schema='toonflow' AND table_name='projects' AND column_name='mode')",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect project video defaults");
    assert_eq!(project_defaults.0.as_deref(), Some("'16:9'::text"));
    assert_eq!(
        project_defaults.1.as_deref(),
        Some("'startEndRequired'::text")
    );

    let asset_isolation_trigger: bool = sqlx::query_scalar(
        "SELECT EXISTS(
           SELECT 1 FROM information_schema.triggers
           WHERE event_object_schema='toonflow'
             AND event_object_table='project_assets'
             AND trigger_name='project_assets_enforce_ownership'
         )",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect project asset isolation trigger");
    assert!(asset_isolation_trigger);

    for table in [
        "ai.model_configs",
        "ai.chat_roles",
        "ai.knowledge_segments",
        "ai.images",
        "ai.music",
        "toonflow.projects",
        "toonflow.project_assets",
        "toonflow.workflow_definitions",
        "toonflow.workflow_runs",
        "toonflow.workflow_node_runs",
        "system_users",
        "system_role",
        "system_menu",
        "system_oauth2_access_token",
        "infra_config",
        "infra_job",
        "infra_job_log",
        "infra_api_access_log",
        "infra_api_error_log",
        "infra_codegen_table",
        "infra_codegen_column",
        "yudao_demo01_contact",
        "yudao_demo02_category",
        "yudao_demo03_student",
        "yudao_demo03_course",
        "yudao_demo03_grade",
    ] {
        let exists: bool = sqlx::query_scalar("SELECT to_regclass($1) IS NOT NULL")
            .bind(table)
            .fetch_one(&pool)
            .await
            .expect("inspect expected table");
        assert!(exists, "expected table {table}");
    }
    for sequence in [
        "system_dict_data_seq",
        "system_login_log_seq",
        "system_mail_log_seq",
        "system_notify_message_seq",
        "system_oauth2_access_token_seq",
        "system_oauth2_refresh_token_seq",
        "system_operate_log_seq",
        "system_sms_log_seq",
        "system_tenant_package_seq",
        "system_tenant_seq",
        "system_user_post_seq",
        "system_user_role_seq",
        "system_users_seq",
    ] {
        let exists: bool = sqlx::query_scalar("SELECT to_regclass($1) IS NOT NULL")
            .bind(sequence)
            .fetch_one(&pool)
            .await
            .expect("inspect expected sequence");
        assert!(exists, "expected sequence {sequence}");
    }
    for removed in ["toonflow.vendor_configs", "toonflow.model_prompts"] {
        let exists: bool = sqlx::query_scalar("SELECT to_regclass($1) IS NOT NULL")
            .bind(removed)
            .fetch_one(&pool)
            .await
            .expect("inspect removed table");
        assert!(!exists, "legacy table {removed} must be removed");
    }
    let menu = sqlx::query("SELECT component,deleted FROM system_menu WHERE id=30006")
        .fetch_one(&pool)
        .await
        .expect("AI model menu exists");
    assert_eq!(menu.get::<String, _>("component"), "ai/model/model/index");
    assert_eq!(menu.get::<i16, _>("deleted"), 1);

    let duplicate_route_names: i64 = sqlx::query_scalar(
        "SELECT count(*)
         FROM (
             SELECT CASE
                    WHEN coalesce(component_name, '') <> '' THEN component_name
                    ELSE name
                    END AS route_name
             FROM system_menu
             WHERE deleted = 0 AND status = 0 AND type <> 3
             GROUP BY route_name
             HAVING count(*) > 1
         ) duplicate_routes",
    )
    .fetch_one(&pool)
    .await
    .expect("read duplicate route names");
    assert_eq!(
        duplicate_route_names, 0,
        "active route menus must not generate duplicate frontend route names"
    );

    let restored_menu_catalog: i64 =
        sqlx::query_scalar("SELECT count(*) FROM system_menu WHERE deleted = 0")
            .fetch_one(&pool)
            .await
            .expect("read restored menu catalog");
    assert!(
        restored_menu_catalog >= 300,
        "fresh bootstrap must include the complete backend menu and permission catalog"
    );

    let restored_navigation_roots: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM system_menu
         WHERE id IN (1, 2, 1185, 2758) AND parent_id = 0
           AND type = 1 AND status = 0 AND deleted = 0",
    )
    .fetch_one(&pool)
    .await
    .expect("read restored navigation roots");
    assert_eq!(
        restored_navigation_roots, 4,
        "system, infrastructure, workflow, and AI navigation roots must be available"
    );

    let orphaned_active_menus: i64 = sqlx::query_scalar(
        "SELECT count(*)
         FROM system_menu child
         LEFT JOIN system_menu parent
           ON parent.id = child.parent_id AND parent.deleted = 0
         WHERE child.deleted = 0 AND child.parent_id <> 0 AND parent.id IS NULL",
    )
    .fetch_one(&pool)
    .await
    .expect("read orphaned active menus");
    assert_eq!(
        orphaned_active_menus, 0,
        "active menus must not disappear because their parent is missing"
    );

    for (table, column) in [
        ("system_dept", "tenant_id"),
        ("system_post", "tenant_id"),
        ("system_role", "tenant_id"),
        ("system_role", "data_scope_dept_ids"),
    ] {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(
               SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name=$1 AND column_name=$2
             )",
        )
        .bind(table)
        .bind(column)
        .fetch_one(&pool)
        .await
        .expect("inspect restored management column");
        assert!(exists, "expected management column {table}.{column}");
    }

    let department_leader_type: String = sqlx::query_scalar(
        "SELECT udt_name FROM information_schema.columns
         WHERE table_schema='public' AND table_name='system_dept'
           AND column_name='leader_user_id'",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect department leader identifier type");
    assert_eq!(department_leader_type, "int8");

    let infra_config_sequence_is_synchronized: bool = sqlx::query_scalar(
        "SELECT last_value >= COALESCE((SELECT max(id) FROM infra_config), 1)
         FROM infra_config_seq",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect infrastructure configuration sequence");
    assert!(infra_config_sequence_is_synchronized);

    let active_menu_links: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM system_menu
         WHERE deleted = 0 AND visible = false AND active_menu_id IS NOT NULL",
    )
    .fetch_one(&pool)
    .await
    .expect("read hidden-page business menu links");
    assert!(active_menu_links >= 14);

    let administrators: i64 = sqlx::query_scalar(
        "SELECT count(*)
         FROM system_users u
         JOIN system_user_role ur ON ur.user_id = u.id AND ur.deleted = 0
         JOIN system_role r ON r.id = ur.role_id AND r.deleted = 0
         WHERE u.deleted = 0 AND u.status = 0 AND r.status = 0
           AND r.code = 'super_admin'",
    )
    .fetch_one(&pool)
    .await
    .expect("read seeded administrators");
    assert!(administrators > 0);

    let baseline_tenants: i64 =
        sqlx::query_scalar("SELECT count(*) FROM system_tenant WHERE deleted = 0")
            .fetch_one(&pool)
            .await
            .expect("read baseline tenants");
    assert_eq!(
        baseline_tenants, 3,
        "fresh migration bootstrap must restore the current baseline tenants, not synthesize a default company"
    );

    let current_baseline_tenant_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(
            SELECT 1 FROM system_tenant
            WHERE id = 1 AND name = '芋道源码' AND deleted = 0
         )",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect current baseline tenant");
    assert!(
        current_baseline_tenant_exists,
        "fresh migration bootstrap must use the current database baseline data"
    );

    let organization_baseline: (i64, i64) = sqlx::query_as(
        "SELECT
            (SELECT count(*) FROM system_dept WHERE deleted = 0),
            (SELECT count(*) FROM system_post WHERE deleted = 0)",
    )
    .fetch_one(&pool)
    .await
    .expect("read organization baseline");
    assert!(organization_baseline.0 >= 10, "departments must be seeded");
    assert!(organization_baseline.1 >= 4, "posts must be seeded");

    let administrator_department_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(
            SELECT 1
            FROM system_users users
            JOIN system_dept dept ON dept.id = users.dept_id AND dept.deleted = 0
            WHERE users.username = 'admin' AND users.deleted = 0
         )",
    )
    .fetch_one(&pool)
    .await
    .expect("inspect administrator department");
    assert!(administrator_department_exists);

    let dictionary_baseline: (i64, i64, i64) = sqlx::query_as(
        "SELECT
            (SELECT count(*) FROM system_dict_type WHERE deleted = 0),
            (SELECT count(DISTINCT dict_type) FROM system_dict_data WHERE deleted = 0),
            (SELECT count(*) FROM system_dict_data data
             WHERE data.deleted = 0
               AND NOT EXISTS (
                   SELECT 1 FROM system_dict_type type
                   WHERE type.type = data.dict_type AND type.deleted = 0
               ))",
    )
    .fetch_one(&pool)
    .await
    .expect("read dictionary baseline");
    assert!(dictionary_baseline.0 >= dictionary_baseline.1);
    assert_eq!(
        dictionary_baseline.2, 0,
        "every dictionary must have a type"
    );

    let legacy_schema_exists: bool =
        sqlx::query_scalar("SELECT to_regnamespace('system') IS NOT NULL")
            .fetch_one(&pool)
            .await
            .expect("inspect legacy schema");
    assert!(!legacy_schema_exists);

    for runtime_table in [
        "system_oauth2_access_token",
        "system_oauth2_refresh_token",
        "system_login_log",
        "system_operate_log",
        "system_notify_message",
    ] {
        let rows: i64 = sqlx::query_scalar(&format!("SELECT count(*) FROM {runtime_table}"))
            .fetch_one(&pool)
            .await
            .expect("read runtime table");
        assert_eq!(rows, 0, "{runtime_table} must start empty");
    }

    let codex_test_users: i64 =
        sqlx::query_scalar("SELECT count(*) FROM system_users WHERE username='codex_excel_user'")
            .fetch_one(&pool)
            .await
            .expect("read test users");
    assert_eq!(
        codex_test_users, 0,
        "transient test users must not be seeded"
    );

    let users_with_login_traces: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM system_users WHERE login_ip <> '' OR login_date IS NOT NULL",
    )
    .fetch_one(&pool)
    .await
    .expect("read user login traces");
    assert_eq!(
        users_with_login_traces, 0,
        "seed users must not carry login traces"
    );

    let users_with_remote_yudao_avatar: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM system_users
         WHERE avatar LIKE 'http://test.yudao.iocoder.cn/%'
            OR avatar LIKE 'https://test.yudao.iocoder.cn/%'",
    )
    .fetch_one(&pool)
    .await
    .expect("read user avatars");
    assert_eq!(
        users_with_remote_yudao_avatar, 0,
        "seed users must not depend on remote Yudao avatar assets"
    );

    let plain_mail_passwords: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM system_mail_account
         WHERE password IS NOT NULL AND password <> '' AND password NOT LIKE 'enc:v1:%'",
    )
    .fetch_one(&pool)
    .await
    .expect("read mail secrets");
    assert_eq!(
        plain_mail_passwords, 0,
        "mail account passwords must be sealed"
    );

    let plain_sms_secrets: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM system_sms_channel
         WHERE api_key NOT LIKE 'enc:v1:%'
            OR (api_secret IS NOT NULL AND api_secret <> '' AND api_secret NOT LIKE 'enc:v1:%')",
    )
    .fetch_one(&pool)
    .await
    .expect("read sms secrets");
    assert_eq!(plain_sms_secrets, 0, "sms channel secrets must be sealed");
}

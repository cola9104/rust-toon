use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::{FromRow, PgPool};

pub const DEFAULT_HISTORY_PAGE_SIZE: usize = 24;
const MAX_HISTORY_PAGE_SIZE: usize = 50;

#[derive(Debug, FromRow)]
struct AgentHistoryRow {
    id: i64,
    role: String,
    content: String,
    create_time: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentHistoryContentBlock {
    id: String,
    #[serde(rename = "type")]
    content_type: &'static str,
    data: String,
    status: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentHistoryMessage {
    id: String,
    role: &'static str,
    name: &'static str,
    status: &'static str,
    datetime: String,
    historical: bool,
    content: Vec<AgentHistoryContentBlock>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentHistoryPage {
    pub messages: Vec<AgentHistoryMessage>,
    pub has_more: bool,
    pub oldest_id: Option<i64>,
    pub prepend: bool,
}

fn message_identity(role: &str) -> (&'static str, &'static str) {
    if role.starts_with("user") {
        return ("user", "你");
    }
    let name = if role.contains("execution:storySkeleton")
        || role.contains("execution:adaptationStrategy")
        || role.contains("execution:script")
    {
        "编剧"
    } else if role.contains("supervision") {
        "编辑"
    } else {
        "统筹"
    };
    ("assistant", name)
}

fn history_message(row: AgentHistoryRow) -> AgentHistoryMessage {
    let (role, name) = message_identity(&row.role);
    let datetime = DateTime::<Utc>::from_timestamp_millis(row.create_time)
        .map(|value| value.to_rfc3339())
        .unwrap_or_else(|| "1970-01-01T00:00:00+00:00".to_string());
    AgentHistoryMessage {
        id: format!("memory:{}", row.id),
        role,
        name,
        status: "complete",
        datetime,
        historical: true,
        content: vec![AgentHistoryContentBlock {
            id: format!("memory:{}:content", row.id),
            content_type: "text",
            data: row.content,
            status: "complete",
        }],
    }
}

pub async fn load_history_page(
    pool: &PgPool,
    agent_type: &str,
    isolation_key: &str,
    before_id: Option<i64>,
    requested_limit: Option<usize>,
    prepend: bool,
) -> Result<AgentHistoryPage, sqlx::Error> {
    let limit = requested_limit
        .unwrap_or(DEFAULT_HISTORY_PAGE_SIZE)
        .clamp(1, MAX_HISTORY_PAGE_SIZE);
    let mut rows = sqlx::query_as::<_, AgentHistoryRow>(
        "SELECT id,role,content,create_time
         FROM toonflow.agent_memories
         WHERE agent_type=$1
           AND isolation_key=$2
           AND memory_type='message'
           AND ($3::bigint IS NULL OR id < $3)
         ORDER BY create_time DESC,id DESC
         LIMIT $4",
    )
    .bind(agent_type)
    .bind(isolation_key)
    .bind(before_id)
    .bind((limit + 1) as i64)
    .fetch_all(pool)
    .await?;
    let has_more = rows.len() > limit;
    rows.truncate(limit);
    rows.reverse();
    let oldest_id = rows.first().map(|row| row.id);
    Ok(AgentHistoryPage {
        messages: rows.into_iter().map(history_message).collect(),
        has_more,
        oldest_id,
        prepend,
    })
}

#[cfg(test)]
mod tests {
    use super::{AgentHistoryRow, history_message, message_identity};

    #[test]
    fn creates_stable_lightweight_history_messages() {
        let message = history_message(AgentHistoryRow {
            id: 123,
            role: "assistant:execution:script".into(),
            content: "历史输出".into(),
            create_time: 1_700_000_000_000,
        });
        assert_eq!(message.id, "memory:123");
        assert_eq!(message.name, "编剧");
        assert_eq!(message.role, "assistant");
        assert!(message.historical);
        assert_eq!(message.content[0].id, "memory:123:content");
        assert_eq!(message.content[0].data, "历史输出");
        assert!(message.datetime.starts_with("2023-"));
    }

    #[test]
    fn maps_user_and_supervision_roles() {
        assert_eq!(message_identity("user"), ("user", "你"));
        assert_eq!(
            message_identity("assistant:supervision"),
            ("assistant", "编辑")
        );
    }
}

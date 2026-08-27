//! Shared contracts and cron parsing for durable background jobs.

use chrono::{DateTime, Utc};
use croner::parser::{CronParser, Seconds};
use serde::{Deserialize, Serialize};

pub const INFRA_SCHEDULED_JOB_KIND: &str = "infra.scheduled";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduledJobPayload {
    pub infra_job_id: i64,
    pub handler_name: String,
    pub handler_param: Option<String>,
    pub scheduled_at: DateTime<Utc>,
    pub triggered_by: String,
    #[serde(default)]
    pub retry_interval_millis: u64,
    #[serde(default)]
    pub monitor_timeout_millis: u64,
}

/// Parses both standard five-field cron and the six-field Quartz-like form
/// used by the administration UI. `?` is accepted in the day fields.
pub fn validate_cron(expression: &str) -> Result<(), String> {
    parse_cron(expression).map(|_| ())
}

pub fn next_occurrence(expression: &str, after: DateTime<Utc>) -> Result<DateTime<Utc>, String> {
    parse_cron(expression)?
        .find_next_occurrence(&after, false)
        .map_err(|error| format!("invalid cron expression: {error}"))
}

pub fn next_occurrences(
    expression: &str,
    after: DateTime<Utc>,
    count: usize,
) -> Result<Vec<DateTime<Utc>>, String> {
    let cron = parse_cron(expression)?;
    let mut cursor = after;
    let mut occurrences = Vec::with_capacity(count.min(100));
    for _ in 0..count.min(100) {
        cursor = cron
            .find_next_occurrence(&cursor, false)
            .map_err(|error| format!("invalid cron expression: {error}"))?;
        occurrences.push(cursor);
    }
    Ok(occurrences)
}

fn parse_cron(expression: &str) -> Result<croner::Cron, String> {
    let normalized = expression
        .split_whitespace()
        .map(|field| if field == "?" { "*" } else { field })
        .collect::<Vec<_>>()
        .join(" ");
    CronParser::builder()
        .seconds(Seconds::Optional)
        .build()
        .parse(&normalized)
        .map_err(|error| format!("invalid cron expression: {error}"))
}

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Timelike, Utc};

    use super::{next_occurrence, next_occurrences, validate_cron};

    #[test]
    fn accepts_ui_quartz_expression_and_preserves_seconds() {
        let after = Utc.with_ymd_and_hms(2026, 8, 27, 10, 0, 15).unwrap();
        let next = next_occurrence("15 */5 * * * ?", after).expect("valid cron");
        assert_eq!(next.minute(), 5);
        assert_eq!(next.second(), 15);
    }

    #[test]
    fn rejects_invalid_expressions_without_fallback_schedule() {
        assert!(validate_cron("not a cron").is_err());
    }

    #[test]
    fn returns_requested_ordered_occurrences() {
        let after = Utc.with_ymd_and_hms(2026, 8, 27, 10, 0, 0).unwrap();
        let values = next_occurrences("0 */10 * * * *", after, 3).expect("valid cron");
        assert_eq!(values.len(), 3);
        assert!(values.windows(2).all(|pair| pair[0] < pair[1]));
    }
}

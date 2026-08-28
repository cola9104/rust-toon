use std::collections::{HashMap, HashSet};

use rust_toon_framework_web::AppError;
use serde_json::Value;
use sqlx::{PgPool, Postgres, Transaction};

const TRANSITION_CUT: &str = "cut";
const TRANSITION_CONTINUOUS: &str = "continuous";
const TRANSITION_ACTION_BRIDGE: &str = "action_bridge";
const TRANSITION_EMPTY_SHOT: &str = "empty_shot";
const TRANSITION_DISSOLVE: &str = "dissolve";
const TRANSITION_AUDIO_BRIDGE: &str = "audio_bridge";
const TRANSITION_MATCH_CUT: &str = "match_cut";

const FRAME_POLICY_OWN: &str = "own";
const FRAME_POLICY_PREVIOUS_TAIL: &str = "previous_tail";

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct SceneTransition {
    pub from_scene_key: String,
    pub to_scene_key: String,
    pub transition_type: String,
    pub description: String,
    pub frame_policy: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ScriptPlanSection {
    None,
    SceneSummary,
    SceneTransitions,
}

/// Converts director- and storyboard-facing scene labels to the canonical `scN`
/// key. Unknown non-numeric labels are still normalized for stable comparisons.
pub(crate) fn normalize_scene_key(value: &str) -> String {
    let compact = value
        .trim()
        .trim_matches(|character: char| {
            matches!(
                character,
                '*' | '_' | '`' | '[' | ']' | '(' | ')' | '{' | '}'
            )
        })
        .chars()
        .filter(|character| !character.is_whitespace())
        .flat_map(char::to_lowercase)
        .collect::<String>();

    for prefix in ["scene", "sc", "场"] {
        if let Some(suffix) = compact.strip_prefix(prefix)
            && let Some(key) = canonical_numeric_scene_key(suffix)
        {
            return key;
        }
    }

    if let Some(suffix) = compact
        .strip_prefix('第')
        .and_then(|value| value.strip_suffix('场'))
        && let Some(key) = canonical_numeric_scene_key(suffix)
    {
        return key;
    }

    compact
}

/// Persistence uses one strict cross-layer contract. Empty values remain
/// nullable for upgraded projects, while every non-empty key must be `scN`.
pub(crate) fn normalize_persisted_scene_key(
    value: Option<&str>,
) -> Result<Option<String>, AppError> {
    let Some(value) = value else {
        return Ok(None);
    };
    if value.trim().is_empty() {
        return Ok(None);
    }
    let scene_key = normalize_scene_key(value);
    if is_canonical_scene_key(&scene_key) {
        Ok(Some(scene_key))
    } else {
        Err(AppError::bad_request(
            "场次键必须使用 scN 格式，例如 sc1、sc2",
        ))
    }
}

/// Produces deterministic parser input for the loosely typed work-data field.
/// Missing/null values deliberately become empty text so a save also clears any
/// stale structured transition rows.
pub(crate) fn script_plan_text(value: Option<&Value>) -> String {
    match value {
        Some(Value::String(value)) => value.clone(),
        Some(Value::Null) | None => String::new(),
        Some(Value::Object(value)) => ["content", "value", "text", "markdown"]
            .iter()
            .find_map(|key| value.get(*key).and_then(Value::as_str))
            .map(str::to_string)
            .unwrap_or_else(|| serde_json::to_string(value).unwrap_or_default()),
        Some(value) => serde_json::to_string(value).unwrap_or_default(),
    }
}

fn canonical_numeric_scene_key(value: &str) -> Option<String> {
    let digits = value.trim_matches(|character| matches!(character, ':' | '：' | '-' | '_' | '#'));
    if digits.is_empty() || !digits.chars().all(|character| character.is_ascii_digit()) {
        return None;
    }

    let digits = digits.trim_start_matches('0');
    Some(format!(
        "sc{}",
        if digits.is_empty() { "0" } else { digits }
    ))
}

pub(crate) fn parse_script_plan(text: &str) -> Vec<SceneTransition> {
    let mut section = ScriptPlanSection::None;
    let mut scene_keys = Vec::new();
    let mut seen_scene_keys = HashSet::new();
    let mut explicit_transitions = HashMap::new();

    for line in text.lines() {
        if let Some(heading) = markdown_heading(line) {
            section = if heading.contains("分场汇总") {
                ScriptPlanSection::SceneSummary
            } else if heading.contains("场间过渡") {
                ScriptPlanSection::SceneTransitions
            } else {
                ScriptPlanSection::None
            };
            continue;
        }

        let Some(cells) = parse_markdown_table_row(line) else {
            continue;
        };
        if cells.iter().all(|cell| is_table_separator(cell)) {
            continue;
        }

        match section {
            ScriptPlanSection::SceneSummary => {
                let Some(scene_key) = cells.first().map(|cell| normalize_scene_key(cell)) else {
                    continue;
                };
                if is_canonical_scene_key(&scene_key) && seen_scene_keys.insert(scene_key.clone()) {
                    scene_keys.push(scene_key);
                }
            }
            ScriptPlanSection::SceneTransitions => {
                let Some((from_scene_key, to_scene_key)) = cells
                    .first()
                    .and_then(|boundary| parse_scene_boundary(boundary))
                else {
                    continue;
                };
                let method = cells.get(1).map(String::as_str).unwrap_or_default();
                let description = cells
                    .get(2..)
                    .map(|cells| cells.join(" | "))
                    .unwrap_or_default();
                let transition_type = normalize_transition_type(method, &description);
                explicit_transitions.insert(
                    (from_scene_key, to_scene_key),
                    (transition_type.to_string(), description),
                );
            }
            ScriptPlanSection::None => {}
        }
    }

    scene_keys
        .windows(2)
        .map(|boundary| {
            let from_scene_key = boundary[0].clone();
            let to_scene_key = boundary[1].clone();
            let (transition_type, description) = explicit_transitions
                .remove(&(from_scene_key.clone(), to_scene_key.clone()))
                .unwrap_or_else(|| (TRANSITION_CUT.to_string(), String::new()));
            let frame_policy = frame_policy_for(&transition_type).to_string();
            SceneTransition {
                from_scene_key,
                to_scene_key,
                transition_type,
                description,
                frame_policy,
            }
        })
        .collect()
}

fn markdown_heading(line: &str) -> Option<&str> {
    let line = line.trim_start();
    let marker_len = line
        .chars()
        .take_while(|character| *character == '#')
        .count();
    if marker_len == 0 {
        return None;
    }

    let heading = line.get(marker_len..)?;
    heading
        .chars()
        .next()
        .is_some_and(char::is_whitespace)
        .then(|| heading.trim().trim_end_matches('#').trim())
}

fn parse_markdown_table_row(line: &str) -> Option<Vec<String>> {
    let line = line.trim();
    if !line.contains('|') {
        return None;
    }

    let mut cells = Vec::new();
    let mut cell = String::new();
    let mut characters = line.chars().peekable();
    while let Some(character) = characters.next() {
        match character {
            '\\' if characters.peek() == Some(&'|') => {
                characters.next();
                cell.push('|');
            }
            '|' => {
                cells.push(cell.trim().to_string());
                cell.clear();
            }
            _ => cell.push(character),
        }
    }
    cells.push(cell.trim().to_string());

    if line.starts_with('|') {
        cells.remove(0);
    }
    if line.ends_with('|') {
        cells.pop();
    }
    (cells.len() >= 2).then_some(cells)
}

fn is_table_separator(value: &str) -> bool {
    let value = value.trim();
    !value.is_empty()
        && value.chars().any(|character| character == '-')
        && value
            .chars()
            .all(|character| matches!(character, '-' | ':' | ' ' | '\t'))
}

fn is_canonical_scene_key(value: &str) -> bool {
    value
        .strip_prefix("sc")
        .and_then(|suffix| suffix.parse::<u64>().ok())
        .is_some_and(|number| number > 0)
}

fn parse_scene_boundary(value: &str) -> Option<(String, String)> {
    for separator in ["-->", "->", "=>", "→", "⇒", "⟶", "至"] {
        let Some((from_scene_key, to_scene_key)) = value.split_once(separator) else {
            continue;
        };
        let from_scene_key = normalize_scene_key(from_scene_key);
        let to_scene_key = normalize_scene_key(to_scene_key);
        if is_canonical_scene_key(&from_scene_key)
            && is_canonical_scene_key(&to_scene_key)
            && from_scene_key != to_scene_key
        {
            return Some((from_scene_key, to_scene_key));
        }
    }
    None
}

fn normalize_transition_type(method: &str, description: &str) -> &'static str {
    classify_transition_label(method)
        .or_else(|| classify_transition_label(description))
        .unwrap_or(TRANSITION_CUT)
}

fn classify_transition_label(value: &str) -> Option<&'static str> {
    let value = value.trim().to_lowercase();
    if value.is_empty() {
        return None;
    }

    match value.as_str() {
        TRANSITION_CUT => return Some(TRANSITION_CUT),
        TRANSITION_CONTINUOUS => return Some(TRANSITION_CONTINUOUS),
        TRANSITION_ACTION_BRIDGE => return Some(TRANSITION_ACTION_BRIDGE),
        TRANSITION_EMPTY_SHOT => return Some(TRANSITION_EMPTY_SHOT),
        TRANSITION_DISSOLVE => return Some(TRANSITION_DISSOLVE),
        TRANSITION_AUDIO_BRIDGE => return Some(TRANSITION_AUDIO_BRIDGE),
        TRANSITION_MATCH_CUT => return Some(TRANSITION_MATCH_CUT),
        _ => {}
    }

    if contains_any(
        &value,
        &[
            "声音桥",
            "声音衔接",
            "声音过渡",
            "声音延续",
            "音频桥",
            "音频衔接",
            "音效桥",
            "声画桥",
            "声画衔接",
            "音画桥",
            "音画衔接",
            "audio bridge",
            "sound bridge",
            "j-cut",
            "l-cut",
        ],
    ) {
        return Some(TRANSITION_AUDIO_BRIDGE);
    }
    if contains_any(
        &value,
        &[
            "匹配剪辑",
            "匹配剪切",
            "匹配切",
            "匹配转场",
            "图形匹配",
            "形状匹配",
            "动作匹配",
            "match cut",
        ],
    ) {
        return Some(TRANSITION_MATCH_CUT);
    }
    if contains_any(&value, &["动作衔接", "动作桥", "动作过渡", "action bridge"]) {
        return Some(TRANSITION_ACTION_BRIDGE);
    }
    if contains_any(
        &value,
        &["空镜", "空镜过场", "establishing shot", "empty shot"],
    ) {
        return Some(TRANSITION_EMPTY_SHOT);
    }
    if contains_any(
        &value,
        &[
            "叠化",
            "淡入淡出",
            "淡入",
            "淡出",
            "渐隐渐显",
            "溶解",
            "dissolve",
            "fade",
        ],
    ) {
        return Some(TRANSITION_DISSOLVE);
    }
    if contains_any(
        &value,
        &[
            "连续过渡",
            "连续衔接",
            "无缝过渡",
            "无缝衔接",
            "一镜到底",
            "continuous",
            "seamless",
        ],
    ) || value == "连续"
    {
        return Some(TRANSITION_CONTINUOUS);
    }
    if contains_any(
        &value,
        &["硬切", "直接切", "无过渡", "hard cut", "straight cut"],
    ) || value == "cut"
    {
        return Some(TRANSITION_CUT);
    }
    None
}

fn contains_any(value: &str, candidates: &[&str]) -> bool {
    candidates.iter().any(|candidate| value.contains(candidate))
}

fn frame_policy_for(transition_type: &str) -> &'static str {
    if transition_type == TRANSITION_CONTINUOUS {
        FRAME_POLICY_PREVIOUS_TAIL
    } else {
        FRAME_POLICY_OWN
    }
}

/// Saves the production workspace and, only when the director plan changed,
/// refreshes structured transitions plus director-owned track defaults in the
/// same transaction. Canvas/workflow-only saves therefore avoid rewriting the
/// whole episode while the persisted plan can never diverge from its projection.
pub(crate) async fn persist_work_data_with_transition_sync(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
    data: &Value,
    update_time: i64,
) -> Result<bool, AppError> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin production workspace save"))?;
    lock_transition_sync(&mut transaction, project_id, script_id).await?;

    let previous_data: Option<Value> = sqlx::query_scalar(
        "SELECT data FROM toonflow.agent_work_data
         WHERE project_id=$1 AND episodes_id=$2 AND key='productionAgent'
         FOR UPDATE",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to load production workspace"))?;
    let previous_script_plan = script_plan_text(
        previous_data
            .as_ref()
            .and_then(|data| data.get("scriptPlan")),
    );
    let current_script_plan = script_plan_text(data.get("scriptPlan"));
    let parsed_transitions = parse_script_plan(&current_script_plan);
    let stored_transitions = sqlx::query_as::<_, (String, String, String, String, String)>(
        "SELECT from_scene_key,to_scene_key,transition_type,description,frame_policy
         FROM toonflow.scene_transitions
         WHERE project_id=$1 AND script_id=$2",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_all(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to inspect scene transition projection"))?;
    let projection_matches = stored_transitions.len() == parsed_transitions.len()
        && parsed_transitions.iter().all(|transition| {
            stored_transitions.iter().any(
                |(from_scene_key, to_scene_key, transition_type, description, frame_policy)| {
                    from_scene_key == &transition.from_scene_key
                        && to_scene_key == &transition.to_scene_key
                        && transition_type == &transition.transition_type
                        && description == &transition.description
                        && frame_policy == &transition.frame_policy
                },
            )
        });
    let script_plan_changed = previous_data.is_none()
        || previous_script_plan != current_script_plan
        || !projection_matches;

    sqlx::query(
        "INSERT INTO toonflow.agent_work_data(
           project_id,episodes_id,key,data,create_time,update_time
         ) VALUES($1,$2,'productionAgent',$3,$4,$4)
         ON CONFLICT(project_id,episodes_id,key)
         DO UPDATE SET data=excluded.data,update_time=excluded.update_time",
    )
    .bind(project_id)
    .bind(script_id)
    .bind(data)
    .bind(update_time)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal("failed to save production workspace"))?;

    if script_plan_changed {
        replace_scene_transitions(
            &mut transaction,
            project_id,
            script_id,
            parsed_transitions,
            update_time,
        )
        .await?;
        apply_track_transition_defaults_in_transaction(&mut transaction, project_id, script_id)
            .await?;
    }

    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal("failed to commit production workspace save"))?;
    Ok(script_plan_changed)
}

async fn lock_transition_sync(
    transaction: &mut Transaction<'_, Postgres>,
    project_id: i64,
    script_id: i64,
) -> Result<(), AppError> {
    let lock_key = format!("toonflow:scene-transition:{project_id}:{script_id}");
    sqlx::query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))")
        .bind(lock_key)
        .execute(&mut **transaction)
        .await
        .map_err(|_| AppError::internal("failed to lock scene transition sync"))?;
    Ok(())
}

async fn replace_scene_transitions(
    transaction: &mut Transaction<'_, Postgres>,
    project_id: i64,
    script_id: i64,
    transitions: Vec<SceneTransition>,
    update_time: i64,
) -> Result<(), AppError> {
    sqlx::query("DELETE FROM toonflow.scene_transitions WHERE project_id=$1 AND script_id=$2")
        .bind(project_id)
        .bind(script_id)
        .execute(&mut **transaction)
        .await
        .map_err(|_| AppError::internal("failed to replace scene transitions"))?;

    for transition in transitions {
        sqlx::query(
            "INSERT INTO toonflow.scene_transitions(
               project_id,script_id,from_scene_key,to_scene_key,
               transition_type,description,frame_policy,update_time
             ) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
        )
        .bind(project_id)
        .bind(script_id)
        .bind(transition.from_scene_key)
        .bind(transition.to_scene_key)
        .bind(transition.transition_type)
        .bind(transition.description)
        .bind(transition.frame_policy)
        .bind(update_time)
        .execute(&mut **transaction)
        .await
        .map_err(|_| AppError::internal("failed to insert scene transition"))?;
    }

    Ok(())
}

pub(crate) async fn apply_track_transition_defaults(
    pool: &PgPool,
    project_id: i64,
    script_id: i64,
) -> Result<(), AppError> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal("failed to begin track transition sync"))?;

    lock_transition_sync(&mut transaction, project_id, script_id).await?;
    apply_track_transition_defaults_in_transaction(&mut transaction, project_id, script_id).await?;

    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal("failed to commit track transition sync"))
}

async fn apply_track_transition_defaults_in_transaction(
    transaction: &mut Transaction<'_, Postgres>,
    project_id: i64,
    script_id: i64,
) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE toonflow.video_tracks
         SET transition_type='cut',frame_policy='own',previous_track_id=NULL
         WHERE project_id=$1 AND script_id=$2 AND transition_source='director'",
    )
    .bind(project_id)
    .bind(script_id)
    .execute(&mut **transaction)
    .await
    .map_err(|_| AppError::internal("failed to reset director track transitions"))?;

    let tracks = sqlx::query_as::<_, (i64, String, Option<String>, Option<String>)>(
        "SELECT track.id,track.transition_source,
           (SELECT board.scene_key
            FROM toonflow.storyboards board
            WHERE board.track_id=track.id AND nullif(btrim(board.scene_key),'') IS NOT NULL
            ORDER BY board.index ASC NULLS LAST,board.id ASC
            LIMIT 1) AS first_scene_key,
           (SELECT board.scene_key
            FROM toonflow.storyboards board
            WHERE board.track_id=track.id AND nullif(btrim(board.scene_key),'') IS NOT NULL
            ORDER BY board.index DESC NULLS LAST,board.id DESC
            LIMIT 1) AS last_scene_key
         FROM toonflow.video_tracks track
         WHERE track.project_id=$1 AND track.script_id=$2
         ORDER BY coalesce((
                    SELECT min(board.index)
                    FROM toonflow.storyboards board
                    WHERE board.track_id=track.id
                  ),2147483647),track.sort_order,track.id",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_all(&mut **transaction)
    .await
    .map_err(|_| AppError::internal("failed to load track scene boundaries"))?;

    let transition_rows = sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT from_scene_key,to_scene_key,transition_type,frame_policy
         FROM toonflow.scene_transitions
         WHERE project_id=$1 AND script_id=$2",
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_all(&mut **transaction)
    .await
    .map_err(|_| AppError::internal("failed to load scene transitions"))?;

    let mut transitions = HashMap::new();
    for (from_scene_key, to_scene_key, transition_type, frame_policy) in transition_rows {
        let from_scene_key = normalize_scene_key(&from_scene_key);
        let to_scene_key = normalize_scene_key(&to_scene_key);
        if from_scene_key.is_empty() || to_scene_key.is_empty() || from_scene_key == to_scene_key {
            continue;
        }
        transitions.insert(
            (from_scene_key, to_scene_key),
            (transition_type, frame_policy),
        );
    }

    for adjacent_tracks in tracks.windows(2) {
        let (previous_track_id, _, _, previous_last_scene_key) = &adjacent_tracks[0];
        let (current_track_id, transition_source, current_first_scene_key, _) = &adjacent_tracks[1];
        if transition_source != "director" {
            continue;
        }

        let (Some(previous_last_scene_key), Some(current_first_scene_key)) =
            (previous_last_scene_key, current_first_scene_key)
        else {
            continue;
        };
        let previous_last_scene_key = normalize_scene_key(previous_last_scene_key);
        let current_first_scene_key = normalize_scene_key(current_first_scene_key);
        if previous_last_scene_key.is_empty()
            || current_first_scene_key.is_empty()
            || previous_last_scene_key == current_first_scene_key
        {
            continue;
        }

        let Some((transition_type, frame_policy)) =
            transitions.get(&(previous_last_scene_key, current_first_scene_key))
        else {
            continue;
        };
        let transition_type = canonical_stored_transition_type(transition_type);
        let frame_policy = if transition_type == TRANSITION_CONTINUOUS
            && frame_policy
                .trim()
                .eq_ignore_ascii_case(FRAME_POLICY_PREVIOUS_TAIL)
        {
            FRAME_POLICY_PREVIOUS_TAIL
        } else {
            FRAME_POLICY_OWN
        };
        let previous_track_id =
            (frame_policy == FRAME_POLICY_PREVIOUS_TAIL).then_some(*previous_track_id);

        sqlx::query(
            "UPDATE toonflow.video_tracks
             SET transition_type=$2,frame_policy=$3,previous_track_id=$4
             WHERE id=$1 AND project_id=$5 AND script_id=$6
               AND transition_source='director'",
        )
        .bind(current_track_id)
        .bind(transition_type)
        .bind(frame_policy)
        .bind(previous_track_id)
        .bind(project_id)
        .bind(script_id)
        .execute(&mut **transaction)
        .await
        .map_err(|_| AppError::internal("failed to apply director track transition"))?;
    }

    Ok(())
}

fn canonical_stored_transition_type(value: &str) -> &'static str {
    match value.trim().to_ascii_lowercase().as_str() {
        TRANSITION_CONTINUOUS => TRANSITION_CONTINUOUS,
        TRANSITION_ACTION_BRIDGE => TRANSITION_ACTION_BRIDGE,
        TRANSITION_EMPTY_SHOT => TRANSITION_EMPTY_SHOT,
        TRANSITION_DISSOLVE => TRANSITION_DISSOLVE,
        TRANSITION_AUDIO_BRIDGE => TRANSITION_AUDIO_BRIDGE,
        TRANSITION_MATCH_CUT => TRANSITION_MATCH_CUT,
        _ => TRANSITION_CUT,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn normalizes_scene_keys_to_canonical_form() {
        assert_eq!(normalize_scene_key(" Sc 001 "), "sc1");
        assert_eq!(normalize_scene_key("scene:02"), "sc2");
        assert_eq!(normalize_scene_key("场3"), "sc3");
        assert_eq!(normalize_scene_key("第 4 场"), "sc4");
        assert_eq!(normalize_scene_key(" Custom Scene "), "customscene");
        assert_eq!(normalize_scene_key("***"), "");
        assert_eq!(
            normalize_persisted_scene_key(Some(" Scene 002 ")).unwrap(),
            Some("sc2".into())
        );
        assert!(normalize_persisted_scene_key(Some("custom scene")).is_err());
        assert!(normalize_persisted_scene_key(Some("sc0")).is_err());
        assert_eq!(normalize_persisted_scene_key(Some("  ")).unwrap(), None);
    }

    #[test]
    fn converts_loose_script_plan_values_without_leaving_stale_input() {
        assert_eq!(
            script_plan_text(Some(&json!("## 分场汇总表"))),
            "## 分场汇总表"
        );
        assert_eq!(script_plan_text(Some(&json!({"content": "plan"}))), "plan");
        assert_eq!(
            script_plan_text(Some(&json!({"markdown": "# 规划"}))),
            "# 规划"
        );
        assert_eq!(
            script_plan_text(Some(&json!({"unknown": "plan"}))),
            r#"{"unknown":"plan"}"#
        );
        assert_eq!(script_plan_text(Some(&Value::Null)), "");
        assert_eq!(script_plan_text(None), "");
    }

    #[test]
    fn parses_explicit_transitions_and_preserves_descriptions() {
        let plan = r#"
<scriptPlan>
### 分场汇总表（核心）

| 场次 | 场景名 | 台词条数 |
|---|---|---|
| Sc1 | 门内 | 1 |
| Sc2 | 长廊 | 0 |
| Sc3 | 庭院 | 2 |

### 场间过渡

| 场间 | 过渡方式 | 说明 |
|---|---|---|
| Sc1 → Sc2 | 动作衔接 | 推门动作跨场\|脚步声延续 |
| Sc2 -> Sc3 | 叠化 | 雨丝叠化为庭院水帘 |
</scriptPlan>
"#;

        assert_eq!(
            parse_script_plan(plan),
            vec![
                SceneTransition {
                    from_scene_key: "sc1".into(),
                    to_scene_key: "sc2".into(),
                    transition_type: "action_bridge".into(),
                    description: "推门动作跨场|脚步声延续".into(),
                    frame_policy: "own".into(),
                },
                SceneTransition {
                    from_scene_key: "sc2".into(),
                    to_scene_key: "sc3".into(),
                    transition_type: "dissolve".into(),
                    description: "雨丝叠化为庭院水帘".into(),
                    frame_policy: "own".into(),
                },
            ]
        );
    }

    #[test]
    fn fills_unlisted_adjacent_boundaries_with_cut() {
        let plan = r#"
## 分场汇总表
| 场次 | 场景名 |
|---|---|
| Sc1 | 一 |
| Sc2 | 二 |
| Sc3 | 三 |

## 场间过渡
| 场间 | 过渡方式 | 说明 |
|---|---|---|
| Sc2 → Sc3 | 连续过渡 | 人物动作与构图无缝延续 |
"#;

        let transitions = parse_script_plan(plan);
        assert_eq!(transitions.len(), 2);
        assert_eq!(transitions[0].transition_type, "cut");
        assert_eq!(transitions[0].frame_policy, "own");
        assert!(transitions[0].description.is_empty());
        assert_eq!(transitions[1].transition_type, "continuous");
        assert_eq!(transitions[1].frame_policy, "previous_tail");
    }

    #[test]
    fn normalizes_all_supported_transition_types() {
        let cases = [
            ("硬切", "cut", "own"),
            ("连续", "continuous", "previous_tail"),
            ("动作衔接", "action_bridge", "own"),
            ("空镜过渡", "empty_shot", "own"),
            ("淡入淡出", "dissolve", "own"),
            ("声音桥", "audio_bridge", "own"),
            ("Match Cut", "match_cut", "own"),
        ];

        for (label, expected_type, expected_policy) in cases {
            let transition_type = normalize_transition_type(label, "");
            assert_eq!(transition_type, expected_type);
            assert_eq!(frame_policy_for(transition_type), expected_policy);
        }
        for canonical_type in [
            "cut",
            "continuous",
            "action_bridge",
            "empty_shot",
            "dissolve",
            "audio_bridge",
            "match_cut",
        ] {
            assert_eq!(
                normalize_transition_type(canonical_type, ""),
                canonical_type
            );
        }
        assert_eq!(normalize_transition_type("未知炫技转场", ""), "cut");
    }

    #[test]
    fn ignores_non_adjacent_and_same_scene_transition_rows() {
        let plan = r#"
### 分场汇总表
| 场次 | 场景名 |
|---|---|
| Sc1 | 一 |
| Sc2 | 二 |
| Sc3 | 三 |

### 场间过渡
| 场间 | 过渡方式 | 说明 |
|---|---|---|
| Sc1 → Sc3 | 连续 | 不应跨过 Sc2 |
| Sc2 → Sc2 | 连续 | 不应自连接 |
"#;

        assert!(
            parse_script_plan(plan)
                .iter()
                .all(|transition| transition.transition_type == "cut")
        );
    }
}

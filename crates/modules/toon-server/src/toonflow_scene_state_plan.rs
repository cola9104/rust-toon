//! Pure validation and planning for AI-proposed durable scene changes.
//!
//! The model may point at a storyboard and describe a completed physical
//! change. Stable keys, ordering and parentage are always assigned by the
//! server so model wording cannot mutate an existing timeline on retry.

use std::collections::{BTreeMap, HashMap, HashSet};

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

pub(crate) const MAX_DURABLE_STATES_PER_SCENE: usize = 8;

const MAX_NAME_CHARS: usize = 80;
const MAX_EVIDENCE_CHARS: usize = 500;
const MIN_EVIDENCE_CHARS: usize = 6;
const MAX_STATE_TEXT_CHARS: usize = 1_200;
const MAX_OBJECTS_PER_STATE: usize = 32;
const MAX_OBJECT_FIELD_CHARS: usize = 160;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub(crate) struct AiDurableState {
    pub(crate) start_storyboard_id: i64,
    pub(crate) evidence: String,
    pub(crate) object_states: AiObjectStates,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub(crate) struct AiObjectStates {
    pub(crate) objects: Vec<AiObjectState>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub(crate) struct AiObjectState {
    pub(crate) label: String,
    pub(crate) state: String,
    pub(crate) anchor: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct DurableStoryboardEvidence {
    pub(crate) id: i64,
    pub(crate) text: String,
}

#[derive(Clone, Debug, PartialEq)]
pub(crate) struct DurableStatePlan {
    pub(crate) state_key: String,
    pub(crate) start_storyboard_id: i64,
    pub(crate) start_position: usize,
    pub(crate) evidence: String,
    pub(crate) name: String,
    pub(crate) change_summary: String,
    pub(crate) state_prompt: String,
    pub(crate) object_states: Value,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct CleanObjectState {
    state: String,
    anchor: String,
}

#[derive(Debug)]
struct DurableStateBoundary {
    state_key: String,
    start_storyboard_id: i64,
    start_position: usize,
    evidence: String,
    object_states: BTreeMap<String, CleanObjectState>,
}

/// Validates an entire scene atomically. One invalid or unverifiable boundary
/// rejects the whole durable plan: accepting a later state while dropping its
/// predecessor would silently corrupt the cumulative physical history.
pub(crate) fn build_durable_state_plan(
    storyboards: &[DurableStoryboardEvidence],
    raw_states: Vec<AiDurableState>,
) -> Result<Vec<DurableStatePlan>, String> {
    if raw_states.len() > MAX_DURABLE_STATES_PER_SCENE {
        return Err("持久物理状态建议过多".to_string());
    }
    if raw_states.is_empty() {
        return Ok(Vec::new());
    }

    let positions = storyboards
        .iter()
        .enumerate()
        .map(|(position, storyboard)| (storyboard.id, position))
        .collect::<HashMap<_, _>>();
    let text_by_id = storyboards
        .iter()
        .map(|storyboard| (storyboard.id, normalize_evidence(&storyboard.text)))
        .collect::<HashMap<_, _>>();
    let mut seen_boundaries = HashSet::new();
    let mut boundaries = Vec::with_capacity(raw_states.len());

    for raw in raw_states {
        let Some(start_position) = positions.get(&raw.start_storyboard_id).copied() else {
            return Err(format!(
                "状态起点分镜 {} 不属于当前场次",
                raw.start_storyboard_id
            ));
        };
        if !seen_boundaries.insert(raw.start_storyboard_id) {
            return Err(format!(
                "分镜 {} 被重复声明为状态起点",
                raw.start_storyboard_id
            ));
        }

        let evidence = clean_text(&raw.evidence, "状态证据", MAX_EVIDENCE_CHARS)?;
        let normalized_evidence = normalize_evidence(&evidence);
        if normalized_evidence.chars().count() < MIN_EVIDENCE_CHARS
            || !text_by_id
                .get(&raw.start_storyboard_id)
                .is_some_and(|text| text.contains(&normalized_evidence))
        {
            return Err(format!(
                "分镜 {} 的状态证据不是画面描述原文",
                raw.start_storyboard_id
            ));
        }

        let object_states = clean_object_states(raw.object_states)?;
        boundaries.push(DurableStateBoundary {
            state_key: format!("auto_sb_{}", raw.start_storyboard_id),
            start_storyboard_id: raw.start_storyboard_id,
            start_position,
            evidence: normalized_evidence,
            object_states,
        });
    }

    boundaries.sort_by_key(|state| state.start_position);
    build_cumulative_state_plans(boundaries)
}

/// Expands inclusive state boundaries into the concrete storyboard batches
/// used by the transactional persistence layer.
pub(crate) fn build_state_intervals(
    ordered_storyboard_ids: &[i64],
    base_state_id: i64,
    state_by_boundary: &HashMap<i64, i64>,
) -> BTreeMap<i64, Vec<i64>> {
    let mut active_state_id = base_state_id;
    let mut assignments = BTreeMap::<i64, Vec<i64>>::new();
    for storyboard_id in ordered_storyboard_ids {
        if let Some(boundary_state_id) = state_by_boundary.get(storyboard_id) {
            active_state_id = *boundary_state_id;
        }
        assignments
            .entry(active_state_id)
            .or_default()
            .push(*storyboard_id);
    }
    assignments
}

fn clean_object_states(raw: AiObjectStates) -> Result<BTreeMap<String, CleanObjectState>, String> {
    if raw.objects.is_empty() || raw.objects.len() > MAX_OBJECTS_PER_STATE {
        return Err("物件状态快照为空或条目过多".to_string());
    }
    let mut result = BTreeMap::<String, CleanObjectState>::new();
    for object in raw.objects {
        let label = clean_state_field(&object.label, "物件名称")?;
        let state = clean_state_field(&object.state, "物件状态")?;
        let anchor = clean_state_field(&object.anchor, "物件固定位置")?;
        if result
            .insert(label.clone(), CleanObjectState { state, anchor })
            .is_some()
        {
            return Err(format!("物件“{label}”在同一状态中重复出现"));
        }
    }
    Ok(result)
}

fn build_cumulative_state_plans(
    boundaries: Vec<DurableStateBoundary>,
) -> Result<Vec<DurableStatePlan>, String> {
    let mut previous = BTreeMap::<String, CleanObjectState>::new();
    let mut plans = Vec::with_capacity(boundaries.len());
    for boundary in boundaries {
        let current = boundary.object_states;
        if !previous.keys().all(|label| current.contains_key(label)) {
            return Err(format!(
                "{} 的物件快照遗漏了前一状态已登记的物件",
                boundary.state_key
            ));
        }
        if let Some(label) = previous.keys().find(|label| {
            current.get(*label).is_some_and(|current_value| {
                previous.get(*label).expect("known previous object").anchor != current_value.anchor
            })
        }) {
            return Err(format!(
                "{} 把物件“{label}”移离了前态固定位置",
                boundary.state_key
            ));
        }
        let changed = current
            .iter()
            .filter(|(label, value)| {
                previous
                    .get(*label)
                    .is_none_or(|previous_value| previous_value.state != value.state)
            })
            .collect::<Vec<_>>();
        if changed.is_empty() {
            return Err(format!("{} 没有登记可见物理变化", boundary.state_key));
        }
        if let Some((label, value)) = changed.iter().find(|(label, value)| {
            !boundary.evidence.contains(label.as_str())
                || !boundary.evidence.contains(value.state.as_str())
        }) {
            return Err(format!(
                "{} 的原文证据未同时包含变化物件“{}”及其完整状态“{}”",
                boundary.state_key, label, value.state
            ));
        }

        let name = generated_state_name(&changed);
        let change_summary = format!(
            "持久变化：{}。",
            changed
                .iter()
                .map(|(label, value)| format!("{label}变为{}", value.state))
                .collect::<Vec<_>>()
                .join("；")
        );
        ensure_generated_length(
            &change_summary,
            "状态变化说明",
            MAX_STATE_TEXT_CHARS,
            &boundary.state_key,
        )?;
        let state_prompt = format!(
            "保持以下累计场景物件状态与固定位置不变：{}。",
            current
                .iter()
                .map(|(label, value)| {
                    format!("{label}为{}，固定位置：{}", value.state, value.anchor)
                })
                .collect::<Vec<_>>()
                .join("；")
        );
        ensure_generated_length(
            &state_prompt,
            "累计状态约束",
            MAX_STATE_TEXT_CHARS,
            &boundary.state_key,
        )?;
        let object_states = json!(
            current
                .iter()
                .map(|(label, value)| (
                    label.clone(),
                    format!("{}；固定位置：{}", value.state, value.anchor)
                ))
                .collect::<BTreeMap<_, _>>()
        );
        plans.push(DurableStatePlan {
            state_key: boundary.state_key,
            start_storyboard_id: boundary.start_storyboard_id,
            start_position: boundary.start_position,
            evidence: boundary.evidence,
            name,
            change_summary,
            state_prompt,
            object_states,
        });
        previous = current;
    }
    Ok(plans)
}

fn generated_state_name(changed: &[(&String, &CleanObjectState)]) -> String {
    let (label, value) = changed.first().expect("changed state is non-empty");
    let suffix = if changed.len() == 1 {
        String::new()
    } else {
        format!(" 等 {} 项变化", changed.len())
    };
    truncate_chars(
        &format!("{label} · {}{suffix}", value.state),
        MAX_NAME_CHARS,
    )
}

fn ensure_generated_length(
    value: &str,
    label: &str,
    max_chars: usize,
    state_key: &str,
) -> Result<(), String> {
    if value.chars().count() > max_chars {
        return Err(format!("{state_key} 的{label}过长"));
    }
    Ok(())
}

fn truncate_chars(value: &str, max_chars: usize) -> String {
    if value.chars().count() <= max_chars {
        return value.to_string();
    }
    let mut result = value
        .chars()
        .take(max_chars.saturating_sub(1))
        .collect::<String>();
    result.push('…');
    result
}

fn clean_state_field(value: &str, label: &str) -> Result<String, String> {
    let value = clean_text(value, label, MAX_OBJECT_FIELD_CHARS)?;
    if contains_forbidden_terms(&value) {
        return Err(format!("{label}混入人物、镜头、光影、动作过程或控制指令"));
    }
    Ok(value)
}

fn clean_text(value: &str, label: &str, max_chars: usize) -> Result<String, String> {
    let value = value.split_whitespace().collect::<Vec<_>>().join(" ");
    if value.is_empty() || value.chars().count() > max_chars {
        return Err(format!("{label}为空或过长"));
    }
    Ok(value)
}

fn normalize_evidence(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn contains_forbidden_terms(value: &str) -> bool {
    let value = value.to_lowercase();
    [
        "人物",
        "角色",
        "演员",
        "镜头",
        "机位",
        "景别",
        "构图",
        "摄影",
        "视角",
        "光线",
        "光影",
        "色调",
        "动作",
        "正在",
        "忽略",
        "系统提示",
        "提示词",
        "指令",
        "执行以下",
        "camera",
        "shot",
        "lighting",
        "character",
        "ignore previous",
        "system prompt",
        "assistant",
        "tool call",
    ]
    .iter()
    .any(|term| value.contains(term))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn evidence(id: i64, text: &str) -> DurableStoryboardEvidence {
        DurableStoryboardEvidence {
            id,
            text: text.to_string(),
        }
    }

    fn state(id: i64, evidence: &str, objects: &[(&str, &str)]) -> AiDurableState {
        AiDurableState {
            start_storyboard_id: id,
            evidence: evidence.to_string(),
            object_states: AiObjectStates {
                objects: objects
                    .iter()
                    .map(|(label, value)| AiObjectState {
                        label: (*label).to_string(),
                        state: (*value).to_string(),
                        anchor: "北墙中央".to_string(),
                    })
                    .collect(),
            },
        }
    }

    #[test]
    fn orders_boundaries_and_assigns_server_keys() {
        let storyboards = vec![
            evidence(10, "门保持完好。"),
            evidence(20, "木门已经断裂。"),
            evidence(30, "桌面已经塌陷。"),
        ];
        let plans = build_durable_state_plan(
            &storyboards,
            vec![
                state(30, "桌面已经塌陷。", &[("木门", "断裂"), ("桌面", "塌陷")]),
                state(20, "木门已经断裂。", &[("木门", "断裂")]),
            ],
        )
        .unwrap();
        assert_eq!(
            plans
                .iter()
                .map(|plan| (plan.state_key.as_str(), plan.start_position))
                .collect::<Vec<_>>(),
            vec![("auto_sb_20", 1), ("auto_sb_30", 2)]
        );
        assert_eq!(plans[0].name, "木门 · 断裂");
        assert_eq!(plans[0].change_summary, "持久变化：木门变为断裂。");
        assert!(plans[1].change_summary.contains("桌面变为塌陷"));
        assert!(plans[1].state_prompt.contains("木门为断裂"));
        assert!(plans[1].state_prompt.contains("桌面为塌陷"));
    }

    #[test]
    fn rejects_unknown_or_duplicate_boundaries() {
        let storyboards = vec![evidence(20, "木门已经断裂。")];
        assert!(
            build_durable_state_plan(
                &storyboards,
                vec![state(99, "木门已经断裂。", &[("门", "断裂")])]
            )
            .is_err()
        );
        assert!(
            build_durable_state_plan(
                &storyboards,
                vec![
                    state(20, "木门已经断裂。", &[("门", "断裂")]),
                    state(20, "木门已经断裂。", &[("门", "断裂")]),
                ],
            )
            .is_err()
        );
    }

    #[test]
    fn rejects_hallucinated_or_ambiguous_evidence() {
        let storyboards = vec![evidence(20, "木门已经断裂。")];
        assert!(
            build_durable_state_plan(
                &storyboards,
                vec![state(20, "桌子已经倒塌。", &[("门", "断裂")])],
            )
            .is_err()
        );
        assert!(
            build_durable_state_plan(&storyboards, vec![state(20, "门", &[("木门", "断裂")])],)
                .is_err()
        );
        let intact = vec![evidence(20, "木门仍保持完好。")];
        assert!(
            build_durable_state_plan(
                &intact,
                vec![state(20, "木门仍保持完好。", &[("木门", "断裂")])],
            )
            .is_err()
        );
    }

    #[test]
    fn rejects_a_second_changed_object_not_supported_by_evidence() {
        let storyboards = vec![evidence(20, "木门已经断裂。")];
        let result = build_durable_state_plan(
            &storyboards,
            vec![state(
                20,
                "木门已经断裂。",
                &[("木门", "断裂"), ("长桌", "塌陷")],
            )],
        );
        assert!(
            result
                .unwrap_err()
                .contains("变化物件“长桌”及其完整状态“塌陷”")
        );
    }

    #[test]
    fn rejects_generated_cumulative_prompt_over_limit() {
        let objects = (1..=8)
            .map(|index| AiObjectState {
                label: format!("物件{index}"),
                state: format!("损坏{index}"),
                anchor: "北墙固定区域".repeat(26),
            })
            .collect::<Vec<_>>();
        let evidence_text = (1..=8)
            .map(|index| format!("物件{index}已经损坏{index}"))
            .collect::<Vec<_>>()
            .join("，");
        let result = build_durable_state_plan(
            &[evidence(20, &evidence_text)],
            vec![AiDurableState {
                start_storyboard_id: 20,
                evidence: evidence_text,
                object_states: AiObjectStates { objects },
            }],
        );
        assert!(result.unwrap_err().contains("累计状态约束过长"));
    }

    #[test]
    fn rejects_non_cumulative_object_snapshots() {
        let storyboards = vec![
            evidence(20, "木门已经断裂。"),
            evidence(30, "桌面已经塌陷。"),
        ];
        assert!(
            build_durable_state_plan(
                &storyboards,
                vec![
                    state(20, "木门已经断裂。", &[("木门", "断裂")]),
                    state(30, "桌面已经塌陷。", &[("长桌", "塌陷")]),
                ],
            )
            .is_err()
        );
    }

    #[test]
    fn rejects_fixed_object_anchor_drift() {
        let storyboards = vec![
            evidence(20, "木门已经断裂。"),
            evidence(30, "桌面已经塌陷。"),
        ];
        let first = state(20, "木门已经断裂。", &[("木门", "断裂")]);
        let mut second = state(30, "桌面已经塌陷。", &[("木门", "断裂"), ("桌面", "塌陷")]);
        second.object_states.objects[0].anchor = "南墙角落".to_string();
        assert!(build_durable_state_plan(&storyboards, vec![first, second]).is_err());
    }

    #[test]
    fn expands_boundaries_inclusively_without_state_regression() {
        let intervals =
            build_state_intervals(&[1, 2, 3, 4, 5], 100, &HashMap::from([(2, 200), (4, 300)]));
        assert_eq!(intervals.get(&100), Some(&vec![1]));
        assert_eq!(intervals.get(&200), Some(&vec![2, 3]));
        assert_eq!(intervals.get(&300), Some(&vec![4, 5]));
    }
}

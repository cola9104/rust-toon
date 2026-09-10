use sqlx::PgPool;
use std::collections::HashSet;

pub(crate) async fn setting_usize(pool: &PgPool, key: &str, default: usize) -> usize {
    sqlx::query_scalar::<_, String>("SELECT value FROM toonflow.settings WHERE key=$1")
        .bind(key)
        .fetch_optional(pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| value.parse::<usize>().ok())
        .filter(|value| *value > 0)
        .unwrap_or(default)
}

/// Removes XML/HTML-style tags while preserving their textual contents.
/// Agent protocol tags are useful during execution but must never leak into memory.
pub(crate) fn strip_xml_tags(content: &str) -> String {
    let mut output = String::with_capacity(content.len());
    let mut in_tag = false;
    for character in content.chars() {
        match character {
            '<' => in_tag = true,
            '>' if in_tag => in_tag = false,
            _ if !in_tag => output.push(character),
            _ => {}
        }
    }
    output.trim().to_string()
}

#[derive(Debug, PartialEq, Eq)]
#[cfg(test)]
pub(crate) enum ThinkingPart {
    Text(String),
    Start,
    Thinking(String),
    End,
}

#[derive(Default)]
#[cfg(test)]
pub(crate) struct ThinkingStream {
    buffer: String,
    in_thinking: bool,
}

#[cfg(test)]
impl ThinkingStream {
    pub(crate) fn push(&mut self, chunk: &str) -> Vec<ThinkingPart> {
        self.buffer.push_str(chunk);
        let mut parts = Vec::new();
        loop {
            let tag = if self.in_thinking {
                "</think>"
            } else {
                "<think>"
            };
            if let Some(index) = self.buffer.find(tag) {
                let content = self.buffer[..index].to_string();
                if !content.is_empty() {
                    parts.push(if self.in_thinking {
                        ThinkingPart::Thinking(content)
                    } else {
                        ThinkingPart::Text(content)
                    });
                }
                self.buffer.drain(..index + tag.len());
                self.in_thinking = !self.in_thinking;
                parts.push(if self.in_thinking {
                    ThinkingPart::Start
                } else {
                    ThinkingPart::End
                });
                continue;
            }
            let keep = tag.len().saturating_sub(1);
            let mut split = self.buffer.len().saturating_sub(keep);
            while split > 0 && !self.buffer.is_char_boundary(split) {
                split -= 1;
            }
            if split > 0 {
                let content = self.buffer[..split].to_string();
                self.buffer.drain(..split);
                parts.push(if self.in_thinking {
                    ThinkingPart::Thinking(content)
                } else {
                    ThinkingPart::Text(content)
                });
            }
            return parts;
        }
    }

    pub(crate) fn finish(mut self) -> Vec<ThinkingPart> {
        if self.buffer.is_empty() {
            return Vec::new();
        }
        vec![if self.in_thinking {
            ThinkingPart::Thinking(std::mem::take(&mut self.buffer))
        } else {
            ThinkingPart::Text(std::mem::take(&mut self.buffer))
        }]
    }
}

async fn embedding(pool: &PgPool, text: &str) -> Option<Vec<f32>> {
    let model_id: i64 = sqlx::query_scalar(
        "SELECT id FROM ai.model_configs WHERE type='embedding' AND status=0 ORDER BY id LIMIT 1",
    )
    .fetch_optional(pool)
    .await
    .ok()??;
    rust_toon_ai_server::AiModelFactory::new(pool.clone())
        .embedding(
            model_id,
            rust_toon_ai_api::EmbeddingRequest {
                inputs: vec![text.to_string()],
            },
        )
        .await
        .ok()?
        .embeddings
        .into_iter()
        .next()
}

pub(crate) async fn store_memory_embedding(pool: &PgPool, id: i64, content: &str) {
    let Some(vector) = embedding(pool, content).await else {
        tracing::warn!(
            memory_id = id,
            "agent memory saved without embedding; configure an enabled embedding model to enable semantic retrieval"
        );
        return;
    };
    if let Err(error) = sqlx::query("UPDATE toonflow.agent_memories SET embedding=$2 WHERE id=$1")
        .bind(id)
        .bind(serde_json::json!(vector))
        .execute(pool)
        .await
    {
        tracing::warn!(memory_id = id, %error, "failed to store agent memory embedding");
    }
}

fn cosine(left: &[f32], right: &[f32]) -> f32 {
    if left.len() != right.len() || left.is_empty() {
        return 0.0;
    }
    let dot = left.iter().zip(right).map(|(a, b)| a * b).sum::<f32>();
    let left_norm = left.iter().map(|value| value * value).sum::<f32>().sqrt();
    let right_norm = right.iter().map(|value| value * value).sum::<f32>().sqrt();
    if left_norm == 0.0 || right_norm == 0.0 {
        0.0
    } else {
        dot / (left_norm * right_norm)
    }
}

fn parse_id_array(value: &str) -> HashSet<i64> {
    let Some(start) = value.find('[') else {
        return HashSet::new();
    };
    let Some(end) = value.rfind(']').map(|index| index + 1) else {
        return HashSet::new();
    };
    serde_json::from_str::<Vec<i64>>(&value[start..end])
        .unwrap_or_default()
        .into_iter()
        .collect()
}

pub(crate) async fn load_agent_skill(pool: &PgPool, agent_key: &str) -> Result<String, String> {
    let (path, content): (String, String) = sqlx::query_as(
        "SELECT a.skill_path,s.content
         FROM toonflow.skill_attributions a
         JOIN toonflow.skill_list s ON s.path=a.skill_path
         WHERE a.agent_key=$1 AND s.state=1 AND s.content<>''
         ORDER BY a.priority,a.skill_path LIMIT 1",
    )
    .bind(agent_key)
    .fetch_optional(pool)
    .await
    .map_err(|error| error.to_string())?
    .ok_or_else(|| format!("Agent {agent_key} 没有可用 Skill"))?;
    if content.trim().is_empty() {
        return Err(format!("Agent {agent_key} 的主 Skill {path} 内容为空"));
    }
    Ok(content)
}

pub(crate) async fn load_skill(pool: &PgPool, path: &str) -> Result<String, String> {
    sqlx::query_scalar(
        "SELECT content FROM toonflow.skill_list WHERE path=$1 AND state=1 AND content<>''",
    )
    .bind(path)
    .fetch_optional(pool)
    .await
    .map_err(|error| error.to_string())?
    .ok_or_else(|| format!("Skill {path} 不存在或已停用"))
}

pub(crate) async fn dynamic_skills(
    pool: &PgPool,
    project_id: i64,
) -> Result<Vec<(String, String, String)>, String> {
    let project: Option<(String, String)> =
        sqlx::query_as("SELECT art_style,director_manual FROM toonflow.projects WHERE id=$1")
            .bind(project_id)
            .fetch_optional(pool)
            .await
            .map_err(|error| error.to_string())?;
    let (art_style, director_manual) = project.unwrap_or_default();
    sqlx::query_as(
        "SELECT path,name,description FROM toonflow.skill_list WHERE state=1 AND (path LIKE 'production_skills/%' OR ($1<>'' AND path LIKE 'art_skills/%') OR ($2<>'' AND path LIKE 'story_skills/%')) ORDER BY path",
    )
    .bind(art_style.trim())
    .bind(director_manual.trim())
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())
}

pub(crate) async fn available_skills(
    pool: &PgPool,
    agent_key: &str,
    project_id: i64,
) -> Result<Vec<(String, String, String)>, String> {
    let mut skills = Vec::new();
    skills.extend(
        sqlx::query_as::<_, (String, String, String)>(
            "SELECT a.skill_path,s.name,s.description
         FROM toonflow.skill_attributions a
         JOIN toonflow.skill_list s ON s.path=a.skill_path
         WHERE a.agent_key=$1 AND s.state=1 ORDER BY a.priority,a.skill_path",
        )
        .bind(agent_key)
        .fetch_all(pool)
        .await
        .map_err(|error| error.to_string())?,
    );
    skills.extend(dynamic_skills(pool, project_id).await?);
    skills.sort_by(|left, right| left.0.cmp(&right.0));
    skills.dedup_by(|left, right| left.0 == right.0);
    Ok(skills)
}

fn terms(value: &str) -> HashSet<String> {
    let lower = value.to_lowercase();
    let chars = lower.chars().collect::<Vec<_>>();
    let mut result = lower
        .split(|character: char| !character.is_alphanumeric())
        .filter(|term| term.chars().count() >= 2)
        .map(str::to_string)
        .collect::<HashSet<_>>();
    for pair in chars.windows(2) {
        if pair.iter().all(|character| !character.is_whitespace()) {
            result.insert(pair.iter().collect());
        }
    }
    result
}

pub(crate) async fn relevant_memories(
    pool: &PgPool,
    agent_type: &str,
    isolation_key: &str,
    query: &str,
    limit: usize,
) -> Result<Vec<String>, String> {
    let rows: Vec<(i64, String, Option<serde_json::Value>)> = sqlx::query_as(
        "SELECT create_time,content,embedding FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='message' ORDER BY create_time DESC LIMIT 100",
    )
    .bind(agent_type)
    .bind(isolation_key)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())?;
    let query_embedding = embedding(pool, query).await;
    let query_terms = terms(query);
    let mut ranked = rows
        .into_iter()
        .filter_map(|(time, content, stored)| {
            let semantic = query_embedding.as_ref().and_then(|query_vector| {
                let vector = serde_json::from_value::<Vec<f32>>(stored?).ok()?;
                Some(cosine(query_vector, &vector))
            });
            let lexical = terms(&content).intersection(&query_terms).count() as f32;
            let score = semantic.map(|value| value * 1000.0).unwrap_or(lexical);
            (score > 0.0).then_some((score, time, content))
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|left, right| right.0.total_cmp(&left.0).then(right.1.cmp(&left.1)));
    Ok(ranked
        .into_iter()
        .take(limit)
        .map(|(_, _, content)| content)
        .collect())
}

pub(crate) async fn deep_retrieve(
    pool: &PgPool,
    agent_type: &str,
    isolation_key: &str,
    keyword: &str,
    judge_agent_key: &str,
    limit: usize,
) -> Result<Vec<String>, String> {
    let rows: Vec<(i64, String, serde_json::Value, i64, Option<serde_json::Value>)> = sqlx::query_as(
        "SELECT id,content,related_message_ids,create_time,embedding FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='summary' ORDER BY create_time DESC",
    )
    .bind(agent_type)
    .bind(isolation_key)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())?;
    let query_embedding = embedding(pool, keyword).await;
    let query_terms = terms(keyword);
    let mut ranked = rows
        .into_iter()
        .filter_map(|(id, content, related, time, stored)| {
            let semantic = query_embedding.as_ref().and_then(|query_vector| {
                let vector = serde_json::from_value::<Vec<f32>>(stored?).ok()?;
                Some(cosine(query_vector, &vector))
            });
            let lexical = terms(&content).intersection(&query_terms).count() as f32;
            let score = semantic.map(|value| value * 1000.0).unwrap_or(lexical);
            (score > 0.0).then_some((score, time, id, content, related))
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|left, right| right.0.total_cmp(&left.0).then(right.1.cmp(&left.1)));
    ranked.truncate(limit);
    if ranked.is_empty() {
        return Ok(Vec::new());
    }

    let candidates = ranked
        .iter()
        .map(|(_, _, id, content, _)| format!("{id}: {content}"))
        .collect::<Vec<_>>()
        .join("\n");
    let judged = crate::ai_client::text(
        pool,
        judge_agent_key,
        "判断哪些摘要与关键词直接相关。只输出相关摘要 ID 的 JSON 数组，例如 [1,2]；没有则输出 []。",
        &format!("关键词：{keyword}\n摘要：\n{candidates}"),
    )
    .await?;
    let relevant_ids = parse_id_array(&judged);
    if relevant_ids.is_empty() {
        return Ok(Vec::new());
    }
    let message_ids = ranked
        .into_iter()
        .filter(|(_, _, id, _, _)| relevant_ids.contains(id))
        .flat_map(|(_, _, _, _, value)| {
            serde_json::from_value::<Vec<i64>>(value).unwrap_or_default()
        })
        .collect::<Vec<_>>();
    if message_ids.is_empty() {
        return Ok(Vec::new());
    }
    expand_related_messages(pool, agent_type, isolation_key, &message_ids).await
}

pub(crate) async fn expand_related_messages(
    pool: &PgPool,
    agent_type: &str,
    isolation_key: &str,
    message_ids: &[i64],
) -> Result<Vec<String>, String> {
    if message_ids.is_empty() {
        return Ok(Vec::new());
    }
    sqlx::query_scalar(
        "SELECT content FROM toonflow.agent_memories WHERE agent_type=$1 AND isolation_key=$2 AND memory_type='message' AND id=ANY($3) ORDER BY create_time",
    )
    .bind(agent_type)
    .bind(isolation_key)
    .bind(message_ids)
    .fetch_all(pool)
    .await
    .map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::{ThinkingPart, ThinkingStream, parse_id_array, strip_xml_tags};

    #[test]
    fn strips_agent_protocol_xml_without_losing_text() {
        assert_eq!(
            strip_xml_tags("<think>草稿</think><result>最终答案</result>"),
            "草稿最终答案"
        );
        assert_eq!(strip_xml_tags("普通文本"), "普通文本");
    }

    #[test]
    fn incrementally_splits_thinking_tags_across_chunks() {
        let mut stream = ThinkingStream::default();
        let mut parts = stream.push("answer<th");
        parts.extend(stream.push("ink>private</thi"));
        parts.extend(stream.push("nk>done"));
        parts.extend(stream.finish());
        let text = parts
            .iter()
            .filter_map(|part| match part {
                ThinkingPart::Text(value) => Some(value.as_str()),
                _ => None,
            })
            .collect::<String>();
        let thinking = parts
            .iter()
            .filter_map(|part| match part {
                ThinkingPart::Thinking(value) => Some(value.as_str()),
                _ => None,
            })
            .collect::<String>();
        assert_eq!(text, "answerdone");
        assert_eq!(thinking, "private");
        assert_eq!(
            parts
                .iter()
                .filter(|part| **part == ThinkingPart::Start)
                .count(),
            1
        );
        assert_eq!(
            parts
                .iter()
                .filter(|part| **part == ThinkingPart::End)
                .count(),
            1
        );
    }

    #[test]
    fn parses_relevance_ids_from_model_wrappers() {
        assert_eq!(
            parse_id_array("```json\n[2, 7]\n```"),
            [2, 7].into_iter().collect()
        );
        assert!(parse_id_array("not json").is_empty());
    }
}

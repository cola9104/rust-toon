//! Plan each base character's face once, using the rest of the cast as context.
//! The readable result lives with the asset prompt; derivatives inherit it.
use serde::Deserialize;
use sqlx::PgPool;

const START: &str = "【角色面部身份 v1】";
const END: &str = "【角色面部身份结束】";

// Gateway is intentionally a single replica. Serializing the short planning
// step ensures characters in one batch can see previously assigned faces,
// without holding database connections while waiting for another planner.
static PLANNING: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct FaceIdentity {
    face_shape: String,
    brows: String,
    eyes: String,
    nose: String,
    mouth: String,
    skin: String,
    distinctive_features: String,
}

fn parse_plan(raw: &str) -> Result<String, String> {
    let raw = raw.trim();
    let raw = raw
        .strip_prefix("```json")
        .or_else(|| raw.strip_prefix("```"))
        .and_then(|body| body.trim().strip_suffix("```"))
        .unwrap_or(raw)
        .trim();
    let plan: FaceIdentity = serde_json::from_str(raw)
        .map_err(|_| "角色面部设定未返回完整 JSON，请重试提示词生成".to_string())?;
    let fields = [
        ("脸型与骨骼", plan.face_shape),
        ("眉形", plan.brows),
        ("眼型与眼距", plan.eyes),
        ("鼻型与比例", plan.nose),
        ("嘴唇与下巴", plan.mouth),
        ("年龄与肤质", plan.skin),
        ("面部辨识特征", plan.distinctive_features),
    ];
    if fields
        .iter()
        .any(|(_, value)| !(2..=240).contains(&value.trim().chars().count()))
    {
        return Err("角色面部设定缺少可用的五官细节，请重试".into());
    }
    Ok(fields
        .into_iter()
        .map(|(label, value)| format!("{label}：{}", value.trim()))
        .collect::<Vec<_>>()
        .join("；"))
}

fn split_identity(prompt: &str) -> (&str, Option<&str>) {
    if let Some((body, rest)) = prompt.split_once(START)
        && let Some((identity, _)) = rest.split_once(END)
        && !identity.trim().is_empty()
    {
        (body.trim(), Some(identity.trim()))
    } else {
        (prompt.trim(), None)
    }
}

pub(crate) fn appearance_description(prompt: &str) -> &str {
    split_identity(prompt).0
}

pub(crate) fn identity_instruction(prompt: &str) -> String {
    let (_, identity) = split_identity(prompt);
    let identity = identity
        .map(str::to_string)
        .unwrap_or_else(|| face_excerpt(prompt));
    format!(
        "角色面部身份约束：{identity}\n这些五官和骨骼比例属于当前同一个角色，所有视图保持一致；面部设定优先于画风手册中的统一美颜、奶油肌、水光肌或通用俊美脸。不得只靠服装、发色、胡须或表情区分不同人物。衍生造型以基础角色参考图的脸为准，不得用其他角色或模板脸替换。"
    )
}

fn face_excerpt(prompt: &str) -> String {
    if let (_, Some(identity)) = split_identity(prompt) {
        return identity.to_string();
    }
    let cleaned = crate::toonflow_asset_prompt::asset_visual_description("role", prompt);
    let terms = [
        "脸", "面容", "额", "颧", "颌", "眉", "眼", "鼻", "嘴", "唇", "下巴", "肤", "皱", "岁",
        "老年", "青年", "face", "jaw", "eye", "nose",
    ];
    cleaned
        .split(['，', '；'])
        .filter(|clause| {
            terms
                .iter()
                .any(|term| clause.to_lowercase().contains(term))
        })
        .collect::<Vec<_>>()
        .join("，")
        .chars()
        .take(900)
        .collect()
}

fn planning_system() -> String {
    format!(
        "你是影视角色造型设计师，为当前基础角色建立可重复使用的独立面部设定。{}\n用户原始角色描述优先；旧润色文本中的通用美颜模板不属于不可修改的身份设定。保留明确指定的年龄、性别、人物背景、物种和外貌，不因职业或姓名套用固定脸。非人类角色使用对应物种的面部结构，不得强制人脸。\n阅读同项目其他角色的面部设定，只为当前角色设计脸，不复述或混合其他人的脸。除明确设定为双胞胎或相同面貌的角色外，与最相近的角色至少在三项稳定骨骼或五官比例上区分（脸宽长比、颧骨/下颌、眉眼形态与间距、鼻型、唇形或下巴），不能只改发色、胡须、服装、年龄或表情。未明确的部分作为本项目的创作造型补全，不宣称是历史人物真实相貌，不随意添加伤疤或残疾。\n只返回一个 JSON 对象，所有字段必须为具体中文描述字符串：face_shape（脸型额头颧骨下颌），brows（眉形粗细与走势），eyes（眼型眼距眼窝），nose（鼻梁鼻头鼻翼比例），mouth（唇形与下巴），skin（符合角色年龄和设定的肤质），distinctive_features（不依赖服装须发的辨识点）。不得返回表格、代码或解释。",
        crate::toonflow_asset_prompt::CHARACTER_IDENTITY_RULE
    )
}

pub(crate) async fn prepare_base_identity(
    pool: &PgPool,
    project_id: i64,
    asset_id: i64,
    requested_prompt: &str,
) -> Result<String, String> {
    if split_identity(requested_prompt).1.is_some() {
        return Ok(requested_prompt.to_string());
    }
    let _guard = PLANNING.lock().await;
    let (name, description, stored): (String, String, String) = sqlx::query_as(
        "SELECT name,description,prompt FROM toonflow.assets WHERE id=$1 AND project_id=$2 AND type='role' AND parent_asset_id IS NULL",
    ).bind(asset_id).bind(project_id).fetch_optional(pool).await.map_err(|error| error.to_string())?
        .ok_or_else(|| "基础角色不存在或不属于当前项目".to_string())?;
    let (stored_body, stored_identity) = split_identity(&stored);
    let requested =
        crate::toonflow_asset_prompt::asset_visual_description("role", requested_prompt);
    if stored_identity.is_some()
        && crate::toonflow_asset_prompt::asset_visual_description("role", stored_body) == requested
    {
        return Ok(stored);
    }
    let peers: Vec<(String, String, String)> = sqlx::query_as(
        "SELECT name,description,prompt FROM toonflow.assets WHERE project_id=$1 AND type='role' AND parent_asset_id IS NULL AND id<>$2 ORDER BY id LIMIT 40",
    ).bind(project_id).bind(asset_id).fetch_all(pool).await.map_err(|error| error.to_string())?;
    let peer_faces = peers
        .iter()
        .filter_map(|(_, _, prompt)| split_identity(prompt).1.map(str::to_string))
        .collect::<Vec<_>>();
    let peers = peers.into_iter().map(|(name, description, prompt)| {
        serde_json::json!({"name":name,"face":face_excerpt(if prompt.is_empty() { &description } else { &prompt })})
    }).collect::<Vec<_>>();
    let user = serde_json::json!({"currentCharacter":{"name":name,"originalDescription":description,"existingVisualDescription":requested},"otherCharacters":peers}).to_string();
    let raw =
        crate::ai_client::project_text(pool, "universalAi", project_id, &planning_system(), &user)
            .await?;
    let identity = parse_plan(&raw)?;
    if peer_faces.iter().any(|face| face.trim() == identity.trim())
        && !["双胞胎", "相同面貌", "同一张脸"]
            .iter()
            .any(|term| description.contains(term))
    {
        return Err("面部设定与已有角色完全相同，请重新生成独立角色设定".into());
    }
    let prepared = format!("{requested}\n{START}\n{identity}\n{END}");
    let updated = sqlx::query("UPDATE toonflow.assets SET prompt=$2,prompt_state='已完成',prompt_error_reason=NULL WHERE id=$1 AND prompt=$3")
        .bind(asset_id).bind(&prepared).bind(&stored).execute(pool).await.map_err(|error| error.to_string())?;
    if updated.rows_affected() != 1 {
        return Err("角色描述在面部设定期间已改变，请使用最新描述重新生成".into());
    }
    Ok(prepared)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn facial_plan_requires_specific_structural_fields() {
        assert!(parse_plan("{}").is_err());
        assert!(parse_plan(r#"{"face_shape":"帅气"}"#).is_err());
        let plan = parse_plan(r#"{"face_shape":"宽方脸，颌骨宽厚","brows":"浓密平直眉","eyes":"较窄眼裂，眼距适中","nose":"鼻头饱满，鼻翼较宽","mouth":"上薄下厚唇，宽下巴","skin":"自然老年肤质","distinctive_features":"宽颌方下巴与平眉"}"#).unwrap();
        assert!(plan.contains("脸型与骨骼：宽方脸"));
    }

    #[test]
    fn derivatives_inherit_saved_identity_instead_of_replanning_a_face() {
        let prompt = format!("紫色长袍\n{START}\n宽方脸，平直眉，宽下巴\n{END}");
        let instruction = identity_instruction(&prompt);
        assert!(instruction.contains("宽方脸，平直眉，宽下巴"));
        assert!(!instruction.contains("紫色长袍"));
        assert!(planning_system().contains("至少在三项稳定骨骼或五官比例上区分"));
        assert!(planning_system().contains("双胞胎"));
    }
}

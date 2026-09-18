//! Versioned input snapshots stored in the existing image task, before dispatch.
//! Hashes identify exact content; they do not imply a user/model author.
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

pub(crate) fn sha256(text: &str) -> String {
    hex::encode(Sha256::digest(text.as_bytes()))
}

pub(crate) fn source(origin: &str, content: &str) -> Value {
    json!({"source": origin, "content": content, "sha256": sha256(content)})
}

pub(crate) fn image_input(
    prompt: &str,
    size: &str,
    reference_count: usize,
    role_sheet: bool,
    provenance: Option<Value>,
) -> Value {
    let mut input = json!({
        "prompt": prompt,
        "size": size,
        "referenceCount": reference_count,
        "roleSheet": role_sheet,
        "promptSha256": sha256(prompt),
    });
    if let Some(provenance) = provenance {
        input["promptProvenance"] = provenance;
    }
    input
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn records_exact_dispatch_prompt_and_keeps_sources_separate() {
        let original = "现代404公寓，电脑、冷白灯、冰雹、泡面桶";
        let edited = "现代404公寓，电脑在窗边，地板有积水";
        let sources = json!({
            "version": 1,
            "assetDescription": source("assets.description", original),
            "requestedPrompt": source("request.prompt", edited),
        });
        let final_prompt = format!("古风写实摄影\n{edited}\n画布4:3");
        let input = image_input(&final_prompt, "2048x1536", 1, false, Some(sources));
        assert_eq!(input["prompt"], final_prompt);
        assert_eq!(input["promptSha256"], sha256(&final_prompt));
        assert_eq!(
            input["promptProvenance"]["requestedPrompt"]["content"],
            edited
        );
        assert_ne!(sha256(original), sha256(edited));
        assert_ne!(input["promptSha256"], sha256(edited));
    }
}

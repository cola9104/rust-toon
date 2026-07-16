use rust_toon_ai_api::{AiModelType, AiPlatform};
use serde_json::{Value, json};

fn models(items: &[&str]) -> Value {
    json!(
        items
            .iter()
            .map(|model| json!({"label": model, "model": model}))
            .collect::<Vec<_>>()
    )
}

fn presets(platform: AiPlatform, model_type: AiModelType) -> Value {
    use AiModelType::{Chat, Embedding, Image, Music, Rerank, Speech, Transcription, Video};
    use AiPlatform::*;

    let items: &[&str] = match (platform, model_type) {
        (OpenAI, Chat) => &[
            "gpt-5.6-sol",
            "gpt-5.6-terra",
            "gpt-5.6-luna",
            "gpt-5.5",
            "gpt-5.5-pro",
            "gpt-5.4",
            "gpt-5.4-pro",
            "gpt-5.4-mini",
            "gpt-5.4-nano",
            "gpt-5.3-codex",
            "gpt-oss-120b",
            "gpt-oss-20b",
        ],
        (OpenAI, Image) => &["gpt-image-2"],
        (OpenAI, Video) => &[],
        (OpenAI, Speech) => &["gpt-audio-1.5", "tts-1-hd", "tts-1"],
        (OpenAI, Transcription) => &[
            "gpt-4o-transcribe",
            "gpt-4o-transcribe-diarize",
            "gpt-4o-mini-transcribe",
            "whisper-1",
        ],
        (OpenAI, Embedding) => &["text-embedding-3-small", "text-embedding-3-large"],
        (DeepSeek, Chat) => &["deepseek-v4-pro", "deepseek-v4-flash"],
        (YiYan, Chat) => &[
            "ernie-5.0",
            "ernie-4.5-turbo-128k",
            "deepseek-v4-pro",
            "deepseek-v4-flash",
            "deepseek-v3.2",
        ],
        (XingHuo, Chat) => &[
            "spark-x",
            "xsparkx2agent",
            "xsparkx2",
            "xsparkx2flash",
            "generalv3",
            "pro-128k",
            "ultra",
        ],
        (HunYuan, Chat) => &[
            "hy3-preview",
            "hunyuan-a13b",
            "hunyuan-translation",
            "hunyuan-vision-1.5-instruct",
        ],
        (MiniMax, Chat) => &[
            "MiniMax-M2.7",
            "MiniMax-M2.7-highspeed",
            "MiniMax-M2.5",
            "MiniMax-M2.5-highspeed",
            "MiniMax-M2.1",
            "MiniMax-M2.1-highspeed",
            "MiniMax-M2",
            "MiniMax-Text-01",
            "MiniMax-VL-01",
        ],
        (MiniMax, Image) => &["image-01", "image-01-live"],
        (MiniMax, Video) => &[
            "MiniMax-Hailuo-2.3",
            "MiniMax-Hailuo-2.3-Fast",
            "MiniMax-Hailuo-02",
        ],
        (MiniMax, Speech) => &[
            "speech-2.8-hd",
            "speech-2.8-turbo",
            "speech-2.6-hd",
            "speech-2.6-turbo",
            "speech-02-hd",
            "speech-02-turbo",
        ],
        (MiniMax, Music) => &["music-2.6", "music-2.5+", "music-2.5", "music-2.0"],
        (TongYi, Chat) => &["qwen-max", "qwen-plus", "qwen-turbo"],
        (TongYi, Image) => &["wanx-v1"],
        (TongYi, Video) => &["wanx2.1-t2v-turbo"],
        (TongYi, Speech) => &["cosyvoice-v1"],
        (TongYi, Embedding) => &[
            "text-embedding-v4",
            "text-embedding-v3",
            "qwen3-vl-embedding",
            "qwen2.5-vl-embedding",
            "tongyi-embedding-vision-plus",
            "tongyi-embedding-vision-flash",
        ],
        (TongYi, Rerank) => &["qwen3-rerank", "qwen3-vl-rerank", "gte-rerank-v2"],
        (Moonshot, Chat) => &["kimi-k2.5", "kimi-k2-0711-preview", "moonshot-v1-128k"],
        (BaiChuan, Chat) => &["Baichuan2-Turbo", "Baichuan2-Turbo-192k"],
        (StepFun, Chat) => &[
            "step-3.5-flash",
            "step-3.5-flash-2603",
            "step-router-v1",
            "step-2-16k",
            "step-1-8k",
            "step-1-32k",
            "step-1v-8k",
            "step-1v-32k",
        ],
        (StepFun, Image) => &["step-image-edit-2", "step-2x-large", "step-1x-edit"],
        (StepFun, Speech) => &["stepaudio-2.5-tts", "stepaudio-2.5-realtime"],
        (StepFun, Transcription) => &["stepaudio-2.5-asr"],
        (Anthropic, Chat) => &[
            "claude-fable-5",
            "claude-opus-4-8",
            "claude-sonnet-5",
            "claude-haiku-4-5",
            "claude-haiku-4-5-20251001",
        ],
        (Gemini, Chat) => &[
            "gemini-3.5-flash",
            "gemini-3.1-flash-lite",
            "gemini-3.1-pro-preview",
            "gemini-3-flash-preview",
            "gemini-2.5-pro",
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
        ],
        (Gemini, Image) => &[
            "gemini-3.1-flash-image",
            "gemini-3.1-flash-lite-image",
            "gemini-3-pro-image",
            "gemini-2.5-flash-image",
        ],
        (Gemini, Video) => &[
            "veo-3.1-preview",
            "veo-3.1-lite-preview",
            "gemini-omni-flash-preview",
        ],
        (Gemini, Speech) => &[
            "gemini-3.1-flash-tts-preview",
            "gemini-2.5-flash-preview-tts",
            "gemini-2.5-pro-preview-tts",
        ],
        (Gemini, Music) => &[
            "lyria-3-pro-preview",
            "lyria-3-clip-preview",
            "lyria-realtime-exp",
        ],
        (Gemini, Embedding) => &["gemini-embedding-2", "gemini-embedding-001"],
        (SiliconFlow, Chat) => &["deepseek-ai/DeepSeek-V3", "Qwen/Qwen2.5-72B-Instruct"],
        (SiliconFlow, Image) => &["black-forest-labs/FLUX.1-schnell"],
        (SiliconFlow, Speech) => &["FunAudioLLM/CosyVoice2-0.5B"],
        (SiliconFlow, Embedding) => &["BAAI/bge-m3"],
        (SiliconFlow, Rerank) => &["BAAI/bge-reranker-v2-m3"],
        (ZhiPu, Chat) => &[
            "glm-5.1",
            "glm-5v-turbo",
            "glm-4.6v",
            "glm-4.5v",
            "glm-4.5-air",
            "glm-4.5-airx",
            "glm-4.7-flash",
            "glm-4-long",
            "glm-4-flashx-250414",
            "glm-4-flash-250414",
        ],
        (ZhiPu, Image) => &["glm-image"],
        (ZhiPu, Video) => &["cogvideox-3", "vidu-q1", "vidu-2", "cogvideox-flash"],
        (ZhiPu, Speech) => &["glm-tts", "glm-tts-clone", "glm-realtime", "glm-4-voice"],
        (ZhiPu, Transcription) => &["glm-asr-2512"],
        (ZhiPu, Embedding) => &["embedding-3", "embedding-2"],
        (Ollama, Chat) => &["qwen2.5", "llama3.2"],
        (Ollama, Embedding) => &["nomic-embed-text"],
        (DouBao, Chat) => &[
            "doubao-seed-2-0-lite-260215",
            "doubao-seed-2.1-pro",
            "doubao-seed-2.1-turbo",
            "doubao-seed-evolving",
            "doubao-seed-character",
        ],
        (DouBao, Image) => &[
            "doubao-seedream-5.0-lite",
            "doubao-seedream-4.5",
            "doubao-seedream-4.0",
        ],
        (DouBao, Video) => &[
            "doubao-seedance-2.0",
            "doubao-seedance-2.0-fast",
            "doubao-seedance-2.0-mini",
        ],
        (DouBao, Speech) => &["doubao-seed-tts-2.0", "doubao-seed-realtimevoice"],
        (DouBao, Transcription) => &[
            "doubao-streaming-speech-recognition",
            "doubao-recording-recognition-2.0",
        ],
        (DouBao, Embedding) => &["doubao-seed-embedding", "doubao-embedding-vision"],
        (StableDiffusion, Image) => &[
            "stable-image-ultra",
            "stable-image-core",
            "sd3.5-large",
            "sd3.5-large-turbo",
            "sd3.5-medium",
            "stable-diffusion-xl-1024-v1-0",
            "stable-diffusion-xl-1024-v0-9",
        ],
        (Midjourney, Image) => &[
            "midjourney-v8.1",
            "midjourney-v8",
            "midjourney-v7",
            "midjourney-v6.1",
            "midjourney-v6",
            "niji-7",
            "niji-6",
        ],
        (Suno, Music) => &["V4", "V4_5", "V4_5PLUS", "V4_5ALL", "V5", "V5_5"],
        (Grok, Chat) => &[
            "grok-4.5",
            "grok-4.3",
            "grok-build-0.1",
            "grok-4.20-multi-agent-0309",
            "grok-4.20-0309-reasoning",
            "grok-4.20-0309-non-reasoning",
        ],
        (Grok, Image) => &["grok-imagine-image-quality", "grok-imagine-image"],
        (Grok, Video) => &["grok-imagine-video-1.5", "grok-imagine-video"],
        (Grok, Speech) => &["grok-voice-tts", "grok-voice-realtime"],
        (Grok, Transcription) => &["grok-voice-stt"],
        _ => &[],
    };
    models(items)
}

pub(crate) fn platform_catalog() -> Vec<Value> {
    AiPlatform::ALL
        .iter()
        .map(|platform| {
            let types = platform.supported_types();
            let preset_map = types
                .iter()
                .map(|model_type| {
                    (
                        model_type.code().to_string(),
                        presets(*platform, *model_type),
                    )
                })
                .collect::<serde_json::Map<String, Value>>();
            json!({
                "platform": platform.code(),
                "label": platform.label(),
                "url": platform.default_url(),
                "types": types.iter().map(|item| item.code()).collect::<Vec<_>>(),
                "presets": preset_map,
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::platform_catalog;

    #[test]
    fn tongyi_rerank_presets_are_complete() {
        let catalog = platform_catalog();
        let tongyi = catalog
            .iter()
            .find(|item| item["platform"] == "TongYi")
            .unwrap();
        assert_eq!(tongyi["presets"]["rerank"].as_array().unwrap().len(), 3);
    }
}

CREATE TABLE IF NOT EXISTS ai.model_platforms (
    platform TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    default_url TEXT NOT NULL DEFAULT '',
    supported_types TEXT[] NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    update_time BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS ai.model_catalog (
    platform TEXT NOT NULL REFERENCES ai.model_platforms(platform) ON DELETE CASCADE,
    model TEXT NOT NULL,
    type TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'preset',
    source_url TEXT NOT NULL DEFAULT '',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    synced_at BIGINT NOT NULL,
    PRIMARY KEY (platform, model)
);

CREATE INDEX IF NOT EXISTS idx_ai_model_catalog_type
    ON ai.model_catalog(platform, type, active);

INSERT INTO ai.model_platforms(platform,label,default_url,supported_types,update_time) VALUES
('TongYi','通义千问','https://dashscope.aliyuncs.com/compatible-mode/v1',ARRAY['chat','image','video','speech','embedding','rerank'],0),
('YiYan','文心一言','https://qianfan.baidubce.com/v2',ARRAY['chat'],0),
('DeepSeek','DeepSeek','https://api.deepseek.com',ARRAY['chat'],0),
('ZhiPu','智谱清言','https://open.bigmodel.cn/api/paas/v4',ARRAY['chat','image','video','speech','transcription','embedding'],0),
('XingHuo','讯飞星火','https://spark-api-open.xf-yun.com/v1',ARRAY['chat'],0),
('DouBao','豆包','https://ark.cn-beijing.volces.com/api/v3',ARRAY['chat','image','video','speech','transcription','embedding'],0),
('HunYuan','腾讯混元','https://api.hunyuan.cloud.tencent.com/v1',ARRAY['chat'],0),
('SiliconFlow','硅基流动','https://api.siliconflow.cn/v1',ARRAY['chat','image','video','speech','embedding','rerank'],0),
('MiniMax','MiniMax','https://api.minimax.chat/v1',ARRAY['chat','image','video','speech','music'],0),
('Moonshot','Kimi','https://api.moonshot.cn/v1',ARRAY['chat'],0),
('BaiChuan','百川智能','https://api.baichuan-ai.com/v1',ARRAY['chat'],0),
('StepFun','阶跃星辰','https://api.stepfun.com/v1',ARRAY['chat','image','speech','transcription'],0),
('OpenAI','OpenAI 官方','https://api.openai.com/v1',ARRAY['chat','image','video','speech','transcription','embedding'],0),
('AzureOpenAI','微软 Azure（OpenAI）','',ARRAY['chat'],0),
('Anthropic','Claude','https://api.anthropic.com/v1',ARRAY['chat'],0),
('Gemini','Gemini','https://generativelanguage.googleapis.com/v1beta',ARRAY['chat','image','video','speech','music','embedding'],0),
('Ollama','Ollama 本地模型','http://127.0.0.1:11434/v1',ARRAY['chat','embedding'],0),
('StableDiffusion','Stable Diffusion','https://api.stability.ai',ARRAY['image'],0),
('Midjourney','Midjourney','',ARRAY['image'],0),
('Suno','Suno 音乐','',ARRAY['music'],0),
('Grok','Grok','https://api.x.ai/v1',ARRAY['chat','image','video','speech','transcription'],0),
('OpenAICompatible','OpenAI 兼容平台','',ARRAY['chat','image','video','speech','transcription','music','embedding','rerank'],0)
ON CONFLICT(platform) DO UPDATE SET
label=EXCLUDED.label,default_url=EXCLUDED.default_url,
supported_types=EXCLUDED.supported_types,update_time=EXCLUDED.update_time;

INSERT INTO ai.model_catalog(platform,model,type,source,synced_at) VALUES
('DeepSeek','deepseek-v4-pro','chat','preset',0),('DeepSeek','deepseek-v4-flash','chat','preset',0),
('Moonshot','kimi-k2.5','chat','preset',0),('Moonshot','kimi-k2-0711-preview','chat','preset',0),
('Anthropic','claude-fable-5','chat','preset',0),('Anthropic','claude-opus-4-8','chat','preset',0),
('Anthropic','claude-sonnet-5','chat','preset',0),('Anthropic','claude-haiku-4-5','chat','preset',0),
('OpenAI','gpt-5.6-sol','chat','preset',0),('OpenAI','gpt-5.6-terra','chat','preset',0),
('OpenAI','gpt-5.6-luna','chat','preset',0),('OpenAI','gpt-image-2','image','preset',0),
('OpenAI','gpt-audio-1.5','speech','preset',0),('OpenAI','gpt-4o-transcribe','transcription','preset',0),
('OpenAI','text-embedding-3-small','embedding','preset',0),('OpenAI','text-embedding-3-large','embedding','preset',0),
('TongYi','qwen-max','chat','preset',0),('TongYi','qwen-plus','chat','preset',0),
('TongYi','qwen-turbo','chat','preset',0),('TongYi','text-embedding-v4','embedding','preset',0),
('TongYi','qwen3-vl-embedding','embedding','preset',0),('TongYi','qwen3-rerank','rerank','preset',0),
('TongYi','qwen3-vl-rerank','rerank','preset',0),('TongYi','gte-rerank-v2','rerank','preset',0),
('ZhiPu','glm-5.1','chat','preset',0),('ZhiPu','glm-5v-turbo','chat','preset',0),
('ZhiPu','glm-image','image','preset',0),('ZhiPu','cogvideox-3','video','preset',0),
('ZhiPu','glm-tts','speech','preset',0),('ZhiPu','glm-asr-2512','transcription','preset',0),
('ZhiPu','embedding-3','embedding','preset',0),
('Gemini','gemini-3.5-flash','chat','preset',0),('Gemini','gemini-3.1-pro-preview','chat','preset',0),
('Gemini','gemini-3.1-flash-image','image','preset',0),('Gemini','veo-3.1-preview','video','preset',0),
('Gemini','gemini-3.1-flash-tts-preview','speech','preset',0),('Gemini','lyria-3-pro-preview','music','preset',0),
('Gemini','gemini-embedding-2','embedding','preset',0),
('MiniMax','MiniMax-M2.7','chat','preset',0),('MiniMax','image-01','image','preset',0),
('MiniMax','MiniMax-Hailuo-2.3','video','preset',0),('MiniMax','speech-2.8-hd','speech','preset',0),
('MiniMax','music-2.6','music','preset',0),
('Suno','V4','music','preset',0),('Suno','V4_5','music','preset',0),('Suno','V5','music','preset',0),
('Grok','grok-4.5','chat','preset',0),('Grok','grok-4.3','chat','preset',0),
('Grok','grok-imagine-image-quality','image','preset',0),('Grok','grok-imagine-video','video','preset',0),
('StableDiffusion','stable-image-ultra','image','preset',0),('StableDiffusion','stable-image-core','image','preset',0),
('StableDiffusion','sd3.5-large','image','preset',0),
('Midjourney','midjourney-v8.1','image','preset',0),('Midjourney','midjourney-v7','image','preset',0),
('Midjourney','niji-7','image','preset',0)
ON CONFLICT(platform,model) DO UPDATE SET
type=EXCLUDED.type,source=EXCLUDED.source,active=TRUE;

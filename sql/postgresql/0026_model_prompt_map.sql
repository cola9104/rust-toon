CREATE TABLE IF NOT EXISTS ai.model_prompt_maps (
    id bigint PRIMARY KEY,
    model_config_id bigint NOT NULL REFERENCES ai.model_configs(id) ON DELETE CASCADE,
    prompt_key text NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL,
    UNIQUE(model_config_id, prompt_key)
);

CREATE INDEX IF NOT EXISTS idx_ai_model_prompt_maps_model
    ON ai.model_prompt_maps(model_config_id);

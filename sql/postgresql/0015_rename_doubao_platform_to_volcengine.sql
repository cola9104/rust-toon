-- Use the provider name as the canonical platform identifier. Model identifiers
-- such as doubao-seed-* remain unchanged because they are assigned by Ark.

INSERT INTO ai.model_platforms (
    platform, label, default_url, supported_types, enabled, update_time
)
SELECT
    'VolcEngine', '火山引擎', default_url, supported_types, enabled, update_time
FROM ai.model_platforms
WHERE platform = 'DouBao'
ON CONFLICT (platform) DO UPDATE
SET label = '火山引擎',
    default_url = EXCLUDED.default_url,
    supported_types = EXCLUDED.supported_types,
    enabled = EXCLUDED.enabled,
    update_time = GREATEST(ai.model_platforms.update_time, EXCLUDED.update_time);

INSERT INTO ai.model_catalog (
    platform, model, type, source, source_url, active, synced_at,
    missing_count, verified_at
)
SELECT
    'VolcEngine', model, type, source, source_url, active, synced_at,
    missing_count, verified_at
FROM ai.model_catalog
WHERE platform = 'DouBao'
ON CONFLICT (platform, model) DO NOTHING;

UPDATE ai.model_configs
SET platform = 'VolcEngine',
    name = regexp_replace(name, '^豆包[[:space:]]*·?[[:space:]]*', '火山引擎 · ')
WHERE platform = 'DouBao';
UPDATE ai.images SET platform = 'VolcEngine' WHERE platform = 'DouBao';
UPDATE ai.music SET platform = 'VolcEngine' WHERE platform = 'DouBao';
UPDATE ai.writes SET platform = 'VolcEngine' WHERE platform = 'DouBao';

DELETE FROM ai.model_catalog WHERE platform = 'DouBao';
DELETE FROM ai.model_platforms WHERE platform = 'DouBao';

DELETE FROM public.system_dict_data AS old
USING public.system_dict_data AS current
WHERE old.dict_type = 'ai_platform'
  AND old.value = 'DouBao'
  AND current.dict_type = 'ai_platform'
  AND current.value = 'VolcEngine';

UPDATE public.system_dict_data
SET value = 'VolcEngine', label = '火山引擎'
WHERE dict_type = 'ai_platform' AND value = 'DouBao';

UPDATE public.system_dict_data
SET label = '火山引擎'
WHERE dict_type = 'ai_platform' AND value = 'VolcEngine';

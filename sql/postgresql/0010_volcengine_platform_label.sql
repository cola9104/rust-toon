-- Rename the provider display label while retaining existing platform/model IDs.
UPDATE ai.model_platforms
SET label = '火山引擎'
WHERE platform = 'DouBao' AND label IS DISTINCT FROM '火山引擎';

UPDATE public.system_dict_data
SET label = '火山引擎'
WHERE dict_type = 'ai_platform' AND value = 'DouBao'
  AND label IS DISTINCT FROM '火山引擎';

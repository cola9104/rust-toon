-- DouBao models are account-specific. Keep them in the catalog only when the
-- provider's /models endpoint has actually returned them for the configured key.
DELETE FROM ai.model_catalog
WHERE platform = 'DouBao'
  AND model IN (
    'doubao-seedance-1-5-pro-251215',
    'doubao-seedream-4-5-251128'
  )
  AND source = 'preset';

UPDATE toonflow.assets
SET prompt = coalesce(nullif(trim(description), ''), name),
    prompt_state = '待润色',
    prompt_error_reason = NULL
WHERE parent_asset_id IS NULL
  AND coalesce(prompt, '') = '';

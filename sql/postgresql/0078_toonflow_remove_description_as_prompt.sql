UPDATE toonflow.assets
SET prompt = '',
    prompt_state = '',
    prompt_error_reason = NULL
WHERE trim(coalesce(prompt, '')) <> ''
  AND trim(coalesce(prompt, '')) = trim(coalesce(description, ''));

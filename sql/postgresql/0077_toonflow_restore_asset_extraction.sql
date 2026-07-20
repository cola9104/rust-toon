UPDATE toonflow.assets
SET prompt = '',
    prompt_state = '',
    prompt_error_reason = NULL
WHERE prompt_state = '待润色'
  AND trim(coalesce(prompt, '')) = trim(coalesce(description, ''));

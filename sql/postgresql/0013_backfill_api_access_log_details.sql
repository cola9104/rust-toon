UPDATE public.infra_api_access_log
SET operate_name = COALESCE(NULLIF(operate_name, ''),
        NULLIF(regexp_replace(request_url, '^.*/', ''), '')),
    operate_type = COALESCE(operate_type, CASE request_method
        WHEN 'POST' THEN 2 WHEN 'PUT' THEN 3 WHEN 'PATCH' THEN 3
        WHEN 'DELETE' THEN 4 ELSE 1 END),
    response_body = COALESCE(NULLIF(response_body, ''),
        json_build_object(
            'status', result_code,
            'message', COALESCE(result_msg, CASE WHEN result_code >= 400 THEN 'failed' ELSE 'ok' END)
        )::text)
WHERE deleted = 0
  AND (operate_name IS NULL OR operate_name = '' OR operate_type IS NULL OR response_body IS NULL OR response_body = '');

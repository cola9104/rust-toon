UPDATE public.infra_api_access_log
SET response_body = '[historical summary; response body was not captured]' || E'\n' || response_body
WHERE deleted = 0
  AND response_body IS NOT NULL
  AND response_body NOT LIKE '[historical summary;%'
  AND response_body NOT LIKE 'HTTP/%';

-- The request-trace screen was only a summary of infra_api_access_log.
UPDATE public.system_menu
SET deleted = 1, visible = false, update_time = now(), updater = 'migration-0012'
WHERE id = 1077 AND deleted = 0;

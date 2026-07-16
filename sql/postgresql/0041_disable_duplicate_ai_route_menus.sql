UPDATE system_menu
SET deleted = 1,
    updater = 'system',
    update_time = current_timestamp
WHERE id BETWEEN 30000 AND 30008
  AND deleted = 0;


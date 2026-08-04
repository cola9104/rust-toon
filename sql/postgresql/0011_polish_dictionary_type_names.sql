-- These types exist in the consolidated dictionary data but were introduced
-- after the upstream type snapshot used by migration 0010.
UPDATE system_dict_type
SET name = CASE type
    WHEN 'system_menu_type' THEN '菜单类型'
    WHEN 'system_data_scope' THEN '数据权限范围'
    WHEN 'mes_wm_issue_status' THEN 'MES 领料单状态'
    ELSE name
END,
    remark = CASE
        WHEN remark = '自动恢复的字典类型' THEN NULL
        ELSE remark
    END,
    updater = 'migration-0011',
    update_time = now()
WHERE type IN ('system_menu_type', 'system_data_scope', 'mes_wm_issue_status')
  AND deleted = 0;

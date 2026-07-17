-- Route nesting and business-menu affiliation are different concerns.
-- parent_id keeps the Vue route tree intact; active_menu_id identifies the
-- visible menu that owns/highlights an internal hidden page.
ALTER TABLE system_menu
    ADD COLUMN IF NOT EXISTS active_menu_id bigint;

COMMENT ON COLUMN system_menu.active_menu_id IS
    '隐藏页面的业务归属菜单ID，用于生成前端路由 meta.activePath';

CREATE INDEX IF NOT EXISTS idx_system_menu_active_menu
    ON system_menu(active_menu_id)
    WHERE deleted=0 AND active_menu_id IS NOT NULL;

UPDATE system_menu AS hidden
SET active_menu_id=links.active_menu_id,
    updater='system',
    update_time=CURRENT_TIMESTAMP
FROM (VALUES
    (30210,2783),
    (30211,2915),(30212,2915),(30213,2915),(30214,2915),(30215,2915),
    (30220,1201),(30221,1187),
    (30222,1193),(30223,1193),(30224,1193),(30225,1193),
    (30230,110),(30231,115),(30232,2151),
    (20006,20001)
) AS links(hidden_id,active_menu_id)
WHERE hidden.id=links.hidden_id
  AND hidden.deleted=0;

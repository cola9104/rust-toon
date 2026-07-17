-- Remove legacy navigation entries whose frontend views do not exist in the
-- current project. Keeping them active produces fallback/blank pages and makes
-- system_menu disagree with the usable sidebar.
WITH RECURSIVE unavailable AS (
    SELECT id
    FROM system_menu
    WHERE id IN (1118,2761,2798,2799,5000,6100)

    UNION ALL

    SELECT child.id
    FROM system_menu child
    JOIN unavailable parent ON child.parent_id=parent.id
    WHERE child.deleted=0
)
UPDATE system_menu
SET deleted=1, updater='system', update_time=CURRENT_TIMESTAMP
WHERE id IN (SELECT id FROM unavailable);

-- OA 示例 is empty after removing its unavailable leave page.
UPDATE system_menu
SET deleted=1, updater='system', update_time=CURRENT_TIMESTAMP
WHERE id=5;

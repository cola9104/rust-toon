DO $$
BEGIN
    IF to_regclass('public.system_menu') IS NOT NULL THEN
        WITH RECURSIVE prune AS (
            SELECT id
            FROM public.system_menu
            WHERE deleted = false
              AND (
                  (parent_id = 0 AND path NOT IN ('/system', '/infra', '/bpm', '/ai'))
                  OR id = 5
                  OR path = '/bpm/oa'
                  OR name IN ('OA 示例', '请假查询')
              )
            UNION ALL
            SELECT child.id
            FROM public.system_menu child
            JOIN prune parent ON child.parent_id = parent.id
            WHERE child.deleted = false
        )
        UPDATE public.system_menu
        SET deleted = true,
            update_time = now()
        WHERE id IN (SELECT id FROM prune);
    END IF;
END $$;

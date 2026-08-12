-- Keep every historical script while making names unique inside a project.
-- Older duplicates receive a deterministic archival suffix before the
-- constraint is installed, so upgrades never discard related production data.
DO $$
DECLARE
    duplicate record;
    archived_name text;
BEGIN
    FOR duplicate IN
        SELECT id, project_id, name
        FROM (
            SELECT id, project_id, name,
                   row_number() OVER (
                       PARTITION BY project_id, name
                       ORDER BY create_time DESC, id DESC
                   ) AS position
            FROM toonflow.scripts
        ) ranked
        WHERE position > 1
        ORDER BY project_id, id
    LOOP
        archived_name := format('%s（历史副本-%s）', duplicate.name, duplicate.id);
        WHILE EXISTS (
            SELECT 1
            FROM toonflow.scripts
            WHERE project_id = duplicate.project_id
              AND name = archived_name
              AND id <> duplicate.id
        ) LOOP
            archived_name := archived_name || '_';
        END LOOP;
        UPDATE toonflow.scripts
        SET name = archived_name
        WHERE id = duplicate.id;
    END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_toonflow_scripts_project_name
    ON toonflow.scripts(project_id, name);

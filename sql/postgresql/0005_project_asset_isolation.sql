-- Assets are strictly project-owned. Remove historical cross-project links and
-- reject future links whose project does not own the asset.
DELETE FROM toonflow.project_assets pa
USING toonflow.assets a
WHERE a.id = pa.asset_id
  AND pa.project_id <> a.project_id;

CREATE OR REPLACE FUNCTION toonflow.enforce_project_asset_ownership()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM toonflow.assets a
        WHERE a.id = NEW.asset_id
          AND a.project_id = NEW.project_id
    ) THEN
        RAISE EXCEPTION 'asset % does not belong to project %', NEW.asset_id, NEW.project_id
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS project_assets_enforce_ownership ON toonflow.project_assets;
CREATE TRIGGER project_assets_enforce_ownership
BEFORE INSERT OR UPDATE ON toonflow.project_assets
FOR EACH ROW
EXECUTE FUNCTION toonflow.enforce_project_asset_ownership();

DELETE FROM toonflow.project_assets pa
USING toonflow.assets a
WHERE pa.asset_id = a.id
  AND a.parent_asset_id IS NOT NULL;

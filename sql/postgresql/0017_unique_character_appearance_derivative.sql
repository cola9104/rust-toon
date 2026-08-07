CREATE UNIQUE INDEX IF NOT EXISTS uq_toonflow_assets_character_appearance
    ON toonflow.assets(project_id, parent_asset_id, appearance_id)
    WHERE parent_asset_id IS NOT NULL AND appearance_id IS NOT NULL;

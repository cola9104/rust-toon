ALTER TABLE toonflow.character_appearances
    DROP CONSTRAINT IF EXISTS character_appearances_script_id_role_asset_id_name_key;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'character_appearances_script_role_age_name_key'
          AND conrelid = 'toonflow.character_appearances'::regclass
    ) THEN
        ALTER TABLE toonflow.character_appearances
            ADD CONSTRAINT character_appearances_script_role_age_name_key
            UNIQUE (script_id, role_asset_id, age_stage, name);
    END IF;
END
$$;

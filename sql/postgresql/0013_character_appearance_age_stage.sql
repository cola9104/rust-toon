ALTER TABLE toonflow.character_appearances
    ADD COLUMN IF NOT EXISTS age_stage text NOT NULL DEFAULT '';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'character_appearances_age_stage_check'
          AND conrelid = 'toonflow.character_appearances'::regclass
    ) THEN
        ALTER TABLE toonflow.character_appearances
            ADD CONSTRAINT character_appearances_age_stage_check
            CHECK (age_stage IN ('', 'child', 'teen', 'young_adult', 'adult', 'middle_aged', 'senior'));
    END IF;
END
$$;

ALTER TABLE toonflow.projects
    ADD COLUMN IF NOT EXISTS chat_model bigint;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'projects_chat_model_fkey'
          AND conrelid = 'toonflow.projects'::regclass
    ) THEN
        ALTER TABLE toonflow.projects
            ADD CONSTRAINT projects_chat_model_fkey
            FOREIGN KEY (chat_model) REFERENCES ai.model_configs(id);
    END IF;
END
$$;

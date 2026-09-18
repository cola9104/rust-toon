-- Identify an asset-image request by all stable inputs available before dispatch.
-- This supports restart-safe lookup and prevents duplicate paid requests while an
-- equivalent generation is already running.
ALTER TABLE toonflow.images
    ADD COLUMN IF NOT EXISTS input_hash text;

CREATE INDEX IF NOT EXISTS idx_toonflow_images_input_hash
    ON toonflow.images(assets_id, input_hash, id DESC)
    WHERE input_hash IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_toonflow_images_active_input
    ON toonflow.images(assets_id, input_hash)
    WHERE state = '生成中' AND input_hash IS NOT NULL;

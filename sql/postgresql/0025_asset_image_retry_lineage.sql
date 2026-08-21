ALTER TABLE toonflow.images
    ADD COLUMN IF NOT EXISTS retry_of_id bigint REFERENCES toonflow.images(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_toonflow_images_retry_of
    ON toonflow.images(retry_of_id);

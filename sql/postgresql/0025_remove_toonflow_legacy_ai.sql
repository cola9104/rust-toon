ALTER TABLE toonflow.projects ALTER COLUMN image_model DROP DEFAULT;
ALTER TABLE toonflow.projects ALTER COLUMN video_model DROP DEFAULT;
ALTER TABLE toonflow.projects ALTER COLUMN image_model DROP NOT NULL;
ALTER TABLE toonflow.projects ALTER COLUMN video_model DROP NOT NULL;
ALTER TABLE toonflow.projects ALTER COLUMN image_model TYPE BIGINT USING (CASE WHEN image_model ~ '^[0-9]+$' THEN image_model::BIGINT ELSE NULL END);
ALTER TABLE toonflow.projects ALTER COLUMN video_model TYPE BIGINT USING (CASE WHEN video_model ~ '^[0-9]+$' THEN video_model::BIGINT ELSE NULL END);
ALTER TABLE toonflow.projects ADD CONSTRAINT fk_toonflow_project_image_model FOREIGN KEY(image_model) REFERENCES ai.model_configs(id);
ALTER TABLE toonflow.projects ADD CONSTRAINT fk_toonflow_project_video_model FOREIGN KEY(video_model) REFERENCES ai.model_configs(id);

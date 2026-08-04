ALTER TABLE toonflow.projects
    ALTER COLUMN video_ratio SET DEFAULT '16:9',
    ALTER COLUMN mode SET DEFAULT 'startEndRequired';

UPDATE toonflow.projects
SET video_ratio = '16:9'
WHERE btrim(video_ratio) = '';

UPDATE toonflow.projects
SET mode = 'startEndRequired'
WHERE btrim(mode) = '';

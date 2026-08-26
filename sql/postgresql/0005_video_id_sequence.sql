-- Allocate video identifiers in PostgreSQL so concurrent Gateway requests and
-- workflow runs cannot collide on process-local wall-clock timestamps.

CREATE SEQUENCE IF NOT EXISTS toonflow.video_id_seq AS bigint;

SELECT setval(
    'toonflow.video_id_seq',
    COALESCE((SELECT max(id) + 1 FROM toonflow.videos), 1),
    false
);

ALTER SEQUENCE toonflow.video_id_seq OWNED BY toonflow.videos.id;

ALTER TABLE toonflow.videos
    ALTER COLUMN id SET DEFAULT nextval('toonflow.video_id_seq');

-- Older continuity-cache rows had no referential constraints. Preserve their
-- object paths in the durable cleanup outbox before removing any orphan, then
-- make future video/project deletion serialize with cache creation and cascade
-- the cache metadata safely.
INSERT INTO toonflow.storage_cleanup_tasks(
    object_path,resource_type,resource_id,error_reason,attempts,state,create_time,update_time
)
SELECT frame.file_path,'orphan_continuity_frame',frame.previous_video_id,
       '迁移发现无父记录的连续帧缓存',0,'pending',
       (extract(epoch FROM clock_timestamp()) * 1000)::bigint,
       (extract(epoch FROM clock_timestamp()) * 1000)::bigint
FROM toonflow.video_continuity_frames frame
WHERE NOT EXISTS(
        SELECT 1 FROM toonflow.videos video WHERE video.id=frame.previous_video_id
      )
   OR NOT EXISTS(
        SELECT 1 FROM toonflow.videos video
        WHERE video.id=frame.previous_video_id AND video.project_id=frame.project_id
      );

DELETE FROM toonflow.video_continuity_frames frame
WHERE NOT EXISTS(
        SELECT 1 FROM toonflow.videos video WHERE video.id=frame.previous_video_id
      )
   OR NOT EXISTS(
        SELECT 1 FROM toonflow.videos video
        WHERE video.id=frame.previous_video_id AND video.project_id=frame.project_id
      );

CREATE UNIQUE INDEX IF NOT EXISTS uq_videos_id_project_id
    ON toonflow.videos(id,project_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid='toonflow.video_continuity_frames'::regclass
          AND conname='video_continuity_frames_video_project_fk'
    ) THEN
        ALTER TABLE toonflow.video_continuity_frames
            ADD CONSTRAINT video_continuity_frames_video_project_fk
            FOREIGN KEY(previous_video_id,project_id)
            REFERENCES toonflow.videos(id,project_id) ON DELETE CASCADE;
    END IF;
END
$$;

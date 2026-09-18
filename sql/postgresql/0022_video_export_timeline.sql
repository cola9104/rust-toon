-- Export timeline: per-track trim points and transition durations so the
-- export renderer can honor cut/dissolve/audio_bridge boundaries instead of
-- plain concatenation. trim_end_ms NULL means the clip plays to its end.
ALTER TABLE toonflow.video_tracks
    ADD COLUMN IF NOT EXISTS trim_start_ms integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS trim_end_ms integer,
    ADD COLUMN IF NOT EXISTS transition_duration_ms integer NOT NULL DEFAULT 600;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname='video_tracks_trim_range_check'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_trim_range_check
            CHECK (trim_start_ms >= 0 AND (trim_end_ms IS NULL OR trim_end_ms > trim_start_ms));
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname='video_tracks_transition_duration_check'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_transition_duration_check
            CHECK (transition_duration_ms BETWEEN 0 AND 10000);
    END IF;
END $$;

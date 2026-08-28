-- Persist scene boundaries and incoming-track transition intent so video
-- generation no longer has to infer every relationship from free-form text.

ALTER TABLE toonflow.storyboards
    ADD COLUMN IF NOT EXISTS scene_key text;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.storyboards'::regclass
          AND conname = 'storyboards_scene_key_canonical'
    ) THEN
        -- NOT VALID keeps upgrades safe if an unreleased/partially applied
        -- build already wrote a custom key, while all new writes are checked.
        ALTER TABLE toonflow.storyboards
            ADD CONSTRAINT storyboards_scene_key_canonical
            CHECK (scene_key IS NULL OR scene_key ~ '^sc[1-9][0-9]*$')
            NOT VALID;
    END IF;
END
$migration$;

ALTER TABLE toonflow.video_tracks
    ADD COLUMN IF NOT EXISTS transition_type text NOT NULL DEFAULT 'cut',
    ADD COLUMN IF NOT EXISTS frame_policy text NOT NULL DEFAULT 'own',
    ADD COLUMN IF NOT EXISTS previous_track_id bigint,
    ADD COLUMN IF NOT EXISTS transition_source text NOT NULL DEFAULT 'director';

-- A partially applied development migration may have left nullable or invalid
-- values behind. Normalize them before enforcing the durable contract.
UPDATE toonflow.video_tracks
SET transition_type = 'cut'
WHERE transition_type IS NULL
   OR transition_type NOT IN (
       'cut',
       'continuous',
       'action_bridge',
       'empty_shot',
       'dissolve',
       'audio_bridge',
       'match_cut'
   );

UPDATE toonflow.video_tracks
SET frame_policy = 'own'
WHERE frame_policy IS NULL OR frame_policy NOT IN ('own', 'previous_tail');

UPDATE toonflow.video_tracks
SET transition_source = 'director'
WHERE transition_source IS NULL OR transition_source NOT IN ('director', 'manual');

ALTER TABLE toonflow.video_tracks
    ALTER COLUMN transition_type SET DEFAULT 'cut',
    ALTER COLUMN transition_type SET NOT NULL,
    ALTER COLUMN frame_policy SET DEFAULT 'own',
    ALTER COLUMN frame_policy SET NOT NULL,
    ALTER COLUMN transition_source SET DEFAULT 'director',
    ALTER COLUMN transition_source SET NOT NULL;

DO $migration$
BEGIN
    -- Run this compatibility backfill only while the new frame-policy contract
    -- is first being installed. A later idempotence check must not reinterpret
    -- a director/user change merely because the legacy column still says always.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.video_tracks'::regclass
          AND conname = 'video_tracks_frame_policy_valid'
    ) THEN
        UPDATE toonflow.video_tracks
        SET frame_policy = CASE continuity_mode
                WHEN 'always' THEN 'previous_tail'
                ELSE 'own'
            END,
            transition_source = CASE continuity_mode
                WHEN 'always' THEN 'manual'
                WHEN 'never' THEN 'manual'
                ELSE 'director'
            END
        WHERE continuity_mode IN ('auto', 'always', 'never')
          AND transition_source = 'director';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.video_tracks'::regclass
          AND conname = 'video_tracks_transition_type_valid'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_transition_type_valid
            CHECK (
                transition_type IN (
                    'cut',
                    'continuous',
                    'action_bridge',
                    'empty_shot',
                    'dissolve',
                    'audio_bridge',
                    'match_cut'
                )
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.video_tracks'::regclass
          AND conname = 'video_tracks_frame_policy_valid'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_frame_policy_valid
            CHECK (frame_policy IN ('own', 'previous_tail'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.video_tracks'::regclass
          AND conname = 'video_tracks_transition_source_valid'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_transition_source_valid
            CHECK (transition_source IN ('director', 'manual'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.video_tracks'::regclass
          AND conname = 'video_tracks_previous_track_fk'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_previous_track_fk
            FOREIGN KEY (previous_track_id)
            REFERENCES toonflow.video_tracks(id)
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.video_tracks'::regclass
          AND conname = 'video_tracks_previous_track_not_self'
    ) THEN
        ALTER TABLE toonflow.video_tracks
            ADD CONSTRAINT video_tracks_previous_track_not_self
            CHECK (previous_track_id IS NULL OR previous_track_id <> id);
    END IF;
END
$migration$;

ALTER TABLE toonflow.videos
    ADD COLUMN IF NOT EXISTS generation_context jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE toonflow.videos
SET generation_context = '{}'::jsonb
WHERE generation_context IS NULL OR jsonb_typeof(generation_context) <> 'object';

ALTER TABLE toonflow.videos
    ALTER COLUMN generation_context SET DEFAULT '{}'::jsonb,
    ALTER COLUMN generation_context SET NOT NULL;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.videos'::regclass
          AND conname = 'videos_generation_context_is_object'
    ) THEN
        ALTER TABLE toonflow.videos
            ADD CONSTRAINT videos_generation_context_is_object
            CHECK (jsonb_typeof(generation_context) = 'object');
    END IF;
END
$migration$;

CREATE TABLE IF NOT EXISTS toonflow.scene_transitions (
    project_id bigint NOT NULL,
    script_id bigint NOT NULL,
    from_scene_key text NOT NULL,
    to_scene_key text NOT NULL,
    transition_type text NOT NULL DEFAULT 'cut',
    description text NOT NULL DEFAULT '',
    frame_policy text NOT NULL DEFAULT 'own',
    update_time bigint NOT NULL DEFAULT
        ((extract(epoch FROM clock_timestamp()) * 1000)::bigint)
);

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.scene_transitions'::regclass
          AND conname = 'scene_transitions_pkey'
    ) THEN
        ALTER TABLE toonflow.scene_transitions
            ADD CONSTRAINT scene_transitions_pkey
            PRIMARY KEY (project_id, script_id, from_scene_key, to_scene_key);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.scene_transitions'::regclass
          AND conname = 'scene_transitions_script_project_fk'
    ) THEN
        ALTER TABLE toonflow.scene_transitions
            ADD CONSTRAINT scene_transitions_script_project_fk
            FOREIGN KEY (script_id, project_id)
            REFERENCES toonflow.scripts(id, project_id)
            ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.scene_transitions'::regclass
          AND conname = 'scene_transitions_scene_keys_not_blank'
    ) THEN
        ALTER TABLE toonflow.scene_transitions
            ADD CONSTRAINT scene_transitions_scene_keys_not_blank
            CHECK (btrim(from_scene_key) <> '' AND btrim(to_scene_key) <> '');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.scene_transitions'::regclass
          AND conname = 'scene_transitions_scene_keys_canonical'
    ) THEN
        ALTER TABLE toonflow.scene_transitions
            ADD CONSTRAINT scene_transitions_scene_keys_canonical
            CHECK (
                from_scene_key ~ '^sc[1-9][0-9]*$'
                AND to_scene_key ~ '^sc[1-9][0-9]*$'
            ) NOT VALID;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.scene_transitions'::regclass
          AND conname = 'scene_transitions_transition_type_valid'
    ) THEN
        ALTER TABLE toonflow.scene_transitions
            ADD CONSTRAINT scene_transitions_transition_type_valid
            CHECK (
                transition_type IN (
                    'cut',
                    'continuous',
                    'action_bridge',
                    'empty_shot',
                    'dissolve',
                    'audio_bridge',
                    'match_cut'
                )
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.scene_transitions'::regclass
          AND conname = 'scene_transitions_frame_policy_valid'
    ) THEN
        ALTER TABLE toonflow.scene_transitions
            ADD CONSTRAINT scene_transitions_frame_policy_valid
            CHECK (frame_policy IN ('own', 'previous_tail'));
    END IF;
END
$migration$;

-- Existing tracks often all carry the historical default sort_order=0. Repair
-- only groups with duplicate positions so rerunning this migration can never
-- overwrite a later, unique user-defined order.
WITH duplicate_track_groups AS (
    SELECT project_id, script_id
    FROM toonflow.video_tracks
    GROUP BY project_id, script_id
    HAVING count(*) > count(DISTINCT sort_order)
),
ranked_tracks AS (
    SELECT track.id,
           (row_number() OVER (
               PARTITION BY track.project_id, track.script_id
               ORDER BY coalesce((
                            SELECT min(storyboard.index)
                            FROM toonflow.storyboards storyboard
                            WHERE storyboard.track_id = track.id
                        ), 2147483647),
                        track.sort_order,
                        track.id
           ) - 1)::integer AS normalized_sort_order
    FROM toonflow.video_tracks track
    JOIN duplicate_track_groups duplicate_group
      ON duplicate_group.project_id = track.project_id
     AND duplicate_group.script_id IS NOT DISTINCT FROM track.script_id
)
UPDATE toonflow.video_tracks track
SET sort_order = ranked.normalized_sort_order
FROM ranked_tracks ranked
WHERE track.id = ranked.id
  AND track.sort_order IS DISTINCT FROM ranked.normalized_sort_order;

-- The storyboard-panel Agent must persist the scene identity that the new
-- structured transition rules consume. Update the released baseline skill via
-- this new migration instead of rewriting 0001_initial.sql.
WITH rewritten_skill AS (
    SELECT id,
           replace(
               replace(
                   replace(
                       content,
                       $needle$| `videoDesc` | `string` |$needle$,
                       $replacement$| `sceneKey` | `string` | 当前写入单位所属场次的规范键，必须取分镜表 `## 场N` 并写为 `scN`；同场各组保持一致，禁止用轨道号代替 |
| `videoDesc` | `string` |$replacement$
                   ),
                   $needle$- `videoDesc`：$needle$,
                   $replacement$- `sceneKey`：当前写入单位所属 `## 场N` 的规范键 `scN`（例如场2传 `sc2`）；同场保持一致，不得用 track 值代替
- `videoDesc`：$replacement$
               ),
               $needle$add_flowData_storyboard({ videoDesc:$needle$,
               $replacement$add_flowData_storyboard({ sceneKey: "scN", videoDesc:$replacement$
           ) AS content
    FROM toonflow.skill_list
    WHERE path = 'production_execution_storyboard_panel.md'
      AND position('| `sceneKey` |' IN content) = 0
)
UPDATE toonflow.skill_list skill
SET content = rewritten.content,
    md5 = md5(rewritten.content),
    update_time = (extract(epoch FROM clock_timestamp()) * 1000)::bigint
FROM rewritten_skill rewritten
WHERE skill.id = rewritten.id;

CREATE INDEX IF NOT EXISTS idx_toonflow_storyboards_scene_order
    ON toonflow.storyboards(project_id, script_id, scene_key, index, id)
    WHERE scene_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_toonflow_video_tracks_previous_track
    ON toonflow.video_tracks(previous_track_id)
    WHERE previous_track_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_toonflow_scene_transitions_target
    ON toonflow.scene_transitions(project_id, script_id, to_scene_key, from_scene_key);

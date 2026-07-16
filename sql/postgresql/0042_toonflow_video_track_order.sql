alter table toonflow.video_tracks
    add column if not exists sort_order integer not null default 0;

with ranked as (
    select id, row_number() over (
        partition by project_id, script_id order by id
    ) - 1 as position
    from toonflow.video_tracks
)
update toonflow.video_tracks track
set sort_order = ranked.position
from ranked
where ranked.id = track.id;

create index if not exists idx_toonflow_video_tracks_order
    on toonflow.video_tracks(project_id, script_id, sort_order, id);

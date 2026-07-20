alter table toonflow.assets_storyboards
    add column if not exists sort_order integer not null default 0;

with ranked as (
    select storyboard_id, asset_id,
           row_number() over (partition by storyboard_id order by asset_id) - 1 as position
    from toonflow.assets_storyboards
)
update toonflow.assets_storyboards target
set sort_order = ranked.position
from ranked
where target.storyboard_id = ranked.storyboard_id
  and target.asset_id = ranked.asset_id;

create index if not exists idx_toonflow_assets_storyboards_order
    on toonflow.assets_storyboards(storyboard_id, sort_order, asset_id);

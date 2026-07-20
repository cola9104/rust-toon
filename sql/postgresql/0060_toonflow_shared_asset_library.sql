create table if not exists toonflow.project_assets (
    project_id bigint not null references toonflow.projects(id) on delete cascade,
    asset_id bigint not null references toonflow.assets(id) on delete cascade,
    linked_at bigint not null,
    primary key (project_id, asset_id)
);

create index if not exists idx_toonflow_project_assets_asset
    on toonflow.project_assets(asset_id);

insert into toonflow.project_assets (project_id, asset_id, linked_at)
select project_id, id, coalesce(start_time, 0)
from toonflow.assets
on conflict do nothing;


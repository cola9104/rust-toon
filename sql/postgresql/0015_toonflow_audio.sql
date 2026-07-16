create table if not exists toonflow.asset_audio_bindings (
    asset_role_id bigint not null references toonflow.assets(id) on delete cascade,
    asset_audio_id bigint not null references toonflow.assets(id) on delete cascade,
    create_time bigint not null,
    primary key (asset_role_id, asset_audio_id)
);

create index if not exists idx_toonflow_audio_binding_audio
    on toonflow.asset_audio_bindings(asset_audio_id);

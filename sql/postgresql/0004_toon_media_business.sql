alter table toon.projects
    add column if not exists description text,
    add column if not exists status varchar(32) not null default 'draft',
    add column if not exists updated_at timestamptz not null default now();

create table if not exists toon.episodes (
    id uuid primary key,
    project_id uuid not null references toon.projects(id) on delete cascade,
    title varchar(128) not null,
    episode_no integer not null,
    summary text,
    status varchar(32) not null default 'draft',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(project_id, episode_no)
);

create table if not exists toon.scenes (
    id uuid primary key,
    episode_id uuid not null references toon.episodes(id) on delete cascade,
    title varchar(128) not null,
    scene_no integer not null,
    content text,
    status varchar(32) not null default 'draft',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(episode_id, scene_no)
);

create table if not exists toon.publications (
    id uuid primary key,
    project_id uuid not null references toon.projects(id) on delete cascade,
    channel varchar(64) not null,
    status varchar(32) not null default 'published',
    published_at timestamptz not null default now(),
    created_by uuid references system.users(id) on delete set null
);

alter table media.assets
    add column if not exists filename varchar(255),
    add column if not exists status varchar(32) not null default 'ready',
    add column if not exists checksum varchar(128),
    add column if not exists metadata jsonb not null default '{}'::jsonb,
    add column if not exists owner_user_id uuid references system.users(id) on delete set null;

create index if not exists idx_episodes_project on toon.episodes(project_id);
create index if not exists idx_scenes_episode on toon.scenes(episode_id);
create index if not exists idx_publications_project on toon.publications(project_id);
create index if not exists idx_media_assets_owner on media.assets(owner_user_id);

alter table toonflow.videos
    alter column time type bigint using time::bigint;

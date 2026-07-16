-- A full JWT can exceed PostgreSQL's B-tree index tuple limit. Index its
-- stable digest until access tokens become Yudao-style 32-character values.
drop index if exists idx_system_oauth2_access_token_01;
create index idx_system_oauth2_access_token_01
    on system_oauth2_access_token (md5(access_token));

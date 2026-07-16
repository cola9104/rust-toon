-- Preserve any legacy post_ids entries that are not yet represented in
-- Yudao's canonical system_user_post relation. Runtime code only uses the
-- relation table after this migration.
insert into system_user_post (
    id, user_id, post_id, creator, create_time, updater, update_time, deleted, tenant_id
)
select nextval('system_user_post_seq'), users.id, legacy.post_id,
       coalesce(users.updater, users.creator, 'system'), now(),
       coalesce(users.updater, users.creator, 'system'), now(), 0, users.tenant_id
from system_users users
cross join lateral jsonb_array_elements_text(
    case
        when coalesce(users.post_ids, '') ~ '^\s*\[' then users.post_ids::jsonb
        else '[]'::jsonb
    end
) value
cross join lateral (select value::text::bigint as post_id) legacy
join system_post post
  on post.id = legacy.post_id
 and post.deleted = 0
 and post.tenant_id = users.tenant_id
where users.deleted = 0
  and not exists (
      select 1
      from system_user_post relation
      where relation.user_id = users.id
        and relation.post_id = legacy.post_id
        and relation.deleted = 0
  );

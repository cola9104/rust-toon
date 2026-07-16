-- Finish the System-domain cutover to Yudao's public.system_* storage.
-- Legacy refresh secrets were stored only as password hashes, so they cannot
-- be converted back into client-usable Yudao refresh tokens. Dropping those
-- sessions intentionally requires one fresh login after this migration.

insert into system_operate_log (
    id, trace_id, user_id, user_type, type, sub_type, biz_id, action, success,
    extra, request_method, request_url, user_ip, user_agent, creator,
    create_time, updater, update_time, deleted, tenant_id
)
select nextval('system_operate_log_seq'),
       audit.id::text,
       coalesce(users.id, 0),
       2,
       audit.target_type,
       audit.action,
       case when audit.target_id ~ '^-?[0-9]+$' then audit.target_id::bigint else 0 end,
       audit.detail::text,
       true,
       '', '', '', '', '',
       coalesce(audit.actor_username, users.username, 'system'),
       audit.created_at,
       coalesce(audit.actor_username, users.username, 'system'),
       audit.created_at,
       0,
       coalesce(users.tenant_id, 0)
from system.audit_logs audit
left join system_users users
  on md5('yudao-user:' || users.id::text)::uuid = audit.actor_user_id
 and users.deleted = 0;

drop table system.auth_sessions;
drop table system.audit_logs;
drop schema system;

-- Restore the table contract used by the System management handlers and the
-- matching Vben pages. These columns were present in the Kairos baseline but
-- were omitted when rust-toon's migration history was consolidated.

ALTER TABLE public.system_dept
  ADD COLUMN IF NOT EXISTS creator varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS updater varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS tenant_id bigint NOT NULL DEFAULT 0;

ALTER TABLE public.system_dict_type
  ADD COLUMN IF NOT EXISTS creator varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS updater varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS deleted_time timestamp without time zone;

ALTER TABLE public.system_post
  ADD COLUMN IF NOT EXISTS creator varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS updater varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS tenant_id bigint NOT NULL DEFAULT 0;

ALTER TABLE public.system_role
  ADD COLUMN IF NOT EXISTS data_scope_dept_ids varchar(500) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS creator varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS updater varchar(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS tenant_id bigint NOT NULL DEFAULT 0;

-- Recover the owning tenant of existing roles from their user assignments.
UPDATE public.system_role role
SET tenant_id = owner.tenant_id
FROM (
  SELECT ur.role_id, min(users.tenant_id) AS tenant_id
  FROM public.system_user_role ur
  JOIN public.system_users users
    ON users.id = ur.user_id AND users.deleted = 0
  WHERE ur.deleted = 0
  GROUP BY ur.role_id
) owner
WHERE role.id = owner.role_id
  AND role.tenant_id = 0;

UPDATE public.system_role_menu role_menu
SET tenant_id = role.tenant_id
FROM public.system_role role
WHERE role.id = role_menu.role_id
  AND role_menu.tenant_id IS NULL;

UPDATE public.system_role_menu SET tenant_id = 0 WHERE tenant_id IS NULL;
ALTER TABLE public.system_role_menu ALTER COLUMN tenant_id SET DEFAULT 0;
ALTER TABLE public.system_role_menu ALTER COLUMN tenant_id SET NOT NULL;

-- The consolidated schema stored department leaders as deterministic user
-- UUIDs, while every management API and the frontend use numeric user IDs.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'system_dept'
      AND column_name = 'leader_user_id'
      AND udt_name = 'uuid'
  ) THEN
    ALTER TABLE public.system_dept
      ADD COLUMN leader_user_id_numeric bigint;

    UPDATE public.system_dept dept
    SET leader_user_id_numeric = users.id
    FROM public.system_users users
    WHERE dept.leader_user_id = md5('yudao-user:' || users.id::text)::uuid;

    ALTER TABLE public.system_dept DROP COLUMN leader_user_id;
    ALTER TABLE public.system_dept
      RENAME COLUMN leader_user_id_numeric TO leader_user_id;
  END IF;
END
$$;

-- Persist authentication throttling state so account lockout also works across
-- Gateway restarts and replicas. This migration is intentionally idempotent to
-- support both an upgraded database and a clean migration bootstrap.
ALTER TABLE public.system_users
    ADD COLUMN IF NOT EXISTS failed_login_attempts integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS locked_until timestamp with time zone;

UPDATE public.system_users
SET failed_login_attempts = 0
WHERE failed_login_attempts < 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.system_users'::regclass
          AND conname = 'system_users_failed_login_attempts_non_negative'
    ) THEN
        ALTER TABLE public.system_users
            ADD CONSTRAINT system_users_failed_login_attempts_non_negative
            CHECK (failed_login_attempts >= 0);
    END IF;
END
$$;

-- Harden the PostgreSQL outbox contract and add a short publish claim so
-- horizontally scaled dispatchers do not all read and publish the same batch.

ALTER TABLE toonflow.distributed_jobs
    ADD COLUMN IF NOT EXISTS publish_owner text,
    ADD COLUMN IF NOT EXISTS publish_token uuid,
    ADD COLUMN IF NOT EXISTS publish_until timestamp with time zone;

-- Quarantine legacy rows that could never be represented by JobEnvelope.
-- Sanitizing their wire fields lets an upgraded database accept the CHECKs,
-- while terminal state prevents accidental dispatch.
WITH quarantined AS (
    UPDATE toonflow.distributed_jobs
    SET message_id = CASE
            WHEN message_id = '00000000-0000-0000-0000-000000000000'::uuid
                THEN gen_random_uuid()
            ELSE message_id
        END,
        kind = CASE
            WHEN octet_length(kind) BETWEEN 1 AND 255
                 AND kind ~ '^[A-Za-z0-9_-]+([.][A-Za-z0-9_-]+)*$'
                THEN kind
            ELSE 'invalid.dead_letter'
        END,
        trace_id = CASE
            WHEN btrim(trace_id) <> '' AND octet_length(trace_id) <= 256
                THEN trace_id
            ELSE 'migration-quarantine'
        END,
        state = 'failed',
        last_error = '任务信封字段不符合分布式协议，升级时已隔离',
        completed_at = now(),
        lease_owner = NULL,
        lease_token = NULL,
        lease_until = NULL,
        heartbeat_at = NULL,
        published_at = NULL,
        publish_owner = NULL,
        publish_token = NULL,
        publish_until = NULL,
        updated_at = now()
    WHERE message_id = '00000000-0000-0000-0000-000000000000'::uuid
       OR octet_length(kind) NOT BETWEEN 1 AND 255
       OR kind !~ '^[A-Za-z0-9_-]+([.][A-Za-z0-9_-]+)*$'
       OR btrim(trace_id) = ''
       OR octet_length(trace_id) > 256
    RETURNING task_id
)
UPDATE toonflow.tasks tasks
SET state = 'failed',
    reason = '任务信封字段不符合分布式协议，升级时已隔离'
FROM quarantined
WHERE tasks.id = quarantined.task_id AND tasks.state = 'running';

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.distributed_jobs'::regclass
          AND conname = 'distributed_jobs_message_id_not_nil'
    ) THEN
        ALTER TABLE toonflow.distributed_jobs
            ADD CONSTRAINT distributed_jobs_message_id_not_nil
            CHECK (message_id <> '00000000-0000-0000-0000-000000000000'::uuid);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.distributed_jobs'::regclass
          AND conname = 'distributed_jobs_kind_wire_valid'
    ) THEN
        ALTER TABLE toonflow.distributed_jobs
            ADD CONSTRAINT distributed_jobs_kind_wire_valid
            CHECK (
                octet_length(kind) BETWEEN 1 AND 255
                AND kind ~ '^[A-Za-z0-9_-]+([.][A-Za-z0-9_-]+)*$'
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.distributed_jobs'::regclass
          AND conname = 'distributed_jobs_trace_wire_valid'
    ) THEN
        ALTER TABLE toonflow.distributed_jobs
            ADD CONSTRAINT distributed_jobs_trace_wire_valid
            CHECK (btrim(trace_id) <> '' AND octet_length(trace_id) <= 256);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.distributed_jobs'::regclass
          AND conname = 'distributed_jobs_publish_claim_complete'
    ) THEN
        ALTER TABLE toonflow.distributed_jobs
            ADD CONSTRAINT distributed_jobs_publish_claim_complete
            CHECK (
                (publish_owner IS NULL AND publish_token IS NULL AND publish_until IS NULL)
                OR
                (publish_owner IS NOT NULL AND publish_token IS NOT NULL AND publish_until IS NOT NULL)
            );
    END IF;
END
$migration$;

CREATE INDEX IF NOT EXISTS idx_distributed_jobs_dispatch_recovery
    ON toonflow.distributed_jobs(available_at, published_at, publish_until, id)
    WHERE state IN ('queued', 'retry');

-- Cleanup is an external side effect too: schedule retries with the database
-- clock and stop hot-looping permanently broken records.
ALTER TABLE toonflow.storage_cleanup_tasks
    ADD COLUMN IF NOT EXISTS next_attempt_at timestamp with time zone NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS max_attempts integer NOT NULL DEFAULT 20;

UPDATE toonflow.storage_cleanup_tasks
SET state = 'failed'
WHERE state IN ('pending', 'running') AND attempts >= max_attempts;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.storage_cleanup_tasks'::regclass
          AND conname = 'storage_cleanup_tasks_attempts_valid'
    ) THEN
        ALTER TABLE toonflow.storage_cleanup_tasks
            ADD CONSTRAINT storage_cleanup_tasks_attempts_valid
            CHECK (attempts >= 0 AND max_attempts > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.storage_cleanup_tasks'::regclass
          AND conname = 'storage_cleanup_tasks_state_valid'
    ) THEN
        ALTER TABLE toonflow.storage_cleanup_tasks
            ADD CONSTRAINT storage_cleanup_tasks_state_valid
            CHECK (state IN ('pending', 'running', 'completed', 'failed'));
    END IF;
END
$migration$;

CREATE INDEX IF NOT EXISTS idx_storage_cleanup_tasks_retry_due
    ON toonflow.storage_cleanup_tasks(next_attempt_at, lease_until, id)
    WHERE state IN ('pending', 'running');

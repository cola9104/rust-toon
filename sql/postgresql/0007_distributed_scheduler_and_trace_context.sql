-- Turn infra_job into a database-coordinated durable scheduler and retain
-- W3C trace context across the PostgreSQL outbox / JetStream boundary.

ALTER TABLE public.infra_job
    ADD COLUMN IF NOT EXISTS next_run_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS last_scheduled_at timestamp with time zone;

ALTER TABLE public.infra_job_log
    ADD COLUMN IF NOT EXISTS distributed_job_id bigint;

ALTER TABLE toonflow.distributed_jobs
    ADD COLUMN IF NOT EXISTS trace_context jsonb NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'toonflow.distributed_jobs'::regclass
          AND conname = 'distributed_jobs_trace_context_is_object'
    ) THEN
        ALTER TABLE toonflow.distributed_jobs
            ADD CONSTRAINT distributed_jobs_trace_context_is_object
            CHECK (jsonb_typeof(trace_context) = 'object');
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.infra_job_log'::regclass
          AND conname = 'infra_job_log_distributed_job_fk'
    ) THEN
        ALTER TABLE public.infra_job_log
            ADD CONSTRAINT infra_job_log_distributed_job_fk
            FOREIGN KEY (distributed_job_id)
            REFERENCES toonflow.distributed_jobs(id)
            ON DELETE SET NULL;
    END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_infra_job_log_distributed_job
    ON public.infra_job_log(distributed_job_id)
    WHERE distributed_job_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_infra_job_due
    ON public.infra_job(next_run_at, id)
    WHERE deleted = 0 AND status = 1;

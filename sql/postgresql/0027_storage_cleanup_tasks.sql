CREATE TABLE IF NOT EXISTS toonflow.storage_cleanup_tasks (
    id BIGINT PRIMARY KEY,
    object_path TEXT NOT NULL,
    resource_type VARCHAR(32) NOT NULL,
    resource_id BIGINT,
    error_reason TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 1,
    state VARCHAR(16) NOT NULL DEFAULT 'pending',
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_storage_cleanup_tasks_pending
    ON toonflow.storage_cleanup_tasks(state, update_time);

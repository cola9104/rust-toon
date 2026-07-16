ALTER TABLE ai.model_catalog
    ADD COLUMN IF NOT EXISTS missing_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS verified_at BIGINT;

COMMENT ON COLUMN ai.model_catalog.missing_count IS
    '连续未在供应商模型目录中出现的次数；仅作为验证依据，不自动删除';
COMMENT ON COLUMN ai.model_catalog.verified_at IS
    '最后一次通过真实模型调用验证可用的时间';

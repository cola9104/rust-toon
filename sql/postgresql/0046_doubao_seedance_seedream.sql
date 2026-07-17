INSERT INTO ai.model_catalog(platform,model,type,source,source_url,synced_at) VALUES
('DouBao','doubao-seedance-2-0-260128','video','preset','https://www.volcengine.com/docs/82379/2291680',0),
('DouBao','doubao-seedance-2-0-fast-260128','video','preset','https://www.volcengine.com/docs/82379/2291680',0),
('DouBao','doubao-seedance-1-5-pro-251215','video','preset','https://www.volcengine.com/docs/82379/1520757',0),
('DouBao','doubao-seedream-5-0-260128','image','preset','https://www.volcengine.com/docs/82379/1541523',0),
('DouBao','doubao-seedream-5-0-lite-260128','image','preset','https://www.volcengine.com/docs/82379/1541523',0)
ON CONFLICT(platform,model) DO UPDATE SET
type=EXCLUDED.type,source=EXCLUDED.source,source_url=EXCLUDED.source_url,active=TRUE;

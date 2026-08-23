-- Match Toonflow-app's memory compaction cadence.
INSERT INTO toonflow.settings (key, value)
VALUES ('messagesPerSummary', '3')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

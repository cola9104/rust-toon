CREATE TABLE IF NOT EXISTS ai.images (
 id BIGINT PRIMARY KEY,user_id TEXT NOT NULL,model_id BIGINT NOT NULL REFERENCES ai.model_configs(id),platform TEXT NOT NULL,model TEXT NOT NULL,prompt TEXT NOT NULL,width INTEGER NOT NULL,height INTEGER NOT NULL,status INTEGER NOT NULL DEFAULT 10,public_status BOOLEAN NOT NULL DEFAULT FALSE,pic_url TEXT,error_message TEXT,options JSONB NOT NULL DEFAULT '{}',task_id TEXT,buttons JSONB NOT NULL DEFAULT '[]',create_time BIGINT NOT NULL,finish_time BIGINT
);
CREATE INDEX IF NOT EXISTS idx_ai_images_user ON ai.images(user_id,id DESC);
CREATE TABLE IF NOT EXISTS ai.music (
 id BIGINT PRIMARY KEY,user_id TEXT NOT NULL,model_id BIGINT NOT NULL REFERENCES ai.model_configs(id),title TEXT NOT NULL DEFAULT '',lyric TEXT NOT NULL DEFAULT '',image_url TEXT,audio_url TEXT,video_url TEXT,status INTEGER NOT NULL DEFAULT 10,gpt_description_prompt TEXT,prompt TEXT NOT NULL DEFAULT '',platform TEXT NOT NULL,model TEXT NOT NULL,generate_mode INTEGER NOT NULL DEFAULT 1,tags TEXT NOT NULL DEFAULT '',duration DOUBLE PRECISION NOT NULL DEFAULT 0,public_status BOOLEAN NOT NULL DEFAULT FALSE,task_id TEXT,error_message TEXT,create_time BIGINT NOT NULL,finish_time BIGINT
);
CREATE TABLE IF NOT EXISTS ai.writes (
 id BIGINT PRIMARY KEY,user_id TEXT NOT NULL,model_id BIGINT NOT NULL REFERENCES ai.model_configs(id),type INTEGER NOT NULL,prompt TEXT NOT NULL,original_content TEXT NOT NULL DEFAULT '',length INTEGER NOT NULL DEFAULT 0,format INTEGER NOT NULL DEFAULT 1,tone INTEGER NOT NULL DEFAULT 1,language INTEGER NOT NULL DEFAULT 1,platform TEXT NOT NULL,model TEXT NOT NULL,generated_content TEXT NOT NULL DEFAULT '',error_message TEXT,create_time BIGINT NOT NULL,finish_time BIGINT
);

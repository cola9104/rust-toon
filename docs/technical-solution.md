# 技术方案

本文档描述 rust-toon 的整体架构与关键技术设计，内容以当前代码为准。配置项见 [configuration.md](configuration.md)，部署操作见 [deployment.md](deployment.md)。

## 1. 项目概览

rust-toon 是一个动漫（短剧）制作管理平台，由以下部分组成：

- **后端**：Rust workspace，单一网关进程 `rust-toon-gateway`（`services/gateway`），基于 axum 0.8 / tokio / SQLx（PostgreSQL）。
- **前端**：Vben Admin（5.7.0）monorepo，位于 `apps/web`，主应用包 `@vben/web-antd`（Vue + Ant Design Vue）。
- **数据与基础设施**：PostgreSQL（主存储，SQLx 迁移）、Redis（缓存与限流，可选）、NATS（消息队列预留）、MinIO（S3 兼容对象存储）。

## 2. 仓库结构

```
├── Cargo.toml                 # Rust workspace（resolver = "3"，edition 2024）
├── services/gateway/          # 网关入口：路由组装、中间件、启动流程
├── crates/
│   ├── framework/             # 框架层（与业务无关）
│   │   ├── common/            # 配置、健康检查、统一响应、日志、HTTP 服务启动
│   │   ├── database/          # PostgreSQL 连接池与 SQLx 迁移
│   │   ├── redis/             # Redis 客户端、JSON 缓存、限流中间件
│   │   ├── security/          # JWT、密码散列、认证/鉴权、权限模型
│   │   ├── web/               # AppError、CORS/RequestId/Trace 等 Web 层
│   │   ├── mq/                # 消息队列扩展点（NATS/Kafka 适配器预留）
│   │   ├── tenant/            # 租户上下文扩展点（预留）
│   │   └── telemetry/         # 遥测扩展点（当前 re-export init_tracing）
│   └── modules/               # 业务模块，每模块一对 crate：
│       ├── system-api/server  #   账号、角色、菜单、字典、部门、租户、日志等管理域
│       ├── infra-api/server   #   参数配置、文件、定时任务、代码生成、监控等基础设施域
│       ├── ai-api/server      #   AI 模型配置、对话、绘画、音乐、知识库等
│       ├── media-api/server   #   媒体资产 CRUD
│       └── toon-api/server    #   toonflow 动漫制作业务（项目/剧本/分镜/视频/Agent）
├── apps/web/                  # Vben Admin 前端 monorepo
├── sql/
│   ├── postgresql/            # SQLx 迁移链（0001 起，唯一事实来源）
│   └── bootstrap/current.sql  # 参考用 pg_dump 快照，应用从不加载
├── script/                    # docker-compose、迁移测试、备份/恢复等脚本
├── deploy/                    # 环境变量样例与 systemd unit 样例
└── storage/uploads/           # 本地文件上传默认目录
```

`*-api` crate 放共享类型（能力描述、请求/响应模型、平台枚举），`*-server` crate 放路由与业务实现。`*-server` 不单独起进程，全部由 gateway 以库形式链接、合并路由。

## 3. 整体架构

### 3.1 单进程多模块

所有业务模块编译进同一个网关二进制（`cargo run -p rust-toon-gateway`）。gateway 在 `services/gateway/src/main.rs` 中：

1. `init_tracing("gateway")` 初始化日志（`RUST_LOG` 控制，默认 `info`）。
2. `DatabaseConfig::from_env()` + `connect()` 建立 PostgreSQL 连接池，随后 `migrate()` 执行 SQLx 迁移。
3. `RedisConfig::from_env()` 可选连接 Redis；连接失败仅告警并降级（缓存与限流关闭），不阻断启动。
4. `SecurityConfig::from_env()` 构造 `TokenService`（JWT HS256）。
5. 依次构造 `SystemState`（带 Redis 缓存）、`InfraState`、`AiState`、`ToonState`、`MediaState`。
6. `system_state.bootstrap().await?` 启动校验：确认数据库中存在启用的 `super_admin` 角色用户，否则拒绝启动（`crates/modules/system-server/src/bootstrap.rs`）。
7. 合并五个模块的路由，追加 `/`、`/openapi.json`、`/health` 与 404 fallback。
8. 全局中间件（自内向外生效）：数据库认证中间件 `authenticate_from_database` → 审计中间件 `audit::record`；若 Redis 可用，再加全局限流中间件 `rate_limit`。
9. `apply_web_layers` 追加 RequestId（`x-request-id`）、Trace、以及可选的宽松 CORS。
10. `serve()` 绑定 `GATEWAY_HOST:GATEWAY_PORT`（默认 `0.0.0.0:8080`），支持 Ctrl+C / SIGTERM 优雅停机。

### 3.2 统一响应与错误

- 成功响应统一为 `ApiResponse { code, data, message }`（`framework/common/src/response.rs`）。
- 错误统一为 `AppError`（`framework/web/src/error.rs`），按类型映射 HTTP 状态码。

### 3.3 认证与鉴权

`framework/security`：

- **密码**：支持 bcrypt（兼容芋道/Yudao 历史数据）与 argon2（`password.rs`）。
- **访问令牌**：JWT，HS256，含 `iss`/`aud` 校验，默认 TTL 900 秒（`token.rs`）。
- **令牌落库**：登录时向 `system_oauth2_access_token` / `system_oauth2_refresh_token` 写入记录（`system-server/src/oauth2_token.rs`），支持 refresh-token 轮换与 logout 吊销。

gateway 全局挂 `authenticate_from_database`（`system-server/src/database_auth.rs`）：带 `Bearer` 的请求会校验 JWT 并核对 `system_oauth2_access_token` 中令牌仍然有效，然后用数据库中最新的角色/权限替换 JWT 内嵌的授权信息（权限实时生效）；不带令牌的请求直接放行，由各路由自己的 `authenticate` 中间件决定是否拒绝。各模块的受保护路由通过 `route_layer(from_fn_with_state(tokens, authenticate))` 要求登录，再用 `require(user, "xxx:yyy:zzz")` 做权限码校验（`super_admin` 角色直接放行）。

### 3.4 审计

- `services/gateway/src/audit.rs`：全局中间件，将每个 HTTP 请求写入 `infra_api_access_log`（方法、路径、UA、耗时等）。
- `system-server/src/audit.rs`：业务操作日志 `system_operate_log` 与登录日志 `system_login_log`。

### 3.5 限流与缓存

- 限流：`framework/redis/src/rate_limit.rs`，按 `IP + 请求方法 + 路径` 维度在 Redis 计数（窗口默认 60 秒、上限默认 300 次），`/health` 豁免；Redis 故障时放行并告警。客户端 IP 优先取 `x-forwarded-for`。
- 缓存：`RedisClient` 提供 `get_json` / `set_json` / `delete_by_pattern` 等，键带前缀（默认 `rust-toon`）。

## 4. 数据库与迁移

- 迁移目录 `sql/postgresql/` 在编译期由 `sqlx::migrate!("../../../sql/postgresql")` 嵌入 `framework-database`（`database/src/postgres.rs`）。当前迁移链从 `0001_initial.sql`（合并基线）到 `0040_add_chat_knowledge_status.sql`，共 40 个；BPM 遗留菜单和字典、Agent 写权限字段已通过后续迁移删除。
- `migrate()` 启动时自动执行；执行前有保护：若数据库里已有业务表但没有 `_sqlx_migrations` 历史表，则拒绝运行，避免覆盖未知数据库。
- `sql/bootstrap/current.sql` 仅是参考快照，应用从不加载。
- 迁移变更流程（新增编号迁移、保持幂等、跑 `script/test-database-migrations.sh`、更新 `crates/framework/database/tests/migrations.rs` 断言）见根 `AGENTS.md` 与 [deployment.md](deployment.md)。

## 5. 业务模块

### 5.1 system（`crates/modules/system-server`）

管理域：认证（login / refresh-token / logout / me / get-permission-info）、用户、角色、菜单、部门、岗位、字典、通知公告、租户、地区（内置 `area.csv`）、社交用户、登录/操作日志等，路由前缀 `/system/*`。公开路由仅有 `/system/capabilities`、`/system/auth/login`、租户简单列表等少数几个（`transport.rs`）。

### 5.2 infra（`crates/modules/infra-server`）

基础设施域：参数配置、数据源配置、文件与文件配置（本地存储 + 预签名 URL）、定时任务（job / job-log）、代码生成（codegen）、API 访问日志、监控（`monitor.rs`，上报 `RUST_ENV`）等，路由前缀 `/infra/*`。文件下载走公开路由 `GET /upload/{*path}`，默认根目录 `storage/uploads`。

### 5.3 ai（`crates/modules/ai-server`）

AI 能力域：

- **模型配置**存于 `ai.model_configs` 表（platform / type / model / api_key / url / config），CRUD 路由 `/ai/model/*`。模型类型：chat、image、speech、video、embedding、rerank、transcription、music。
- **Provider 体系**：`AiModelFactory`（`factory.rs`）按平台分发到 `provider/` 下的实现——OpenAI 兼容协议 Provider（覆盖 OpenAI、通义、星火、DeepSeek、豆包、混元、硅基流动、MiniMax、Moonshot、百川、阶跃、文心、智谱、Grok、Ollama、OpenAICompatible），以及 Anthropic、Gemini、AzureOpenAI、豆包媒体生成等专用 Provider；未实现的平台显式报错。`AiPlatform` 枚举见 `crates/modules/ai-api`。
- **子模块**：`chat`（对话/会话）、`chat_role`、`media`（图片/音乐生成，含 10 秒间隔的音乐任务轮询后台任务）、`midjourney`（含后台同步任务）、`knowledge`（知识库）、`tools`、`write`、`vector`。

### 5.4 media（`crates/modules/media-server`）

媒体资产 CRUD：`/media/assets` 及 `/media/capabilities`。

### 5.5 toon（`crates/modules/toon-server`）

动漫制作业务核心，分为两组路由：

- REST 资源：`/toon/projects`、`/toon/episodes`、`/toon/scenes` 等。
- toonflow 兼容层：大量与 Toonflow 前端协议兼容的路由（`/toonflow/*`、`/api/*` 及不带前缀的别名），覆盖项目、小说、剧本、资产（素材库/AI 生图/提示词润色）、分镜（storyboard）、图片工作流、视频工作台（轨道、视频生成、导出）、配音、手册、任务、设置、技能管理等。

**Agent 运行时**（`toonflow_agents.rs` / `toonflow_agent_runtime.rs` / `toonflow_agent_tools.rs`）：

- HTTP 接口 `/api/agents/*`（chat / start / runState / stop / events / retry / memories / runs / clearMemory / tools/execute）与剧本计划接口 `/api/scriptAgent/*`。
- WebSocket：`GET /api/socket/{agent}`（别名 `/socket/{agent}`，`toonflow_ws.rs`），query 参数 `token`、`isolationKey`、`projectId`、`scriptId` 鉴权与隔离；客户端消息类型 `chat` / `stop` / `updateThinkConfig` / `updateContext`，协议对齐 Toonflow-app 的 socket 协议。
- 记忆向量化：取 `ai.model_configs` 中启用的 embedding 模型，经 `AiModelFactory` 生成向量写入 `toonflow.agent_memories`；写入长期记忆前会剥离协议 XML 标签。

**文件与对象存储**：

- 素材/片段上传（base64 data URL）落盘到 `INFRA_UPLOAD_DIR`（默认 `storage/uploads`，`toonflow_materials.rs`、`toonflow_video_export.rs`）。
- MinIO 交互在 `toonflow_storage.rs`：不依赖 SDK，自行实现 AWS SigV4 签名（HMAC-SHA256）对 S3 请求签名，用于桶内对象的读写。endpoint/密钥/桶/区域由 `MINIO_*` 环境变量配置。

## 6. 前端

`apps/web` 为 pnpm + turbo monorepo（Vben Admin 5.7.0，`packageManager: pnpm@11.13.0`），主应用 `apps/web/apps/web-antd`：

- 开发：`pnpm dev:antd`，端口 `5666`（`.env.development` 的 `VITE_PORT`），API 前缀 `/api`，指向 `http://127.0.0.1:8080`。
- 构建产物：`apps/web/apps/web-antd/dist`（`VITE_ARCHIVER=true` 时额外生成 `dist.zip`）。
- 前端环境变量（`VITE_*`）详见 [configuration.md](configuration.md)。

## 7. 关键外部依赖端口

| 组件 | 端口 | 说明 |
| --- | --- | --- |
| gateway | 8080 | HTTP API |
| 前端 dev server | 5666 | `VITE_PORT` |
| PostgreSQL | 5432 | 主数据库 |
| Redis | 6379 | 缓存/限流（可选） |
| NATS | 4222 / 8222 | 预留（mq crate 尚未接线） |
| MinIO | 9000 / 9001 | S3 API / 控制台 |

compose 定义见 `script/docker/docker-compose.yml` 与 [deployment.md](deployment.md)。

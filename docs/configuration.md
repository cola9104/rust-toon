# 配置说明

本文档列出 rust-toon 的全部配置项，每项均已对照代码核实（出处见"来源"列）。架构背景见 [technical-solution.md](technical-solution.md)，部署步骤见 [deployment.md](deployment.md)。

## 1. 后端环境变量

后端通过环境变量配置，无配置文件。生产环境建议写入 `/etc/rust-toon/gateway.env` 并由 systemd `EnvironmentFile` 加载（样例见 `deploy/env/gateway.env.example`）。

### 1.1 服务监听（`crates/framework/common/src/config.rs`）

`ServiceConfig::from_env("gateway", 8080)` 按服务名大写加前缀读取：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `GATEWAY_HOST` | `0.0.0.0` | 监听地址 |
| `GATEWAY_PORT` | `8080` | 监听端口（非法值回退默认） |

### 1.2 数据库（`crates/framework/database/src/config.rs`）

| 变量 | 默认值 | 校验规则 |
| --- | --- | --- |
| `DATABASE_URL` | 无（**必填**，缺失报错 `DATABASE_URL is required`） | 必须以 `postgres://` 或 `postgresql://` 开头 |
| `DATABASE_MIN_CONNECTIONS` | `1` | 正整数，且 ≤ 最大连接数 |
| `DATABASE_MAX_CONNECTIONS` | `20` | 正整数，不能为 0 |
| `DATABASE_ACQUIRE_TIMEOUT_SECONDS` | `5` | 正整数，不能为 0 |

本地开发：`postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon`。

### 1.3 安全 / JWT（`crates/framework/security/src/config.rs`）

| 变量 | 默认值 | 校验规则 |
| --- | --- | --- |
| `JWT_SECRET` | 无（**必填**） | **至少 32 字节**，否则启动报错 `JWT_SECRET must contain at least 32 bytes` |
| `JWT_ISSUER` | `rust-toon` | 签发与校验 JWT `iss` |
| `JWT_AUDIENCE` | `rust-toon-api` | 签发与校验 JWT `aud` |
| `JWT_ACCESS_TOKEN_TTL_SECONDS` | `900` | 正整数，访问令牌有效期（秒） |

### 1.4 Redis 与限流（`crates/framework/redis/src/lib.rs`、`rate_limit.rs`）

Redis 为**可选**：`REDIS_URL` 未设置或连接失败时，缓存与限流自动关闭，服务照常启动（日志告警）。

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `REDIS_URL` | 无（不设置则禁用 Redis） | 如 `redis://127.0.0.1:6379` |
| `REDIS_KEY_PREFIX` | `rust-toon` | 缓存键前缀 |
| `REDIS_CONNECT_TIMEOUT_SECONDS` | `3` | 连接超时 |
| `RATE_LIMIT_NAMESPACE` | `rate-limit` | 限流键命名空间 |
| `RATE_LIMIT_MAX_REQUESTS` | `300` | 窗口内最大请求数（按 IP+方法+路径） |
| `RATE_LIMIT_WINDOW_SECONDS` | `60` | 限流窗口（秒） |

### 1.5 Web / CORS（`crates/framework/web/src/middleware.rs`）

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `WEB_PERMISSIVE_CORS`（别名 `CORS_PERMISSIVE`） | `false` | 为 `1`/`true`/`yes` 时放行任意来源/方法/头；生产应在反代收敛跨域而非开启此项 |

无论是否开启，网关都会写入/透传 `x-request-id` 并输出访问日志（tower-http Trace）。

### 1.6 文件存储

| 变量 | 默认值 | 说明 | 来源 |
| --- | --- | --- | --- |
| `INFRA_UPLOAD_DIR` | `storage/uploads`（相对工作目录） | 本地上传根目录；infra 文件下载路由 `GET /upload/{*path}` 与 toon 素材/导出共用 | `infra-server/src/lib.rs`、`toon-server/src/toonflow_materials.rs`、`toonflow_video_export.rs` |

生产环境若用 systemd 且开启 `ProtectSystem=strict`，需保证该目录可写（`deploy/systemd/rust-toon-gateway.service` 已放行 `/opt/rust-toon/storage`）。

### 1.7 MinIO 对象存储（`crates/modules/toon-server/src/toonflow_storage.rs`）

网关以自实现的 AWS SigV4 签名直连 MinIO/S3：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `MINIO_ENDPOINT` | `http://127.0.0.1:9000` | S3 endpoint（末尾 `/` 会被裁剪） |
| `MINIO_ACCESS_KEY` | `rust_toon` | 与 compose 的 `MINIO_ROOT_USER` 对应 |
| `MINIO_SECRET_KEY` | `rust_toon_password` | 与 compose 的 `MINIO_ROOT_PASSWORD` 对应 |
| `MINIO_BUCKET` | `rust-toon` | 桶名 |
| `MINIO_REGION` | `us-east-1` | 签名区域 |

### 1.8 其他

| 变量 | 默认值 | 说明 | 来源 |
| --- | --- | --- | --- |
| `RUST_LOG` | `info` | tracing 日志过滤（EnvFilter） | `framework/common/src/telemetry.rs` |
| `RUST_ENV` | `development` | 运行环境标识，展示在 infra 监控的服务器信息中 | `infra-server/src/monitor.rs` |
| `SECRET_ENCRYPTION_KEY` | 回退 `JWT_SECRET`，再回退内置常量 `rust-toon-local-secret` | AI 模型 api_key、文件配置等敏感字段落库时的对称加密密钥（`enc:v1:` 前缀格式） | `system-server/src/management/compat.rs`、`infra-server/src/lib.rs` |
| `TEST_DATABASE_URL` | 无 | 仅测试使用：迁移测试与分镜数据库集成测试 | `toon-server/src/lib.rs` 测试、`script/test-database-migrations.sh` |
| `TEST_POSTGRES_PORT` | `55432` | 迁移测试脚本起临时 PostgreSQL 容器所用端口 | `script/test-database-migrations.sh` |
| `AI_REQUEST_TIMEOUT_SECONDS` | `120` | AI Provider 单次 HTTP 请求总超时；连接超时固定为 15 秒，连接/超时/5xx 最多尝试 3 次 | `ai-server/src/provider.rs` |
| `AI_VIDEO_POLL_INTERVAL_SECONDS` | `5` | 异步视频任务轮询间隔 | `toon-server/src/ai_client.rs` |
| `AI_VIDEO_POLL_TIMEOUT_SECONDS` | `600` | 异步视频任务最长等待时间 | `toon-server/src/ai_client.rs` |

模型能力矩阵写入 `ai.model_configs.config.capabilities`，支持 `videoModes`、`durationResolutionMap`、`thinkLevels` 和 `multiReference`。视频调用会在请求上游前校验模式以及时长/分辨率组合；未配置能力矩阵的旧模型保持兼容。

### 1.9 启动账号说明

根 `AGENTS.md` 与 `deploy/env/gateway.env.example` 约定了 `BOOTSTRAP_ADMIN_USERNAME` / `BOOTSTRAP_ADMIN_PASSWORD` 两个变量用于首次启动的初始管理员。请以代码实际行为为准理解当前版本：`system-server` 的启动引导（`bootstrap.rs`）是**校验**数据库中必须存在启用状态的 `super_admin` 用户，否则拒绝启动；基线迁移 `sql/postgresql/0001_initial.sql` 已内置 `admin` 用户（bcrypt 密码散列）与 `super_admin` 角色，空库初始化后可直接使用。前端开发环境默认填充的登录口令见 `apps/web/apps/web-antd/.env.development`（`VITE_APP_DEFAULT_USERNAME=admin` / `VITE_APP_DEFAULT_PASSWORD=admin123`）。首次登录后请立即修改密码。

## 2. 前端环境变量（`apps/web/apps/web-antd/`）

### 2.1 开发（`.env.development`）

| 变量 | 值 | 说明 |
| --- | --- | --- |
| `VITE_PORT` | `5666` | dev server 端口 |
| `VITE_BASE` | `/` | 部署基础路径 |
| `VITE_BASE_URL` | `http://127.0.0.1:8080` | 后端地址 |
| `VITE_GLOB_API_URL` | `/api` | 接口前缀 |
| `VITE_UPLOAD_TYPE` | `server` | 上传方式（server=经后端） |
| `VITE_DEVTOOLS` / `VITE_INJECT_APP_LOADING` | `false` / `true` | 开发工具 / 全局 loading |
| `VITE_APP_DEFAULT_USERNAME` / `VITE_APP_DEFAULT_PASSWORD` | `admin` / `admin123` | 登录页默认填充 |

### 2.2 生产（`.env.production`）

`VITE_BASE=/`、`VITE_BASE_URL=http://127.0.0.1:8080`、`VITE_GLOB_API_URL=/api`、`VITE_UPLOAD_TYPE=server`、`VITE_COMPRESS=none`、`VITE_PWA=false`、`VITE_ROUTER_HISTORY=hash`、`VITE_INJECT_APP_LOADING=true`、`VITE_ARCHIVER=true`（构建后额外产出 `dist.zip`）、`VITE_APP_CAPTCHA_ENABLE=false`。

### 2.3 公共（`.env`）

应用标题 `VITE_APP_TITLE=Rust Toon 管理平台`、命名空间 `VITE_APP_NAMESPACE=rust-toon-vben-antd`、store 加密密钥 `VITE_APP_STORE_SECURE_KEY`（**生产必须替换**）、租户开关 `VITE_APP_TENANT_ENABLE=true`、验证码开关 `VITE_APP_CAPTCHA_ENABLE=false` 等。

## 3. 本地基础设施（`script/docker/docker-compose.yml`）

| 服务 | 镜像 | 端口 | 关键配置 |
| --- | --- | --- | --- |
| postgres | `postgres:18` | `5432` | 用户/密码/库均为 `rust_toon`，数据卷 `rust-toon-postgres` |
| redis | `redis:8` | `6379` | 无认证 |
| nats | `nats:2` | `4222`、`8222` | 预留，后端当前未接线 |
| minio | `minio/minio:latest` | `9000`（S3）、`9001`（控制台） | root 账号 `rust_toon` / `rust_toon_password`，数据卷 `rust-toon-minio` |

启动：`docker compose -f script/docker/docker-compose.yml up -d`。注意不要把 `sql/postgresql` 挂载进 PostgreSQL 初始化目录——数据库初始化由网关的 SQLx 迁移负责。

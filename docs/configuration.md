# 配置说明

本文档列出 rust-toon 的全部配置项，每项均已对照代码核实（出处见"来源"列）。架构背景见 [technical-solution.md](technical-solution.md)，部署步骤见 [deployment.md](deployment.md)。

## 1. 后端环境变量

后端通过环境变量配置，无配置文件。生产环境建议将网关配置写入 `/etc/rust-toon/gateway.env`，worker 配置写入 `/etc/rust-toon/toon-worker.env`，并由 systemd `EnvironmentFile` 加载（样例见 `deploy/env/`）。

### 1.1 服务监听（`crates/framework/common/src/config.rs`）

`ServiceConfig::from_env("gateway", 8080)` 按服务名大写加前缀读取：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `GATEWAY_HOST` | `0.0.0.0` | 监听地址 |
| `GATEWAY_PORT` | `8080` | 监听端口（非法值回退默认） |
| `GATEWAY_DRAIN_DELAY_SECONDS` | production 为 `5`，其他环境为 `0` | SIGTERM 后先让 `/readyz` 失败并等待负载均衡摘流；范围 0～300 秒 |

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
| `READINESS_REQUIRE_REDIS` | 设置了 `REDIS_URL` 时为 `true` | Redis 不可用时让 `/readyz` 返回 503 | `gateway/src/readiness.rs` |
| `READINESS_REQUIRE_MINIO` | 生产环境或设置了 `MINIO_ENDPOINT` 时为 `true` | 使用生产链路同款签名 S3 请求验证凭据和 bucket；不可访问时让 `/readyz` 返回 503 | `gateway/src/readiness.rs` |
| `READINESS_REQUIRE_FFMPEG` | `false` | 仅在承担成片导出的节点上启用；缺少或无法执行 FFmpeg/FFprobe 时让 `/readyz` 返回 503 | `gateway/src/readiness.rs` |
| `SECRET_ENCRYPTION_KEY` | 回退 `JWT_SECRET`，再回退内置常量 `rust-toon-local-secret` | AI 模型 api_key、文件配置等敏感字段落库时的对称加密密钥（`enc:v1:` 前缀格式） | `system-server/src/management/compat.rs`、`infra-server/src/lib.rs` |
| `TEST_DATABASE_URL` | 无 | 仅测试使用：迁移测试与分镜数据库集成测试 | `toon-server/src/lib.rs` 测试、`script/test-database-migrations.sh` |
| `TEST_POSTGRES_PORT` | `55432` | 迁移测试脚本起临时 PostgreSQL 容器所用端口 | `script/test-database-migrations.sh` |
| `AI_REQUEST_TIMEOUT_SECONDS` | `120` | AI Provider 单次 HTTP 请求总超时，实际限制在 5～900 秒；连接超时固定为 15 秒 | `ai-server/src/provider.rs` |
| `AI_REQUEST_RETRIES` | `2` | AI Provider 失败重试次数，实际最多 5 次；连接失败、超时、408/409/425/429 和 5xx 会指数退避重试，支持上游 `Retry-After` | `ai-server/src/provider.rs` |
| `AI_VIDEO_POLL_INTERVAL_SECONDS` | `5` | 异步视频任务轮询间隔 | `toon-server/src/ai_client.rs` |
| `AI_VIDEO_POLL_TIMEOUT_SECONDS` | `600` | 异步视频任务最长等待时间 | `toon-server/src/ai_client.rs` |

### 1.9 分布式任务与 Toon Worker

最终成片等长任务不在 HTTP 网关进程中执行。网关在同一个 PostgreSQL 事务中写入业务任务和 `toonflow.distributed_jobs`，worker 的 dispatcher 再把任务引用投递到 NATS JetStream。PostgreSQL 是任务真相源，JetStream 使用显式 ACK 和至少一次投递；worker 通过数据库租约、心跳和 fencing token 保证多个实例竞争时只有租约持有者能够提交结果。

视频 Provider 返回成功后，Gateway 会先以流式方式把源视频归档到项目 MinIO，再把视频记录标记为“生成成功”；成片任务只接受这些项目内不可变对象路径，避免排队或重试期间上游签名 URL 过期、换内容。对象清理在 DELETE 前会再次校验 cleanup lease，并检查成片、视频、图片、分镜与连续帧引用；仍被引用的对象只关闭清理任务，不执行删除。

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `NATS_URL` | `nats://127.0.0.1:4222` | Worker 使用的 NATS JetStream 地址；Gateway 只事务性写 PostgreSQL outbox |
| `NATS_CREDENTIALS_FILE` | 无 | 可选 NATS `.creds` 文件路径；密钥只从文件加载，不写入日志 |
| `NATS_TLS_REQUIRED` | `false` | 是否强制 NATS TLS；配置 CA 或客户端证书时必须为 `true` |
| `NATS_TLS_CA_FILE` | 无 | 可选自定义 CA PEM 文件路径 |
| `NATS_TLS_CLIENT_CERT_FILE` / `NATS_TLS_CLIENT_KEY_FILE` | 无 | 可选 mTLS 客户端证书与私钥路径，必须成对配置 |
| `TOON_WORKER_HOST` | `0.0.0.0` | Worker 健康检查服务监听地址 |
| `TOON_WORKER_PORT` | `8081` | Worker 健康检查服务监听端口 |
| `TOON_WORKER_CONCURRENCY` | `4` | 单个 worker 实例并发执行上限；横向副本数另由 systemd/Compose/Kubernetes 控制 |
| `TOON_WORKER_LEASE_SECONDS` | `300` | 数据库任务租约时长 |
| `TOON_WORKER_HEARTBEAT_SECONDS` | `30` | 执行中任务续租与 JetStream progress ACK 周期，必须小于租约时长 |
| `TOON_WORKER_DISPATCH_INTERVAL_MS` | `500` | PostgreSQL outbox 扫描和 JetStream 发布周期 |
| `TOON_WORKER_PUBLISH_CLAIM_SECONDS` | `15` | dispatcher 发布前持有的短 PostgreSQL claim；实例崩溃后由其他 dispatcher 接管 |
| `TOON_WORKER_REPUBLISH_AFTER_SECONDS` | `300` | 数据库仍为非终态但 JetStream 消息丢失或超过 MaxDeliver 时，轮换 `message_id` 并重新发布的等待时间 |
| `TOON_WORKER_REAPER_INTERVAL_SECONDS` | `15` | 过期租约扫描与重试调度周期 |
| `TOON_WORKER_CLEANUP_INTERVAL_SECONDS` | `5` | 独立对象清理 subsystem 的扫描周期；不会阻塞 worker 注册心跳与任务 reaper |
| `TOON_WORKER_CLEANUP_TIMEOUT_SECONDS` | `30` | 单个 MinIO 删除请求超时，必须短于任务租约；失败按 PostgreSQL 时间指数退避，最多 20 次 |
| `TOON_WORKER_STAGING_CLEANUP_DELAY_SECONDS` | `1800` | 失败 attempt 的未引用上传至少延迟多久再删除；实际不会短于 MinIO 流超时，避免 DELETE/PUT 竞态 |
| `TOON_WORKER_DRAIN_TIMEOUT_SECONDS` | `45` | Worker 停机时取消在途执行、按当前 fencing token 无损重新排队且不消耗业务重试次数的最长等待时间 |
| `TOON_WORKER_MAX_SOURCE_BYTES` | `2147483648` | 单个成片源视频的最大字节数 |
| `TOON_WORKER_MAX_JOB_SOURCE_BYTES` | `10737418240` | 单次成片任务全部源视频的累计最大字节数 |
| `TOON_WORKER_SOURCE_TIMEOUT_SECONDS` | `1800` | 下载外部源视频的总超时 |
| `TOON_PROVIDER_VIDEO_CONCURRENCY` | `2` | Gateway 同时轮询、下载并归档 Provider 视频的全局并发上限；达到上限时新请求返回 429 |
| `TOON_PROVIDER_VIDEO_MAX_BYTES` | `2147483648` | 单个 Provider 视频归档时允许占用的最大临时文件字节数 |
| `TOON_PROVIDER_VIDEO_TEMP_QUOTA_BYTES` | `4294967296` | Gateway Provider 视频临时文件的进程级总预留配额；启动时会清理上次异常退出遗留的 `.download` 文件 |
| `TOON_WORKFLOW_STALE_SECONDS` | `7200` | 运行期 panic 兜底扫描判定工作流节点失联前的最小年龄；正常重启由启动修复立即处理 |
| `TOON_WORKER_FFMPEG_TIMEOUT_SECONDS` | `7200` | 单个 FFmpeg 标准化或合并进程的总超时 |
| `TOON_WORKER_STALE_WORKDIR_SECONDS` | `604800` | Worker 启动时删除的遗留 attempt 临时目录最小年龄；应大于 FFmpeg 超时 |
| `MINIO_CONNECT_TIMEOUT_SECONDS` | `10` | Gateway/Worker 连接 MinIO 的超时 |
| `MINIO_REQUEST_TIMEOUT_SECONDS` | `30` | MinIO HEAD、DELETE 和小对象请求总超时 |
| `MINIO_STREAM_TIMEOUT_SECONDS` | `1800` | MinIO 视频流式 GET/PUT 总超时，防止连接永久占用 Worker |
| `NATS_JOB_REPLICAS` | `1` | JetStream stream 副本数；三节点生产集群设为 `3` |
| `NATS_JOB_MAX_BYTES` | `10737418240` | stream 最大磁盘字节数，达到上限时拒绝新消息而不是删除未 ACK 的旧任务 |
| `NATS_JOB_ACK_WAIT_SECONDS` | `120` | 未收到 ACK/progress ACK 后的重投等待时间 |
| `NATS_JOB_MAX_DELIVER` | `20` | 单条消息最大 JetStream 投递次数；数据库 `max_attempts` 仍是业务重试上限 |
| `NATS_JOB_MAX_ACK_PENDING` | `32` | durable consumer 允许的最大未 ACK 消息数 |

Worker 提供 `/livez` 和 `/readyz`。负载均衡器或编排器应使用 `/readyz`，它必须在 PostgreSQL、JetStream、MinIO 和 FFmpeg 链路可用后才返回成功。网关与 worker 必须共享 PostgreSQL 和 MinIO，所有 worker 必须共享 JetStream；视频吞吐量由 worker 副本数及 `TOON_WORKER_CONCURRENCY` 决定。当前 Agent/Workflow 仍有进程内运行协调，Gateway 暂时必须保持单副本，不能把 HTTP 无状态路由误当成整个 Gateway 已可横向扩容。

网关提供三个探针：`/health` 保留旧版固定 200 及 `checked_at` 响应字段，`/livez` 只确认进程存活，`/readyz` 检查 PostgreSQL 以及按上述开关要求的 Redis、对象存储、FFmpeg 和 FFprobe。依赖探针均有超时，生产负载均衡应使用 `/readyz`，旧监控或进程管理器可继续使用 `/health`，新部署建议使用 `/livez`。

模型能力矩阵写入 `ai.model_configs.config.capabilities`，支持 `videoModes`、`durationResolutionMap`、`thinkLevels` 和 `multiReference`。视频调用会在请求上游前校验模式以及时长/分辨率组合；未配置能力矩阵的旧模型保持兼容。

### 1.10 启动账号说明

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
| nats | `nats:2` | `4222`、`8222` | 已启用 JetStream，文件存储卷 `rust-toon-nats`；8222 为监控端口 |
| minio | `minio/minio:RELEASE.2025-04-22T22-12-26Z` | `9000`（S3）、`9001`（控制台） | root 账号 `rust_toon` / `rust_toon_password`，数据卷 `rust-toon-minio` |

启动：`docker compose -f script/docker/docker-compose.yml up -d`。注意不要把 `sql/postgresql` 挂载进 PostgreSQL 初始化目录——数据库初始化由网关的 SQLx 迁移负责。

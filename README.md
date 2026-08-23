# Rust Toon

Rust Toon 是面向动漫/短剧生产的 AI 工作台。后端使用 Rust，前端使用 Vue 3 + Ant Design Vue；Toonflow 页面提供从项目、剧本、资产、分镜到音视频生成与 Agent 协作的一体化流程。

## 功能组成

- System：认证、用户、角色、权限、菜单、租户及后台管理能力。
- Infra：配置、文件、任务、日志、数据源等基础设施能力。
- AI：统一模型管理、聊天/SSE、工具调用、知识库、图片、Midjourney、音乐、语音、Embedding 和写作。
- Toonflow：项目、小说、剧本、事件、资产、分镜、音频、视频、Agent、提示词、Skill 和任务中心。
- Media：素材上传及媒体基础能力。

## 环境要求

- Rust stable（项目使用 Rust 2024 edition）
- PostgreSQL 18
- Node.js `22.18+`（Node 25+ 需单独安装 Corepack/pnpm）
- pnpm `11+`
- Docker 及 Docker Compose（推荐用于本地基础设施）

## 五分钟本地启动

也可以直接执行：

```bash
bash script/start-local.sh all
```

`infra` 仅启动基础设施，`backend` 启动基础设施并在前台运行网关，`all` 同时运行网关和前端。

### 1. 启动基础设施

```bash
docker compose -f script/docker/docker-compose.yml up -d
```

启动 PostgreSQL、Redis、NATS 和 MinIO。容器只创建空数据库 `rust_toon`，
数据库结构统一由 Rust 网关的 SQLx Migrator 自动管理。

### 2. 启动 Rust 网关

```bash
export DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon'
export REDIS_URL='redis://127.0.0.1:6379'
export JWT_SECRET='replace-with-at-least-32-random-bytes'
export BOOTSTRAP_ADMIN_USERNAME='admin'
export BOOTSTRAP_ADMIN_PASSWORD='Admin#123456'
cargo run -p rust-toon-gateway
```

网关启动时自动执行 SQLx 迁移。`0001_initial.sql` 是已合并的当前完整表结构
和基准数据，因此部署时不需要
`sql/bootstrap/current.sql`。`current.sql` 仅作为人工核对用的快照，不会被应用加载。

后续修改数据库时，必须在当前最高版本之后新增迁移文件（当前最高为 `0040`），并在干净数据库
完成全量迁移后重新导出 `current.sql` 参考快照。合并后的 `0001` 一旦发布就不能再修改。

可选环境变量：
- `DATABASE_MIN_CONNECTIONS`（默认 1）
- `DATABASE_MAX_CONNECTIONS`（默认 20）
- `DATABASE_ACQUIRE_TIMEOUT_SECONDS`（默认 5）
- `GATEWAY_HOST`（默认 `0.0.0.0`）
- `GATEWAY_PORT`（默认 `8080`）
- `RUST_LOG`（推荐 `info`）

### 3. 启动 Vben 前端

```bash
cd apps/web
corepack enable
pnpm install
pnpm dev:antd
```

访问 `http://127.0.0.1:5666`，默认后端为 `http://127.0.0.1:8080`。

> 生产环境必须替换示例密码和 JWT 密钥。

## 验证

```bash
cargo test --workspace
bash script/test-database-migrations.sh
bash script/test-ai-e2e.sh
bash script/test-production-e2e.sh
pnpm --dir apps/web --filter @vben/web-antd run typecheck
pnpm --dir apps/web --filter @vben/web-antd run build
```

真实图片与视频供应商测试会产生费用，因此不会进入默认测试。确认测试数据库已有可用模型配置后显式运行：

```bash
RUN_PAID_AI_E2E=1 \
DATABASE_URL='postgres://...' \
REAL_IMAGE_MODEL_ID='1' \
REAL_VIDEO_MODEL_ID='2' \
REAL_VIDEO_PAYLOAD_JSON='{"prompt":"A red paper boat slowly moving on calm water"}' \
bash script/test-real-ai-providers.sh
```

## 文档

- [AI 启动交接指南](AGENTS.md)
- [技术架构](docs/technical-solution.md)
- [配置与模型接入](docs/configuration.md)
- [启动、部署与运维](docs/deployment.md)

## 数据库备份

```bash
DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon' \
BACKUP_DIR="$PWD/backups/postgresql" \
bash script/database/backup-postgres.sh
```

备份采用 PostgreSQL custom format，并生成 SHA-256 校验文件。生产环境建议安装仓库中的 systemd timer，详细恢复与演练流程见[部署文档](docs/deployment.md#数据库备份与恢复)。
- [功能范围与验收口径](docs/parity-roadmap.md)

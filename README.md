# Rust Toon

Rust Toon 是 Rust 后端与 Vben Admin 5 前端组成的动漫生产及通用 AI 管理平台。基础后台按 Yudao 的模块化思想实现，动漫工厂按 Toonflow 的业务流程实现；后端统一使用 Rust，前端统一使用 Vue 3、Vben 和 Ant Design Vue。

## 功能组成

- System：认证、用户、角色、权限、菜单、租户及后台管理能力。
- Infra：配置、文件、任务、日志、数据源等基础设施能力。
- AI：统一模型管理、聊天/SSE、工具调用、知识库、图片、Midjourney、音乐、语音、Embedding 和写作。
- Toonflow：项目、小说、剧本、事件、资产、分镜、音频、视频、Agent、提示词、Skill 和任务中心。
- Media：素材上传及媒体基础能力。

## 环境要求

- Rust stable（项目使用 Rust 2024 edition）
- PostgreSQL 18
- Node.js `22.18+` 或 `24.x`
- pnpm `11+`
- Docker 及 Docker Compose（推荐用于本地基础设施）

## 五分钟本地启动

启动 PostgreSQL、Redis、NATS 和 MinIO：

```bash
docker compose -f script/docker/docker-compose.yml up -d
```

启动 Rust 网关。首次启动自动执行 `sql/postgresql` 中的 SQLx 迁移并创建管理员：

```bash
export DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon'
export REDIS_URL='redis://127.0.0.1:6379'
export JWT_SECRET='replace-with-at-least-32-random-bytes'
export BOOTSTRAP_ADMIN_USERNAME='admin'
export BOOTSTRAP_ADMIN_PASSWORD='Admin#123456'
cargo run -p rust-toon-gateway
```

另开终端启动 Vben：

```bash
cd apps/web
corepack enable
pnpm install
pnpm dev:antd
```

访问 `http://127.0.0.1:5666`，默认后端为 `http://127.0.0.1:8080`。

> `BOOTSTRAP_ADMIN_PASSWORD` 只用于创建不存在的初始管理员。生产环境必须替换示例密码和 JWT 密钥。

## 验证

```bash
cargo test --workspace
bash script/test-database-migrations.sh
bash script/test-ai-e2e.sh
pnpm --dir apps/web --filter @vben/web-antd run typecheck
pnpm --dir apps/web --filter @vben/web-antd run build
```

## 文档

- [AI 启动交接指南](AGENTS.md)
- [技术架构](docs/technical-solution.md)
- [配置与模型接入](docs/configuration.md)
- [启动、部署与运维](docs/deployment.md)
- [功能范围与验收口径](docs/parity-roadmap.md)

# 部署文档

本文档给出本地开发与生产部署的操作步骤。配置项的含义与默认值见 [configuration.md](configuration.md)，架构说明见 [technical-solution.md](technical-solution.md)。根目录 `AGENTS.md` 是启动命令的权威参考，本文与之保持一致。

## 1. 前置要求

- Rust stable（支持 Rust 2024 edition）。
- Docker 与 Docker Compose（本地基础设施）。
- Node.js `22.18+`，pnpm `11+`（`apps/web/package.json` 锁定 `pnpm@11.13.0`）。Node.js 25 起不再内置 Corepack，如系统没有 `corepack` 命令，需要先单独安装 Corepack 或 pnpm。
- 生产环境另需 Nginx 或其他反向代理。

## 2. 本地开发

### 2.1 启动基础设施

```bash
docker compose -f script/docker/docker-compose.yml up -d
```

包含 PostgreSQL（5432）、Redis（6379）、NATS（4222/8222）、MinIO（9000/9001）。也可以使用便捷脚本 `script/start-local.sh [infra|backend|all]`：它会先起 compose，再按模式启动后端（自动导出本地默认环境变量）。

### 2.2 启动后端网关

```bash
export DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon'
export REDIS_URL='redis://127.0.0.1:6379'
export JWT_SECRET='local-development-jwt-secret-change-me-32bytes'
export BOOTSTRAP_ADMIN_USERNAME='admin'
export BOOTSTRAP_ADMIN_PASSWORD='Admin#123456'
export RUST_LOG='info'
cargo run -p rust-toon-gateway
```

网关启动时自动执行 `sql/postgresql` 下的全部迁移（空库从零建表并写入基线数据），并校验存在启用的超级管理员。

### 2.3 启动前端

```bash
cd apps/web
corepack enable
pnpm install
pnpm dev:antd
```

### 2.4 访问入口

- 前端：`http://127.0.0.1:5666`
- 后端兼容存活检查：`http://127.0.0.1:8080/health`（固定 200，保留旧响应字段）
- 存活/就绪探针：`http://127.0.0.1:8080/livez`、`http://127.0.0.1:8080/readyz`
- OpenAPI 文档：`http://127.0.0.1:8080/openapi.json`
- MinIO 控制台：`http://127.0.0.1:9001`（`rust_toon` / `rust_toon_password`）

默认本地账号：`admin`（基线迁移内置；开发前端默认填充密码 `admin123`，首次登录后请修改）。

### 2.5 本地验证

```bash
curl -fsS http://127.0.0.1:8080/health
cargo test --workspace
bash script/test-database-migrations.sh
bash script/test-ai-e2e.sh
bash script/test-gateway-e2e.sh
bash script/test-production-e2e.sh
bash script/test-minio-backup.sh
pnpm --dir apps/web run test:unit
pnpm --dir apps/web --filter @vben/web-antd run typecheck
```

前端生产构建检查：`pnpm --dir apps/web --filter @vben/web-antd run build`。

## 3. 数据库迁移管理

- 迁移由网关启动时自动执行，迁移目录 `sql/postgresql`（当前 `0001`–`0002`）在编译期嵌入二进制；**不要**把该目录挂载到 PostgreSQL 的 initdb 目录。
- 变更流程（与根 `AGENTS.md` 一致）：
  1. 新增编号迁移文件，已发布/已应用的迁移不得修改。
  2. 迁移必须幂等，同时支持空库初始化与已有库升级。
  3. 运行 `bash script/test-database-migrations.sh` 验证空库可到达最新结构（脚本用 Docker 起临时 `postgres:18`，端口 `TEST_POSTGRES_PORT`，默认 55432）。
  4. 可选：对干净参考库导出 `sql/bootstrap/current.sql`（`pg_dump` 快照，仅供查阅，应用从不加载）。
  5. 更新 `crates/framework/database/tests/migrations.rs` 中的迁移数量与基线断言。
- 保护机制：若数据库已有业务表但无 `_sqlx_migrations` 历史，启动迁移会拒绝执行，防止误覆盖。

## 4. 新服务器生产部署

### 4.1 克隆与基础设施

```bash
git clone <repo-url> rust-toon
cd rust-toon
docker compose -f script/docker/docker-compose.yml up -d
```

使用云厂商托管的 PostgreSQL/Redis 时，可只启动其余服务，并把 `DATABASE_URL` / `REDIS_URL` 指向托管实例。

### 4.2 网关环境文件

在 git 之外创建 `/etc/rust-toon/gateway.env`（样例见 `deploy/env/gateway.env.example`）：

```bash
DATABASE_URL=postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon
REDIS_URL=redis://127.0.0.1:6379
JWT_SECRET=replace-with-a-strong-random-secret-at-least-32-bytes
MINIO_ENDPOINT=http://127.0.0.1:9000
MINIO_ACCESS_KEY=rust_toon
MINIO_SECRET_KEY=replace-with-a-strong-object-storage-secret
MINIO_BUCKET=rust-toon
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=8080
RUST_LOG=info
RUST_ENV=production
READINESS_REQUIRE_REDIS=true
READINESS_REQUIRE_MINIO=true
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=replace-with-a-strong-initial-password
```

`JWT_SECRET` 必须 ≥ 32 字节，否则启动失败。首次登录成功后将 `BOOTSTRAP_ADMIN_PASSWORD` 从环境文件中移除并重启服务。生产环境如使用本地文件存储，建议显式设置 `INFRA_UPLOAD_DIR`（默认 `storage/uploads`，相对工作目录）；AI 密钥落库加密可通过 `SECRET_ENCRYPTION_KEY` 独立指定（缺省回退 `JWT_SECRET`）。

### 4.3 构建与试运行

```bash
cargo build --release -p rust-toon-gateway
set -a; . /etc/rust-toon/gateway.env; set +a
./target/release/rust-toon-gateway
```

确认迁移与管理员就绪后 Ctrl+C 停止，交给 systemd 管理。

### 4.4 systemd

仓库提供样例 `deploy/systemd/rust-toon-gateway.service`（`User=rust-toon`、`EnvironmentFile=/etc/rust-toon/gateway.env`、开启 `ProtectSystem=strict` 等加固项，并放行 `/opt/rust-toon/storage` 可写）：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-gateway
sudo systemctl status rust-toon-gateway
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/readyz
```

### 4.5 备份与恢复

仓库提供脚本与定时器样例：

- `script/database/backup-postgres.sh`：`pg_dump` 备份，要求 `DATABASE_URL`；`BACKUP_DIR`（默认 `/var/backups/rust-toon/postgresql`）、`BACKUP_RETENTION_DAYS`（默认 14）控制目录与保留天数，拒绝不安全的备份目录。
- `script/database/restore-postgres.sh`：恢复，`--backup FILE --database-url URL --confirm`。
- `deploy/systemd/rust-toon-postgres-backup.service` + `.timer`：每日 03:15 定时备份（环境文件 `/etc/rust-toon/backup.env`，样例 `deploy/env/backup.env.example`）。
- `script/database/backup-minio.sh`：使用 MinIO Client `mc` 镜像对象桶，生成逐对象 SHA-256 清单；配置 `MINIO_ENDPOINT`、`MINIO_ACCESS_KEY`、`MINIO_SECRET_KEY`、`MINIO_BUCKET` 和 `MINIO_BACKUP_DIR`，宿主机还需提供 `jq`。
- `script/database/restore-minio.sh`：严格校验 manifest 版本、bucket、普通文件全集和 SHA-256 清单后恢复对象；跨 bucket 恢复必须额外传入 `--allow-bucket-mismatch`。默认保留目标端额外对象，只有显式传入 `--delete-extra --confirm` 才执行镜像删除。
- `deploy/systemd/rust-toon-minio-backup.service` + `.timer`：每日 03:45 定时备份对象，和 PostgreSQL 备份错峰执行。

systemd 样例以 `rust-toon` 用户运行，启用前需安装 `mc`、创建可写目录并保护包含凭据的环境文件。以下示例为 Linux amd64；其他架构请从 MinIO 官方下载目录选择对应二进制：

```bash
sudo apt-get update && sudo apt-get install -y jq
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2025-04-16T18-13-26Z \
  -o /tmp/rust-toon-mc
sudo install -o root -g root -m 0755 /tmp/rust-toon-mc /usr/local/bin/mc
sudo install -d -o rust-toon -g rust-toon -m 0700 \
  /var/backups/rust-toon/postgresql /var/backups/rust-toon/minio
sudo install -d -o root -g rust-toon -m 0750 /etc/rust-toon
sudo install -o root -g rust-toon -m 0640 \
  deploy/env/backup.env.example /etc/rust-toon/backup.env
sudoedit /etc/rust-toon/backup.env
sudo install -o root -g root -m 0644 deploy/systemd/rust-toon-*-backup.service \
  deploy/systemd/rust-toon-*-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-postgres-backup.timer rust-toon-minio-backup.timer
sudo systemctl start rust-toon-postgres-backup.service rust-toon-minio-backup.service
```

生产恢复必须同时选择时间相近的 PostgreSQL 与 MinIO 备份，先隔离流量，再恢复两者，最后通过 `/readyz`、成果视频抽查和对象引用审计后恢复流量。建议在对象存储端同时开启 versioning、异地复制或 object lock；文件级镜像不能替代这些能力。

## 5. 前端生产部署

```bash
corepack enable
pnpm --dir apps/web install --frozen-lockfile
pnpm --dir apps/web --filter @vben/web-antd run build
```

产物目录：`apps/web/apps/web-antd/dist`（另产出 `dist.zip`）。交给 Nginx/CDN 托管，SPA 路由回退 `index.html`，`/api/` 反代到网关：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}

location /api/ {
    proxy_pass http://127.0.0.1:8080/;
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_read_timeout 600s;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

要点：`X-Forwarded-For` 影响后端限流的客户端识别；SSE/流式响应需要关闭代理缓冲并加大读超时；WebSocket 端点（`/api/socket/{agent}`）依赖 Upgrade 头。生产跨域应在反代层控制，不要开启 `WEB_PERMISSIVE_CORS`。

## 6. 持续集成

根目录 `.github/workflows/ci.yml` 是仓库门禁，覆盖 Rust fmt/Clippy/workspace tests、空库迁移、本地 mock AI Provider E2E、前端 typecheck/unit/build、启动真实 PostgreSQL、Redis、MinIO 和 gateway 的 HTTP/WebSocket 黑盒 E2E、FFmpeg 最终成片归档 E2E，以及 MinIO 备份/恢复回环。仅供应商付费生成测试保持显式运行，不进入默认 CI。

## 7. 常见问题

- `DATABASE_URL is required`：未导出或未写入环境文件。
- JWT 启动报错：`JWT_SECRET` 必须至少 32 字节。
- 启动报 "no enabled super administrator"：数据库缺少基线超级管理员，检查迁移是否完整执行。
- 没有管理员账号：首次启动参考 `AGENTS.md` 设置 `BOOTSTRAP_ADMIN_PASSWORD`，账号建立后移除该变量。
- 前端 API 404：检查 `VITE_BASE_URL`、`VITE_GLOB_API_URL` 与 Nginx `/api/` 前缀处理。
- SSE 一次性返回：反代未关缓冲或读超时太短。
- 端口占用：`ss -ltnp | rg ':(8080|5666|5432|6379)'`。

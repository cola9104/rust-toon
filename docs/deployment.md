# 启动、部署与运维

AI 编码助手接手项目时应先阅读仓库根目录的 [AI 启动交接指南](../AGENTS.md)。该文件包含本地启动、新服务器启动、systemd、Nginx 和常见故障的可执行命令。

## 本地开发方案

推荐使用仓库启动脚本：

```bash
bash script/start-local.sh infra    # 仅 PostgreSQL、Redis、NATS、MinIO
bash script/start-local.sh backend  # 基础设施 + 前台网关
bash script/start-local.sh all      # 基础设施 + 网关 + 前端
```

脚本只为本地开发提供默认密码。生产环境不得使用其中的默认密钥。

1. 执行 `docker compose -f script/docker/docker-compose.yml up -d`。
2. 按 [配置文档](configuration.md) 导出数据库、JWT 和管理员环境变量。
3. 执行 `cargo run -p rust-toon-gateway`（首次启动自动初始化数据库并执行全部迁移）。
4. 在 `apps/web` 执行 `pnpm install && pnpm dev:antd`。
5. 检查 `GET http://127.0.0.1:8080/health`，然后访问 `http://127.0.0.1:5666`。

数据库结构由网关的 SQLx Migrator 自动管理，启动时仅执行迁移，禁止同时把 SQL 文件挂载进 `/docker-entrypoint-initdb.d`。

## 后端生产构建

```bash
cargo build --release -p rust-toon-gateway
```

产物为 `target/release/rust-toon-gateway`。生产服务至少需要：

- `DATABASE_URL`
- 强随机 `JWT_SECRET`
- `GATEWAY_HOST` 和 `GATEWAY_PORT`
- 可选 `REDIS_URL`

推荐由 systemd、Docker、Kubernetes 或其他进程管理器注入环境变量并负责重启。多个网关实例可以共享 PostgreSQL 和 Redis；异步任务轮询使用持久化状态，重复轮询应由供应商任务查询接口保持幂等。

新服务器首次部署建议流程：

1. 安装 Rust stable、Docker Compose、Node.js `22.18+` 或 `24.x`，并通过 Corepack 使用 pnpm `11+`。
2. 克隆代码到固定目录，例如 `/opt/rust-toon`。
3. 启动基础设施：`docker compose -f script/docker/docker-compose.yml up -d`。使用托管 PostgreSQL/Redis 时，改为在环境变量中指向托管地址。
4. 创建 `/etc/rust-toon/gateway.env`，写入 `DATABASE_URL`、`REDIS_URL`、强随机 `JWT_SECRET`、`GATEWAY_HOST`、`GATEWAY_PORT`、`RUST_LOG` 和首次管理员变量。
5. 执行 `cargo build --release -p rust-toon-gateway`。
6. 手动加载环境变量运行一次 `target/release/rust-toon-gateway`，确认迁移成功和管理员可登录。
7. 管理员创建后，从环境文件移除 `BOOTSTRAP_ADMIN_PASSWORD`。
8. 使用 systemd、Docker 或 Kubernetes 托管网关进程。

仓库已提供可直接安装的 systemd 单元：

```bash
sudo install -d -m 0750 -o rust-toon -g rust-toon /etc/rust-toon
sudo install -m 0644 deploy/systemd/rust-toon-gateway.service /etc/systemd/system/
sudo install -m 0640 deploy/env/gateway.env.example /etc/rust-toon/gateway.env
sudo editor /etc/rust-toon/gateway.env
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-gateway
```

等价的核心配置为：

```ini
[Unit]
Description=Rust Toon Gateway
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/rust-toon
EnvironmentFile=/etc/rust-toon/gateway.env
ExecStart=/opt/rust-toon/target/release/rust-toon-gateway
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-gateway
sudo systemctl status rust-toon-gateway
curl -fsS http://127.0.0.1:8080/health
```

## 前端生产构建

```bash
corepack enable
pnpm --dir apps/web install --frozen-lockfile
pnpm --dir apps/web --filter @vben/web-antd run build
```

静态产物位于 `apps/web/apps/web-antd/dist`，可由 Nginx 或对象存储/CDN 托管。SPA 部署需要把未知前端路径回退至 `index.html`，并将 `/api/` 反向代理到 Rust 网关。

Nginx 核心配置示例：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}

location /api/ {
    proxy_pass http://rust-toon-gateway:8080/;
    proxy_http_version 1.1;
    proxy_buffering off; # SSE 必须关闭代理缓冲
    proxy_read_timeout 600s;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

## 数据库迁移

数据库结构由 Rust 网关启动时的 SQLx Migrator 统一管理，不依赖 Docker 卷挂载或外部 SQL 导入。

- 迁移文件位于 `sql/postgresql`，版本号必须是唯一整数前缀。
- 网关连接数据库后、监听端口前自动执行迁移。
- 空数据库首次启动时直接执行全部迁移。`0001_initial.sql` 提供当前完整 schema 和基准数据，不依赖 `sql/bootstrap/current.sql`。
- 每次修改 schema 或基准数据都必须新增更高版本的迁移，并更新空库迁移测试的版本数和数据断言。
- 全部迁移在干净参考库执行成功后，重新导出 `sql/bootstrap/current.sql` 用于人工比对；应用不得依赖该文件启动。
- 发布前运行 `bash script/test-database-migrations.sh`，验证空 PostgreSQL 18 可完成全部迁移。
- 已在生产执行的迁移不得修改；后续结构变化应新增更高版本迁移。
- 本次迁移历史已合并为新的 `0001`，保留旧 `_sqlx_migrations` 记录的数据库需要清空后重建。
- 正式升级前必须备份数据库，并先在备份副本验证升级。

## 数据库备份与恢复

### 手动备份

服务器需要安装与 PostgreSQL 服务端主版本兼容的 `pg_dump`、`pg_restore` 和 `sha256sum`。

```bash
set -a
. /etc/rust-toon/backup.env
set +a
/opt/rust-toon/script/database/backup-postgres.sh
```

备份脚本具有以下行为：

- 使用 PostgreSQL custom format，支持并行恢复和对象级检查；
- 先写入 `.partial` 文件，`pg_restore --list` 成功后才原子改名；
- 为每个 dump 生成 `.sha256` 校验文件；
- 默认保留 14 天，可通过 `BACKUP_RETENTION_DAYS` 调整；
- 不备份运行中的 PostgreSQL 数据目录，不依赖 Docker volume 路径。

### 自动备份

```bash
sudo install -d -m 0700 -o rust-toon -g rust-toon /var/backups/rust-toon/postgresql
sudo install -m 0640 deploy/env/backup.env.example /etc/rust-toon/backup.env
sudo editor /etc/rust-toon/backup.env
sudo install -m 0644 deploy/systemd/rust-toon-postgres-backup.service /etc/systemd/system/
sudo install -m 0644 deploy/systemd/rust-toon-postgres-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-postgres-backup.timer
sudo systemctl start rust-toon-postgres-backup.service
sudo systemctl status rust-toon-postgres-backup.service
sudo systemctl list-timers rust-toon-postgres-backup.timer
```

timer 默认每天 03:15 执行，并有最多 15 分钟随机延迟。至少把一份备份同步到服务器之外的对象存储，并对异地副本配置独立保留策略。

### 恢复与演练

恢复会清理目标数据库中的同名对象，必须显式传入 `--confirm`。恢复前停止网关，避免恢复期间产生新写入：

```bash
sudo systemctl stop rust-toon-gateway
set -a
. /etc/rust-toon/backup.env
set +a
/opt/rust-toon/script/database/restore-postgres.sh \
  --backup /var/backups/rust-toon/postgresql/rust-toon-YYYYMMDDTHHMMSSZ.dump \
  --confirm
sudo systemctl start rust-toon-gateway
curl -fsS http://127.0.0.1:8080/health
```

推荐每月至少在临时数据库执行一次恢复演练，检查 `_sqlx_migrations`、管理员登录、项目数量和资产记录。`sql/bootstrap/current.sql` 是开发比对快照，不是生产备份，不能替代上述 dump。

数据库只保存 MinIO 对象键和元数据，图片、音频、视频等文件本体位于 MinIO。完整灾备必须同时备份 MinIO bucket（例如用 `mc mirror` 同步到异地对象存储），并确保数据库与对象备份的时间窗口一致。

### 升级顺序

1. 创建并校验数据库备份，同时完成 MinIO 增量同步。
2. 在备份副本上恢复并运行新版本网关，验证迁移。
3. 停止生产网关，执行最后一次备份。
4. 部署新二进制并启动；网关在监听端口前自动执行 SQLx 迁移。
5. 验证 `/health`、登录、项目和任务状态后再恢复外部流量。

## 首次管理员

仅首次部署设置：

```bash
export BOOTSTRAP_ADMIN_USERNAME=admin
export BOOTSTRAP_ADMIN_PASSWORD='替换为高强度密码'
```

管理员存在后可以移除 `BOOTSTRAP_ADMIN_PASSWORD`，网关会跳过初始化。不要把生产密码提交到仓库或镜像。

## 健康检查与日志

- 存活检查：`GET /health`
- OpenAPI 文档：`GET /openapi.json`
- 请求自动生成或透传 `x-request-id`
- 使用 `RUST_LOG=info` 或模块级过滤规则控制 tracing 输出

## 测试和发布检查

```bash
cargo fmt --all -- --check
cargo test --workspace
bash script/test-database-migrations.sh
bash script/test-ai-e2e.sh
pnpm --dir apps/web --filter @vben/web-antd run typecheck
pnpm --dir apps/web --filter @vben/web-antd run build
```

`test-ai-e2e.sh` 会启动临时 PostgreSQL，并用本地模拟模型验证 JWT、普通聊天、SSE、消息落库及 Midjourney Imagine/Action 状态机，不调用外部付费模型。

## 常见问题

- 网关提示 `DATABASE_URL is required`：未配置数据库连接串。
- 网关提示 JWT 密钥过短：`JWT_SECRET` 必须至少 32 字节。
- 没有初始管理员：确认首次启动时设置了 `BOOTSTRAP_ADMIN_PASSWORD`。
- SSE 到前端后一次性出现：关闭 Nginx/Ingress 的响应缓冲并增加读取超时。
- AI 任务一直处理中：检查模型配置的任务查询路径、鉴权头和供应商任务 ID；可调用 `/poll` 接口立即同步。
- 前端请求 404：确认 Vben API 基址或 Nginx `/api/` 转发是否去掉了正确的前缀。

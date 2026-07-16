# 启动、部署与运维

## 本地开发方案

1. 执行 `docker compose -f script/docker/docker-compose.yml up -d`。
2. 按 [配置文档](configuration.md) 导出数据库、JWT 和管理员环境变量。
3. 执行 `cargo run -p rust-toon-gateway`。
4. 在 `apps/web` 执行 `pnpm install && pnpm dev:antd`。
5. 检查 `GET http://127.0.0.1:8080/health`，然后访问 `http://127.0.0.1:5666`。

PostgreSQL 容器只创建空数据库。数据库结构统一由网关启动时的 SQLx Migrator 管理，禁止同时把 SQL 文件挂载进 `/docker-entrypoint-initdb.d`，否则无法可靠记录迁移版本。

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

- 迁移文件位于 `sql/postgresql`，版本号必须是唯一整数前缀。
- 网关连接数据库后、监听端口前自动执行迁移。
- 发布前运行 `bash script/test-database-migrations.sh`，验证空 PostgreSQL 18 可完成全部迁移。
- 已在生产执行的迁移不得修改；后续结构变化应新增更高版本迁移。
- 正式升级前必须备份数据库，并先在备份副本验证升级。

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

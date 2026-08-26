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

包含 PostgreSQL（5432）、Redis（6379）、启用持久化 JetStream 的 NATS（4222/8222）、MinIO（9000/9001）。也可以使用便捷脚本 `script/start-local.sh [infra|gateway|worker|backend|all]`：它会先起 compose，再按模式启动服务（自动导出本地默认环境变量）。`backend` 同时启动网关与 worker，`all` 再加上前端；单独调试时可用 `gateway` 或 `worker`。

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

另开一个终端启动持久任务 worker；最终成片合并由 worker 执行，网关节点不再需要安装 FFmpeg：

```bash
export DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon'
export NATS_URL='nats://127.0.0.1:4222'
export MINIO_ENDPOINT='http://127.0.0.1:9000'
export MINIO_ACCESS_KEY='rust_toon'
export MINIO_SECRET_KEY='rust_toon_password'
cargo run -p rust-toon-worker
```

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
bash script/test-distributed-deployment.sh
bash script/test-k8s-deployment.sh
bash script/test-distributed-jobs-e2e.sh
bash script/test-minio-backup.sh
pnpm --dir apps/web run test:unit
pnpm --dir apps/web --filter @vben/web-antd run typecheck
```

前端生产构建检查：`pnpm --dir apps/web --filter @vben/web-antd run build`。

## 3. 数据库迁移管理

- 迁移由网关启动时自动执行，迁移目录 `sql/postgresql`（当前 `0001`–`0006`）在编译期嵌入二进制；**不要**把该目录挂载到 PostgreSQL 的 initdb 目录。
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
sudo install -d -o "$(id -un)" -g "$(id -gn)" -m 0755 /opt/rust-toon
git clone <repo-url> /opt/rust-toon
cd /opt/rust-toon
```

`script/docker/docker-compose.yml` 使用开发口令并把全部基础设施端口发布到宿主机，**不得直接用于生产**。单服务器生产使用 4.5 节的分布式 compose；多服务器部署使用托管 PostgreSQL/Redis/S3 与三节点 JetStream，或自行提供等价的加固集群。

### 4.2 网关环境文件

在 git 之外创建 `/etc/rust-toon/gateway.env`（样例见 `deploy/env/gateway.env.example`）：

```bash
DATABASE_URL=postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon
DATABASE_MIN_CONNECTIONS=1
DATABASE_MAX_CONNECTIONS=12
REDIS_URL=redis://127.0.0.1:6379
JWT_SECRET=replace-with-a-strong-random-secret-at-least-32-bytes
MINIO_ENDPOINT=http://127.0.0.1:9000
MINIO_ACCESS_KEY=rust_toon
MINIO_SECRET_KEY=replace-with-a-strong-object-storage-secret
MINIO_BUCKET=rust-toon
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=8080
GATEWAY_DRAIN_DELAY_SECONDS=10
RUST_LOG=info
RUST_ENV=production
READINESS_REQUIRE_REDIS=true
READINESS_REQUIRE_MINIO=true
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=replace-with-a-strong-initial-password
```

`JWT_SECRET` 必须 ≥ 32 字节，否则启动失败。首次登录成功后将 `BOOTSTRAP_ADMIN_PASSWORD` 从环境文件中移除并重启服务。当前上传、生成片段和最终成片统一进入 MinIO/S3；旧版本遗留的 `storage/uploads` 应先用 `script/migrate-local-uploads-to-minio.sh` 迁移。AI 密钥落库加密可通过 `SECRET_ENCRYPTION_KEY` 独立指定（缺省回退 `JWT_SECRET`）。

### 4.3 构建与试运行

```bash
cargo build --release -p rust-toon-gateway -p rust-toon-worker
set -a; . /etc/rust-toon/gateway.env; set +a
./target/release/rust-toon-gateway
```

确认迁移与管理员就绪后 Ctrl+C 停止，交给 systemd 管理。

### 4.4 systemd

仓库提供样例 `deploy/systemd/rust-toon-gateway.service`（`User=rust-toon`、`EnvironmentFile=/etc/rust-toon/gateway.env`、开启 `ProtectSystem=strict` 等加固项；运行时对象进入 MinIO，不开放仓库目录写权限）：

```bash
sudo useradd --system --home /opt/rust-toon --shell /usr/sbin/nologin rust-toon
sudo install -d -o root -g rust-toon -m 0750 /etc/rust-toon
```

将 release 二进制/仓库安装到 unit 约定的 `/opt/rust-toon`。Worker 节点还必须安装 `ffmpeg` 和 `ffprobe`（Debian/Ubuntu 可执行 `sudo apt-get install -y ffmpeg`）。

```bash
sudo install -o root -g root -m 0644 \
  deploy/systemd/rust-toon-gateway.service /etc/systemd/system/
sudo install -o root -g rust-toon -m 0640 \
  deploy/env/gateway.env.example /etc/rust-toon/gateway.env
sudoedit /etc/rust-toon/gateway.env
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-gateway
sudo systemctl status rust-toon-gateway
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/readyz
```

在视频执行节点安装 `deploy/systemd/rust-toon-worker.service`，将 `deploy/env/toon-worker.env.example` 复制到 `/etc/rust-toon/toon-worker.env` 后替换凭据：

```bash
sudo install -o root -g root -m 0644 \
  deploy/systemd/rust-toon-worker.service /etc/systemd/system/
sudo install -o root -g rust-toon -m 0640 \
  deploy/env/toon-worker.env.example /etc/rust-toon/toon-worker.env
sudoedit /etc/rust-toon/toon-worker.env
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-worker
curl -fsS http://127.0.0.1:8081/readyz
```

网关与 worker 可以部署到不同服务器。应用集群必须共享 PostgreSQL 和 MinIO，所有 worker 还必须连接同一 JetStream；每个 worker 都使用独立实例 ID 和数据库租约，无需指定静态分片。当前 Agent/Workflow 运行协调仍含进程内状态，因此生产集群暂时只运行 **1 个 Gateway**；最终成片 worker 可以运行任意多个副本。待 Agent/Workflow 也迁到持久任务协议后，才能解除 Gateway 单副本限制。

单机 systemd 部署可用统一探针脚本检查网关、worker 和 JetStream；端点不在本机时通过同名环境变量覆盖：

```bash
bash script/check-distributed-health.sh
GATEWAY_READY_URL=https://api.example.com/readyz bash script/check-distributed-health.sh
```

Worker 默认只在 `127.0.0.1:8081` 暴露管理探针；远程节点通过主机监控 agent 或 `ssh worker-host curl -fsS http://127.0.0.1:8081/readyz` 检查，不要把管理端口直接暴露到公网。

### 4.5 Docker Compose 分布式部署

`script/docker/docker-compose.distributed.yml` 是独立的单机生产骨架，不继承本地 compose 的固定 `container_name`。业务流量只经 edge 进入；PostgreSQL、MinIO 和 NATS 监控端口仅绑定 loopback，供本机备份/监控使用。先用 `0600` 权限安装密钥文件，再启动 1 个 Gateway 和多个 worker：

```bash
sudo install -d -o root -g root -m 0700 /etc/rust-toon
sudo install -o root -g root -m 0600 \
  deploy/env/distributed.env.example /etc/rust-toon/distributed.env
sudoedit /etc/rust-toon/distributed.env

docker compose \
  --env-file /etc/rust-toon/distributed.env \
  -f script/docker/docker-compose.distributed.yml \
  config >/dev/null

docker compose \
  --env-file /etc/rust-toon/distributed.env \
  -f script/docker/docker-compose.distributed.yml \
  up -d --build --scale gateway=1 --scale toon-worker=4
```

如果使用 CI 已推送的镜像，则设置 `RUST_TOON_BACKEND_IMAGE`，显式拉取并禁止本地构建：

```bash
docker compose \
  --env-file /etc/rust-toon/distributed.env \
  -f script/docker/docker-compose.distributed.yml pull gateway toon-worker
docker compose \
  --env-file /etc/rust-toon/distributed.env \
  -f script/docker/docker-compose.distributed.yml \
  up -d --no-build --scale gateway=1 --scale toon-worker=4
```

`DATABASE_URL` 是完整 URI；若数据库密码含 `@`、`/`、`:`、`#` 或 `%`，必须在 URI 中 percent-encode，并保证解码后的密码与 `POSTGRES_PASSWORD` 相同。示例连接池预算为 1×12（Gateway）+ 4×8（worker）= 44，扩容 worker 前需按数据库 `max_connections` 重新核算并留出管理连接。

Nginx edge 会重新解析 Docker DNS，并在连接错误/502/503/504 时被动重试其他地址；它不主动消费容器 `/readyz`，因此这不是多 Gateway 的安全门禁。当前必须保持 Gateway=1。SSE 和 WebSocket 在连接建立后固定到该实例；edge access log 只记录 path，不记录可能包含临时凭据的 query，素材上传关闭请求缓冲并允许最大 2 GiB。检查探针和副本：

```bash
curl -fsS http://127.0.0.1:8080/readyz
docker compose \
  --env-file /etc/rust-toon/distributed.env \
  -f script/docker/docker-compose.distributed.yml ps
```

扩缩 worker 时重复 `up -d --scale gateway=1 --scale toon-worker=N`。worker 收到 SIGTERM 后立即停止领新任务，取消在途执行并用当前 fencing token 把尝试重新排队；整个过程受 `TOON_WORKER_DRAIN_TIMEOUT_SECONDS` 限制，数据库或网络故障时仍可在租约过期后由其他实例接管。`stop_grace_period` 必须大于 drain deadline，生产若提高它需同步提高容器停止宽限。Gateway 收到 SIGTERM 会先把 `/readyz` 置为不可用并等待 `GATEWAY_DRAIN_DELAY_SECONDS`，但单机 Compose 的 edge 只有被动故障重试；需要无损滚动 Gateway 时应由真正消费 readiness 的编排器/LB 摘流。

该 compose 不包含前端静态站；仍需按第 5 节使用 CDN/独立 Nginx 托管 `dist`，并把 `/api/` 指向 edge。Compose 中的 PostgreSQL、Redis、NATS 和 MinIO 是单机持久化数据面。高可用生产应替换为托管 PostgreSQL/Redis/对象存储及三节点 JetStream 集群。JetStream 卷用于降低恢复延迟，但业务任务真相源是 PostgreSQL outbox，因此不能用 NATS 消息替代数据库备份。

### 4.6 Kubernetes：1 Gateway + N Worker

`deploy/k8s` 提供生产基础清单，使用 Kustomize 管理以下资源：

- 固定单副本且使用 `Recreate` 更新策略的 Gateway Deployment/Service。Agent/Workflow 实时运行表仍有进程内状态，因此不能为 Gateway 配置 HPA，也不能把副本数改为 2；`Recreate` 会带来短暂升级窗口，并避免正常 Deployment 更新期间两个 revision 重叠。它不是分布式 leader lease，节点网络分区等极端场景仍需运维隔离故障节点。Gateway PDB 以 `minAvailable: 1` 阻止未协调的自愿驱逐，但不能消除节点故障或版本升级的单副本停机窗口；执行 node drain 前必须先安排维护窗口并临时调整/移除 PDB。
- 默认 2 副本的 Worker Deployment/Service、CPU HPA（2–8 副本）与 PDB。Worker 通过 PostgreSQL lease/fencing 和共享 JetStream durable consumer 横向扩容。
- `/livez`、`/readyz` 与启动探针、SIGTERM 宽限、non-root、只读根文件系统、默认 seccomp、移除 Linux capabilities、资源 request/limit 和临时盘上限。
- 默认拒绝入站/出站的 NetworkPolicy，以及 DNS、Gateway 入口、监控与外部依赖所需的最小端口规则。
- Gateway/Worker 临时目录使用有 `sizeLimit` 的 `emptyDir`；上传、生成片段和最终成片都写到共享 MinIO/S3，因此基础清单不创建无消费者的本地上传 PVC。

这些清单**不部署 PostgreSQL、Redis、NATS 或 MinIO**。部署前准备外部服务、支持 NetworkPolicy 的 CNI，以及供 HPA 使用的 Metrics Server。基础 HPA 最大 8 个 Worker；按示例连接池计算为 Gateway 12 + Worker 8×8 = 76 个数据库连接，修改上限或副本数时必须重新核算 PostgreSQL 连接预算。生产 JetStream 建议三副本；若外部集群的 replication factor 不同，应同步修改 `NATS_JOB_REPLICAS`。

先构建并推送 `deploy/docker/Dockerfile.backend`，使用不可变 tag 或 digest，然后修改 `deploy/k8s/kustomization.yaml` 的 `images` 条目。不要部署示例中的 `.invalid` 镜像/endpoint。修改两个 ConfigMap 中的 MinIO endpoint、桶和容量参数；敏感连接信息不要写入 ConfigMap 或 Git。

`deploy/k8s/secret.example.yaml` 仅列出 Secret key，故意不在 Kustomize resources 中，所有值都是不可用的 `REPLACE_ME`。它把 Gateway 的 JWT/Redis/管理员密钥与 Worker 的 NATS 密钥拆成两个最小权限 Secret，只有 PostgreSQL/MinIO 连接值需要分别写入两份。建议从权限为 `0600`、位于仓库外的文件或 External Secrets/Sealed Secrets 创建 `rust-toon-gateway-secrets` 和 `rust-toon-worker-secrets`。以下是文件方式的安装顺序：

```bash
kubectl apply -f deploy/k8s/namespace.yaml

sudo install -o "$(id -un)" -g "$(id -gn)" -m 0600 \
  deploy/k8s/secret.example.yaml /secure/path/rust-toon-secret.yaml
${EDITOR:-vi} /secure/path/rust-toon-secret.yaml
kubectl apply -f /secure/path/rust-toon-secret.yaml

# 确认已修改 image、MINIO_ENDPOINT 和 NATS_JOB_REPLICAS 后再安装。
kubectl apply -k deploy/k8s
```

`DATABASE_URL`、`REDIS_URL` 与 `NATS_URL` 均放在 Secret 中；URI 密码的保留字符必须 percent-encode，生产 Redis/NATS 应使用 TLS。`BOOTSTRAP_ADMIN_PASSWORD` 只用于首次启动：第一次成功登录并修改密码后，从 Secret 来源中删除该 key 并重新应用。基础清单使用固定名称的 ConfigMap/Secret，修改或轮换后必须显式执行 `kubectl -n rust-toon rollout restart deployment/rust-toon-gateway`，Worker 配置/密钥变更则重启 `deployment/rust-toon-worker`；等待对应 `rollout status` 成功后再结束变更。Gateway 使用 Recreate，重启期间会短暂不可用，需要在维护窗口执行。环境 overlay 也可以改用带内容哈希的 generator 或受控 reloader。更严格的生产集群应通过外部 Secret 控制器注入密钥，并对 Secret 启用静态加密与最小 RBAC。

全新数据库也可以一次性应用全部资源：Gateway 启动时先执行 SQLx 迁移；每个 Worker 的受限 init container 会持续访问 `rust-toon-gateway:8080/readyz`，只有迁移、管理员校验及 Gateway 必需依赖全部就绪后才启动 Worker。不要删除这个等待条件，也不要让 Worker 自行执行迁移。

基础 NetworkPolicy 只能按常用端口放行任意外部目的地，因为标准 Kubernetes NetworkPolicy 不支持 FQDN。请在环境 overlay 中把 PostgreSQL、Redis、NATS、MinIO 和 HTTPS provider egress 收窄为实际 CIDR，或使用 CNI 的 FQDN policy；若托管服务使用非默认端口也要同步调整。把 Ingress Controller 和监控组件所在 namespace 显式打标后才允许访问：

```bash
kubectl label namespace ingress-nginx rust-toon.io/gateway-access=true
kubectl label namespace monitoring rust-toon.io/monitoring-access=true
```

集群入口、TLS 证书和前端静态站依赖各环境的 Ingress/Gateway API 与证书控制器，因此基础清单不内置。将业务 `/api/` 流量转发到 `Service/rust-toon-gateway:8080`，保持 SSE/WebSocket 超时及关闭代理缓冲等要求。若集群 DNS Pod 不使用 `k8s-app=kube-dns` 标签，应在 overlay 中调整 DNS egress selector。

Gateway 与 Worker 默认输出 JSON 结构化日志并在各自管理 HTTP 端口开放 `/metrics`。Gateway 的 `/metrics` 与业务 API 同在 8080：标准 NetworkPolicy 只能按 IP/端口过滤，**不能按 URL path 阻断**，因此面向公网的 Ingress/Nginx 必须显式拒绝精确路径 `/metrics`（例如 Nginx `location = /metrics { return 404; }`），不得把它随 `/api/` 或 `/` 暴露。Pod 模板已经带有 `prometheus.io/*` 抓取注解；Prometheus 应通过 Kubernetes Pod/EndpointSlice 服务发现逐 Pod 抓取，不能把多副本 Worker 的 ClusterIP 当成单一静态目标，否则每次请求只会随机落到一个副本而漏掉其余进程内指标。Worker 8081 Service 只供集群内探针或监控发现使用。若使用 Prometheus Operator，可在环境 overlay 中按相同标签创建 PodMonitor。若启用注释示例 `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`，还必须仅向实际 Collector namespace/CIDR 放行其 4317 端口，不能在基础 egress 中全局开放该端口。

部署后检查：

```bash
kubectl -n rust-toon rollout status deployment/rust-toon-gateway --timeout=10m
kubectl -n rust-toon rollout status deployment/rust-toon-worker --timeout=15m
kubectl -n rust-toon get pods,service,hpa,pdb,networkpolicy
kubectl -n rust-toon port-forward service/rust-toon-gateway 8080:8080
curl -fsS http://127.0.0.1:8080/readyz
```

Gateway 在收到 SIGTERM 后先关闭 readiness 并等待 10 秒摘流，Pod 提供 45 秒终止宽限；Worker 停止领取任务并在 45 秒内把在途尝试安全重新排队，Pod 提供 75 秒宽限。不要把 Kubernetes 宽限缩短到应用 drain deadline 以下。基础清单把单 Pod 导出并发设为 1、Worker ephemeral-storage limit 设为 48 GiB、`/tmp` 的 `emptyDir` 设为 44 GiB，以容纳默认最多 10 GiB 源文件、规范化副本、最终输出和 FFmpeg 余量，并为容器日志/可写层保留 4 GiB；优先通过 Worker 副本扩容。Gateway 同样在 6 GiB limit 内只给 `/tmp` 分配 5 GiB。提高并发、分辨率或单任务上限前，必须用实际码率测算峰值并同步扩大 ephemeral-storage request/limit、`emptyDir.sizeLimit` 与节点磁盘预算。

无需集群即可验证 Kustomize 引用、YAML、单 Gateway 限制、探针、安全上下文、HPA/PDB 与 NetworkPolicy：

```bash
bash script/test-k8s-deployment.sh
```

脚本优先使用本机 `kubectl kustomize` 或 `kustomize build`；没有这两个工具时使用 Ruby YAML/语义检查，最后还有 POSIX 工具的最小 fallback。CI 会执行同一检查。

Kubernetes 环境的 PostgreSQL/对象备份优先使用托管服务 PITR、CSI VolumeSnapshot/S3 versioning 或同一恢复点能力；下面的 systemd 停写协调器用于仓库提供的单机/systemd 拓扑，不能直接当作 Kubernetes 多节点备份方案。

### 4.7 备份与恢复

仓库提供脚本与定时器样例：

分布式 compose 把 PostgreSQL/MinIO 维护端口绑定到 `MAINTENANCE_BIND_ADDRESS`（默认 `127.0.0.1`），因此宿主机上的现有备份脚本可直接使用 `postgres://...@127.0.0.1:${POSTGRES_MAINTENANCE_PORT}/rust_toon` 和 `http://127.0.0.1:${MINIO_MAINTENANCE_PORT}`；不要把维护地址改成公网网卡。

- `script/database/backup-consistent-set.sh`：生产定时备份入口。它按反向依赖顺序优雅停止 `BACKUP_SYSTEMD_UNITS` 中当时正在运行的 Worker/Gateway，等待写入完全静止，以同一个 `BACKUP_SET_ID` 依次执行 PostgreSQL 与 MinIO 备份并原子发布 set manifest，最后只恢复原先运行的服务。任一组件失败也会执行恢复服务的 trap，且不会发布完整 set manifest。
- `script/database/backup-postgres.sh`：一致性协调器使用的 `pg_dump` 组件，也可在已人工停写时单独执行；要求 `DATABASE_URL`。`BACKUP_DIR`（默认 `/var/backups/rust-toon/postgresql`）、`BACKUP_RETENTION_DAYS`（默认 14）控制目录与保留天数。
- `script/database/restore-postgres.sh`：恢复，`--backup FILE --database-url URL --confirm`。
- `script/database/backup-minio.sh`：一致性协调器使用的对象组件，使用 MinIO Client `mc` 镜像对象桶并生成逐对象 SHA-256 清单；配置 `MINIO_ENDPOINT`、`MINIO_ACCESS_KEY`、`MINIO_SECRET_KEY`、`MINIO_BUCKET` 和 `MINIO_BACKUP_DIR`，宿主机还需提供 `jq`。
- `script/database/restore-minio.sh`：严格校验 manifest 版本、bucket、普通文件全集和 SHA-256 清单后恢复对象；跨 bucket 恢复必须额外传入 `--allow-bucket-mismatch`。默认保留目标端额外对象，只有显式传入 `--delete-extra --confirm` 才执行镜像删除。
- `deploy/systemd/rust-toon-consistent-backup.service` + `.timer`：每日 03:15 触发唯一的一致性恢复集；旧的两个错峰 timer 已移除。单组件 service 仅供已人工停写后的诊断/补备份使用，不能把不同时间的组件产物拼成生产恢复集。

systemd 样例以 `rust-toon` 用户运行，启用前需安装 `mc`、创建可写目录并保护包含凭据的环境文件。以下示例为 Linux amd64；其他架构请从 MinIO 官方下载目录选择对应二进制：

```bash
sudo apt-get update && sudo apt-get install -y jq
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2025-04-16T18-13-26Z \
  -o /tmp/rust-toon-mc
sudo install -o root -g root -m 0755 /tmp/rust-toon-mc /usr/local/bin/mc
sudo install -d -o root -g root -m 0700 \
  /var/backups/rust-toon/postgresql /var/backups/rust-toon/minio /var/backups/rust-toon/sets
sudo install -d -o root -g rust-toon -m 0750 /etc/rust-toon
sudo install -o root -g root -m 0600 \
  deploy/env/backup.env.example /etc/rust-toon/backup.env
sudoedit /etc/rust-toon/backup.env
sudo install -o root -g root -m 0644 deploy/systemd/rust-toon-*-backup.service \
  deploy/systemd/rust-toon-*-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-consistent-backup.timer
sudo systemctl start rust-toon-consistent-backup.service
```

生产恢复必须按 `sets/rust-toon-<set-id>.json` 选择同一个 set-id 指向的 PostgreSQL 与 MinIO 产物，不能再按“时间相近”自行配对。恢复期间保持 Gateway/Worker 停止，依次恢复两者，最后通过 `/readyz`、成果视频抽查和对象引用审计后恢复流量。维护窗口会短暂停止生成与 API 服务；若业务不能接受停写，应改用支持同一 as-of 版本的对象存储 versioning/快照方案。建议同时开启异地复制或 object lock；文件级镜像不能替代这些能力。

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

location = /api/metrics {
    return 404;
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

要点：`X-Forwarded-For` 影响后端限流的客户端识别；SSE/流式响应需要关闭代理缓冲并加大读超时；WebSocket 端点（`/api/socket/{agent}`）依赖 Upgrade 头。生产跨域应在反代层控制，不要开启 `WEB_PERMISSIVE_CORS`。`/api/metrics` 必须在通用 `/api/` 代理规则之前精确拒绝；Prometheus 从内网直接抓 Gateway `/metrics`。

## 6. 持续集成

根目录 `.github/workflows/ci.yml`（GitHub）和 `.gitcode/workflows/ci.yml`（GitCode/AtomGit）是等价仓库门禁，覆盖 Rust fmt/Clippy/workspace tests、空库迁移、本地 mock AI Provider E2E、前端 typecheck/unit/build、启动真实 PostgreSQL、Redis、MinIO 和 gateway 的 HTTP/WebSocket 黑盒 E2E、FFmpeg 最终成片归档 E2E、两个 worker 对 JetStream/数据库租约的竞争与故障恢复，以及 MinIO 备份/恢复回环。仅供应商付费生成测试保持显式运行，不进入默认 CI。

## 7. 常见问题

- `DATABASE_URL is required`：未导出或未写入环境文件。
- JWT 启动报错：`JWT_SECRET` 必须至少 32 字节。
- 启动报 "no enabled super administrator"：数据库缺少基线超级管理员，检查迁移是否完整执行。
- 没有管理员账号：首次启动参考 `AGENTS.md` 设置 `BOOTSTRAP_ADMIN_PASSWORD`，账号建立后移除该变量。
- 前端 API 404：检查 `VITE_BASE_URL`、`VITE_GLOB_API_URL` 与 Nginx `/api/` 前缀处理。
- SSE 一次性返回：反代未关缓冲或读超时太短。
- 端口占用：`ss -ltnp | rg ':(8080|5666|5432|6379)'`。

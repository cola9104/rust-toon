# AI Startup Guide

This file is the handoff guide for AI coding agents working in this repository. Read it before starting services or changing deployment docs.

## Project Shape

- Backend: Rust workspace, HTTP gateway entrypoint at `services/gateway` and durable media worker at `services/toon-worker`.
- Frontend: Vben Admin app at `apps/web`, main app package `@vben/web-antd`.
- Database migrations: `sql/postgresql`, executed automatically by the Rust gateway on startup. `0001_initial.sql` is the consolidated schema and baseline data.
- Bootstrap reference: `sql/bootstrap/current.sql` is a reference-only `pg_dump` snapshot and is never loaded by the application. The migration chain is sufficient to initialize a new server without `current.sql`.
- Local infrastructure: PostgreSQL, Redis, NATS, and MinIO via `script/docker/docker-compose.yml`.

The durable worker is horizontally scalable. Keep the current Gateway at one production replica: Toon Agent/Workflow live-run registries are still process-local even though video export and cleanup jobs are distributed. Do not advertise or configure Gateway horizontal scaling until those realtime runtimes are migrated to durable workers.

Do not mount `sql/postgresql` into PostgreSQL init scripts. The gateway owns database initialization through SQLx, and PostgreSQL should start as an empty database.

## Database Change Workflow

Whenever a database schema or baseline-data change is made:

1. Add a new numbered migration under `sql/postgresql`; never edit a migration that has already been released or applied.
2. Make the migration idempotent so both upgraded databases and empty-database bootstrap are supported.
3. Run `bash script/test-database-migrations.sh` to prove an empty PostgreSQL instance reaches the latest schema and baseline data without importing `current.sql`.
4. After applying all migrations to a clean reference database, export a fresh `sql/bootstrap/current.sql` with `pg_dump` for review and comparison. The gateway must remain fully functional when this snapshot is absent.
5. Update the expected migration count and relevant baseline assertions in `crates/framework/database/tests/migrations.rs`.

The migration history was intentionally reset to the consolidated `0001_initial.sql`; existing databases must be recreated once. After this reset is released, do not rewrite `0001` or any subsequently applied migration.

## Local Development Startup

From the repository root:

```bash
docker compose -f script/docker/docker-compose.yml up -d
```

Start the backend gateway:

```bash
export DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon'
export REDIS_URL='redis://127.0.0.1:6379'
export JWT_SECRET='local-development-jwt-secret-change-me-32bytes'
export BOOTSTRAP_ADMIN_USERNAME='admin'
export BOOTSTRAP_ADMIN_PASSWORD='Admin#123456'
export RUST_LOG='info'
cargo run -p rust-toon-gateway
```

After the gateway has applied migrations, start the durable worker in a second terminal:

```bash
export DATABASE_URL='postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon'
export NATS_URL='nats://127.0.0.1:4222'
export MINIO_ENDPOINT='http://127.0.0.1:9000'
export MINIO_ACCESS_KEY='rust_toon'
export MINIO_SECRET_KEY='rust_toon_password'
cargo run -p rust-toon-worker
```

The gateway owns migrations; on a clean database, do not start the worker until gateway `/readyz` succeeds. The worker owns FFmpeg execution, durable task dispatch, expired-lease recovery, and object cleanup. It exposes `/livez` and `/readyz` on port `8081` by default.

In a third terminal, start the frontend:

```bash
cd apps/web
corepack enable
pnpm install
pnpm dev:antd
```

Open:

- Frontend: `http://127.0.0.1:5666`
- Backend health: `http://127.0.0.1:8080/health`
- Backend liveness/readiness: `http://127.0.0.1:8080/livez`, `http://127.0.0.1:8080/readyz`
- Worker liveness/readiness: `http://127.0.0.1:8081/livez`, `http://127.0.0.1:8081/readyz`
- OpenAPI: `http://127.0.0.1:8080/openapi.json`
- MinIO console: `http://127.0.0.1:9001`

Default local bootstrap account:

- Username: `admin`
- Password: `Admin#123456`

`BOOTSTRAP_ADMIN_PASSWORD` is only used to create the initial admin when it does not exist. If the database already has admins, startup skips creating another one.

## Local Verification

Use these checks after startup:

```bash
curl -fsS http://127.0.0.1:8080/health
cargo test --workspace
bash script/test-database-migrations.sh
bash script/test-gateway-e2e.sh
bash script/test-production-e2e.sh
bash script/test-distributed-jobs-e2e.sh
bash script/test-minio-backup.sh
pnpm --dir apps/web run test:unit
pnpm --dir apps/web --filter @vben/web-antd run typecheck
```

Frontend production build check:

```bash
pnpm --dir apps/web --filter @vben/web-antd run build
```

## New Server Startup

Install prerequisites:

- Rust stable with Rust 2024 edition support.
- Docker and Docker Compose.
- Node.js `22.18+`.
- pnpm `11+` through Corepack.
- Nginx or another reverse proxy for production frontend/API routing.
- FFmpeg and FFprobe on media worker nodes (the gateway does not execute video merges).

Clone and enter the repository:

```bash
git clone <repo-url> rust-toon
cd rust-toon
```

Start infrastructure. For a single-server deployment, the repository compose file is enough:

```bash
docker compose -f script/docker/docker-compose.yml up -d
```

For managed PostgreSQL or Redis, skip those compose services and set `DATABASE_URL` / `REDIS_URL` to the managed endpoints.

Create a backend environment file outside git, for example `/etc/rust-toon/gateway.env`:

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

Build the gateway and worker:

```bash
cargo build --release -p rust-toon-gateway -p rust-toon-worker
```

Run once manually to verify migrations and initial admin creation:

```bash
set -a
. /etc/rust-toon/gateway.env
set +a
./target/release/rust-toon-gateway
```

After the first successful login, remove `BOOTSTRAP_ADMIN_PASSWORD` from `/etc/rust-toon/gateway.env` and restart the service.

Create `/etc/rust-toon/toon-worker.env` from `deploy/env/toon-worker.env.example`, using the same PostgreSQL, NATS, and MinIO endpoints as the gateway. Start `rust-toon-worker` only after the gateway has completed migrations. Multiple worker replicas share the same JetStream durable consumer and PostgreSQL leases; use a unique `TOON_WORKER_INSTANCE_ID` per static systemd instance or leave it unset for an automatically generated ID.

Scale media capacity by adding worker replicas, not Gateway replicas. The current production topology is Gateway `1` + Toon Worker `N`; this preserves existing Toonflow HTTP/WebSocket behavior while long-running media work remains durable across worker failures.

## systemd Service

Use systemd or another process manager in production. Example `/etc/systemd/system/rust-toon-gateway.service`:

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

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rust-toon-gateway
sudo systemctl enable --now rust-toon-worker
sudo systemctl status rust-toon-gateway
sudo systemctl status rust-toon-worker
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/readyz
curl -fsS http://127.0.0.1:8081/readyz
```

## Frontend Production

Build the frontend:

```bash
corepack enable
pnpm --dir apps/web install --frozen-lockfile
pnpm --dir apps/web --filter @vben/web-antd run build
```

Static output:

```text
apps/web/apps/web-antd/dist
```

Serve that directory through Nginx or a CDN. Route SPA paths to `index.html`, and reverse proxy API traffic to the gateway.

Minimal Nginx location rules:

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

## Backups

Back up PostgreSQL and MinIO as one recovery set. The repository provides:

```bash
sudo bash script/database/backup-consistent-set.sh
```

The coordinator gracefully stops the configured Gateway/Worker systemd units, runs both component backups with the same `BACKUP_SET_ID`, publishes a set manifest, and restarts only units that were active. The matching restore scripts require an explicit `--confirm`. Example systemd units and the single consistent timer are under `deploy/systemd` and use `/etc/rust-toon/backup.env`.

## Common Problems

- `DATABASE_URL is required`: export it or add it to the systemd environment file.
- JWT startup error: `JWT_SECRET` must be at least 32 bytes.
- No admin account: set `BOOTSTRAP_ADMIN_PASSWORD` for the first startup, then remove it after the account exists.
- Frontend API 404: check `VITE_BASE_URL`, `VITE_GLOB_API_URL`, and Nginx `/api/` proxy prefix handling.
- SSE responses arrive all at once: disable proxy buffering and increase read timeout.
- `/readyz` returns 503: inspect the per-dependency checks and verify PostgreSQL plus required Redis/MinIO/FFmpeg endpoints.
- Queued video exports never start: verify at least one worker is ready and NATS has JetStream enabled; check `toonflow.distributed_jobs` for `last_error` and lease state.
- Port already in use: check `ss -ltnp | rg ':(8080|8081|5666|4222|5432|6379)'`.

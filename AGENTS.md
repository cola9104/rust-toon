# AI Startup Guide

This file is the handoff guide for AI coding agents working in this repository. Read it before starting services or changing deployment docs.

## Project Shape

- Backend: Rust workspace, gateway entrypoint at `services/gateway`.
- Frontend: Vben Admin app at `apps/web`, main app package `@vben/web-antd`.
- Database migrations: `sql/postgresql`, executed automatically by the Rust gateway on startup.
- Local infrastructure: PostgreSQL, Redis, NATS, and MinIO via `script/docker/docker-compose.yml`.

Do not mount `sql/postgresql` into PostgreSQL init scripts. The gateway owns migrations through SQLx, and PostgreSQL should start as an empty database.

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

In a second terminal, start the frontend:

```bash
cd apps/web
corepack enable
pnpm install
pnpm dev:antd
```

Open:

- Frontend: `http://127.0.0.1:5666`
- Backend health: `http://127.0.0.1:8080/health`
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
- Node.js `22.18+` or `24.x`.
- pnpm `11+` through Corepack.
- Nginx or another reverse proxy for production frontend/API routing.

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
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=8080
RUST_LOG=info
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=replace-with-a-strong-initial-password
```

Build the backend:

```bash
cargo build --release -p rust-toon-gateway
```

Run once manually to verify migrations and initial admin creation:

```bash
set -a
. /etc/rust-toon/gateway.env
set +a
./target/release/rust-toon-gateway
```

After the first successful login, remove `BOOTSTRAP_ADMIN_PASSWORD` from `/etc/rust-toon/gateway.env` and restart the service.

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
sudo systemctl status rust-toon-gateway
curl -fsS http://127.0.0.1:8080/health
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
}
```

## Common Problems

- `DATABASE_URL is required`: export it or add it to the systemd environment file.
- JWT startup error: `JWT_SECRET` must be at least 32 bytes.
- No admin account: set `BOOTSTRAP_ADMIN_PASSWORD` for the first startup, then remove it after the account exists.
- Frontend API 404: check `VITE_BASE_URL`, `VITE_GLOB_API_URL`, and Nginx `/api/` proxy prefix handling.
- SSE responses arrive all at once: disable proxy buffering and increase read timeout.
- Port already in use: check `ss -ltnp | rg ':(8080|5666|5432|6379)'`.
